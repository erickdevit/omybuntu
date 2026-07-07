echo "Installing third-party packages (Dotnet 9, Spotify, Bitwarden, LocalSend, Obsidian, pnpm, tldr)..."

# 1. DOTNET 9
if ! dotnet --version &>/dev/null; then
  echo "  - Installing .NET Runtime 9..."
  wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb || true
  if [[ -f /tmp/packages-microsoft-prod.deb ]]; then
    sudo dpkg -i /tmp/packages-microsoft-prod.deb || true
    rm -f /tmp/packages-microsoft-prod.deb
    sudo apt-get update -qq || true
    sudo apt-get install -y -qq dotnet-runtime-9.0 || true
  fi
fi

# 2. Spotify
echo "  - Configuring Spotify repository..."
curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg || true
echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
if ! command -v spotify &>/dev/null; then
  echo "  - Installing Spotify..."
  sudo apt-get update -qq || true
  sudo apt-get install -y -qq spotify-client || true
fi

# 3. Bitwarden
if ! command -v bitwarden &>/dev/null; then
  echo "  - Installing Bitwarden..."
  curl -L -o /tmp/bitwarden.deb "https://vault.bitwarden.com/download/?app=desktop&platform=linux&format=deb" || true
  if [[ -f /tmp/bitwarden.deb && -s /tmp/bitwarden.deb ]]; then
    sudo apt-get install -y -qq /tmp/bitwarden.deb || true
    rm -f /tmp/bitwarden.deb
  fi
fi

# 4. LocalSend
if ! command -v localsend &>/dev/null; then
  echo "  - Installing LocalSend..."
  LOCALSEND_URL=$(curl -s https://api.github.com/repos/localsend/localsend/releases/latest | grep "browser_download_url.*linux-x64.deb" | cut -d '"' -f 4)
  if [[ -z $LOCALSEND_URL ]]; then
    LOCALSEND_URL="https://github.com/localsend/localsend/releases/download/v1.14.0/LocalSend-1.14.0-linux-x64.deb"
  fi
  curl -L -o /tmp/localsend.deb "$LOCALSEND_URL" || true
  if [[ -f /tmp/localsend.deb && -s /tmp/localsend.deb ]]; then
    sudo apt-get install -y -qq /tmp/localsend.deb || true
    rm -f /tmp/localsend.deb
  fi
fi

# 5. Obsidian
if ! command -v obsidian &>/dev/null; then
  echo "  - Installing Obsidian..."
  OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
  if [[ -z $OBSIDIAN_URL ]]; then
    OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.6.7/obsidian_1.6.7_amd64.deb"
  fi
  curl -L -o /tmp/obsidian.deb "$OBSIDIAN_URL" || true
  if [[ -f /tmp/obsidian.deb && -s /tmp/obsidian.deb ]]; then
    sudo apt-get install -y -qq /tmp/obsidian.deb || true
    rm -f /tmp/obsidian.deb
  fi
fi

# 6. pnpm
if ! command -v pnpm &>/dev/null; then
  echo "  - Installing pnpm..."
  (corepack enable && corepack prepare pnpm@latest --activate) || sudo npm install -g pnpm || true
fi

# 7. tldr
if ! command -v tldr &>/dev/null; then
  echo "  - Installing tldr..."
  sudo npm install -g tldr || true
fi
