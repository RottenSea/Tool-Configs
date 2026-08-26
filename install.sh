#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Dotfiles Installer — Linux
# Strategy: Symlink regular files directly; for .template files, materialize
# inside the repo first, then symlink the materialized result.
# Everything deployed to ~/ is a symlink, so edits feed back to the repo.
# ============================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$REPO_ROOT/linux"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

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
