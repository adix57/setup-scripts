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
            for pkg in base-devel curl git; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in build-essential curl git; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in gcc make curl git; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_pyenv() {
    if cmd_exists pyenv; then
        warn "pyenv already installed, updating..."
        git -C "$HOME/.pyenv" pull 2>/dev/null || true
    else
        info "Installing pyenv..."
        curl -fsSL https://pyenv.run | bash
    fi

    local plugin="$HOME/.pyenv/plugins/pyenv-virtualenv"
    if [ ! -d "$plugin" ]; then
        info "Installing pyenv-virtualenv plugin..."
        git clone https://github.com/pyenv/pyenv-virtualenv.git "$plugin"
    else
        git -C "$plugin" pull 2>/dev/null || true
    fi
    ok "pyenv installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# pyenv setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'PYENV_BLOCK'

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[ -d "$HOME/.pyenv/bin" ] && export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
PYENV_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# pyenv setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'PYENV_BLOCK'

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[ -d "$HOME/.pyenv/bin" ] && export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
PYENV_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/pyenv.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'PYENV_FISH'
# pyenv setup
if command -v pyenv >/dev/null 2>&1
    set -gx PYENV_ROOT $HOME/.pyenv
    set -gx PATH $PYENV_ROOT/bin $PATH
    pyenv init - | source
    pyenv virtualenv-init - | source
end
PYENV_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_pyenv

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "pyenv ready! Run: pyenv install 3.12 && pyenv virtualenv 3.12 myenv"
}

main "$@"
