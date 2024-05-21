#!/bin/bash

timestamp=$(date +%F_%H%M%S)

bak_dir="${HOME}/.dotfiles_bkp/${timestamp}"

script_dir=$(dirname "$(readlink -f "$0")")

echo "The current directory of the script is: $script_dir"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

USER_LOCAL_HOME="${HOME}/.local"
USER_LOCAL_BIN="${USER_LOCAL_HOME}/bin"

install_dependencies() {
  yes="$1"
  mkdir -p "${USER_LOCAL_BIN}"

  echo "sudo apt update && sudo apt upgrade ${yes}"
  sudo apt update && sudo apt upgrade "${yes}"
  
  # tmux_dependencies="libevent-2.1-7 libevent-dev libncurses6 autotools-dev automake"
  tmux_dependencies="libevent-dev libncurses-dev autotools-dev automake bison byacc"
  echo "sudo apt install ${yes} ${tmux_dependencies}"
  sudo apt install "${yes}" ${tmux_dependencies}
  
  # Dependencies to install Allacritty terminal: https://github.com/alacritty/alacritty/blob/master/INSTALL.md
  sudo apt install "${yes}" \
    curl \
    gawk \
    git \
    vim \
    cmake \
    pkg-config \
    libfreetype6-dev \
    libfontconfig1-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    python3 \
    jp2a

  # https://gist.github.com/trungnt13/4466aa135026c6e21786ea0964f46171
  if [ ! -f "${HOME}/.bash_completion/tmux_completion" ]; then
    curl -o "${HOME}/.bash_completion/tmux_completion" https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux
  fi

  if ! command -v cargo > /dev/null 2>&1 ; then
    # https://rustup.rs/
    # curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    export RUSTUP_HOME=${XDG_CONFIG_HOME}/rustup
    export CARGO_HOME=${XDG_CONFIG_HOME}/cargo

    echo "Installing Rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    
    # shellcheck source=/dev/null
    source "${XDG_CONFIG_HOME}/cargo/env"
  fi
  
  echo "Installing Rust-based tools..."
  cargo install alacritty procs du-dust zoxide ripgrep fd-find bat exa viu --locked

  if [ ! -f "${USER_LOCAL_BIN}/starship" ]; then
    echo -e "\n\n"
    echo "Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "${USER_LOCAL_BIN}/"
  fi

  if [ ! -d ".tmux" ] ; then
    echo "cloning tmux..."
    git clone https://github.com/tmux/tmux.git .tmux
  else
    pushd .tmux > /dev/null 2>&1 || echo "failed to pushd .tmux"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "failed to popd"
  fi

  if [ -d ".tmux" ] ; then
    pushd ".tmux" > /dev/null 2>&1 || echo "failed to pushd .tmux"
    sh autogen.sh
    ./configure --prefix="${USER_LOCAL_HOME}" \
      && make -j$(( $(nproc) - 2)) \
      && make install
    popd > /dev/null 2>&1 || echo "failed to popd"
  fi

  if [ ! -d ".ble.sh" ]; then
    echo -e "\n\n"
    echo "Cloning Ble.sh..."
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git .ble.sh
  fi

  if [ -d ".ble.sh" ]; then
    echo "Pulling new changes from master..."
    pushd .ble.sh > /dev/null 2>&1 || echo "pushd .ble.sh has failed"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "popd has failed!"

    make -C .ble.sh install PREFIX="${USER_LOCAL_HOME}"
  fi

  if [ ! -d ".fzf" ]; then
    echo -e "\n\n"
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git .fzf
  else
    pushd ".fzf" > /dev/null 2>&1 || echo "failed to pushd .fzf"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo ".fzf popd has failed"
  fi

  if pushd .fzf ; then
    ./install --all --xdg --completion --no-zsh --no-fish --no-update-rc
    popd > /dev/null 2>&1 || echo ".fzf popd has failed"
  fi

  if [ ! -d ".neofetch" ] ; then
    echo "cloning neofetch..."
    git clone https://github.com/dylanaraps/neofetch .neofetch
  else
    pushd .neofetch > /dev/null 2>&1 || echo "failed to pushd .neofetch"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo ""
  fi

  if pushd .neofetch ; then
    echo "installing.. "
    make PREFIX="${USER_LOCAL_HOME}" install
    popd || echo ".neofetch popd has failed!" # this only to silence the shlint as it is unlikely to occurr
  fi
}

function create_backup() {
  file="$1"

  if [ ! -e "${file}" ]; then
    echo "File ${file} does not exist. Skipping backup."
    return
  fi

  if [ -L "${file}" ]; then
    echo "File ${file} is a symbolic link. Skipping backup."
    return
  fi

  bak_name="${file}"
  echo "creating back for: ${file}"
  if [[ ${file} == ${HOME}* ]] ; then
    bak_name="${bak_name##*${HOME}/}"
  fi
  echo "creating backup: moving ${file} to ${bak_dir}/${bak_name}"
  mkdir -p "${bak_dir}/$(dirname "${bak_name}")"
  mv "${file}" "${bak_dir}/${bak_name}"
}

function gen_symlinks() {
  mkdir -p "${bak_dir}"
  
  create_backup "${HOME}/.bashrc"
  ln -srf bashrc "${HOME}/.bashrc"
  
  create_backup "${HOME}/.bash_aliases"
  ln -srf bash_aliases "${HOME}/.bash_aliases"
  
  create_backup "${HOME}/.bash_aliases.d"
  ln -srf bash_aliases.d "${HOME}/.bash_aliases.d"
  
  mkdir -p "${HOME}/.bash_completion"
  ln -srf bash_completion/* "${HOME}/.bash_completion/"
  
  create_backup "${HOME}/.bashrc.d"
  ln -srf bashrc.d "${HOME}/.bashrc.d"

  create_backup "${XDG_CONFIG_HOME}/starship.toml"
  ln -srf config/starship.toml "${XDG_CONFIG_HOME}/"

  create_backup "${XDG_CONFIG_HOME}/fzf.bash"
  ln -srf config/fzf.bash "${XDG_CONFIG_HOME}/"

  create_backup "${XDG_CONFIG_HOME}/neofetch"
  ln -srf config/neofetch/* "${XDG_CONFIG_HOME}/neofetch/"

  ln -srf bin/* "${USER_LOCAL_BIN}/"

  create_backup "${HOME}/.gitignore"
  ln -srf gitignore "${HOME}/.gitignore"

  create_backup "${HOME}/.gitconfig"
  ln -srf gitconfig "${HOME}/.gitconfig"

  create_backup "${HOME}/.tmux.conf"
  ln -srf tmux.conf "${HOME}/.tmux.conf"

  create_backup "${HOME}/.vimrc"
  ln -srf vimrc "${HOME}/.vimrc"
}

installAll=""

case "$1" in
  "-y"|"--yes")
    installAll="--yes"
    ;;
  "*")
    echo "Invalid option"
    exit 1
    ;;
esac

if [ -z "${installAll}" ] ; then
  echo "This script will install the following additional packages:"
  echo '  automake
  autotools-dev
  bison
  byacc
  cmake
  curl
  gawk
  git
  jp2a
  libevent-dev
  libfontconfig1-dev
  libfreetype6-dev
  libncurses-dev
  libxcb-xfixes0-dev
  libxkbcommon-dev
  pkg-config
  python3
  vim'
  read -rp "Do you want to continue? [Y/n] " response

  response=${response,,}
  if [[ "${response}" != "y" && "${response}" != "yes" ]]; then
    echo "Thank you. Goodbye!"
    exit 1
  fi
fi

install_dependencies "${installAll}"
gen_symlinks

echo ""
echo "dotfiles have been successfully installed"
