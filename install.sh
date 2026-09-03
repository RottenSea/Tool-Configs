#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Dotfiles Installer — Linux
# Strategy: Symlink regular files directly; for .template files, materialize
# inside the repo first, then symlink the materialized result.
# Everything deployed to ~/ is a symlink, so edits feed back to the repo.
#
# Usage: ./install.sh            (install/update symlinks)
#        ./install.sh --revert   (convert existing symlinks back into standalone files)
#        ./install.sh --backup   (copy local secret files into repo/backup, outside git)
# ============================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$REPO_ROOT/linux"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
PRIVATE_BACKUP_DIR="$REPO_ROOT/backup"

REVERT=false
BACKUP=false
case "${1:-}" in
    --revert) REVERT=true ;;
    --backup) BACKUP=true ;;
esac

# Color definitions
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

log_info()  { echo -e "${C_BLUE}[INFO]${C_RESET} $*"; }
log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
log_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $*"; }

# --------------------------------------------
# Platform detection
# --------------------------------------------
detect_platform() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# --------------------------------------------
# Backup existing target file/directory/symlink
# Preserves directory structure for easy restoration
# --------------------------------------------
backup_target() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local rel_path="${target#$HOME/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        mv "$target" "$backup_path"
        log_warn "Backed up → $backup_path"
    fi
}

# --------------------------------------------
# Create symlink (unified entry point)
# src: source file path inside the repo
# --------------------------------------------
create_symlink() {
    local src="$1"
    local rel_path="${src#$PLATFORM_DIR/}"
    local dst="$HOME/$rel_path"

    mkdir -p "$(dirname "$dst")"
    backup_target "$dst"
    ln -s "$src" "$dst"
    log_ok "Linked $rel_path"
}

# --------------------------------------------
# Revert: convert an existing managed symlink back into a standalone file
# Reads through the symlink to capture its resolved content, then replaces
# the symlink with a plain file holding that content. The repo is untouched.
# --------------------------------------------
revert_target() {
    local target="$1"

    if [[ ! -L "$target" ]]; then
        return 1
    fi

    local tmp
    tmp="$(mktemp "${target}.XXXXXX")"
    cp -L "$target" "$tmp"
    rm "$target"
    mv "$tmp" "$target"
    return 0
}

# --------------------------------------------
# Revert all managed paths (mirrors the file enumeration used by main)
# --------------------------------------------
revert_all() {
    local revert_count=0

    while IFS= read -r -d '' template_file; do
        local real_file="${template_file%.template}"
        local rel_path="${real_file#$PLATFORM_DIR/}"
        local dst="$HOME/$rel_path"
        if revert_target "$dst"; then
            log_ok "Reverted $rel_path"
            (( ++revert_count ))
        fi
    done < <(find "$PLATFORM_DIR" -type f -name "*.template" -print0)

    while IFS= read -r -d '' file; do
        if [[ -f "$file.template" ]]; then
            continue
        fi
        local rel_path="${file#$PLATFORM_DIR/}"
        local dst="$HOME/$rel_path"
        if revert_target "$dst"; then
            log_ok "Reverted $rel_path"
            (( ++revert_count ))
        fi
    done < <(find "$PLATFORM_DIR" -type f ! -name "*.template" -print0)

    echo ""
    log_ok "Revert complete. $revert_count symlink(s) converted to standalone files."
    log_info "The repo itself was untouched; these files are now decoupled from it."
}

# --------------------------------------------
# Back up one materialized secret file into repo/backup, mirroring its
# path under linux/. Used by --backup so gitignored files (real
# configs generated from .template) survive outside of git.
# Returns 0 if a file was copied, 1 if nothing to back up yet.
# --------------------------------------------
backup_private_file() {
    local real_file="$1"

    if [[ ! -f "$real_file" ]]; then
        return 1
    fi

    local rel_path="${real_file#$PLATFORM_DIR/}"
    local dest_path="$PRIVATE_BACKUP_DIR/linux/$rel_path"

    # Drop any stale backup before copying the current version in its place
    if [[ -e "$dest_path" ]]; then
        rm -f "$dest_path"
    fi

    mkdir -p "$(dirname "$dest_path")"
    cp "$real_file" "$dest_path"
    log_ok "Backed up linux/$rel_path"
    return 0
}

# --------------------------------------------
# Back up every materialized secret file (mirrors the .template
# enumeration used by main)
# --------------------------------------------
backup_all_private() {
    local backup_count=0
    local skipped_count=0

    while IFS= read -r -d '' template_file; do
        local real_file="${template_file%.template}"
        if backup_private_file "$real_file"; then
            (( ++backup_count ))
        else
            local rel_path="${real_file#$PLATFORM_DIR/}"
            log_info "Skipping (not materialized yet): $rel_path"
            (( ++skipped_count ))
        fi
    done < <(find "$PLATFORM_DIR" -type f -name "*.template" -print0)

    echo ""
    log_ok "Privacy backup complete. $backup_count file(s) backed up, $skipped_count skipped."
    log_info "Backup location: $PRIVATE_BACKUP_DIR"
    log_warn "This folder holds secrets — it stays out of git (see .gitignore)."
}

# --------------------------------------------
# Materialize a .template file inside the repo
# Returns 0 if newly generated, 1 if already exists
# --------------------------------------------
materialize_template() {
    local template_file="$1"
    local real_file="${template_file%.template}"

    if [[ -f "$real_file" ]]; then
        log_info "Materialized file already exists: ${real_file#$REPO_ROOT/}"
        return 1
    fi

    cp "$template_file" "$real_file"
    log_warn "Generated from template: ${real_file#$REPO_ROOT/}"
    return 0
}

# --------------------------------------------
# Main flow
# --------------------------------------------
main() {
    echo -e "${C_CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Dotfiles Installer (Linux)                       ║"
    echo "║  Regular files → direct symlink                            ║"
    echo "║  .template → materialize in repo → symlink result          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"

    if [[ "$(detect_platform)" != "linux" ]]; then
        log_error "This script only supports Linux."
        exit 1
    fi

    if [[ ! -d "$PLATFORM_DIR" ]]; then
        log_error "$PLATFORM_DIR not found. Please run this script from the repo root."
        exit 1
    fi

    if [[ "$REVERT" == true && "$BACKUP" == true ]]; then
        log_error "--revert and --backup are mutually exclusive. Run one at a time."
        exit 1
    fi

    if [[ "$REVERT" == true ]]; then
        log_info "Running in --revert mode: symlinks will be converted back to standalone files."
        revert_all
        return 0
    fi

    if [[ "$BACKUP" == true ]]; then
        log_info "Running in --backup mode: local secret files will be copied into backup/."
        backup_all_private
        return 0
    fi

    log_info "Backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    local link_count=0
    local generated_count=0

    # ========================================
    # Phase 1: Process all .template files
    # ========================================
    while IFS= read -r -d '' template_file; do
        # 1. Materialize: copy template to real file inside the repo
        if materialize_template "$template_file"; then
            (( ++generated_count ))
        fi

        # 2. Create symlink from ~/ to the materialized real file
        local real_file="${template_file%.template}"
        create_symlink "$real_file"
        (( ++link_count ))

    done < <(find "$PLATFORM_DIR" -type f -name "*.template" -print0)

    # ========================================
    # Phase 2: Process regular files
    # Skip files that have a corresponding .template (already linked in Phase 1)
    # ========================================
    while IFS= read -r -d '' file; do
        if [[ -f "$file.template" ]]; then
            log_info "Skipping: ${file#$PLATFORM_DIR/} (managed by corresponding template)"
            continue
        fi

        create_symlink "$file"
        (( ++link_count ))

    done < <(find "$PLATFORM_DIR" -type f ! -name "*.template" -print0)

    # ========================================
    # Summary
    # ========================================
    echo ""
    echo -e "${C_GREEN}════════════════════════════════════════════════════════════${C_RESET}"
    log_ok "Deployment complete!"
    log_info "Total symlinks:       ${C_GREEN}$link_count${C_RESET}"
    log_info "Newly materialized:   ${C_GREEN}$generated_count${C_RESET}"
    log_info "Backup location:      ${C_GREEN}$BACKUP_DIR${C_RESET}"
    echo -e "${C_GREEN}════════════════════════════════════════════════════════════${C_RESET}"
    echo ""

    if [[ $generated_count -gt 0 ]]; then
        log_warn "Sensitive config files were generated from templates. Please edit them manually."
        log_info "These files are excluded by .gitignore and will not be committed. Secrets stay local."
        log_info "When moving to a new machine, re-run install.sh to materialize templates and fill in secrets."
    fi

    log_warn "Some configurations (Shell, desktop environment) require logging out and back in to take full effect."
}

main "$@"
