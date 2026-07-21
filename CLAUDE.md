# dotfiles

Windows configuration files managed under `home/`, mirroring `%USERPROFILE%` structure.

## Config Inventory

| Repo Path | Deploy Target | App |
|---|---|---|
| `home/.claude/` | `%USERPROFILE%\.claude\` | Claude Code |
| `home/.config/fastfetch/` | `%USERPROFILE%\.config\fastfetch\` | Fastfetch |
| `home/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\` | Windows Terminal |
| `home/AppData/Roaming/Code/User/settings.json` | `%APPDATA%\Code\User\` | VS Code |
| `home/AppData/Roaming/JPEGView/JPEGView.ini` | `%APPDATA%\JPEGView\` | JPEGView |
| `home/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\WindowsPowerShell\` | PowerShell |

## Update Notes

- **Never commit tokens or secrets** — `.claude/settings.json` env vars use empty/placeholder values. The actual values live on each machine.
- **Use `%VAR%` / `$env:VAR`** for paths in config files — never hardcode `C:\Users\RottenTh\...`.
- **Configs mirror actual paths** — a file under `home/AppData/Roaming/` deploys to `%APPDATA%\`. Keep the path structure intact.
- **VS Code settings** are JSONC (trailing commas, `//` comments allowed). The repo version is organized by category with dictionary-ordered keys within each group.
- **Windows Terminal** settings are published by the app (via gear icon → "Open JSON file"). Copy the full file, not just the `profiles.list` section.
- **Terminal and PowerShell** configs are intentionally skipped from source synchronization — their values diverge per-machine.

## Privacy

This repo has been audited for leaks:
- ✅ No API keys, tokens, SSH keys, or passwords
- ✅ Emails use GitHub's `@users.noreply.github.com` (safe)
- ⚠️ `README.md` formerly contained hardcoded username `RottenTh` — now replaced with env vars
- ⚠️ Git history still contains deleted files (opencode skills, V2RayN rules) — rewrite if going public
