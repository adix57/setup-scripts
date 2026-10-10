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

SETUP_NUM=06
SETUP_NAME="vsftpd"

install_deps() {
    local pkgs=()

    case "$DISTRO" in
        arch)
            for pkg in vsftpd; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in vsftpd; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get update -y
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in vsftpd; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

vsftpd_conf_path() {
    if [ "${DISTRO:-}" = "fedora" ]; then
        echo /etc/vsftpd/vsftpd.conf
    else
        echo /etc/vsftpd.conf
    fi
}

vsftpd_config() {
    cat << 'VSFTPD_CONF'
# Managed by setup-scripts — re-run setup to overwrite
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
ssl_enable=NO
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
VSFTPD_CONF
}

configure_vsftpd() {
    local conf desired current
    conf=$(vsftpd_conf_path)
    desired=$(vsftpd_config)

    if [ -f "$conf" ]; then
        current=$(cat "$conf" 2>/dev/null || true)
        if [ "$current" = "$desired" ]; then
            return 0
        fi
        if grep -q 'Managed by setup-scripts' "$conf" 2>/dev/null; then
            if [ "${SETUP_FORCE:-0}" != "1" ]; then
                warn "vsftpd config was customized; skipping (re-run with --force to overwrite)"
                return 0
            fi
        elif [ ! -f "${conf}.setup-scripts.bak" ]; then
            sudo cp "$conf" "${conf}.setup-scripts.bak"
            info "Backed up existing config to ${conf}.setup-scripts.bak"
        fi
    fi

    info "Writing $conf..."
    sudo mkdir -p "$(dirname "$conf")" /var/run/vsftpd/empty
    printf '%s\n' "$desired" | sudo tee "$conf" >/dev/null
    sudo chmod 644 "$conf"
}

install_vsftpd() {
    if cmd_exists vsftpd; then
        warn "vsftpd already installed"
    else
        info "Installing vsftpd..."
    fi

    configure_vsftpd

    if cmd_exists systemctl; then
        sudo systemctl enable vsftpd 2>/dev/null || true
        sudo systemctl restart vsftpd 2>/dev/null || true
    fi

    ok "vsftpd installed"
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
# vsftpd helpers
alias ftp-status='systemctl status vsftpd'
alias ftp-restart='sudo systemctl restart vsftpd'
alias ftp-logs='journalctl -u vsftpd -f'
TOOL_BLOCK

    for sh in ${SHELLS//,/ }; do
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
# vsftpd helpers
alias ftp-status 'systemctl status vsftpd'
alias ftp-restart 'sudo systemctl restart vsftpd'
alias ftp-logs 'journalctl -u vsftpd -f'
FISH_BLOCK
                ;;
        esac
    done

    info "Configured ${SETUP_NAME}"
}

uninstall() {
    local conf
    conf=$(vsftpd_conf_path)

    rm -f "$HOME/.setup.d/${SETUP_NUM}-${SETUP_NAME}.sh"
    rm -f "$HOME/.config/fish/conf.d/${SETUP_NUM}-${SETUP_NAME}.fish"

    if cmd_exists systemctl; then
        sudo systemctl stop vsftpd 2>/dev/null || true
        sudo systemctl disable vsftpd 2>/dev/null || true
    fi

    if [ -f "${conf}.setup-scripts.bak" ]; then
        sudo mv "${conf}.setup-scripts.bak" "$conf"
    elif [ -f "$conf" ] && grep -q 'Managed by setup-scripts' "$conf" 2>/dev/null; then
        sudo rm -f "$conf"
    fi

    ok "vsftpd uninstalled"
}

main() {
    if [ "${UNINSTALL:-0}" = "1" ]; then
        uninstall
        exit 0
    fi

    install_deps
    install_vsftpd
    setup_shell

    warn "Open TCP 21 and 40000-40100 (passive) in your firewall if needed"
    ok "vsftpd ready! Connect: ftp://<host>  (status: systemctl status vsftpd)"
}

main "$@"
