#compdef install.sh

_install_sh() {
  _arguments \
    '--no-install-deps[Skip dependency installation]' \
    '--no-sudo-install[Install system packages via Homebrew instead of sudo apt]' \
    '--no-backups[Skip backing up existing dotfiles]' \
    '--install-all[Accept all prompts automatically]'
}

_install_sh "$@"
