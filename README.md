# dotfiles

Cross-platform config for Linux and Windows, kept in one repo.

## Layout

- `linux/` — Linux configs and dotfiles.
- `windows/` — Windows configs, actively deployed via `install.ps1`.
- `Legacy/` — retired configs kept for reference only; not installed or symlinked anywhere.

## Tools covered

### Linux

- Shell and core: `.bashrc`, `.bash_profile`, `.gitconfig`, `.npmrc`, `.prettierrc.json`
- Terminal: Alacritty, Kitty
- Editors: Zed, VS Code
- System and UI: Niri, XDG-Desktop-Portal, XFCE, Fastfetch, Fcitx5, Noctalia
- AI and CLI: OpenCode, GitHub CLI

### Windows

- Fastfetch
- OpenCode
- Zed
- Windows Terminal
- Windows PowerShell profile

## Installing on Windows

From the repo root:

```powershell
.\install.ps1
```

It symlinks everything under `windows/` into place under `%USERPROFILE%`, `%APPDATA%`, or `%LOCALAPPDATA%` (mapped by path), materializing any `.template` file into a real file first. Creating symlinks needs either an elevated PowerShell or Developer Mode enabled (Settings → Privacy & Security → Developer Mode).

## Secrets

API keys and tokens never get committed. The repo uses a sanitized template pattern:

- The real secret file goes in `.gitignore`.
- A redacted copy with the same name plus `.template` is committed. Placeholders like `YOUR_TOKEN` mark where secrets go.
- On a new machine, copy the template to its real path and fill in your own values.
