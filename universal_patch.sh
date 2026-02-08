#!/bin/bash
# ============================================================================
# Universal Forwarder.js Patch
# Fixes: "subprocess terminated immediately with return code 127"
# Works across: Antigravity IDE, Cursor, VS Code, Windsurf, and other forks
#
# Usage:  chmod +x universal_patch.sh && ./universal_patch.sh
# Info:   https://jcwalker3.github.io/antigravity-forwarder-fix/
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Forwarder.js Universal Path Resolver              ║"
echo "║       Fixes 'return code 127' in dev containers             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ---------- Auto-detect IDE installations ----------

SEARCH_PATHS=()
FOUND_FILES=()

case "$(uname -s)" in
    Darwin)
        # macOS application paths
        SEARCH_PATHS=(
            "/Applications/Antigravity.app/Contents/Resources/app/extensions"
            "/Applications/Cursor.app/Contents/Resources/app/extensions"
            "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions"
            "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/extensions"
            "/Applications/VSCodium.app/Contents/Resources/app/extensions"
            "/Applications/Windsurf.app/Contents/Resources/app/extensions"
            "$HOME/.vscode/extensions"
            "$HOME/.cursor/extensions"
            "$HOME/.vscode-insiders/extensions"
        )
        ;;
    Linux)
        # Linux paths
        SEARCH_PATHS=(
            "/usr/share/code/resources/app/extensions"
            "/usr/share/code-insiders/resources/app/extensions"
            "/usr/share/codium/resources/app/extensions"
            "/opt/visual-studio-code/resources/app/extensions"
            "/opt/cursor/resources/app/extensions"
            "$HOME/.vscode/extensions"
            "$HOME/.cursor/extensions"
            "$HOME/.vscode-insiders/extensions"
            # Snap & Flatpak
            "/snap/code/current/usr/share/code/resources/app/extensions"
        )
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Windows (Git Bash / WSL)
        SEARCH_PATHS=(
            "$LOCALAPPDATA/Programs/Microsoft VS Code/resources/app/extensions"
            "$LOCALAPPDATA/Programs/cursor/resources/app/extensions"
            "$LOCALAPPDATA/Programs/Antigravity/resources/app/extensions"
            "$LOCALAPPDATA/Programs/Windsurf/resources/app/extensions"
        )
        ;;
esac

echo -e "${YELLOW}Scanning for IDE installations...${NC}"
echo ""

for base in "${SEARCH_PATHS[@]}"; do
    if [ -d "$base" ]; then
        # Look for forwarder.js in dev-container extension dirs
        while IFS= read -r -d '' f; do
            FOUND_FILES+=("$f")
        done < <(find "$base" -path "*/dev-containers/scripts/forwarder.js" -print0 2>/dev/null || true)
        while IFS= read -r -d '' f; do
            FOUND_FILES+=("$f")
        done < <(find "$base" -path "*remote-containers/scripts/forwarder.js" -print0 2>/dev/null || true)
    fi
done

# Also allow a custom path as argument
if [ "${1:-}" != "" ] && [ -f "$1" ]; then
    FOUND_FILES+=("$1")
fi

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo -e "${RED}No forwarder.js files found.${NC}"
    echo ""
    echo "You can provide the path manually:"
    echo "  $0 /path/to/forwarder.js"
    echo ""
    echo "Typical locations:"
    echo "  macOS:   /Applications/<IDE>.app/Contents/Resources/app/extensions/<ext>/scripts/forwarder.js"
    echo "  Linux:   /usr/share/<ide>/resources/app/extensions/<ext>/scripts/forwarder.js"
    echo "  Windows: %LOCALAPPDATA%/Programs/<IDE>/resources/app/extensions/<ext>/scripts/forwarder.js"
    exit 1
fi

# ---------- De-duplicate ----------
declare -A seen
UNIQUE_FILES=()
for f in "${FOUND_FILES[@]}"; do
    real=$(realpath "$f" 2>/dev/null || echo "$f")
    if [ -z "${seen[$real]+_}" ]; then
        seen[$real]=1
        UNIQUE_FILES+=("$f")
    fi
done

echo -e "${GREEN}Found ${#UNIQUE_FILES[@]} forwarder.js file(s):${NC}"
for i in "${!UNIQUE_FILES[@]}"; do
    echo -e "  ${BOLD}[$((i+1))]${NC} ${UNIQUE_FILES[$i]}"
done
echo ""

# ---------- Patch target (the string to find & replace) ----------

OLD_CODE='nodeCommand = '\'''\''
\t\t\t\t\t\t\t.concat(remoteServerNodePath, '\'' -e "'\'')'

# We search for the simpler unique marker
MARKER="nodeCommand = ''"

# ---------- Apply patches ----------

PATCHED=0
SKIPPED=0
FAILED=0

for FILE in "${UNIQUE_FILES[@]}"; do
    echo -e "${CYAN}Processing:${NC} $FILE"

    # Check if already patched
    if grep -q "Universal Path Resolver" "$FILE" 2>/dev/null; then
        echo -e "  ${YELLOW}⏭  Already patched — skipping${NC}"
        ((SKIPPED++))
        continue
    fi

    # Check for the target code
    if ! grep -q "nodeCommand = ''" "$FILE" 2>/dev/null; then
        echo -e "  ${RED}✗  Target code not found (different version?) — skipping${NC}"
        ((FAILED++))
        continue
    fi

    # Create backup
    cp "$FILE" "${FILE}.bak"
    echo -e "  ${GREEN}✓${NC}  Backup → ${FILE}.bak"

    # Apply patch using python3 for reliable multi-line replacement
    python3 - "$FILE" << 'PYTHON_PATCH'
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

OLD = "\t\t\t\t\t\tnodeCommand = ''\n\t\t\t\t\t\t\t.concat(remoteServerNodePath, ' -e \"')\n\t\t\t\t\t\t\t.concat(nodeJsCode, '\"');"

NEW = """\t\t\t\t\t\t// Universal Path Resolver - handle version prefix mismatch
\t\t\t\t\t\tvar pathParts = remoteServerNodePath.split('/');
\t\t\t\t\t\tvar nodeBin = pathParts[pathParts.length - 1];
\t\t\t\t\t\tvar commitDir = pathParts[pathParts.length - 2];
\t\t\t\t\t\tvar binDir = pathParts.slice(0, -2).join('/');
\t\t\t\t\t\tnodeCommand = 'NODE_PATH=$(ls -d '
\t\t\t\t\t\t\t.concat(binDir, '/*')
\t\t\t\t\t\t\t.concat(commitDir, ' 2>/dev/null | head -1) && \\"${NODE_PATH}/')
\t\t\t\t\t\t\t.concat(nodeBin, '\\" -e \\"')
\t\t\t\t\t\t\t.concat(nodeJsCode, '\\"');"""

if OLD in content:
    patched = content.replace(OLD, NEW, 1)
    with open(filepath, 'w') as f:
        f.write(patched)
    print("  PATCHED")
else:
    print("  NOT_FOUND")
    sys.exit(1)
PYTHON_PATCH

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓  Patched successfully!${NC}"
        ((PATCHED++))
    else
        echo -e "  ${RED}✗  Patch failed${NC}"
        # Restore backup
        mv "${FILE}.bak" "$FILE"
        ((FAILED++))
    fi
    echo ""
done

# ---------- Summary ----------

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}Patched: $PATCHED${NC}  |  ${YELLOW}Skipped: $SKIPPED${NC}  |  ${RED}Failed: $FAILED${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $PATCHED -gt 0 ]; then
    echo -e "${GREEN}${BOLD}Please restart your IDE(s) for the fix to take effect.${NC}"
    echo -e "${YELLOW}Note: You may need to re-run this script after IDE updates.${NC}"
fi
echo ""
echo -e "Full write-up: ${CYAN}https://jcwalker3.github.io/antigravity-forwarder-fix/${NC}"
