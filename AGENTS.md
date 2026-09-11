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
2. **Dependency installation** — install OS packages via the distro's package manager
3. **Tool installation** — install the actual tool
4. **Shell configuration** — one function per shell (`configure_bash`, `configure_zsh`, `configure_fish`)
5. **`main()` function** — orchestrates the above steps

### 5. Dependency Installation

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

### 6. Tool Installation

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

### 7. Shell Configuration

| Shell  | Config Location                            | Method                          |
|--------|---------------------------------------------|---------------------------------|
| bash   | `~/.bashrc`                                 | Append block                    |
| zsh    | `~/.zshrc`                                  | Append block                    |
| fish   | `~/.config/fish/conf.d/<tool>.fish`         | Write file to conf.d            |

**Idempotency:** all config functions must be silent no-ops if already configured:
- bash/zsh: `grep -q "# <tool> setup" "$rc" 2>/dev/null && return`
- fish: `[ -f "$file" ] && return`

Use a heredoc with the unique comment marker `# <tool> setup` at the top of each block.

For bash/zsh heredocs, **always quote the delimiter** (`<< 'EOF'`) to prevent variable expansion.

Only print `info "Configured $rc"` when actually writing (not when skipping).

### 8. Main Function

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

    ok "<tool> ready! Run: <example usage>"
}

main "$@"
```

Success message should include a short example of how to actually use the tool.

### 9. Permissions

After creating a script, always run:
```bash
chmod +x scripts/setup-<tool>.sh
```

## Adding a New Script — Full Workflow

1. Copy `scripts/setup-pyenv.sh` as a template
2. Replace the tool-specific logic:
   - Rename `install_pyenv` → `install_<tool>`, `configure_bash`, etc.
   - Update the dependency list per distro (research what build deps are needed)
   - Update the shell config blocks to match the tool's requirements
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