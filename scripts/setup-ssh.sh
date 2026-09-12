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

SETUP_NUM=05
SETUP_NAME="ssh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config/${SETUP_NAME}"

install_deps() {
    local pkgs=()

    case "$DISTRO" in
        arch)
            for pkg in openssh; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in openssh-client openssh-server; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get update -y
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in openssh-clients openssh-server; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

configure_sshd() {
    local conf=/etc/ssh/sshd_config
    [ -f "$conf" ] || return

    info "Enabling password and pubkey authentication in $conf..."
    sudo sed -i \
        -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' \
        -e 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' \
        "$conf"

    if command -v sshd >/dev/null 2>&1; then
        sudo sshd -t 2>/dev/null || true
    fi
}

install_ssh() {
    if cmd_exists ssh; then
        warn "openssh already installed"
    else
        info "Installing openssh..."
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$CONFIG_DIR/config" ]; then
        if [ ! -f "$HOME/.ssh/config" ]; then
            cp "$CONFIG_DIR/config" "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
        else
            warn "~/.ssh/config already exists, leaving as-is"
        fi
    fi

    configure_sshd

    if cmd_exists systemctl; then
        local svc=sshd
        [ "$DISTRO" = "debian" ] && svc=ssh
        sudo systemctl enable "$svc" 2>/dev/null || true
        sudo systemctl restart "$svc" 2>/dev/null || true
    fi

    ok "ssh installed"
}

ensure_source_block() {
    local rc=$1
    grep -q "# === setup.d ===" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'RC_BLOCK'

# === setup.d ===
for f in "$HOME/.setup.d"/*.sh; do
    [ -f "$f" ] && . "$f"
done
# === end setup.d ===
RC_BLOCK
}

setup_shell() {
    mkdir -p "$HOME/.setup.d"

    cat > "$HOME/.setup.d/${SETUP_NUM}-${SETUP_NAME}.sh" << 'TOOL_BLOCK'
# ssh-agent setup — single shared agent
[ -z "${SSH_AUTH_SOCK:-}" ] && export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
ssh-add -l >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
    rm -f "$HOME/.ssh/agent.sock" 2>/dev/null || true
    ssh-agent -a "$HOME/.ssh/agent.sock" >/dev/null 2>&1 || true
fi
[ -f "$HOME/.ssh/id_ed25519" ] && ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1 || true
TOOL_BLOCK

    for sh in $SHELLS; do
        case "$sh" in
            bash)
                ensure_source_block "$HOME/.bashrc"
                ;;
            zsh)
                ensure_source_block "$HOME/.zshrc"
                ;;
            fish)
                mkdir -p "$HOME/.config/fish/conf.d"
                cat > "$HOME/.config/fish/conf.d/${SETUP_NUM}-${SETUP_NAME}.fish" << 'FISH_BLOCK'
# ssh-agent setup — single shared agent
if not set -q SSH_AUTH_SOCK
    set -gx SSH_AUTH_SOCK $HOME/.ssh/agent.sock
end
ssh-add -l >/dev/null 2>&1
set -l rc $status
if test $rc -eq 2
    rm -f $HOME/.ssh/agent.sock 2>/dev/null
    ssh-agent -a $HOME/.ssh/agent.sock >/dev/null 2>&1
end
if test -f $HOME/.ssh/id_ed25519
    ssh-add $HOME/.ssh/id_ed25519 >/dev/null 2>&1
end
FISH_BLOCK
                ;;
        esac
    done

    info "Configured ${SETUP_NAME}"
}

uninstall() {
    rm -f "$HOME/.setup.d/${SETUP_NUM}-${SETUP_NAME}.sh"
    rm -f "$HOME/.config/fish/conf.d/${SETUP_NUM}-${SETUP_NAME}.fish"
    pkill -f "ssh-agent -a $HOME/.ssh/agent.sock" 2>/dev/null || true
    rm -f "$HOME/.ssh/agent.sock"
    ok "ssh uninstalled"
}

main() {
    if [ "${UNINSTALL:-0}" = "1" ]; then
        uninstall
        exit 0
    fi

    install_deps
    install_ssh
    setup_shell

    ok "ssh ready! Run: ssh-add -l"
}

main "$@"