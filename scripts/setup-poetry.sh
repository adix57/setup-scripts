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
            for pkg in python curl git; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in python3 curl git; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get update -y
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in python3 curl git; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_poetry() {
    if cmd_exists poetry; then
        warn "poetry already installed, updating..."
        poetry self update 2>/dev/null || true
    else
        info "Installing poetry..."
        curl -sSL https://install.python-poetry.org | python3 -
    fi
    ok "poetry installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# poetry setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'POETRY_BLOCK'

# poetry setup
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
POETRY_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# poetry setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'POETRY_BLOCK'

# poetry setup
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
POETRY_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/poetry.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'POETRY_FISH'
# poetry setup
if test -d "$HOME/.local/bin"
    set -gx PATH $HOME/.local/bin $PATH
end
POETRY_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_poetry

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "poetry ready! Run: poetry new myproject"
}

main "$@"