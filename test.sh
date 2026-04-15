#!/bin/bash
# CLI entry point for all testing operations.
#
# Usage:
#   ./test.sh build-image <sudo|no-sudo|all>
#   ./test.sh sanity-check [--docker] <sudo|no-sudo|all>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<'EOF'
Usage:
  ./test.sh build-image <sudo|no-sudo|all>
  ./test.sh sanity-check [--docker] <sudo|no-sudo|all>

Commands:
  build-image     Build Docker test images
  sanity-check    Run sanity checks against the installation

Flags (sanity-check):
  --docker        Run inside Docker containers (default: run locally)

Targets:
  sudo            Full install / system packages checked
  no-sudo         No-sudo install / skip system package checks
  all             (default) Both scenarios
EOF
    exit 1
}

# ── build-image ──────────────────────────────────────────────────────

cmd_build_image() {
    local target="${1:-all}"
    case "$target" in
        sudo)
            echo "Building dotfiles-test-sudo..."
            docker build -t dotfiles-test-sudo \
                -f "$SCRIPT_DIR/tests/docker/Dockerfile.sudo" \
                "$SCRIPT_DIR/tests/docker"
            ;;
        no-sudo)
            echo "Building dotfiles-test-no-sudo..."
            docker build -t dotfiles-test-no-sudo \
                -f "$SCRIPT_DIR/tests/docker/Dockerfile.no-sudo" \
                "$SCRIPT_DIR"
            ;;
        all)
            cmd_build_image sudo
            cmd_build_image no-sudo
            ;;
        *)
            echo "Error: invalid target '$target' (use: sudo, no-sudo, all)"
            exit 1
            ;;
    esac
}

# ── sanity-check (local) ────────────────────────────────────────────

run_local_checks() {
    local target="${1:-all}"
    local rc=0

    export SANITY_COUNTERS_FILE
    SANITY_COUNTERS_FILE=$(mktemp)
    trap 'rm -f "$SANITY_COUNTERS_FILE"' EXIT
    printf '0 0 0' > "$SANITY_COUNTERS_FILE"

    # Source shell config to ensure PATH is set up correctly
    # Try zshrc for zsh shells, bashrc for bash shells
    if [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    elif [ -z "$ZSH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
    # Also ensure cargo is in PATH (for non-interactive shells)
    CARGO_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/cargo"
    [ -d "${CARGO_HOME}/bin" ] && export PATH="${CARGO_HOME}/bin:$PATH"

    # Ensure Homebrew is in PATH (Linux user-local install)
    if [ -x "$HOME/.homebrew/bin/brew" ]; then
        eval "$("$HOME/.homebrew/bin/brew" shellenv)"
    fi

    # Propagate install mode to check scripts
    if [ "$target" = "no-sudo" ]; then
        export NO_SUDO_INSTALL=1
    fi

    "$SCRIPT_DIR/tests/check-system-packages.sh" || rc=1
    "$SCRIPT_DIR/tests/check-asdf-tools.sh"      || rc=1
    "$SCRIPT_DIR/tests/check-cargo-tools.sh"      || rc=1
    "$SCRIPT_DIR/tests/check-brew-tools.sh"       || rc=1
    "$SCRIPT_DIR/tests/check-non-asdf-tools.sh"   || rc=1
    "$SCRIPT_DIR/tests/check-symlinks.sh"         || rc=1

    . "$SCRIPT_DIR/tests/helpers.sh"
    summary || rc=1

    return "$rc"
}

# ── sanity-check (docker) ───────────────────────────────────────────

run_docker_scenario() {
    local scenario="$1"
    local image="dotfiles-test-$scenario"
    local install_flags=""
    local check_target="$scenario"

    if [ "$scenario" = "no-sudo" ]; then
        install_flags="--no-sudo-install"
    fi

    echo ""
    echo "🐳 [$scenario] Running in Docker..."

    if ! docker image inspect "$image" &>/dev/null; then
        echo "Image '$image' not found. Building first..."
        cmd_build_image "$scenario"
    fi

    docker run --rm \
        -v "$SCRIPT_DIR:/home/testuser/.dotfiles:ro" \
        --tmpfs /tmp \
        "$image" \
        bash -c "
            mkdir -p /home/testuser/dotfiles-work
            tar -C /home/testuser/.dotfiles --exclude=.git_downloads --exclude=.git -cf - . \
                | tar -C /home/testuser/dotfiles-work -xf -
            cd /home/testuser/dotfiles-work
            printf 'GIT_USER_NAME=\"Test User\"\nGIT_USER_EMAIL=\"test@test.com\"\n' > .config.properties
            yes y | ./install.sh $install_flags || true
            echo '--- Re-running install to verify idempotency ---'
            yes y | ./install.sh $install_flags || true
            ./test.sh sanity-check $check_target
        "
}

run_docker_checks() {
    local target="${1:-all}"
    local rc=0

    case "$target" in
        sudo)    run_docker_scenario sudo    || rc=1 ;;
        no-sudo) run_docker_scenario no-sudo || rc=1 ;;
        all)
            run_docker_scenario sudo    || rc=1
            run_docker_scenario no-sudo || rc=1
            ;;
        *)
            echo "Error: invalid target '$target'"
            exit 1
            ;;
    esac

    return "$rc"
}

cmd_sanity_check() {
    local docker_mode=false
    local target="all"

    while [ $# -gt 0 ]; do
        case "$1" in
            --docker) docker_mode=true; shift ;;
            sudo|no-sudo|all) target="$1"; shift ;;
            *) echo "Error: unknown argument '$1'"; usage ;;
        esac
    done

    if [ "$docker_mode" = true ]; then
        run_docker_checks "$target"
    else
        run_local_checks "$target"
    fi
}

# ── Main ─────────────────────────────────────────────────────────────

case "${1:-}" in
    build-image)   shift; cmd_build_image "$@" ;;
    sanity-check)  shift; cmd_sanity_check "$@" ;;
    *)             usage ;;
esac
