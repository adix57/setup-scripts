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
            for pkg in base-devel curl; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in build-essential curl; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get update -y
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in gcc make curl; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_rustup() {
    if cmd_exists rustup; then
        warn "rustup already installed, updating..."
        rustup self update 2>/dev/null || true
    else
        info "Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
    ok "rustup installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# rustup setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'RUSTUP_BLOCK'

# rustup setup
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"
RUSTUP_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# rustup setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'RUSTUP_BLOCK'

# rustup setup
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"
RUSTUP_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/rustup.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'RUSTUP_FISH'
# rustup setup
if test -d "$HOME/.cargo/bin"
    set -gx PATH $HOME/.cargo/bin $PATH
end
RUSTUP_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_rustup

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "rustup ready! Run: rustup default stable"
}

main "$@"