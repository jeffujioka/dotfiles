#!/usr/bin/env bash
# wd40: pbcopy - on a host with no pbcopy, copy stdin to the Mac clipboard through the SSH reverse tunnel on localhost:2224

# Loaded first (000-) so the `pp` alias in 001-basic.sh sees pbcopy.
# The Mac side is the localhost.pbcopy launchd listener; reach it with
# `ssh jfujiok-ubuntu` (RemoteForward 2224 localhost:2224).
if ! command -v pbcopy >/dev/null 2>&1; then
    function pbcopy() {
        nc -N localhost "${WD40_PBCOPY_PORT:-2224}"
    }
fi
