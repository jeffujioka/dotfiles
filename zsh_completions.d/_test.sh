#compdef test.sh

_test_sh() {
  local -a commands targets

  commands=(
    'build-image:Build Docker test images'
    'sanity-check:Run sanity checks against the installation'
  )

  targets=(
    'sudo:Full install with system packages'
    'no-sudo:No-sudo install via Homebrew'
    'all:Both scenarios'
  )

  _arguments -C \
    '1:command:->cmd' \
    '*:: :->args'

  case "$state" in
    cmd)
      _describe 'command' commands
      ;;
    args)
      case "${words[1]}" in
        build-image)
          _describe 'target' targets
          ;;
        sanity-check)
          _arguments \
            '--docker[Run inside Docker containers]' \
            '1:target:(sudo no-sudo all)'
          ;;
      esac
      ;;
  esac
}

_test_sh "$@"
