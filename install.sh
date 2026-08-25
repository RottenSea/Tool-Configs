#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Dotfiles Installer — Linux
# 策略: 普通文件直接软链接；.template 文件先在仓库内物化，再对物化结果软链接。
# 所有最终部署到 ~/ 的都是软链接，修改直接反馈到仓库。
# ============================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$REPO_ROOT/linux"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# 颜色定义
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
# 平台检测
# --------------------------------------------
detect_platform() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# --------------------------------------------
# 备份已存在的目标文件/目录/链接
# 保持目录结构，便于一键恢复
# --------------------------------------------
backup_target() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        local rel_path="${target#$HOME/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        mv "$target" "$backup_path"
        log_warn "已备份 → $backup_path"
    fi
}

# --------------------------------------------
# 创建软链接（统一入口）
# src: 仓库内的源文件路径
# --------------------------------------------
create_symlink() {
    local src="$1"
    local rel_path="${src#$PLATFORM_DIR/}"
    local dst="$HOME/$rel_path"

    mkdir -p "$(dirname "$dst")"
    backup_target "$dst"
    ln -s "$src" "$dst"
    log_ok "链接 $rel_path"
}

# --------------------------------------------
# 主流程
# --------------------------------------------
main() {
    echo -e "${C_CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Dotfiles Installer (Linux)                       ║"
    echo "║  普通文件 → 直接软链接                                   ║"
    echo "║  .template → 仓库内物化 → 对物化结果软链接               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${C_RESET}"

    if [[ "$(detect_platform)" != "linux" ]]; then
        log_error "当前脚本仅支持 Linux。"
        exit 1
    fi

    if [[ ! -d "$PLATFORM_DIR" ]]; then
        log_error "未找到 $PLATFORM_DIR，请在仓库根目录运行此脚本。"
        exit 1
    fi

    log_info "备份目录: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    local link_count=0
    local generated_count=0

    # ========================================
    # 第一阶段：处理所有 .template 文件
    # ========================================
    while IFS= read -r -d '' template_file; do
        local real_file="${template_file%.template}"

        # 1. 物化：如果真实文件不存在，从模板复制生成（在仓库目录内）
        if [[ ! -f "$real_file" ]]; then
            cp "$template_file" "$real_file"
            log_warn "从模板生成: ${real_file#$REPO_ROOT/}"
            ((generated_count++))
        else
            log_info "物化文件已存在: ${real_file#$REPO_ROOT/}"
        fi

        # 2. 对物化后的真实文件创建软链接到 ~/
        create_symlink "$real_file"
        ((link_count++))

    done < <(find "$PLATFORM_DIR" -type f -name "*.template" -print0)

    # ========================================
    # 第二阶段：处理普通文件
    # 跳过"已有对应 .template 的文件"（它们已在第一阶段被链接）
    # ========================================
    while IFS= read -r -d '' file; do
        if [[ -f "$file.template" ]]; then
            log_info "跳过: ${file#$PLATFORM_DIR/}（由对应模板管理）"
            continue
        fi

        create_symlink "$file"
        ((link_count++))

    done < <(find "$PLATFORM_DIR" -type f ! -name "*.template" -print0)

    # ========================================
    # 总结
    # ========================================
    echo ""
    echo -e "${C_GREEN}════════════════════════════════════════════════════════════${C_RESET}"
    log_ok "部署完成!"
    log_info "软链接总数:      ${C_GREEN}$link_count${C_RESET} 个"
    log_info "新生成物化文件:  ${C_GREEN}$generated_count${C_RESET} 个"
    log_info "备份位置:        ${C_GREEN}$BACKUP_DIR${C_RESET}"
    echo -e "${C_GREEN}════════════════════════════════════════════════════════════${C_RESET}"
    echo ""

    if [[ $generated_count -gt 0 ]]; then
        log_warn "检测到新生成的敏感配置文件，请手动填入密钥。"
        log_info "这些文件已被 .gitignore 排除，不会入仓。密钥仅保存在本地。"
        log_info "换机器时需重新运行 install.sh 从模板物化并填入密钥。"
    fi

    log_warn "部分配置（Shell、桌面环境）需要注销并重新登录才能完全生效"
}

main "$@"
