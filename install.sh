#!/usr/bin/env bash
set -euo pipefail

# ── bid-web-fetch installer ────────────────────────────────────────────────────
# Usage:  curl -fsSL https://raw.githubusercontent.com/dumas45/bid-web-fetch/main/install.sh | bash

APP_NAME="bid-web-fetch"
COMMAND="bid-fetch"
APP_DIR="$HOME/.bid-web-fetch"
VENV_DIR="$APP_DIR/venv"
BIN_DIR="$HOME/.local/bin"

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

echo "┌─────────────────────────────────────────┐"
echo "│        bid-web-fetch  installer         │"
echo "└─────────────────────────────────────────┘"
echo ""

# ── 1. Check npm ───────────────────────────────────────────────────────────────
if ! command -v npm &>/dev/null; then
    echo "ERROR: npm is not installed or not on your PATH." >&2
    echo "" >&2
    echo "  npm (Node.js) is required to run bid-web-fetch." >&2
    echo "  Install it from: https://nodejs.org/" >&2
    echo "" >&2
    exit 1
fi
echo "✔  npm $(npm --version) found"

# ── 2. Check / install uv ──────────────────────────────────────────────────────
if ! command -v uv &>/dev/null; then
    echo ""
    echo "→  uv not found — installing uv (no sudo required)…"
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
    echo "✔  uv installed: $(uv --version)"
else
    echo "✔  uv $(uv --version) found"
fi

# ── 3. Ensure ~/.local/bin is on PATH for this session ────────────────────────
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
fi

# ── 4. Create app directory and venv ──────────────────────────────────────────
echo ""
echo "→  Setting up ${APP_DIR}…"
mkdir -p "$APP_DIR"
if [[ -d "$VENV_DIR" ]]; then
    echo "✔  Virtualenv already exists at ${VENV_DIR} — skipping creation"
else
    uv venv "$VENV_DIR" --python 3.12
    echo "✔  Virtualenv created at ${VENV_DIR}"
fi

# ── 5. Install bid-web-fetch into the venv from TestPyPI ─────────────────────
echo ""
echo "→  Installing ${APP_NAME} from TestPyPI…"
uv pip install \
    --python "$VENV_DIR/bin/python" \
    --index-url "https://test.pypi.org/simple/" \
    --extra-index-url "https://pypi.org/simple/" \
    "$APP_NAME"
echo "✔  ${APP_NAME} installed"

# ── 6. Install npm packages inside the package directory ──────────────────────
echo ""
echo "→  Installing npm packages for ${APP_NAME}…"

PKG_DIR=""
while IFS= read -r candidate; do
    if [[ -f "$candidate/package.json" ]]; then
        PKG_DIR="$candidate"
        break
    fi
done < <(find "$VENV_DIR" -type d -name "bid_fetch_mcp" 2>/dev/null)

if [[ -z "$PKG_DIR" ]]; then
    echo "ERROR: Could not locate bid_fetch_mcp package directory under ${VENV_DIR}" >&2
    echo "       npm packages were NOT installed. Run 'npm install' manually in that directory." >&2
    exit 1
fi

npm install --prefix "$PKG_DIR"
echo "✔  npm packages installed"

# ── 7. Create launcher script in ~/.local/bin ─────────────────────────────────
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/$COMMAND" <<EOF
#!/usr/bin/env bash
exec "$VENV_DIR/bin/$COMMAND" "\$@"
EOF
chmod +x "$BIN_DIR/$COMMAND"
echo "✔  Launcher created at ${BIN_DIR}/${COMMAND}"

# ── 8. Persist ~/.local/bin to the user's shell profile ───────────────────────
export_line='export PATH="$HOME/.local/bin:$PATH"'

add_to_profile() {
    local profile="$1"
    # Match both literal '$HOME/.local/bin' and the expanded path
    if [[ -f "$profile" ]] && grep -qF '.local/bin' "$profile"; then
        return  # already present
    fi
    if [[ -f "$profile" ]]; then
        printf '\n# Added by bid-web-fetch installer\n%s\n' "$export_line" >> "$profile"
        echo "✔  Added ~/.local/bin to PATH in $profile"
    fi
}

# Detect current shell
CURRENT_SHELL="$(basename "${SHELL:-bash}")"
case "$CURRENT_SHELL" in
    zsh)  add_to_profile "$HOME/.zshrc" ;;
    bash) add_to_profile "$HOME/.bashrc"
          add_to_profile "$HOME/.bash_profile" ;;
    *)    add_to_profile "$HOME/.profile" ;;
esac

# ── 9. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│           Installation complete!         │"
echo "└─────────────────────────────────────────┘"
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
