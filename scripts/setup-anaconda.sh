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
            for pkg in curl; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in curl; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in curl; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_anaconda() {
    if cmd_exists conda || [ -d "$HOME/.anaconda3" ]; then
        warn "anaconda already installed, skipping..."
        return
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) err "Unsupported architecture: $arch"; exit 1 ;;
    esac

    info "Fetching latest Anaconda version..."
    local file
    file=$(curl -fsSL https://repo.anaconda.com/archive/ | grep -oE "Anaconda3-[0-9]{4}\.[0-9]{2}(-[0-9]+)?-Linux-${arch}\.sh" | sort -V | tail -1)

    if [ -z "$file" ]; then
        warn "Could not resolve latest version, using fallback..."
        file="Anaconda3-2024.10-1-Linux-${arch}.sh"
    fi

    info "Installing $file..."
    curl -fsSL "https://repo.anaconda.com/archive/$file" -o /tmp/anaconda.sh
    bash /tmp/anaconda.sh -b -p "$HOME/.anaconda3"
    rm -f /tmp/anaconda.sh

    info "Disabling auto-activation of base env..."
    "$HOME/.anaconda3/bin/conda" config --set auto_activate_base false
    ok "anaconda installed"
}

configure_bash() {
    local rc="$HOME/.bashrc"
    grep -q "# anaconda setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'CONDA_BLOCK'

# anaconda setup
if [ -d "$HOME/.anaconda3" ]; then
    source "$HOME/.anaconda3/etc/profile.d/conda.sh"
    export PATH="$HOME/.anaconda3/bin:$PATH"
fi
CONDA_BLOCK
    info "Configured $rc"
}

configure_zsh() {
    local rc="$HOME/.zshrc"
    grep -q "# anaconda setup" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'CONDA_BLOCK'

# anaconda setup
if [ -d "$HOME/.anaconda3" ]; then
    source "$HOME/.anaconda3/etc/profile.d/conda.sh"
    export PATH="$HOME/.anaconda3/bin:$PATH"
fi
CONDA_BLOCK
    info "Configured $rc"
}

configure_fish() {
    local file="$HOME/.config/fish/conf.d/anaconda.fish"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && return
    cat > "$file" << 'CONDA_FISH'
# anaconda setup
if test -d "$HOME/.anaconda3"
    set -gx PATH $HOME/.anaconda3/bin $PATH
    source "$HOME/.anaconda3/etc/fish/conf.d/conda.fish"
end
CONDA_FISH
    info "Configured $file"
}

main() {
    install_deps
    install_anaconda

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "anaconda ready! Run: conda create -n myenv python=3.12 && conda activate myenv"
}

main "$@"