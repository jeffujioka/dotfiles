#!/bin/bash

timestamp=$(date +%F_%H%M%S)

bak_dir="${HOME}/.dotfiles_bkp/${timestamp}"

script_dir=$(dirname "$(readlink -f "$0")")

echo "The current directory of the script is: $script_dir"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

USER_LOCAL_HOME="${HOME}/.local"
USER_LOCAL_BIN="${USER_LOCAL_HOME}/bin"

echo "creating folder: $XDG_CONFIG_HOME"
mkdir -p "${XDG_CONFIG_HOME}"
mkdir -p "${USER_LOCAL_BIN}"
mkdir -p .gitrepos
mkdir -p "${HOME}/.bash_completion.d"

get_cpu_count() {
    if command -v nproc &>/dev/null; then
        # Use nproc if available (common on Linux)
        nproc
    elif command -v sysctl &>/dev/null; then
        # Use sysctl for systems where it's available (e.g., macOS/ARM)
        sysctl -n hw.logicalcpu 2>/dev/null || sysctl -n hw.ncpu
    else
        # Fallback to checking /proc/cpuinfo (Linux systems)
        echo "10"
    fi
}

install_dependencies() {
  yes="$1"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Running on macOS. Using brew for dependency installation."

    # Update Homebrew
    echo "Updating Homebrew..."
    brew update && brew upgrade

    # Install tmux dependencies
    tmux_dependencies=("libevent" "ncurses" "automake" "bison" "byacc" "utf8proc")

    echo "Installing tmux dependencies: ${tmux_dependencies[*]}"
    for dependency in "${tmux_dependencies[@]}"; do
      echo "Installing ${dependency}..."
      brew install "${dependency}"
    done

    # Install Alacritty dependencies
    other_dependencies=("curl" "gawk" "git" "vim" "cmake" "pkg-config" "freetype" "fontconfig" "xcb-util-xrm" "xkbcommon" "python3" "jp2a")

    echo "Installing Alacritty dependencies: ${other_dependencies[*]}"
    for dependency in "${other_dependencies[@]}"; do
      echo "Installing ${dependency}..."
      brew install "${dependency}"
    done

  else
    echo "Running on Linux. Using apt for dependency installation."

    echo "sudo apt update && sudo apt upgrade ${yes}"
    sudo apt update && sudo apt upgrade "${yes}"

    tmux_dependencies="libevent-dev libncurses-dev autotools-dev automake bison byacc"
    echo "sudo apt install ${yes} ${tmux_dependencies}"
    sudo apt install "${yes}" ${tmux_dependencies}

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
  fi

  if [ ! -f "${HOME}/.bash_completion.d/tmux_completion" ]; then
    echo "Installing tmux completion..."
    curl -o "${HOME}/.bash_completion.d/tmux_completion" https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux
  fi

  if ! command -v cargo > /dev/null 2>&1 ; then
    echo "Installing Rust..."
    export RUSTUP_HOME=${XDG_CONFIG_HOME}/rustup
    export CARGO_HOME=${XDG_CONFIG_HOME}/cargo
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    
    source "${XDG_CONFIG_HOME}/cargo/env"
  fi

  echo "setting default rust toolchain to stable"
  rustup default stable

  echo "Installing Rust-based tools..."
  cargo install procs du-dust zoxide ripgrep fd-find bat exa viu --locked

  if [ ! -f "${USER_LOCAL_BIN}/starship" ]; then
    echo "Installing Starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "${USER_LOCAL_BIN}/"
  fi

  if [ ! -d ".tmux" ]; then
    echo "Cloning tmux..."
    git clone https://github.com/tmux/tmux.git .tmux
  else
    echo "Updating tmux repository..."
    pushd .tmux > /dev/null 2>&1 || echo "Failed to pushd .tmux"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if [ -d ".tmux" ]; then
    echo "Building tmux..."
    pushd ".tmux" > /dev/null 2>&1 || echo "Failed to pushd .tmux"
    sh autogen.sh
    local enable_utf8_proc=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
      enable_utf8_proc="--enable-utf8proc"
    fi
    # Get the number of CPUs, subtract 2, and ensure it's at least 1
    cpu_count=$(( $(get_cpu_count) - 2 ))
    if (( cpu_count < 1 )); then
        cpu_count=1
    fi
    ./configure --prefix="${USER_LOCAL_HOME}" "$enable_utf8_proc" \
      && make -j$cpu_count \
      && make install
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if [ ! -d ".fzf" ]; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git .fzf
  else
    echo "Updating fzf repository..."
    pushd ".fzf" > /dev/null 2>&1 || echo "Failed to pushd .fzf"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if pushd .fzf ; then
    ./install --all --xdg --completion --no-bash --no-zsh --no-fish --no-update-rc
    echo "installing fzf!!!"
    fzf_bin_dir="$(readlink -f bin)"
    find "$(readlink -f bin)" -type f -exec ln -sf {} "${HOME}/.local/bin/" \;
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if [ ! -d ".gitrepos/nerd-fonts" ]; then
    echo "Cloning nerd-fonts..."
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git .gitrepos/nerd-fonts
  else
    echo "Updating nerd-fonts repository..."
    pushd ".gitrepos/nerd-fonts" > /dev/null 2>&1 || echo "Failed to pushd .gitrepos/nerd-fonts"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if pushd .gitrepos/nerd-fonts ; then
    ./install.sh
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi
}

function backup_this() {
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

function create_backups() {
  mkdir -p "${bak_dir}"
  
  mkdir -p "${HOME}/.bash_completion"
  ln -sf "$(readlink -f bash_completion)" "${HOME}/.bash_completion"
  
  backup_this "${HOME}/.bashrc"
  ln -sf "$(readlink -f bashrc)" "${HOME}/.bashrc"
  
  backup_this "${HOME}/.zshrc"
  ln -sf "$(readlink -f zshrc)" "${HOME}/.zshrc"
  
  backup_this "${HOME}/.bash_aliases"
  ln -sf "$(readlink -f bash_aliases)" "${HOME}/.bash_aliases"
  
  backup_this "${HOME}/.bashrc.d"
  ln -sf "$(readlink -f bashrc.d)" "${HOME}/.bashrc.d"

  ln -sf "$(readlink -f config/ascii-art-goku.txt)" "${XDG_CONFIG_HOME}/"

  backup_this "${XDG_CONFIG_HOME}/starship.toml"
  ln -sf "$(readlink -f config/starship.toml)" "${XDG_CONFIG_HOME}/"

  # backup_this "${XDG_CONFIG_HOME}/fzf/fzf.bash"
  # ln -sf "$(readlink -f config/fzf.bash)" "${XDG_CONFIG_HOME}/fzf/"

  backup_this "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
  ln -sf "$(readlink -f config/fzf.zsh)" "${XDG_CONFIG_HOME}/fzf/"

  backup_this "${HOME}/.gitignore"
  ln -sf "$(readlink -f gitignore)" "${HOME}/.gitignore"

  backup_this "${HOME}/.gitconfig"
  ln -sf "$(readlink -f gitconfig)" "${HOME}/.gitconfig"

  backup_this "${HOME}/.tmux.conf"
  ln -sf "$(readlink -f tmux.conf)" "${HOME}/.tmux.conf"

  backup_this "${HOME}/.vimrc"
  ln -sf "$(readlink -f vimrc)" "${HOME}/.vimrc"

  ln -sf "$(readlink -f bin)/*" "${USER_LOCAL_BIN}/"
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
create_backups

echo ""
echo "dotfiles have been successfully installed"
