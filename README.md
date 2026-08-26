# dotfiles

Cross-platform config for Linux and Windows, kept in one repo.

## Layout

- `linux/` — Linux configs and dotfiles.
- `windows/` — Windows configs.

## Tools covered

### Linux

- Shell and core: `.bashrc`, `.bash_profile`, `.gitconfig`, `.npmrc`, `.prettierrc.json`
- Terminal: Alacritty, Kitty
- Editors: Zed, VS Code
- System and UI: Niri, XDG-Desktop-Portal, XFCE, Fastfetch, Fcitx5, Noctalia
- AI and CLI: OpenCode, GitHub CLI

### Windows

- Windows PowerShell
- Windows Terminal

## Secrets

API keys and tokens never get committed. The repo uses a sanitized template pattern:

- The real secret file goes in `.gitignore`.
- A redacted copy with the same name plus `.template` is committed. Placeholders like `YOUR_TOKEN` mark where secrets go.
- On a new machine, copy the template to its real path and fill in your own values.
