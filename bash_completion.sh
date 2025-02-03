#!/usr/bin/env bash

if [ -d "${HOME}/.bash_completion.d" ]; then
  for completion in "${HOME}"/.bash_completion.d/*.sh; do
    if [ -x "$completion" ]; then
      #echo "Reading completion file: $completion"
      . $completion
    fi
  done
  unset completion
fi
