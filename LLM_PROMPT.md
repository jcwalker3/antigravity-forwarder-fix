# Fix: Dev Container "subprocess terminated immediately with return code 127"

## Context for AI Assistant

There is a known bug in VS Code-based IDEs (Cursor, Windsurf, Antigravity, VS Code, etc.) in the dev containers extension's `forwarder.js` file. When the IDE updates, the commit hash in the node binary path changes, but the container still has the old version — causing exit code 127 ("command not found").

## The Bug

In `forwarder.js`, find the `handleClient` function. Inside it, around line 297, there is this code that constructs the node command:

```js
nodeCommand = ''
    .concat(remoteServerNodePath, ' -e "')
    .concat(nodeJsCode, '"');
```

This uses `remoteServerNodePath` verbatim (e.g. `/home/user/.antigravity-server/bin/abc1234/node`). When the IDE updates, the commit hash directory (`abc1234`) changes but the container still has the old one — so the path doesn't exist and bash returns exit code 127.

## The Fix

Replace those 3 lines with this "Universal Path Resolver" that glob-matches the correct directory dynamically:

```js
// Universal Path Resolver - handle version prefix mismatch
var pathParts = remoteServerNodePath.split('/');
var nodeBin = pathParts[pathParts.length - 1];
var commitDir = pathParts[pathParts.length - 2];
var binDir = pathParts.slice(0, -2).join('/');
nodeCommand = 'NODE_PATH=$(ls -d '
    .concat(binDir, '/*')
    .concat(commitDir, ' 2>/dev/null | head -1) && \"${NODE_PATH}/')
    .concat(nodeBin, '\" -e \"')
    .concat(nodeJsCode, '\"');
```

## Instructions

1. Find `forwarder.js` in this IDE's dev containers extension. Typical paths:
   - **macOS**: `/Applications/<IDE>.app/Contents/Resources/app/extensions/*dev-containers*/scripts/forwarder.js`
   - **Linux**: `/usr/share/<ide>/resources/app/extensions/*dev-containers*/scripts/forwarder.js` or `~/.vscode/extensions/*dev-containers*/scripts/forwarder.js`
   - **Windows**: `%LOCALAPPDATA%/Programs/<IDE>/resources/app/extensions/*dev-containers*/scripts/forwarder.js`

2. In the `handleClient` function, find the 3-line `nodeCommand = ''` block shown above and replace it with the Universal Path Resolver code.

3. Restart the IDE after patching.

## Reference

Full write-up: https://jcwalker3.github.io/antigravity-forwarder-fix/
Repo with scripts: https://github.com/jcwalker3/antigravity-forwarder-fix
