#!/bin/sh

set -e

. ./helper.sh

# check if $HOME/.local/bin is in the path
case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin${PATH:+:${PATH}}";;
esac

install_asdf_plugin() {
  plugin_name=$1
  release=$2

  if ! asdf plugin list | grep -q "^$plugin_name\$"; then
    asdf plugin add $plugin_name
  fi
  asdf install $plugin_name $release
  # get all installed version of the given plugin, remove '*', sort it and get the latest version
  version=$(asdf list $plugin_name | sed 's/*//g' | sort -V | tail -n 1)
  asdf set $plugin_name $version
}

# checking if tmux is already installed
install_tmux=true
prompt_msg=""
prompt_msg="$prompt_msg\nTmux installation via asdf requires sudo permissions."
prompt_msg="$prompt_msg\nThis will install tmux using asdf, which may override any existing tmux installation."
prompt_msg="$prompt_msg\nWould you like to continue with the tmux installation? [y/n]"

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

. "$HOME/.asdf/installs/rust/1.89.0/env"
rustup default stable

install_asdf_plugin fzf latest
install_asdf_plugin ripgrep latest
install_asdf_plugin bat latest
install_asdf_plugin starship latest
install_asdf_plugin fd latest
install_asdf_plugin vim latest

# Note: I'm installing zoxide and exa using cargo instead of asdf plugins
# because the plugin repositories are currently unavailable
# https://github.com/nyrst/asdf-zoxide
# https://github.com/nyrst/asdf-exa
# install_asdf_plugin zoxide latest
# install_asdf_plugin exa latest

if command -v cargo > /dev/null; then
    if command -v exa > /dev/null; then
        echo "'exa $(exa --version | grep "^v")' is already installed."
    else
        echo "Installing exa via cargo..."
        cargo install exa
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