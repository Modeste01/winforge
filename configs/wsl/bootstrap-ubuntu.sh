#!/usr/bin/env bash
# WinForge WSL2 Ubuntu Bootstrap
# Run inside Ubuntu WSL2: bash configs/wsl/bootstrap-ubuntu.sh
set -euo pipefail
echo "=== WinForge WSL2 Bootstrap ==="

sudo apt-get update -qq && sudo apt-get upgrade -y -qq

sudo apt-get install -y -qq \
    curl wget git zsh tmux htop tree \
    build-essential pkg-config libssl-dev \
    unzip zip jq ripgrep fd-find bat \
    python3-pip python3-venv \
    gcc g++ make cmake \
    openssh-client gpg

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Starship
if ! command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

# Configure .zshrc
ZSHRC="$HOME/.zshrc"
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z docker)/' "$ZSHRC" 2>/dev/null || true
grep -q 'starship init zsh' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"

cat >> "$ZSHRC" << 'ALIASES'
alias ll='ls -lah --color=auto'
alias la='ls -lAh --color=auto'
alias ..='cd ..'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias glog='git log --oneline --graph --decorate --all'
alias py='python3'
alias serve='python3 -m http.server'
ALIASES

chsh -s "$(which zsh)" 2>/dev/null || true
echo "=== WSL2 Bootstrap Complete — restart terminal or run: exec zsh ==="
