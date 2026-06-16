# AI One-Click Install Guide

This document instructs an AI (e.g., Claude Code) how to deploy all dotfiles in this repository to their correct system locations.

## Overview

This repo mirrors the user's `%USERPROFILE%` directory structure under `home/`. Each file under `home/` maps to a real path on the Windows system.

## Source Base

All config files are rooted at `home/` in the repository.

## Deployment Map

| Repo Path | Target Path | Method |
|---|---|---|
| `home/.claude/` | `%USERPROFILE%\.claude\` | Copy |
| `home/.config/fastfetch/` | `%USERPROFILE%\.config\fastfetch\` | Copy |
| `home/.config/opencode/` | `%USERPROFILE%\.config\opencode\` | Copy |
| `home/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\` | Copy |
| `home/AppData/Roaming/Code/User/settings.json` | `%APPDATA%\Code\User\` | Copy |
| `home/AppData/Roaming/JPEGView/JPEGView.ini` | `%APPDATA%\JPEGView\` | Copy |
| `home/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` | `%USERPROFILE%\Documents\WindowsPowerShell\` | Copy |

## Instructions for AI

1. Expand `%USERPROFILE%`, `%APPDATA%`, `%LOCALAPPDATA%` to actual paths on the target system.
2. For each entry in the deployment map:
   - Ensure the target directory exists (`mkdir -p`).
   - Copy the file from the repo path to the target path.
3. **Do NOT** overwrite files that already exist unless the user confirms.
4. After deployment, skip files that are identical (compare checksums).

## Special Notes

- **PowerShell profile**: Always ensure the target directory `%USERPROFILE%\Documents\WindowsPowerShell\` exists before copying.
- **VS Code settings**: Only copy if VS Code is installed on the target machine.
- **Windows Terminal**: The package folder name may include a version suffix. Use wildcard or check `dir` for the exact path.
- **Claude Code**: Uses two config files (`settings.json`, `CLAUDE.md`) and a shell script (`statusline.sh`). All three must be present.
