# asdf owns Node, updates it automatically, and MCP servers launch from `$HOME`

asdf picks Node from the `.tool-versions` nearest the working directory, so an agent session started in a repo that pins an uninstalled Node made `npx` fail before the Atlassian MCP (`mcp-remote`) could start. asdf is now the only Node owner (nvm and the brew `node` formula are gone), `asdf-update` keeps the untracked `~/.tool-versions` at the newest release of every installed plugin (from `install.sh` and, weekly, from `upd`), and MCP servers are started through `mcp-npx`, which runs `npx` from `$HOME` so they always follow the global versions instead of a repo pin.

## Considered Options

- **Install the missing version each time.** Fixes one repo, not the next pin.
- **Homebrew `node` for MCP only.** Two Node installs, and `brew upgrade` changes the major version without notice.
- **Track `~/.tool-versions` in dotfiles.** Rejected: the file is machine-written by `asdf-update`, so a tracked copy would show a diff after every update.

## Consequences

`mcp.json` stays untracked; it must name `mcp-npx` in `command`. Old Node versions are never uninstalled automatically because repos may still pin them. A new Node major arrives without review; running MCP processes keep the old one until their session restarts.
