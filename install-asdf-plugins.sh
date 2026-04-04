#!/bin/sh

set -e

. ./helper.sh

# Ensure $HOME/.local/bin is in PATH (where asdf binary lives)
case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin${PATH:+:${PATH}}";;
esac

if ! command -v asdf > /dev/null 2>&1; then
  echo "Error: asdf is not installed or not in PATH."
  echo "Run ./install-asdf.sh first."
  exit 1
fi

install_asdf_plugin() {
  plugin_name=$1
  release=$2

  if ! asdf plugin list | grep -q "^${plugin_name}$"; then
    asdf plugin add "$plugin_name"
  fi
  asdf install "$plugin_name" "$release"
  # get all installed versions of the given plugin, remove '*', sort and get the latest
  version=$(asdf list "$plugin_name" | sed 's/[* ]//g' | sort -V | tail -n 1)
  asdf set "$plugin_name" "$version"
}

# Ask before installing tmux (it is a heavier build dependency)
install_tmux=true
prompt_msg=""
prompt_msg="$prompt_msg\nInstall tmux via asdf? This will build tmux from source using asdf"
prompt_msg="$prompt_msg\nand may override any existing system tmux installation."
prompt_msg="$prompt_msg\nNo sudo is required."
prompt_msg="$prompt_msg\nWould you like to continue? [y/n]"

if yes_or_no "$prompt_msg"; then
    if command -v tmux > /dev/null && which tmux | grep -vq '\.asdf/shims'; then
        prompt_msg="\n"
        prompt_msg="$prompt_msg\nA system tmux installation was detected: $(tmux -V) at $(which tmux)"
        prompt_msg="$prompt_msg\nYou can either uninstall the system tmux manually, or proceed with the asdf installation."
        prompt_msg="$prompt_msg\nThe asdf version will take precedence in your PATH."
        prompt_msg="$prompt_msg\nDo you want to continue and install tmux via asdf? [y/n]"

        if yes_or_no "$prompt_msg"; then
            echo ""
            echo "Proceeding with tmux installation via asdf..."
            echo ""
            sleep 1
        else
            install_tmux=false
        fi
    fi
else
    install_tmux=false; 
fi

if [ "$install_tmux" = true ]; then
    install_asdf_plugin tmux latest
else
    echo ""
    echo "Tmux installation via asdf was cancelled by the user."
    echo ""
    sleep 1
fi

install_asdf_plugin rust latest

rust_version=$(asdf list rust | sed 's/[* ]//g' | sort -V | tail -1)
# shellcheck disable=SC1090
. "${ASDF_DATA_DIR:-$HOME/.asdf}/installs/rust/${rust_version}/env"
rustup default stable

install_asdf_plugin fzf latest
install_asdf_plugin ripgrep latest
install_asdf_plugin bat latest
install_asdf_plugin starship latest
install_asdf_plugin fd latest
install_asdf_plugin vim latest

# Note: I'm installing zoxide and eza using cargo instead of asdf plugins
# because the plugin repositories are currently unavailable
# https://github.com/nyrst/asdf-zoxide
# https://github.com/nyrst/asdf-eza
# install_asdf_plugin zoxide latest
# install_asdf_plugin eza latest

if command -v cargo > /dev/null; then
    if command -v eza > /dev/null; then
        echo "'eza $(eza --version | head -1)' is already installed."
    else
        echo "Installing eza via cargo..."
        cargo install eza
    fi
    if command -v zoxide > /dev/null; then
        echo "'$(zoxide --version)' is already installed."
    else
        echo "Installing zoxide via cargo..."
        cargo install zoxide
    fi
else
    echo "Something went wrong: cargo is not installed or not in the path."
    exit 1
fi

asdf reshim

set +e
