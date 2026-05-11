#!/usr/bin/env bash
set -euo pipefail

# -- bid-web-fetch installer ----------------------------------------------------
# Install: curl -fsSL https://github.com/Dumas45/bid-web-fetch/raw/refs/heads/master/install.sh | bash
# Run: bid-fetch
# Uninstall: bid-fetch --uninstall

APP_NAME="bid-web-fetch"
COMMAND="bid-fetch"
APP_DIR="$HOME/.bid-web-fetch"
VENV_DIR="$APP_DIR/venv"
BIN_DIR="$HOME/.local/bin"
ORIGINAL_PATH="$PATH"

# Detect available downloader
if command -v curl &>/dev/null; then
    DOWNLOADER="curl"
elif command -v wget &>/dev/null; then
    DOWNLOADER="wget"
else
    echo "ERROR: curl or wget is required but neither is installed." >&2
    exit 1
fi

# Wrapper: download URL to stdout
download() {
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

echo "+-----------------------------------------+"
echo "|        bid-web-fetch  installer         |"
echo "+-----------------------------------------+"
echo ""

# -- 1. Check npm ---------------------------------------------------------------
if ! command -v npm &>/dev/null; then
    echo "ERROR: npm is not installed or not on your PATH." >&2
    echo "" >&2
    echo "  npm (Node.js) is required to run bid-web-fetch." >&2
    echo "  Install it from: https://nodejs.org/" >&2
    echo "" >&2
    exit 1
fi
echo "[ok] npm $(npm --version) found"

# -- 2. Check / install uv ------------------------------------------------------
if ! command -v uv &>/dev/null; then
    echo ""
    echo "-->  uv not found - installing uv (no sudo required)..."
    if ! download https://astral.sh/uv/install.sh | sh; then
        echo "" >&2
        echo "ERROR: Failed to install uv automatically." >&2
        echo "  Please install it manually and re-run this script:" >&2
        echo "  https://docs.astral.sh/uv/getting-started/installation/" >&2
        echo "" >&2
        exit 1
    fi
    # The installer drops uv into ~/.local/bin; bring it into the current session
    export PATH="$BIN_DIR:$PATH"
    echo "[ok] uv installed: $(uv --version)"
else
    echo "[ok] uv $(uv --version) found"
fi

# -- 3. Ensure ~/.local/bin is on PATH for this session ------------------------
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
fi

# -- 4. Create app directory and venv ------------------------------------------
echo ""
echo "-->  Setting up ${APP_DIR}..."
mkdir -p "$APP_DIR"
if [[ -d "$VENV_DIR" ]]; then
    echo "[ok] Virtualenv already exists at ${VENV_DIR} - skipping creation"
else
    echo "-->  Ensuring Python 3.12 is available (may download if not cached)..."
    uv venv "$VENV_DIR" --python 3.12
    echo "[ok] Virtualenv created at ${VENV_DIR}"
fi

# -- 5. Install bid-web-fetch into the venv from TestPyPI ---------------------
echo ""
echo "-->  Installing ${APP_NAME} from TestPyPI..."
uv pip install \
    --python "$VENV_DIR/bin/python" \
    --upgrade --refresh-package "$APP_NAME" \
    --index-url "https://test.pypi.org/simple/" \
    --extra-index-url "https://pypi.org/simple/" \
    "$APP_NAME"
echo "[ok] ${APP_NAME} installed"

# -- 5b. Install spaCy model from bundled requirements.txt -------------------
echo ""
echo "-->  Installing spaCy model..."
# Ask Python exactly where the package is installed
PKG_DIR=$("$VENV_DIR/bin/python" -c "import bid_fetch_mcp, os; print(os.path.dirname(bid_fetch_mcp.__file__))" 2>/dev/null || true)
if [[ -n "$PKG_DIR" && -f "$PKG_DIR/requirements.txt" ]]; then
    uv pip install \
        --python "$VENV_DIR/bin/python" \
        -r "$PKG_DIR/requirements.txt"
    echo "[ok] spaCy model installed"
else
    echo "WARNING: requirements.txt not found in ${PKG_DIR:-<unknown>} - skipping model install" >&2
fi

# -- 6. Install npm packages inside the package directory ----------------------
echo ""
echo "-->  Installing npm packages for ${APP_NAME}..."

if [[ -z "$PKG_DIR" || ! -f "$PKG_DIR/package.json" ]]; then
    echo "ERROR: Could not locate bid_fetch_mcp package directory (or package.json is missing) under ${VENV_DIR}" >&2
    echo "       npm packages were NOT installed." >&2
    exit 1
fi

npm install --prefix "$PKG_DIR" --no-fund --no-audit --loglevel=error
echo "[ok] npm packages installed"

# -- 7. Write launcher into app dir and symlink into ~/.local/bin --------------
LAUNCHER="$APP_DIR/bin/$COMMAND"
mkdir -p "$APP_DIR/bin"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# bid-fetch launcher - auto-updates before starting

_APP="$APP_NAME"
_VENV="$VENV_DIR"
_APP_DIR="$APP_DIR"
_BIN_DIR="$BIN_DIR"
_COMMAND="$COMMAND"

if [[ "\${1:-}" == "--uninstall" ]]; then
    echo "+-----------------------------------------+"
    echo "|       bid-web-fetch  uninstaller        |"
    echo "+-----------------------------------------+"
    echo ""
    if [[ -L "\$_BIN_DIR/\$_COMMAND" ]]; then
        rm "\$_BIN_DIR/\$_COMMAND"
        echo "[ok] Removed \$_BIN_DIR/\$_COMMAND"
    fi
    if [[ -d "\$_APP_DIR" ]]; then
        rm -rf "\$_APP_DIR"
        echo "[ok] Removed \$_APP_DIR"
    fi
    echo ""
    echo "Uninstall complete."
    echo ""
    exit 0
fi

if command -v uv &>/dev/null; then
    _OLD_VER=\$(uv pip show --python "\$_VENV/bin/python" "\$_APP" 2>/dev/null \
        | awk '/^Version:/{print \$2}' || true)
    echo "\${_APP} current version: \${_OLD_VER:-unknown}"

    uv pip install --quiet --upgrade --python "\$_VENV/bin/python" \
        --index-url "https://test.pypi.org/simple/" \
        --extra-index-url "https://pypi.org/simple/" "\$_APP" 2>/dev/null || true

    _NEW_VER=\$(uv pip show --python "\$_VENV/bin/python" "\$_APP" 2>/dev/null \
        | awk '/^Version:/{print \$2}' || true)

    if [[ "\$_OLD_VER" != "\$_NEW_VER" ]]; then
        echo "\${_APP} updated to version: \${_NEW_VER:-unknown}"

        # Re-run npm install in case npm deps changed after upgrade
        _PKG_DIR=\$("\$_VENV/bin/python" -c \
            "import bid_fetch_mcp, os; print(os.path.dirname(bid_fetch_mcp.__file__))" \
            2>/dev/null || true)
        if [[ -n "\$_PKG_DIR" && -f "\$_PKG_DIR/package.json" ]]; then
            echo "Running npm install for updated package..."
            npm install --prefix "\$_PKG_DIR" --no-fund --no-audit --loglevel=error 2>/dev/null || true
        fi
    fi
fi

exec "\$_VENV/bin/$COMMAND" "\$@"
EOF
chmod +x "$LAUNCHER"
mkdir -p "$BIN_DIR"
ln -sf "$LAUNCHER" "$BIN_DIR/$COMMAND"
echo "[ok] Launcher created at ${LAUNCHER}"
echo "[ok] Symlinked to ${BIN_DIR}/${COMMAND}"

# -- 8. Persist ~/.local/bin to the user's shell profile -----------------------
# Only needed if BIN_DIR was not on PATH before this script modified it
if [[ ":$ORIGINAL_PATH:" != *":$BIN_DIR:"* ]]; then
    export_line='export PATH="$HOME/.local/bin:$PATH"'

    add_to_profile() {
        local profile="$1"
        if [[ -f "$profile" ]] && grep -qF '.local/bin' "$profile"; then
            return  # already present
        fi
        if [[ -f "$profile" ]]; then
            printf '\n# Added by bid-web-fetch installer\n%s\n' "$export_line" >> "$profile"
            echo "[ok] Added ~/.local/bin to PATH in $profile"
        fi
    }

    CURRENT_SHELL="$(basename "${SHELL:-bash}")"
    case "$CURRENT_SHELL" in
        zsh)  add_to_profile "$HOME/.zshrc"
              add_to_profile "$HOME/.zprofile" ;;
        bash) add_to_profile "$HOME/.bashrc"
              add_to_profile "$HOME/.bash_profile" ;;
        *)    add_to_profile "$HOME/.profile" ;;
    esac
fi

# -- 9. Done -------------------------------------------------------------------
echo ""
echo "+-----------------------------------------+"
echo "|           Installation complete!        |"
echo "+-----------------------------------------+"
echo ""
echo "  Run the app from any folder:"
echo ""
echo "    ${COMMAND}"
echo ""
echo "  Then open http://127.0.0.1:5000 in your browser."
echo ""
echo "  NOTE: If '${COMMAND}' is not found, open a new terminal or run:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo ""
