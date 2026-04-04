dotfiles
========

Personal dotfiles for zsh, tmux, vim, git and more.

## Quick start

```sh
cp config.properties.in .config.properties
# edit .config.properties and set GIT_USER_NAME and GIT_USER_EMAIL
./install.sh
```

## install.sh flags

| Flag | Description |
|---|---|
| `--no-install-asdf` | Skip downloading/installing the asdf binary |
| `--no-install-asdf-plugins` | Skip installing tools via asdf plugins |
| `--no-install-non-asdf-tools` | Skip tpm, nerd-fonts, mate, etc. |
| `--no-backups` | Skip creating dotfile backups before symlinking |
| `--no-sudo-install` | Skip system package installation (apt/brew) — use this on build servers or machines without admin rights |

## No-admin environments (build servers)

asdf installs everything under `$HOME/.local/bin` and `$HOME/.asdf` — **no sudo required**.

```sh
./install.sh --no-sudo-install
```

This will:
1. Install the asdf binary to `~/.local/bin`
2. Install all tools (tmux, rust, fzf, ripgrep, bat, starship, fd, vim, exa, zoxide) via asdf
3. Symlink dotfiles to `$HOME`
4. Skip any `apt`/`brew` package installation

## Scripts

| Script | Description |
|---|---|
| `install.sh` | Main entry point — installs everything |
| `install-asdf.sh` | Downloads and installs the asdf binary to `~/.local/bin` |
| `install-asdf-plugins.sh` | Installs tools via asdf plugins (run after install-asdf.sh) |
| `build-docker.sh` | Helper to build the test Docker image |
