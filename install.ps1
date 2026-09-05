#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Revert,
    [switch]$Backup
)

$ErrorActionPreference = 'Stop'

# ============================================
# Dotfiles Installer — Windows
# Strategy: Symlink regular files directly; for .template files, materialize
# inside the repo first, then symlink the materialized result.
# Everything deployed to %USERPROFILE% is a symlink, so edits feed back to the repo.
#
# Usage: .\install.ps1            (install/update symlinks)
#        .\install.ps1 -Revert    (convert existing symlinks back into standalone files)
#        .\install.ps1 -Backup    (copy local secret files into repo\backup, outside git)
# ============================================

$RepoRoot       = $PSScriptRoot
$PlatformDir    = Join-Path $RepoRoot 'Windows'
$BackupDir      = Join-Path $env:USERPROFILE ("dotfiles_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$PrivateBackupDir = Join-Path $RepoRoot 'backup'

# Color output functions
function Write-Info  { param([string]$Message) Write-Host "[INFO] $Message"  -ForegroundColor Cyan    }
function Write-Ok    { param([string]$Message) Write-Host "[OK] $Message"    -ForegroundColor Green   }
function Write-Warn  { param([string]$Message) Write-Host "[WARN] $Message"  -ForegroundColor Yellow  }
function Write-ErrorColored { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red     }

# --------------------------------------------
# Platform detection
# --------------------------------------------
function Test-WindowsPlatform {
    return ($env:OS -eq 'Windows_NT')
}

# --------------------------------------------
# Symlink permission check
# Creating symlinks on Windows requires admin rights or Developer Mode
# --------------------------------------------
function Test-SymlinkPermission {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }

    try {
        $devMode = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
                                    -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop
        if ($devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
            return $true
        }
    } catch {
        # Registry key does not exist or is inaccessible
    }

    return $false
}

# --------------------------------------------
# Path mapping: resolve Windows/ relative path to actual target path
# Supports AppData special path mapping
# --------------------------------------------
function Resolve-TargetPath {
    param([string]$RelativePath)

    $relPath = $RelativePath -replace '\\', '/'

    if ($relPath -like 'AppData/Roaming/*') {
        $subPath = ($relPath.Substring('AppData/Roaming/'.Length) -replace '/', '\')
        return Join-Path $env:APPDATA $subPath
    }
    if ($relPath -like 'AppData/Local/*') {
        $subPath = ($relPath.Substring('AppData/Local/'.Length) -replace '/', '\')
        return Join-Path $env:LOCALAPPDATA $subPath
    }
    if ($relPath -like 'AppData/LocalLow/*') {
        $subPath = ($relPath.Substring('AppData/LocalLow/'.Length) -replace '/', '\')
        return Join-Path (Join-Path $env:USERPROFILE 'AppData\LocalLow') $subPath
    }

    # Default: map to USERPROFILE
    return Join-Path $env:USERPROFILE ($relPath -replace '/', '\')
}

# --------------------------------------------
# Backup existing target file/directory/symlink
# Preserves directory structure for easy restoration
# --------------------------------------------
function Backup-Target {
    param([string]$TargetPath)

    if (Test-Path $TargetPath) {
        $relPath     = $TargetPath.Substring($env:USERPROFILE.Length + 1)
        $backupPath  = Join-Path $BackupDir $relPath
        $backupParent = Split-Path -Parent $backupPath

        if (-not (Test-Path $backupParent)) {
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }

        Move-Item -Path $TargetPath -Destination $backupPath -Force
        Write-Warn "Backed up → $backupPath"
    }
}

# --------------------------------------------
# Create a symbolic link without requiring elevation
# Windows PowerShell 5.1's New-Item -ItemType SymbolicLink omits
# SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE, so it always demands admin
# even with Developer Mode on. Call the Win32 API directly with that flag instead.
# --------------------------------------------
Add-Type -Namespace DotfilesNative -Name SymLink -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CreateSymbolicLink(string lpSymlinkFileName, string lpTargetFileName, int dwFlags);
'@

function New-Symlink {
    param([string]$Path, [string]$Value)

    # SYMBOLIC_LINK_FLAG_FILE (0) | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE (2)
    $ok = [DotfilesNative.SymLink]::CreateSymbolicLink($Path, $Value, 2)
    if (-not $ok) {
        $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Failed to create symbolic link '$Path' -> '$Value' (Win32 error $errCode)"
    }
}

# --------------------------------------------
# Create symlink (unified entry point)
# src: source file path inside the repo
# --------------------------------------------
function New-DotfileSymlink {
    param([string]$SourcePath)

    $relPath = ($SourcePath.Substring($PlatformDir.Length + 1) -replace '\\', '/')
    $dstPath = Resolve-TargetPath -RelativePath $relPath

    # Ensure target directory exists
    $dstParent = Split-Path -Parent $dstPath
    if (-not (Test-Path $dstParent)) {
        New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
    }

    # Backup existing target
    Backup-Target -TargetPath $dstPath

    # Defensive cleanup (Backup-Target should have moved it, but just in case)
    if (Test-Path $dstPath) {
        Remove-Item -Path $dstPath -Recurse -Force
    }

    # Create symbolic link
    New-Symlink -Path $dstPath -Value $SourcePath
    Write-Ok "Linked $relPath"
}

# --------------------------------------------
# Revert: convert an existing managed symlink back into a standalone file
# Reads through the symlink to capture its resolved content, then replaces
# the symlink with a plain file holding that content. The repo is untouched.
# --------------------------------------------
function Invoke-RevertTarget {
    param([string]$TargetPath)

    $item = Get-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue
    if (-not $item -or $item.LinkType -ne 'SymbolicLink') {
        return $false
    }

    $bytes = [System.IO.File]::ReadAllBytes($TargetPath)
    Remove-Item -LiteralPath $TargetPath -Force
    [System.IO.File]::WriteAllBytes($TargetPath, $bytes)
    return $true
}

# --------------------------------------------
# Revert all managed paths (mirrors the file enumeration used by Main)
# --------------------------------------------
function Invoke-RevertAll {
    $revertCount = 0

    $templateFiles = Get-ChildItem -Path $PlatformDir -Recurse -File -Filter '*.template'
    foreach ($templateFile in $templateFiles) {
        $realFilePath = $templateFile.FullName -replace '\.template$', ''
        $relPath = ($realFilePath.Substring($PlatformDir.Length + 1) -replace '\\', '/')
        $dstPath = Resolve-TargetPath -RelativePath $relPath
        if (Invoke-RevertTarget -TargetPath $dstPath) {
            Write-Ok "Reverted $relPath"
            $revertCount++
        }
    }

    $allFiles = Get-ChildItem -Path $PlatformDir -Recurse -File | Where-Object { $_.Extension -ne '.template' }
    foreach ($file in $allFiles) {
        $relativePath = ($file.FullName.Substring($PlatformDir.Length + 1) -replace '\\', '/')
        if (Test-Path ($file.FullName + '.template')) { continue }

        $dstPath = Resolve-TargetPath -RelativePath $relativePath
        if (Invoke-RevertTarget -TargetPath $dstPath) {
            Write-Ok "Reverted $relativePath"
            $revertCount++
        }
    }

    Write-Host ""
    Write-Ok "Revert complete. $revertCount symlink(s) converted to standalone files."
    Write-Info "The repo itself was untouched; these files are now decoupled from it."
}

# --------------------------------------------
# Back up one materialized secret file into repo\backup, mirroring its
# path under Windows\. Used by -Backup so gitignored files (real
# configs generated from .template) survive outside of git.
# Returns $true if a file was copied, $false if nothing to back up yet.
# --------------------------------------------
function Backup-PrivateFile {
    param([string]$RealFilePath)

    if (-not (Test-Path $RealFilePath)) {
        return $false
    }

    $relPath  = $RealFilePath.Substring($PlatformDir.Length + 1)
    $destPath = Join-Path (Join-Path $PrivateBackupDir 'Windows') $relPath

    # Drop any stale backup before copying the current version in its place
    if (Test-Path $destPath) {
        Remove-Item -Path $destPath -Force
    }

    $destParent = Split-Path -Parent $destPath
    if (-not (Test-Path $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    Copy-Item -Path $RealFilePath -Destination $destPath -Force
    Write-Ok "Backed up Windows/$relPath"
    return $true
}

# --------------------------------------------
# Back up every materialized secret file (mirrors the .template
# enumeration used by Main)
# --------------------------------------------
function Invoke-PrivacyBackup {
    $templateFiles = Get-ChildItem -Path $PlatformDir -Recurse -File -Filter '*.template'
    $backupCount  = 0
    $skippedCount = 0

    foreach ($templateFile in $templateFiles) {
        $realFilePath = $templateFile.FullName -replace '\.template$', ''
        if (Backup-PrivateFile -RealFilePath $realFilePath) {
            $backupCount++
        } else {
            $relPath = $realFilePath.Substring($PlatformDir.Length + 1)
            Write-Info "Skipping (not materialized yet): $relPath"
            $skippedCount++
        }
    }

    Write-Host ""
    Write-Ok "Privacy backup complete. $backupCount file(s) backed up, $skippedCount skipped."
    Write-Info "Backup location: $PrivateBackupDir"
    Write-Warn "This folder holds secrets — it stays out of git (see .gitignore)."
}

# --------------------------------------------
# Materialize a .template file inside the repo
# Returns $true if newly generated, $false if already exists
# --------------------------------------------
function Invoke-TemplateMaterialize {
    param([string]$TemplatePath)

    $realFilePath = $TemplatePath -replace '\.template$', ''

    if (Test-Path $realFilePath) {
        Write-Info "Materialized file already exists: $($realFilePath.Substring($RepoRoot.Length + 1))"
        return $false
    }

    Copy-Item -Path $TemplatePath -Destination $realFilePath -Force
    Write-Warn "Generated from template: $($realFilePath.Substring($RepoRoot.Length + 1))"
    return $true
}

# --------------------------------------------
# Main flow
# --------------------------------------------
function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Dotfiles Installer (Windows)                     ║" -ForegroundColor Cyan
    Write-Host "║  Regular files → direct symlink                            ║" -ForegroundColor Cyan
    Write-Host "║  .template → materialize in repo → symlink result          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Platform check
    if (-not (Test-WindowsPlatform)) {
        Write-ErrorColored "This script only supports Windows."
        exit 1
    }

    if (-not (Test-Path $PlatformDir)) {
        Write-ErrorColored "$PlatformDir not found. Please run this script from the repo root."
        exit 1
    }

    if ($Revert -and $Backup) {
        Write-ErrorColored "-Revert and -Backup are mutually exclusive. Run one at a time."
        exit 1
    }

    if ($Revert) {
        Write-Info "Running in -Revert mode: symlinks will be converted back to standalone files."
        Invoke-RevertAll
        return
    }

    if ($Backup) {
        Write-Info "Running in -Backup mode: local secret files will be copied into backup\."
        Invoke-PrivacyBackup
        return
    }

    # Execution policy check
    $execPolicy = Get-ExecutionPolicy
    if ($execPolicy -eq 'Restricted') {
        Write-Warn "Current PowerShell execution policy is Restricted. Cannot run scripts."
        Write-Info "Please run one of the following commands and try again:"
        Write-Host "    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" -ForegroundColor White
        Write-Host "    or" -ForegroundColor DarkGray
        Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor White
        exit 1
    }

    # Symlink permission check
    if (-not (Test-SymlinkPermission)) {
        Write-Warn "Current user does not have permission to create symbolic links."
        Write-Host ""
        Write-Host "Windows requires one of the following to create symlinks:" -ForegroundColor Yellow
        Write-Host "  1. Run PowerShell as Administrator" -ForegroundColor White
        Write-Host "  2. Enable Developer Mode (Settings → Privacy & Security → Developer Mode)" -ForegroundColor White
        Write-Host ""
        Write-Info "This script always uses symbolic links and will not fall back to file copies."
        Write-Info "Please satisfy one of the above conditions and re-run."
        exit 1
    }

    Write-Info "Backup directory: $BackupDir"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $linkCount      = 0
    $generatedCount = 0

    # ========================================
    # Phase 1: Process all .template files
    # ========================================
    $templateFiles = Get-ChildItem -Path $PlatformDir -Recurse -File -Filter '*.template'
    foreach ($templateFile in $templateFiles) {
        # 1. Materialize: copy template to real file inside the repo
        $wasGenerated = Invoke-TemplateMaterialize -TemplatePath $templateFile.FullName
        if ($wasGenerated) { $generatedCount++ }

        # 2. Create symlink from %USERPROFILE% to the materialized real file
        $realFilePath = $templateFile.FullName -replace '\.template$', ''
        New-DotfileSymlink -SourcePath $realFilePath
        $linkCount++
    }

    # ========================================
    # Phase 2: Process regular files
    # Skip files that have a corresponding .template (already linked in Phase 1)
    # ========================================
    $allFiles = Get-ChildItem -Path $PlatformDir -Recurse -File | Where-Object { $_.Extension -ne '.template' }
    foreach ($file in $allFiles) {
        $relativePath = ($file.FullName.Substring($PlatformDir.Length + 1) -replace '\\', '/')
        $templatePath = $file.FullName + '.template'

        if (Test-Path $templatePath) {
            Write-Info "Skipping: $relativePath (managed by corresponding template)"
            continue
        }

        New-DotfileSymlink -SourcePath $file.FullName
        $linkCount++
    }

    # ========================================
    # Summary
    # ========================================
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Ok "Deployment complete!"
    Write-Info "Total symlinks:       $linkCount"
    Write-Info "Newly materialized:   $generatedCount"
    Write-Info "Backup location:      $BackupDir"
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    if ($generatedCount -gt 0) {
        Write-Warn "Sensitive config files were generated from templates. Please edit them manually."
        Write-Info "These files are excluded by .gitignore and will not be committed. Secrets stay local."
        Write-Info "When moving to a new machine, re-run install.ps1 to materialize templates and fill in secrets."
    }

    Write-Warn "Some configurations require logging out and back in to take full effect."
}

Main
