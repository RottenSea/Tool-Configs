#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================
# Dotfiles Installer — Windows
# 对应 install.sh 的 Windows 端实现。
# 策略：普通文件直接软链接；.template 文件先在仓库内物化，再对物化结果软链接。
# 所有最终部署到 %USERPROFILE% 的都是软链接，修改直接反馈到仓库。
# ============================================

$RepoRoot    = $PSScriptRoot
$PlatformDir = Join-Path $RepoRoot 'windows'
$BackupDir   = Join-Path $env:USERPROFILE ("dotfiles_backup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))

# 颜色输出函数
function Write-Info         { param([string]$Message) Write-Host "[INFO]  $Message"  -ForegroundColor Cyan    }
function Write-Ok           { param([string]$Message) Write-Host "[OK]    $Message"  -ForegroundColor Green   }
function Write-Warn         { param([string]$Message) Write-Host "[WARN]  $Message"  -ForegroundColor Yellow  }
function Write-ErrorColored { param([string]$Message) Write-Host "[ERROR] $Message"  -ForegroundColor Red     }

# --------------------------------------------
# 平台检测
# --------------------------------------------
function Test-WindowsPlatform {
    return ($env:OS -eq 'Windows_NT')
}

# --------------------------------------------
# 符号链接权限检测
# Windows 创建符号链接需要管理员权限或开发者模式
# --------------------------------------------
function Test-SymlinkPermission {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }

    try {
        $devMode = Get-ItemProperty `
            -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
            -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop
        if ($devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
            return $true
        }
    } catch {
        # 注册表项不存在或无法访问
    }

    return $false
}

# --------------------------------------------
# 路径映射：将 windows/ 下的相对路径解析为实际目标路径
# 支持 AppData 特殊路径映射
# --------------------------------------------
function Resolve-TargetPath {
    param([string]$RelativePath)

    $relPath = $RelativePath -replace '\\', '/'

    if ($relPath -like 'AppData/Roaming/*') {
        $subPath = $relPath.Substring('AppData/Roaming/'.Length) -replace '/', '\'
        return Join-Path $env:APPDATA $subPath
    }
    if ($relPath -like 'AppData/Local/*') {
        $subPath = $relPath.Substring('AppData/Local/'.Length) -replace '/', '\'
        return Join-Path $env:LOCALAPPDATA $subPath
    }
    if ($relPath -like 'AppData/LocalLow/*') {
        $subPath = $relPath.Substring('AppData/LocalLow/'.Length) -replace '/', '\'
        return Join-Path (Join-Path $env:USERPROFILE 'AppData\LocalLow') $subPath
    }

    return Join-Path $env:USERPROFILE ($relPath -replace '/', '\')
}

# --------------------------------------------
# 备份已存在的目标文件/目录/链接
# 保持目录结构，便于一键恢复
# --------------------------------------------
function Backup-Target {
    param([string]$TargetPath)

    if (Test-Path $TargetPath) {
        $relPath      = $TargetPath.Substring($env:USERPROFILE.Length + 1)
        $backupPath   = Join-Path $BackupDir $relPath
        $backupParent = Split-Path -Parent $backupPath

        if (-not (Test-Path $backupParent)) {
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }

        Move-Item -Path $TargetPath -Destination $backupPath -Force
        Write-Warn "已备份 → $backupPath"
    }
}

# --------------------------------------------
# 创建软链接（统一入口）
# src: 仓库内的源文件路径
# --------------------------------------------
function New-DotfileSymlink {
    param([string]$SourcePath)

    $relPath = $SourcePath.Substring($PlatformDir.Length + 1) -replace '\\', '/'
    $dstPath = Resolve-TargetPath -RelativePath $relPath

    $dstParent = Split-Path -Parent $dstPath
    if (-not (Test-Path $dstParent)) {
        New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
    }

    Backup-Target -TargetPath $dstPath

    if (Test-Path $dstPath) {
        Remove-Item -Path $dstPath -Recurse -Force
    }

    New-Item -ItemType SymbolicLink -Path $dstPath -Value $SourcePath | Out-Null
    Write-Ok "链接 $relPath"
}

# --------------------------------------------
# 模板物化：扫描 __VAR_NAME__ 占位符并交互式填充
# 返回是否新生成了物化文件
# --------------------------------------------
function Invoke-TemplateMaterialize {
    param([string]$TemplatePath)

    $realPath = $TemplatePath -replace '\.template$', ''

    if (Test-Path $realPath) {
        Write-Info "物化文件已存在: $($realPath.Substring($RepoRoot.Length + 1))"
        return $false
    }

    $content = Get-Content -Raw -Path $TemplatePath

    $pattern  = '__VAR_([A-Z_][A-Z0-9_]*)__'
    $matches  = [regex]::Matches($content, $pattern)
    $varNames = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

    if ($varNames) {
        Write-Host ""
        Write-Host "正在处理模板: $($TemplatePath.Substring($RepoRoot.Length + 1))" -ForegroundColor Magenta
        $varCache = @{}

        foreach ($varName in $varNames) {
            if ($varCache.ContainsKey($varName)) {
                $value = $varCache[$varName]
            } else {
                $prompt = "请输入 __${varName}__ 的值 (直接回车保留占位符)"
                $value  = Read-Host -Prompt $prompt

                if ([string]::IsNullOrWhiteSpace($value)) {
                    Write-Warn "保留占位符 __VAR_${varName}__"
                    $value = "__VAR_${varName}__"
                }
                $varCache[$varName] = $value
            }

            $content = $content -replace "__VAR_${varName}__", $value
        }
    }

    Set-Content -NoNewline -Path $realPath -Value $content
    Write-Warn "从模板生成: $($realPath.Substring($RepoRoot.Length + 1))"
    return $true
}

# --------------------------------------------
# 主流程
# --------------------------------------------
function Main {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "           Dotfiles Installer (Windows)                    " -ForegroundColor Cyan
    Write-Host "  普通文件 -> 直接软链接                                   " -ForegroundColor Cyan
    Write-Host "  .template -> 仓库内物化 -> 对物化结果软链接               " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-WindowsPlatform)) {
        Write-ErrorColored "当前脚本仅支持 Windows。"
        exit 1
    }

    if (-not (Test-Path $PlatformDir)) {
        Write-ErrorColored "未找到 $PlatformDir，请在仓库根目录运行此脚本。"
        exit 1
    }

    $execPolicy = Get-ExecutionPolicy
    if ($execPolicy -eq 'Restricted') {
        Write-Warn "当前 PowerShell 执行策略为 Restricted，无法运行脚本。"
        Write-Info "请运行以下命令后重试："
        Write-Host "    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" -ForegroundColor White
        Write-Host "    或" -ForegroundColor DarkGray
        Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor White
        exit 1
    }

    if (-not (Test-SymlinkPermission)) {
        Write-Warn "检测到当前用户没有创建符号链接的权限。"
        Write-Host ""
        Write-Host "Windows 创建符号链接需要以下任一条件：" -ForegroundColor Yellow
        Write-Host "  1. 以管理员身份运行 PowerShell" -ForegroundColor White
        Write-Host "  2. 开启开发者模式（设置 -> 隐私和安全性 -> 开发者模式）" -ForegroundColor White
        Write-Host ""
        Write-Info "本脚本始终使用符号链接进行部署，不会回退到文件复制。"
        Write-Info "请满足上述条件之一后重新运行。"
        exit 1
    }

    Write-Info "备份目录: $BackupDir"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $linkCount      = 0
    $generatedCount = 0

    # 第一阶段：处理所有 .template 文件
    $templateFiles = Get-ChildItem -Path $PlatformDir -Recurse -File -Filter '*.template'
    foreach ($templateFile in $templateFiles) {
        $realFilePath = $templateFile.FullName -replace '\.template$', ''

        $wasGenerated = Invoke-TemplateMaterialize -TemplatePath $templateFile.FullName
        if ($wasGenerated) { $generatedCount++ }

        New-DotfileSymlink -SourcePath $realFilePath
        $linkCount++
    }

    # 第二阶段：处理普通文件
    # 跳过已有对应 .template 的文件（它们已在第一阶段被链接）
    $allFiles = Get-ChildItem -Path $PlatformDir -Recurse -File |
        Where-Object { $_.Extension -ne '.template' }
    foreach ($file in $allFiles) {
        $templatePath = $file.FullName + '.template'
        if (Test-Path $templatePath) {
            $relativePath = $file.FullName.Substring($PlatformDir.Length + 1) -replace '\\', '/'
            Write-Info "跳过: $relativePath (由对应模板管理)"
            continue
        }

        New-DotfileSymlink -SourcePath $file.FullName
        $linkCount++
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Ok "部署完成!"
    Write-Info "软链接总数:      $linkCount 个"
    Write-Info "新生成物化文件:  $generatedCount 个"
    Write-Info "备份位置:        $BackupDir"
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""

    if ($generatedCount -gt 0) {
        Write-Warn "检测到新生成的敏感配置文件，请手动填入密钥。"
        Write-Info "这些文件已被 .gitignore 排除，不会入仓。密钥仅保存在本地。"
        Write-Info "换机器时需重新运行 install.ps1 从模板物化并填入密钥。"
    }

    Write-Warn "部分配置需要注销并重新登录才能完全生效"
}

Main
