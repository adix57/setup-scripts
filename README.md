# setup-scripts

Universal Linux setup scripts for multiple distros and shells.

## Supported Distros

| Distro | ID |
|--------|-----|
| Arch / Manjaro / EndeavourOS / Omarchy | `arch` |
| Debian / Ubuntu / Linux Mint / Pop!_OS / Kali | `debian` |
| Fedora | `fedora` |

## Supported Shells

Bash, Zsh, Fish

## Available Setups

| Tool | Description |
|------|-------------|
| [pyenv](https://github.com/pyenv/pyenv) | Python version manager (with pyenv-virtualenv) |
| [uv](https://docs.astral.sh/uv/) | Fast Python package installer & resolver |
| [pipx](https://github.com/pypa/pipx) | Install and run Python applications in isolated environments |
| [poetry](https://python-poetry.org/) | Python dependency management and packaging |
| [miniconda](https://docs.conda.io/en/latest/miniconda.html) | Minimal Python environment & package manager |
| [anaconda](https://www.anaconda.com/download) | Full data science & Python distribution |
| [nvm](https://github.com/nvm-sh/nvm) | Node.js version manager |
| [bun](https://bun.sh/) | Fast JavaScript runtime, package manager & bundler |
| [rustup](https://rustup.rs/) | Rust toolchain installer |

## Usage

```bash
chmod +x setup.sh
./setup.sh
```

This launches an interactive fzf menu where you can select which tools to install.

### Commands

| Command | Description |
|---------|-------------|
| `./setup.sh` | Interactive fzf menu |
| `./setup.sh --regen` | Regenerate cached system info |
| `./setup.sh --help` | Show help |
