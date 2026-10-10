# AGENTS.md

## Project Overview

A collection of **universal setup scripts** for Linux. Each script installs and configures a tool so it works across multiple distros and shells with zero manual intervention.

Supported distros are grouped into three families:

| Group     | Distro IDs                                            |
|-----------|-------------------------------------------------------|
| `arch`    | `arch`, `manjaro`, `endeavouros`, `omarchy`          |
| `debian`  | `debian`, `ubuntu`, `linuxmint`, `pop`, `raspbian`, `kali` |
| `fedora`  | `fedora`                                              |

Supported shells: **bash**, **zsh**, **fish**.

## Directory Structure

```
setup-scripts/
├── AGENTS.md          # This file
├── README.md          # Project docs for users
├── setup.sh           # Main entry point — fzf launcher
├── .gitignore         # Ignores generated env file
├── env                # Cached system info (auto-generated, git-ignored)
├── config/            # Per-tool default config files, copied at setup time
│   └── ssh/           # SSH client config
│       └── config     # → ~/.ssh/config
├── lib/               # Reusable functions shared by setup scripts
│   └── checklist.sh   # Interactive checklist + yes/no prompt
└── scripts/
    ├── setup-pyenv.sh # pyenv — Python version manager
    ├── setup-uv.sh    # uv — fast Python package installer
    ├── setup-pipx.sh  # pipx — isolated Python apps
    ├── setup-poetry.sh # poetry — Python dependency management
    ├── setup-nvm.sh    # nvm — Node.js version manager
    ├── setup-bun.sh    # bun — fast JavaScript runtime, bundler
    ├── setup-rustup.sh # rustup — Rust toolchain installer
    ├── setup-miniconda.sh # miniconda — minimal Python distro
    ├── setup-anaconda.sh # anaconda — full data science distro
    ├── setup-ssh.sh    # ssh — openssh + single shared ssh-agent
    ├── setup-vsftpd.sh # vsftpd — FTP server
    └── ...            # More tools as needed
```

## Architecture

### setup.sh (main entry point)

The universal launcher. It owns **all** system detection logic:

1. **Loads/creates `env`** — if `./env` exists, sources it; otherwise detects and caches system info
2. **Ensures `fzf`** — installs it only if missing (via `$DISTRO` package manager)
3. **Discovers scripts** — finds all `scripts/setup-*.sh` files, derives tool names from filenames (e.g. `scripts/setup-pyenv.sh` → `pyenv`)
4. **fzf multi-select menu** — user picks tools to install
5. **Exports `DISTRO` and `SHELLS`** — then runs each selected script in sequence

Also supports `--uninstall` which lists installed tools (by scanning `~/.setup.d/*.sh` and `~/.config/fish/conf.d/*.fish`), presents an fzf picker, then runs each selected script with `UNINSTALL=1`. After uninstall, if `~/.setup.d/` has no `.sh` files left, the sourcing block is removed from bashrc/zshrc.

### env file (auto-generated)

Cached system info, created on first run:

```
DISTRO=arch
SHELLS=bash,zsh
```

- Regenerate with `./setup.sh --regen`
- Never edit manually
- Git-ignored

### Individual scripts (scripts/setup-<tool>.sh)

Tool-specific installers. They do **NOT** detect anything — they consume the exported variables:

```bash
main() {
    install_deps    # uses $DISTRO directly
    install_<tool>

    for sh in $SHELLS; do
        case "$sh" in
            bash) configure_bash ;;
            zsh)  configure_zsh  ;;
            fish) configure_fish ;;
        esac
    done

    ok "<tool> ready!"
}
```

## Script Conventions

Every script in `scripts/` **must** follow these rules:

### 1. Naming

- Filename pattern: `setup-<tool-name>.sh`
- Use lowercase and hyphens (not underscores)
- The tool name derived from the filename is what appears in the fzf menu and README

### 2. Header

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### 3. Logging Helpers

Include these exact functions at the top of every script:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
```

Also include a `cmd_exists()` helper:

```bash
cmd_exists() { command -v "$1" &>/dev/null; }
```

### 4. Structure

Each script must have these sections in order:

1. **Colors & logging helpers**
2. **`SETUP_NUM` and `SETUP_NAME` constants**
3. **Dependency installation** — install OS packages via the distro's package manager
4. **Tool installation** — install the actual tool
5. **`ensure_source_block`** — idempotent rc-file source loop for `~/.setup.d`
6. **`setup_shell`** — writes `~/.setup.d/<num>-<tool>.sh` + fish conf.d file, ensures source block
7. **`uninstall`** — removes the setup.d file, fish conf.d file, and tool data dirs
8. **`main()`** — handles `UNINSTALL=1` mode, else install_deps → install_tool → setup_shell

### 5. SETUP_NUM and SETUP_NAME

Every script defines two constants:

```bash
SETUP_NUM=NN       # unique number (see numbering table)
SETUP_NAME="tool"  # tool name matching the filename suffix
```

**Numbering scheme** — each tool gets a unique two-digit number:

| Tool | Number |
|------|--------|
| ssh | 05 |
| vsftpd | 06 |
| pyenv | 10 |
| uv | 15 |
| pipx | 20 |
| poetry | 25 |
| miniconda | 30 |
| anaconda | 40 |
| nvm | 50 |
| bun | 60 |
| rustup | 70 |

New tools get a number between existing ones (e.g. 12, 35, 55).

### 5.5 Shared Library (`lib/`)

Reusable UI/helper functions live in `lib/` and are sourced by any script that needs them:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/checklist.sh"
```

Available helpers:

- **`checklist`** — interactive multi-select. Usage:
  ```bash
  selection=$(checklist "SSH authentication methods:" "*PasswordAuthentication" "*PubkeyAuthentication") || exit 1
  ```
  Prefix an item with `*` to mark it checked by default. Selected items print to stdout, one per line (prefix stripped). If stdin is not a TTY (e.g. piped), it returns the default-checked items without prompting.
- **`ask_yesno`** — `ask_yesno "Proceed?" [default]` — returns 0 on yes, 1 on no. The optional second argument sets the default answer for empty or non-interactive input (`yes` or `no`; defaults to `yes`).

Add new shared functions to a file under `lib/` and document them here.

### 6. Dependency Installation

Follow the same pattern from `scripts/setup-pyenv.sh`. Key rules:

| Distro Group | Package Manager | Common args            | Check installed with |
|-------------|----------------|------------------------|----------------------|
| `arch`      | `pacman`       | `-S --needed --noconfirm` | `pacman -Qi <pkg>`  |
| `debian`    | `apt-get`      | `install -y`           | `dpkg -s <pkg>`      |
| `fedora`    | `dnf`          | `install -y`           | `rpm -q <pkg>`       |

**Never blindly install — always check first.** Build an array of missing packages, then install only if non-empty:

```bash
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
```

### 7. Tool Installation

- If the tool is already installed (use `cmd_exists`), offer to update it instead
- Otherwise install via official installer (curl pipe, git clone, etc.)

```bash
install_<tool>() {
    if cmd_exists <tool>; then
        warn "<tool> already installed, updating..."
        # update command
    else
        info "Installing <tool>..."
        # install command
    fi
    ok "<tool> installed"
}
```

### 8. Shell Configuration

Tool startup code is managed via `~/.setup.d/`:

| Shell  | Config Location                                   | Method                          |
|--------|---------------------------------------------------|---------------------------------|
| bash   | `~/.bashrc`                                       | One-time source block for `~/.setup.d/*.sh` |
| zsh    | `~/.zshrc`                                        | One-time source block for `~/.setup.d/*.sh` |
| fish   | `~/.config/fish/conf.d/<num>-<tool>.fish`         | Native auto-source by filename   |

**bash/zsh:** Each script writes a numbered file `~/.setup.d/<num>-<tool>.sh`. The rc file gets a **single** idempotent sourcing block (once, never duplicated):

```bash
# === setup.d ===
for f in "$HOME/.setup.d"/*.sh; do
    [ -f "$f" ] && . "$f"
done
# === end setup.d ===
```

The `ensure_source_block <rc>` helper writes this block only if the `# === setup.d ===` marker is not yet present.

**fish:** Each script writes `~/.config/fish/conf.d/<num>-<tool>.fish`. Fish auto-sources all files in `conf.d/` in sorted filename order, so the number prefix controls execution order automatically.

**Idempotency:** bash/zsh source blocks are never duplicated (checked by marker). Fish files are overwritten if they already exist.

### 8.5 Config File Copying

Tools that ship a default config file (e.g. ssh's `~/.ssh/config`) store it in `config/<tool>/<filename>`. At setup time the script copies it to its target location:

- Only copy if the destination does **not** already exist (never clobber a user's own config)
- Preserve correct permissions (`chmod`)
- Derive the config dir from the script's own location: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then `"$SCRIPT_DIR/../config/<tool>"`

Example from `setup-ssh.sh`:

```bash
if [ -f "$CONFIG_DIR/config" ] && [ ! -f "$HOME/.ssh/config" ]; then
    cp "$CONFIG_DIR/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
fi
```

### 9. Uninstall

Each script must define an `uninstall()` function that removes:
1. The `~/.setup.d/<num>-<tool>.sh` file
2. The `~/.config/fish/conf.d/<num>-<tool>.fish` file
3. The tool's data directories (tool-specific)

When `UNINSTALL=1` is in the environment, `main()` calls `uninstall` and exits. After all uninstalls, `setup.sh` removes the source block from bashrc/zshrc if `~/.setup.d/` has no `.sh` files left.

**Uninstall directory mapping:**

| Tool | Directories removed |
|------|---------------------|
| ssh | `~/.ssh/agent.sock` (kills agent on that socket), `/etc/ssh/sshd_config.d/00-setup-scripts.conf` (if managed) |
| vsftpd | none (stops/disables the service, restores the backed-up `/etc/vsftpd.conf`) |
| pyenv | `~/.pyenv` |
| uv | `~/.local/bin/uv{,x}`, `~/.cache/uv`, `~/.local/share/uv` |
| pipx | `~/.local/pipx`, `~/.local/bin/pipx` |
| poetry | `~/.local/bin/poetry`, `~/.local/share/pypoetry`, `~/.cache/pypoetry` |
| miniconda | `~/.miniconda3` |
| anaconda | `~/.anaconda3` |
| nvm | `~/.nvm` |
| bun | `~/.bun` |
| rustup | `~/.rustup`, `~/.cargo` |

Note: `ssh` uninstall does **not** remove `~/.ssh/config` (user may have their own) — it removes the agent socket, the setup.d/fish files, kills the shared agent, and removes the managed `/etc/ssh/sshd_config.d/00-setup-scripts.conf` drop-in (if present). System-wide sshd configuration is opt-in during setup and never overwrites a config already managed by another user; use `./setup.sh --force` to override it.

### 10. Main Function

```bash
main() {
    if [ "${UNINSTALL:-0}" = "1" ]; then
        uninstall
        exit 0
    fi

    install_deps
    install_<tool>
    setup_shell

    ok "<tool> ready! Run: <example usage>"
}

main "$@"
```

Success message should include a short example of how to actually use the tool.

### 11. Permissions

After creating a script, always run:
```bash
chmod +x scripts/setup-<tool>.sh
```

## Adding a New Script — Full Workflow

1. Copy `scripts/setup-pyenv.sh` as a template
2. Replace the tool-specific logic:
   - Rename `install_pyenv` → `install_<tool>`, update `SETUP_NUM`, `SETUP_NAME`
   - Pick a unique number (see numbering table)
   - Update the dependency list per distro (research what build deps are needed)
   - Update the shell config blocks to match the tool's requirements
   - Update `uninstall()` with the correct data directories to remove
3. Update the success message with correct usage instructions
4. Make executable: `chmod +x scripts/setup-<tool>.sh`
5. Verify it runs without syntax errors and is executable (see Testing)
6. Update `README.md`:
   - Add the tool to the "Available Setups" table under the matching category (see "Updating the README" for grouping rules)

## Updating the README

README changes are required when:
- **Adding a new script** → add a row to the "Available Setups" table:

```markdown
| [<tool>](<official-url>) | Short description |
```

- **Changing supported distros or shells** → update the tables in "Supported Distros" / "Supported Shells"

- **Grouping rules** — the "Available Setups" table is a **single table** organized by category, so tools are easy to find:
  - Existing categories (in order): **Python**, **JavaScript**, **Rust**
  - Add the new tool under the matching category, keeping related tools together
  - If no existing category fits, create a new one (e.g. Go, Databases)
  - Insert into the correct position within the category (alphabetical or logical order), NOT at the end of the table

Keep the README minimal — no installation instructions for individual tools, no screenshots, no badges.

## Style Rules

- **No comments** inside functions (except heredoc markers, which are required)
- Use `local` for all function variables
- Quote all variable expansions: `"$var"` not `$var`
- Use `set -euo pipefail` at the top of every script
- No `detect_distro()` / `detect_shells()` in individual scripts — only in `setup.sh`
- Keep scripts self-contained — no external helper files
- Silent no-ops for idempotency (don't print "already configured" warnings)

## Testing

Before committing, verify:

1. Syntax check all scripts:
   ```bash
   bash -n setup.sh && for s in scripts/*.sh; do bash -n "$s"; done
   ```
2. Executable:
   ```bash
   ls -l setup.sh scripts/setup-<tool>.sh
   ```
3. `.gitignore` still covers `env`

## Git Notes

- `env` is auto-generated and git-ignored — never commit it
- Don't commit empty commits or push unless explicitly asked
