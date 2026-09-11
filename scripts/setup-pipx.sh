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
            for pkg in git curl; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in python3 git curl; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get update -y
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in python3 git curl; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_pipx() {
    if cmd_exists pipx; then
        warn "pipx already installed, updating..."
        pipx upgrade-all 2>/dev/null || true
    else
        info "Installing pipx..."
        case "$DISTRO" in
            arch)   sudo pacman -S --needed --noconfirm python-pipx ;;
            debian) sudo apt-get install -y pipx ;;
            fedora) sudo dnf install -y pipx ;;
        esac
    fi
    ok "pipx installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# pipx setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'PIPX_BLOCK'

# pipx setup
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
PIPX_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# pipx setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'PIPX_BLOCK'

# pipx setup
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
PIPX_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/pipx.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'PIPX_FISH'
# pipx setup
if test -d "$HOME/.local/bin"
    set -gx PATH $HOME/.local/bin $PATH
end
PIPX_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_pipx

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "pipx ready! Run: pipx install pycowsay"
}

main "$@"