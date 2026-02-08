# Bug: "subprocess terminated immediately with return code 127" in Dev Containers

## Summary

The `forwarder.js` script in the dev containers extension fails with exit code 127 ("command not found") when the IDE's commit hash changes between updates but the container still has the previous version's node binary installed.

## Error Message

```
forwarder error: handleClient Error: subprocess terminated immediately with return code 127
```

## Environment

- **IDE**: [Your IDE name and version]
- **OS**: [Your OS]
- **Docker version**: [Output of `docker --version`]
- **Dev Container image**: [Your container image]

## Root Cause

In `forwarder.js`, the `handleClient()` method constructs the node command using a hardcoded path from `remoteServerNodePath`:

```js
// forwarder.js — handleClient(), around line 297
nodeCommand = ''
    .concat(remoteServerNodePath, ' -e "')
    .concat(nodeJsCode, '"');
```

The `remoteServerNodePath` looks like:
```
/home/user/.antigravity-server/bin/abc1234/node
```

When the IDE updates on the host, the **commit hash directory** (`abc1234`) changes — but the container still has the node binary under the *old* hash directory (`def5678`). Since the path is used verbatim, bash can't find the binary → **exit code 127**.

## Proposed Fix

Replace the hardcoded path with a dynamic resolver that glob-matches the correct directory:

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

This dynamically discovers whichever commit-hash directory actually exists in the container, making the connection resilient to IDE updates.

## Steps to Reproduce

1. Open a dev container with the IDE
2. Update the IDE (or let it auto-update)
3. Reconnect to the same dev container without rebuilding it
4. Observe the error in the output panel

## Additional Context

Full write-up with diagrams and code diffs: **https://jcwalker3.github.io/antigravity-forwarder-fix/**
