#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

cmd_exists() { command -v "$1" &>/dev/null; }

install_deps() {
    local pkgs=()

    case "$DISTRO" in
        arch)
            for pkg in curl unzip; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in curl unzip; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in curl unzip; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_bun() {
    if cmd_exists bun; then
        warn "bun already installed, updating..."
        bun upgrade 2>/dev/null || true
    else
        info "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
    ok "bun installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# bun setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'BUN_BLOCK'

# bun setup
[ -d "$HOME/.bun/bin" ] && export PATH="$HOME/.bun/bin:$PATH"
BUN_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# bun setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'BUN_BLOCK'

# bun setup
[ -d "$HOME/.bun/bin" ] && export PATH="$HOME/.bun/bin:$PATH"
BUN_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/bun.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'BUN_FISH'
# bun setup
if test -d "$HOME/.bun/bin"
    set -gx PATH $HOME/.bun/bin $PATH
end
BUN_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_bun

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "bun ready! Run: bun create next-app"
}

main "$@"