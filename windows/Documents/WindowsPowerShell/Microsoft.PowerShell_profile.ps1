try
{
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch
{
}

# DefaultPath
$defaultPaths = @(
    "$env:windir\System32"
)

if ($PWD.Path -in $defaultPaths)
{
    Set-Location "$env:USERPROFILE"
}

Clear-Host

# Fastfetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue)
{
    fastfetch
}
