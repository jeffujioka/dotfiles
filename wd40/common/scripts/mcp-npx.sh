#!/bin/bash
#
# mcp-npx.sh - run npx from $HOME so MCP servers always use the global asdf Node.
#
# wd40: mcp-npx - run npx from $HOME so asdf uses ~/.tool-versions, never a repo's pin
#
# asdf picks the Node version from the .tool-versions nearest the working
# directory. An MCP server is started from the cwd of the agent session, so a
# repo that pins a Node version which is not installed makes `npx` fail before
# the server starts. Starting npx from $HOME avoids that.
#
# Usage (mcp.json): "command": "mcp-npx", "args": ["-y", "mcp-remote@latest", ...]

cd "$HOME" || exit 1
exec npx "$@"
