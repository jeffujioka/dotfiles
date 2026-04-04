#!/bin/bash

set -e

. ./helper.sh

timestamp=$(date +%F_%H%M%S)

bak_dir="${HOME}/.dotfiles_bkp/${timestamp}"

script_dir=$(dirname "$(readlink -f "$0")")

echo "The current directory of the script is: $script_dir"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

USER_LOCAL_HOME="${HOME}/.local"
USER_LOCAL_BIN="${USER_LOCAL_HOME}/bin"
USER_GIT_DOWNLOADS=".git_downloads"

mkdir -p "${XDG_CONFIG_HOME}"
mkdir -p "${USER_LOCAL_BIN}"
mkdir -p "${HOME}/.bash_completion.d"

DARWIN_PACKAGES=(
  "autoconf"                                                                  \
  "curl"                                                                      \
  "fontconfig"                                                                \
  "freetype"                                                                  \
  "gawk"                                                                      \
  "gcc"                                                                       \
  "git"                                                                       \
  "jp2a"                                                                      \
  "libevent"                                                                  \
  "make"                                                                      \
  "ncurses"                                                                   \
  "pkg-config"                                                                \
  "python3"                                                                   \
  "utf8proc"                                                                  \
  "zsh"                                                                       \
)

LINUX_PACKAGES="
  autoconf                                                                    \
  bison                                                                       \
  build-essential                                                             \
  curl                                                                        \
  gawk                                                                        \
  gcc                                                                         \
  git                                                                         \
  jp2a                                                                        \
  libevent-dev                                                                \
  libfontconfig1-dev                                                          \
  libfreetype6-dev                                                            \
  libncurses5-dev                                                             \
  make                                                                        \
  pkg-config                                                                  \
  python3                                                                     \
  xsel                                                                        \
  zsh                                                                         \
"
# libxcb-xfixes0-dev \
# libxkbcommon-dev \

get_system_package_list() {
  case "$OSTYPE" in
  darwin*)
    echo "${DARWIN_PACKAGES[@]}" | tr -s ' ' | tr ' ' '\n'
    ;;
  linux*)
    echo "${LINUX_PACKAGES[@]}" | tr -s ' ' | tr ' ' '\n'
    ;;
  esac
}

get_cpu_count() {
    if command -v nproc &>/dev/null; then
        # Use nproc if available (common on Linux)
        nproc
    elif sysctl -n hw.logicalcpu &>/dev/null || sysctl -n hw.ncpu &>/dev/null ; then
        # Use sysctl for systems where it's available (e.g., macOS/ARM)
        sysctl -n hw.logicalcpu 2>/dev/null || sysctl -n hw.ncpu
    else
        # Fallback to checking /proc/cpuinfo (Linux systems)
        echo "10"
    fi
}

install_sys_packages() {
  set -x
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &>/dev/null; then
      echo "homebrew is not installed."
      echo "trying to install it."
      sleep 1
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      echo >> "$HOME/.zprofile"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Update Homebrew
    echo ""
    sleep 1
    brew update && brew upgrade

    echo "Installing packages: $(get_system_package_list)"
    for package in "${DARWIN_PACKAGES[@]}"; do
      echo "Installing ${package}..."
      brew install "${package}"
    done

  else
    echo ""
    sleep 1
    sudo apt update && sudo apt upgrade -y

    echo ""
    echo "Installing packages: $(get_system_package_list)"
    sleep 1
    sudo apt install -y ${LINUX_PACKAGES}
  fi
  set +x
}

install_non_asdf_tools() {
  if [ ! -f "${HOME}/.bash_completion.d/tmux_completion" ]; then
    echo "Installing tmux completion..."
    curl -o "${HOME}/.bash_completion.d/tmux_completion" https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux
  fi

  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "trying to clone tpm"
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
  else
    echo "Updating tmux tpm repository..."
    pushd "$HOME/.tmux/plugins/tpm" > /dev/null 2>&1 || echo "Failed to pushd .tmux/plugins/tpm"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if [ ! -d "${USER_GIT_DOWNLOADS}/nerd-fonts" ]; then
    echo "Cloning nerd-fonts..."
    git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git ${USER_GIT_DOWNLOADS}/nerd-fonts
  else
    echo "Updating nerd-fonts repository..."
    pushd "${USER_GIT_DOWNLOADS}/nerd-fonts" > /dev/null 2>&1 || echo "Failed to pushd ${USER_GIT_DOWNLOADS}/nerd-fonts"
    git fetch --all --prune
    git pull --rebase origin master
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if pushd "${USER_GIT_DOWNLOADS}/nerd-fonts" ; then
    ./install.sh
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if [ ! -d "${USER_GIT_DOWNLOADS}/mate" ]; then
    echo "Cloning mate..."
    git clone --depth 1 https://github.com/jeffujioka/mate.git ${USER_GIT_DOWNLOADS}/mate
  else
    echo "Updating mate repository..."
    pushd "${USER_GIT_DOWNLOADS}/mate" > /dev/null 2>&1 || echo "Failed to pushd ${USER_GIT_DOWNLOADS}/mate"
    git fetch --all --prune
    git pull --rebase origin main
    popd > /dev/null 2>&1 || echo "Failed to popd"
  fi

  if pushd "${USER_GIT_DOWNLOADS}/mate" ; then
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
  
  mkdir -p "${HOME}/.zsh_completion.d"
  ln -sf "$(readlink -f zsh_completion.d)" "${HOME}/.zsh_completion.d"
  
  # backup_this "${HOME}/.bashrc"
  # ln -sf "$(readlink -f bashrc)" "${HOME}/.bashrc"
  
  backup_this "${HOME}/.zshrc"
  ln -sf "$(readlink -f zshrc)" "${HOME}/.zshrc"
  
  backup_this "${HOME}/.zsh_aliases"
  ln -sf "$(readlink -f zsh_aliases)" "${HOME}/.zsh_aliases"
  
  backup_this "${HOME}/.zsh_completions"
  ln -sf "$(readlink -f zsh_completions)" "${HOME}/.zsh_completions"
  
  backup_this "${HOME}/.zsh_aliases.d"
  ln -sf "$(readlink -f zsh_aliases.d)" "${HOME}/"

  ln -sf "$(readlink -f config/ascii-art-goku.txt)" "${XDG_CONFIG_HOME}/"

  backup_this "${XDG_CONFIG_HOME}/starship.toml"
  ln -sf "$(readlink -f config/starship.toml)" "${XDG_CONFIG_HOME}/"

  backup_this "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
  ln -sf "$(readlink -f config/fzf.zsh)" "${XDG_CONFIG_HOME}/fzf/"

  backup_this "${HOME}/.gitignore"
  ln -sf "$(readlink -f gitignore)" "${HOME}/.gitignore"

  backup_this "${HOME}/.gitconfig"
  cp gitconfig "${HOME}/.gitconfig"
  # ln -sf "$(readlink -f gitconfig)" "${HOME}/.gitconfig"
  if [ -n "$GIT_USER_NAME" ]; then
    echo "setting git user.name to $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
  fi
  if [ -n "$GIT_USER_EMAIL" ]; then
    echo "setting git user.email to $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
  fi

  backup_this "${HOME}/.tmux.conf"
  ln -sf "$(readlink -f tmux.conf)" "${HOME}/.tmux.conf"

  backup_this "${HOME}/.vimrc"
  ln -sf "$(readlink -f vimrc)" "${HOME}/.vimrc"

  ln -sf "$(readlink -f bin)/*" "${USER_LOCAL_BIN}/"
}

function check_config_properties() {
  if [ -f ".config.properties" ]; then
      echo "exporting vars"
      set -a  # Automatically export all variables
      . .config.properties
      set +a  # Turn off auto-export
  else
      echo "Properties file '.config.properties' not found!"
      exit 1
  fi

  error=0

  if [ -z "$GIT_USER_NAME" ]; then
      echo "Please set GIT_USER_NAME environment variable!"
      error=1
  fi
  if [ -z "$GIT_USER_EMAIL" ]; then
      echo "Please set GIT_USER_EMAIL environment variable!"
      error=1
  fi

  if [ $error -eq 1 ]; then
      exit 1
  fi
}

check_config_properties

install_asdf=true
install_asdf_plugins=true
should_install_non_asdf_tools=true
should_create_backups=true
no_sudo_install=false

while [ -n "$1" ]
do
  case "$1" in
    --no-install-asdf)
      install_asdf=false
      echo "It won't install asdf!!!"
      shift
      ;;
    --no-install-asdf-plugins)
      install_asdf_plugins=false
      echo "It won't install asdf plugins!!!"
      shift
      ;;
    --no-install-non-asdf-tools)
      should_install_non_asdf_tools=false
      echo "It won't install non-asdf tools such as tpm, nerd-fonts, mate, etc.!!!"
      shift
      ;;
    --no-backups)
      should_create_backups=false
      shift
      ;;
    --no-sudo-install)
      no_sudo_install=true
      shift
      ;;
    *)
      echo "Invalid option"
      echo "Usage: $0 [--no-install-asdf] [--no-install-asdf-plugins] [--no-install-non-asdf-tools] [--no-backups] [--no-sudo-install]"
      exit 1
      ;;
  esac
done

if [ "$should_create_backups" = "true" ]; then
  set +e
  create_backups
  set -e
fi

if [ "$install_asdf" = "true" ]; then
  ./install-asdf.sh
fi

if [ "$no_sudo_install" = "false" ]; then
  # print a big warning ASCII message before printing the prompt_msg
  echo "********************************************************************************"
  echo "********************************************************************************"
  prompt_msg="\nThis script requires the following system packages on your environment: "
  prompt_msg="${prompt_msg}$(get_system_package_list)\n\n"
  prompt_msg="${prompt_msg}If they are not installed, the script can install them for you.\n"
  prompt_msg="${prompt_msg}However, it requires sudo privileges.\n"
  prompt_msg="${prompt_msg}Please, ask your system administrator to install them for you in case you do not have sudo privileges.\n"
  prompt_msg="${prompt_msg}Would you like to proceed and install them on your environment? (y/n)\n"

  if yes_or_no "$prompt_msg"; then
    echo "********************************************************************************"
    echo "********************************************************************************"
    echo "Great! Let's install the necessary packages."
    echo ""
    install_sys_packages
  else
    echo "********************************************************************************"
    echo "********************************************************************************"
    echo -e "\nSkipping system package installation as you do not have sudo privileges."
    echo "You should ask your system administrator to install them for you."
    no_sudo_install=true
  fi
fi

if [ "$should_install_non_asdf_tools" = "true" ]; then
  install_non_asdf_tools
fi

if [ "$install_asdf_plugins" = "true" ]; then
  ./install-asdf-plugins.sh
fi

echo ""
echo "dotfiles have been successfully installed"
