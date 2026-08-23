# dotfiles

A centralized repository for cross-platform configuration files (Linux & Windows).

## Structure

- `linux/`: Linux-specific configurations and dotfiles.
- `windows/`: Windows-specific configurations.

## Configured Tools

### Linux
- **Shell & Core**: `.bashrc`, `.bash_profile`, `.gitconfig`, `.npmrc`, `.prettierrc.json`
- **Terminal**: Alacritty, Kitty
- **Editors**: Zed, VS Code
- **System & UI**: Niri, XDG-Desktop-Portal, XFCE, Fastfetch, Fcitx5, Noctalia
- **AI & CLI**: OpenCode, GitHub CLI

### Windows
- Windows PowerShell
- Windows Terminal

## Secrets Handling

To prevent API keys and tokens from being leaked, this repository follows a **Sanitized Template** approach:
- Actual secret files are added to `.gitignore`.
- A redacted version (`*.template`) is committed with placeholders (e.g., `YOUR_TOKEN`).
- Users should copy the template to the actual filename and fill in their own credentials.

