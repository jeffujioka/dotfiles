#!/bin/bash
set -o pipefail

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

get_system_package_list() {
  if [[ "$OSTYPE" == darwin* ]]; then
    "$script_dir/helpers/read-manifest.py" packages.darwin.list
  elif [[ "$OSTYPE" == linux* ]]; then
    "$script_dir/helpers/read-manifest.py" packages.linux.list
  fi
}

# shellcheck source=helpers/shell-utils.sh
. "$(dirname "$(readlink -f "$0")")/helpers/shell-utils.sh"

# Validate manifest.toml before doing any destructive work.
"$script_dir/helpers/read-manifest.py" cargo.tools --format tsv --fields "crate,binary:" > /dev/null \
  || { echo "Error: manifest.toml is missing or invalid. Aborting."; exit 1; }

install_sys_packages() {
  [ -n "${DEBUG:-}" ] && set -x
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

    echo ""
    sleep 1
    brew update && brew upgrade

    echo "Installing packages:"
    get_system_package_list | while IFS= read -r package; do
      echo "Installing ${package}..."
      brew install "${package}"
    done

  else
    echo ""
    sleep 1
    sudo apt update && sudo apt upgrade -y

    echo ""
    echo "Installing packages:"
    sleep 1
    sudo apt install -y $(get_system_package_list | tr '\n' ' ')
  fi
  [ -n "${DEBUG:-}" ] && set +x
}

install_non_asdf_tools() {
  "$script_dir/helpers/read-manifest.py" resources --format tsv \
      --fields "name,type,path,url,branch:main,shallow:false,post_install:" \
      | while IFS=$'\t' read -r name rtype rpath url branch shallow post_install; do

    # Expand ~ to $HOME
    rpath="${rpath/#\~/$HOME}"

    case "$rtype" in
      git-clone)
        local clone_args=()
        if [ "$shallow" = "true" ]; then
          clone_args+=(--depth 1)
        fi

        if [ ! -d "$rpath" ]; then
          echo "Cloning $name..."
          git clone "${clone_args[@]}" "$url" "$rpath"
        else
          echo "Updating $name..."
          pushd "$rpath" > /dev/null 2>&1 || { echo "Failed to pushd $rpath"; continue; }
          git fetch --all --prune
          git pull --rebase origin "$branch"
          popd > /dev/null 2>&1 || echo "Failed to popd"
        fi

        if [ -n "$post_install" ] && pushd "$rpath" > /dev/null 2>&1; then
          echo "Running post-install for $name..."
          # Intentional: post_install is a trusted shell snippet from manifest.toml
          eval "$post_install"
          popd > /dev/null 2>&1 || echo "Failed to popd"
        fi
        ;;
      file-download)
        mkdir -p "$(dirname "$rpath")"
        if [ ! -f "$rpath" ]; then
          echo "Downloading $name..."
          curl -o "$rpath" "$url"
        fi
        ;;
    esac
  done
}

install_dependencies() {
  if [ -z "$no_sudo_install" ]; then
    install_sys_packages
  fi

  if ! command -v cargo > /dev/null 2>&1 ; then
    echo "Installing Rust..."
    export RUSTUP_HOME=${XDG_CONFIG_HOME}/rustup
    export CARGO_HOME=${XDG_CONFIG_HOME}/cargo
    export TMPDIR=${XDG_CONFIG_HOME}/tmp
    mkdir -p "$TMPDIR"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    
    source "${XDG_CONFIG_HOME}/cargo/env"

    rustup default stable
  fi

  rustup default stable

  echo "Installing Rust-based tools..."
  export TMPDIR=${XDG_CONFIG_HOME}/tmp
  mkdir -p "$TMPDIR"
  "$script_dir/helpers/read-manifest.py" cargo.tools --format tsv --fields "crate,binary:" \
    | while IFS=$'\t' read -r crate binary; do
    binary="${binary:-$crate}"
    if command -v "$binary" > /dev/null 2>&1; then
      echo "'$binary' is already installed."
    else
      echo "Installing $crate via cargo..."
      cargo install --locked "$crate"
    fi
  done

  install_non_asdf_tools
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

function apply_dotfiles() {
  mkdir -p "${bak_dir}"

  "$script_dir/helpers/read-manifest.py" symlinks --format tsv \
      --fields "source,target,type:symlink,backup:true" \
      | while IFS=$'\t' read -r src tgt typ should_backup; do

    # Expand ~ to $HOME
    tgt="${tgt/#\~/$HOME}"
    # Resolve src relative to repo root (not $PWD) — C2 fix
    if [[ "$src" != /* ]]; then src="$script_dir/$src"; fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$tgt")"

    case "$typ" in
      symlink)
        if [ "$should_backup" = "true" ]; then
          backup_this "$tgt"
        fi
        ln -sf "$(resolve_path "$src")" "$tgt"
        ;;
      copy)
        if [ "$should_backup" = "true" ]; then
          backup_this "$tgt"
        fi
        cp "$src" "$tgt"
        ;;
      glob)
        for f in $src; do
          tgt_dir="${tgt%/\*}"
          tgt_dir="${tgt_dir/#\~/$HOME}"
          mkdir -p "$tgt_dir"
          ln -sf "$(resolve_path "$f")" "$tgt_dir/"
        done
        ;;
    esac
  done

  # Initialize default Starship preset
  backup_this "${XDG_CONFIG_HOME}/starship.toml"
  default_preset="config/starship/presets/starship-clean-gradient-aurora.toml"
  if [ -f "$default_preset" ]; then
    ln -sf "$(readlink -f "$default_preset")" "config/starship.toml"
  fi
  ln -sf "$(readlink -f config/starship.toml)" "${XDG_CONFIG_HOME}/"

  # gitconfig special handling: set user name/email after copy
  if [ -n "$GIT_USER_NAME" ]; then
    echo "setting git user.name to $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
  fi
  if [ -n "$GIT_USER_EMAIL" ]; then
    echo "setting git user.email to $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
  fi
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

install_deps="1"
no_sudo_install=""
no_backups="1"
install_all=""

while [ -n "$1" ]
do
  case "$1" in
    --no-install-deps)
      install_deps=""
      echo "it won't install deps!!!"
      shift
      ;;
    --no-sudo-install)
      no_sudo_install="1"
      echo "skipping system package installation (no sudo)"
      shift
      ;;
    --no-backups)
      no_backups=""
      shift
      ;;
    --install-all)
      install_all="--yes"
      shift
      ;;
    *)
      echo "Invalid option"
      exit 1
      ;;
  esac
done

check_config_properties

if [ -n "$install_deps" ]; then
  if [ -z "${install_all}" ] && [ -z "$no_sudo_install" ]; then
    echo "This script will install the following additional packages:"
    get_system_package_list | sed 's/^/  /'
    read -rp "Do you want to continue? [Y/n] " response

    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    if [[ "${response}" != "y" && "${response}" != "yes" ]]; then
      echo "Thank you. Goodbye!"
      exit 1
    fi
  fi
  install_dependencies
fi

if [ -n "$no_backups" ]; then
  apply_dotfiles
fi

echo ""
echo "dotfiles have been successfully installed"
