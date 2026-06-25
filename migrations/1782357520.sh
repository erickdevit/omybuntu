echo "Install cliamp music TUI player and create its desktop launcher"

if omybuntu-cmd-missing cliamp; then
  echo "Downloading and installing cliamp..."
  mkdir -p "$HOME/.local/bin"
  if curl -sL https://github.com/bjarneo/cliamp/releases/latest/download/cliamp-linux-amd64 -o "$HOME/.local/bin/cliamp"; then
    chmod +x "$HOME/.local/bin/cliamp"
  fi
fi

ICON_DIR="$HOME/.local/share/applications/icons"
mkdir -p "$ICON_DIR"
if [[ ! -f "$ICON_DIR/Cliamp.png" ]]; then
  curl -sL https://raw.githubusercontent.com/bjarneo/cliamp/main/Cliamp.png -o "$ICON_DIR/Cliamp.png"
fi

if omybuntu-cmd-present omybuntu-tui-install; then
  omybuntu-tui-install "Cliamp" "cliamp" float "$ICON_DIR/Cliamp.png"
fi
