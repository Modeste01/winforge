#!/usr/bin/env bash
# =============================================================================
# WinForge: Ubuntu (WSL) bootstrap.
#
# Idempotent — safe to re-run. Installs:
#   - apt baseline + build-essential
#   - zsh + oh-my-zsh + plugins
#   - starship prompt
#   - SDKMAN (Java, Maven, Gradle, etc.)
#   - fnm (Node) and pnpm
#   - uv (Python) + pipx
#   - rustup, Go (via apt)
#   - Docker CLI (uses Docker Desktop integration if WSL integration is on)
#   - GitHub CLI
#
# Usage from PowerShell:
#   wsl -- bash /mnt/c/path/to/winforge/configs/wsl/bootstrap-ubuntu.sh
# =============================================================================
set -euo pipefail

log() { printf "\033[36m[winforge]\033[0m %s\n" "$*"; }
warn(){ printf "\033[33m[winforge]\033[0m %s\n" "$*"; }
ok()  { printf "\033[32m[winforge]\033[0m %s\n" "$*"; }

# ---- 0. Sanity --------------------------------------------------------------
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "Not running in WSL — continuing anyway."
fi

export DEBIAN_FRONTEND=noninteractive

# ---- 1. apt baseline --------------------------------------------------------
log "Updating apt and installing baseline packages"
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
    build-essential curl wget git ca-certificates gnupg lsb-release \
    unzip zip xz-utils tar jq tree htop ripgrep fd-find bat \
    zsh tmux \
    python3 python3-pip python3-venv pipx \
    golang-go \
    software-properties-common apt-transport-https

# Debian renames bat/fd binaries; symlink to common names.
[ -e /usr/bin/batcat ] && sudo ln -sf /usr/bin/batcat /usr/local/bin/bat || true
[ -e /usr/bin/fdfind ] && sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd || true

# ---- 2. zsh + oh-my-zsh -----------------------------------------------------
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
    git clone --depth=1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
  fi
done

# Set zsh as default shell if it isn't already.
if [ "${SHELL##*/}" != "zsh" ] && command -v zsh >/dev/null; then
  log "Setting zsh as default shell"
  sudo chsh -s "$(command -v zsh)" "$USER" || true
fi

# ---- 3. starship prompt -----------------------------------------------------
if ! command -v starship >/dev/null; then
  log "Installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# ---- 4. SDKMAN (Java, Maven, Gradle) ---------------------------------------
if [ ! -d "${HOME}/.sdkman" ]; then
  log "Installing SDKMAN"
  curl -fsSL "https://get.sdkman.io" | bash
fi
# shellcheck disable=SC1091
set +u
[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ] && source "$HOME/.sdkman/bin/sdkman-init.sh"
if command -v sdk >/dev/null; then
  sdk install java 21.0.4-tem  </dev/null || true
  sdk install maven           </dev/null || true
  sdk install gradle          </dev/null || true
fi
set -u

# ---- 5. fnm (Node) ----------------------------------------------------------
if ! command -v fnm >/dev/null; then
  log "Installing fnm"
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm >/dev/null; then
  eval "$(fnm env --use-on-cd || true)"
  fnm install --lts || true
  fnm default lts-latest || true
  if command -v npm >/dev/null; then
    npm i -g pnpm yarn || true
  fi
fi

# ---- 6. uv (Python) + pipx --------------------------------------------------
if ! command -v uv >/dev/null; then
  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath || true

# ---- 7. rustup --------------------------------------------------------------
if ! command -v rustup >/dev/null; then
  log "Installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
fi

# ---- 8. Docker CLI (Docker Desktop WSL integration) -------------------------
# If Docker Desktop integration is on, /usr/bin/docker is provided automatically.
if ! command -v docker >/dev/null; then
  warn "docker not on PATH — enable Docker Desktop's WSL integration for Ubuntu, or install docker-ce manually."
fi

# ---- 9. GitHub CLI ----------------------------------------------------------
if ! command -v gh >/dev/null; then
  log "Installing GitHub CLI"
  type -p curl >/dev/null
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y gh
fi

# ---- 10. Drop a baseline ~/.zshrc ------------------------------------------
ZSHRC="${HOME}/.zshrc"
if [ -f "$ZSHRC" ] && ! grep -q "WinForge baseline" "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.winforge.bak.$(date +%s)"
fi
cat > "$ZSHRC" <<'ZSHRC'
# WinForge baseline ~/.zshrc -------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf docker kubectl)
source $ZSH/oh-my-zsh.sh

# starship
command -v starship >/dev/null && eval "$(starship init zsh)"
# fnm
[ -d "$HOME/.local/share/fnm" ] && export PATH="$HOME/.local/share/fnm:$PATH"
command -v fnm >/dev/null && eval "$(fnm env --use-on-cd)"
# uv
export PATH="$HOME/.local/bin:$PATH"
# rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# go
export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"
# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

alias ll='ls -lah --color=auto'
alias gs='git status'
alias k='kubectl'
ZSHRC

ok "WSL bootstrap complete. Open a new terminal or run: exec zsh"
