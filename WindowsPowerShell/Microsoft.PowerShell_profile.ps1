# Minimal profile: UTF‑8 + Oh My Posh (if installed) + Fastfetch with explicit config path
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
}
catch {}

Clear-Host

# Fastfetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
}