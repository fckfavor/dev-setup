#!/usr/bin/env bash
# ============================================================================
# Genel amacli dev ortami kurulum scripti (WSL2 Ubuntu icinde calisir)
# Idempotent: her arac icin once "kurulu mu?" kontrolu yapar, eksikse kurar.
# Proje-bagimsizdir — herhangi bir makinede tekrar calistirilabilir.
# ============================================================================
set -uo pipefail

CYAN='\033[1;36m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}==> $1${NC}"; }
ok()    { echo -e "  ${GREEN}OK${NC} $1"; }
skip()  { echo -e "  ${YELLOW}-${NC} $1 zaten kurulu, atlaniyor"; }
fail()  { echo -e "  ${RED}HATA${NC} $1"; }
ask()   { read -r -p "$(echo -e "${YELLOW}?${NC} $1 [e/H]: ")" _a; [[ "$_a" =~ ^[EeYy]$ ]]; }

echo -e "${CYAN}"
echo "============================================================"
echo "  Dev Ortami Kurulum Scripti — WSL2 Ubuntu"
echo "============================================================"
echo -e "${NC}"

# ── 1) Sistem paketleri ─────────────────────────────────────────────────────
step "apt guncelleniyor..."
sudo apt-get update -y -qq && sudo apt-get upgrade -y -qq
ok "apt guncel"

step "Temel araclar (curl, git, build-essential, unzip) kontrol ediliyor..."
NEEDED=()
for pkg in curl git unzip build-essential ca-certificates gnupg jq; do
  dpkg -s "$pkg" &>/dev/null || NEEDED+=("$pkg")
done
if [ ${#NEEDED[@]} -gt 0 ]; then
  sudo apt-get install -y -qq "${NEEDED[@]}"
  ok "kuruldu: ${NEEDED[*]}"
else
  skip "temel araclar"
fi

# ── 2) Node.js LTS ───────────────────────────────────────────────────────────
step "Node.js kontrol ediliyor..."
if command -v node &>/dev/null && [ "$(node -v | sed 's/v//' | cut -d. -f1)" -ge 20 ]; then
  skip "Node.js ($(node -v))"
else
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1
  sudo apt-get install -y -qq nodejs
  ok "Node.js kuruldu ($(node -v))"
fi

# ── 3) Python + pip + uv ─────────────────────────────────────────────────────
step "Python3 / pip / uv kontrol ediliyor..."
if command -v python3 &>/dev/null; then skip "python3 ($(python3 -V))"; else
  sudo apt-get install -y -qq python3 python3-pip python3-venv
  ok "python3 kuruldu"
fi
if command -v pip3 &>/dev/null; then skip "pip3"; else
  sudo apt-get install -y -qq python3-pip
  ok "pip3 kuruldu"
fi
if command -v uv &>/dev/null; then skip "uv"; else
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH="$HOME/.local/bin:$PATH"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  ok "uv kuruldu"
fi

# ── 4) GitHub CLI ─────────────────────────────────────────────────────────────
step "GitHub CLI (gh) kontrol ediliyor..."
if command -v gh &>/dev/null; then
  skip "gh ($(gh --version | head -1))"
else
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y -qq
  sudo apt-get install -y -qq gh
  ok "gh kuruldu"
fi

# ── 5) Cloudflare wrangler ───────────────────────────────────────────────────
step "wrangler (Cloudflare CLI) kontrol ediliyor..."
if command -v wrangler &>/dev/null; then
  skip "wrangler ($(wrangler --version 2>/dev/null | head -1))"
else
  sudo npm install -g wrangler --silent
  ok "wrangler kuruldu"
fi

# ── 5b) Hesap girisleri (opsiyonel, giris gerektirir) ─────────────────────────
step "Hesap girisleri..."
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    skip "gh zaten giris yapilmis ($(gh api user -q .login 2>/dev/null))"
  elif ask "GitHub CLI (gh) icin simdi giris yapilsin mi?"; then
    gh auth login
  else
    echo "  Atlandi. Sonradan: gh auth login"
  fi
fi

if command -v wrangler &>/dev/null; then
  if wrangler whoami &>/dev/null; then
    skip "wrangler zaten giris yapilmis"
  elif ask "Cloudflare (wrangler) icin simdi giris yapilsin mi?"; then
    echo "  Not: WSL'de tarayici callback'i bazen calismayabilir. Sorun olursa"
    echo "  CLOUDFLARE_API_TOKEN ortam degiskeni ile alternatif giris yapin."
    wrangler login || echo "  wrangler login basarisiz oldu, API token ile deneyin."
  else
    echo "  Atlandi. Sonradan: wrangler login  (veya CLOUDFLARE_API_TOKEN env degiskeni)"
  fi
fi

# ── 6) Claude Code ───────────────────────────────────────────────────────────
step "Claude Code kontrol ediliyor..."
CLAUDE_INSTALLED=false
if command -v claude &>/dev/null; then
  skip "Claude Code ($(claude --version 2>/dev/null || echo kurulu))"
  CLAUDE_INSTALLED=true
else
  if ask "Claude Code kurulsun mu?"; then
    sudo npm install -g @anthropic-ai/claude-code --silent
    ok "Claude Code kuruldu"
    CLAUDE_INSTALLED=true
  else
    echo "  Claude Code atlandi."
  fi
fi

# ── 7) MCP sunuculari / skill & pluginler ────────────────────────────────────
if $CLAUDE_INSTALLED; then
  step "Claude Code eklentileri (MCP sunuculari) yapilandiriliyor..."
  echo "  Not: Claude Code'un kendisi icin ilk calistirmada 'claude' komutuyla"
  echo "  tarayici tabanli hesap girisi gerekir — bu adim atlanamaz, script"
  echo "  sonunda hatirlatilacak."

  echo ""
  echo -e "${CYAN}  -- Giris gerektirmeyen (offline) MCP sunuculari --${NC}"
  echo "  Bunlar herhangi bir token/API key istemez, direkt kullanilabilir."

  declare -A NO_LOGIN_MCP=(
    [filesystem]="npx -y @modelcontextprotocol/server-filesystem $HOME"
    [fetch]="npx -y @modelcontextprotocol/server-fetch"
    [memory]="npx -y @modelcontextprotocol/server-memory"
    [sequential-thinking]="npx -y @modelcontextprotocol/server-sequential-thinking"
  )

  if ask "Giris gerektirmeyen tum MCP sunuculari otomatik eklensin mi (filesystem, fetch, memory, sequential-thinking)?"; then
    for name in "${!NO_LOGIN_MCP[@]}"; do
      cmd="${NO_LOGIN_MCP[$name]}"
      if claude mcp list 2>/dev/null | grep -q "^$name"; then
        skip "MCP: $name"
      else
        claude mcp add "$name" -- $cmd >/dev/null 2>&1 && ok "MCP eklendi: $name" || fail "MCP eklenemedi: $name (elle deneyin: claude mcp add $name -- $cmd)"
      fi
    done
  else
    echo "  Atlandi. Sonradan elle eklemek icin: claude mcp add <isim> -- <komut>"
  fi

  echo ""
  echo -e "${CYAN}  -- Giris/API key gerektiren MCP sunuculari --${NC}"
  echo "  Her biri icin ayri ayri sorulacak, istemediginizi 'h' ile atlayin."

  # GitHub MCP — gh zaten login ise onun token'ini kullanabilir
  if ask "GitHub MCP sunucusu eklensin mi? (repo/issue/PR erisimi icin gh login gerektirir)"; then
    if ! gh auth status &>/dev/null; then
      echo "  gh henuz login degil. Simdi giris yapin:"
      gh auth login
    fi
    GH_TOKEN_VAL=$(gh auth token 2>/dev/null)
    if [ -n "$GH_TOKEN_VAL" ]; then
      claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN_VAL" -- npx -y @modelcontextprotocol/server-github >/dev/null 2>&1 \
        && ok "MCP eklendi: github" || fail "MCP eklenemedi: github (elle: claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=... -- npx -y @modelcontextprotocol/server-github)"
    else
      fail "gh token alinamadi, github MCP atlandi"
    fi
  fi

  # Slack MCP
  if ask "Slack MCP sunucusu eklensin mi? (Slack Bot Token gerektirir)"; then
    read -r -p "  Slack Bot Token (xoxb-...): " SLACK_TOKEN
    read -r -p "  Slack Team ID: " SLACK_TEAM
    if [ -n "$SLACK_TOKEN" ]; then
      claude mcp add slack -e SLACK_BOT_TOKEN="$SLACK_TOKEN" -e SLACK_TEAM_ID="$SLACK_TEAM" -- npx -y @modelcontextprotocol/server-slack >/dev/null 2>&1 \
        && ok "MCP eklendi: slack" || fail "MCP eklenemedi: slack"
    else
      echo "  Token girilmedi, atlandi."
    fi
  fi

  # Postgres MCP
  if ask "Postgres MCP sunucusu eklensin mi? (baglanti string'i gerektirir)"; then
    read -r -p "  Postgres connection string (postgres://user:pass@host:port/db): " PG_URL
    if [ -n "$PG_URL" ]; then
      claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres "$PG_URL" >/dev/null 2>&1 \
        && ok "MCP eklendi: postgres" || fail "MCP eklenemedi: postgres"
    else
      echo "  Baglanti bilgisi girilmedi, atlandi."
    fi
  fi

  # Cloudflare (wrangler zaten CLI, ama MCP olarak da eklenebilir)
  if ask "Cloudflare MCP sunucusu eklensin mi? (Cloudflare API token gerektirir)"; then
    read -r -s -p "  Cloudflare API Token (gizli, ekrana yazilmaz): " CF_TOKEN
    echo ""
    if [ -n "$CF_TOKEN" ]; then
      claude mcp add cloudflare -e CLOUDFLARE_API_TOKEN="$CF_TOKEN" -- npx -y @cloudflare/mcp-server-cloudflare >/dev/null 2>&1 \
        && ok "MCP eklendi: cloudflare" || fail "MCP eklenemedi: cloudflare"
    else
      echo "  Token girilmedi, atlandi."
    fi
  fi

  echo ""
  echo "  Kurulu MCP sunuculari:"
  claude mcp list 2>/dev/null || echo "  (henuz claude ilk kez calistirilip login olunmadan liste gorunmeyebilir)"
fi

# ── Ozet ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Kurulum tamamlandi${NC}"
echo -e "${GREEN}============================================================${NC}"
echo "  node:      $(command -v node &>/dev/null && node -v || echo '-')"
echo "  npm:       $(command -v npm &>/dev/null && npm -v || echo '-')"
echo "  python3:   $(command -v python3 &>/dev/null && python3 -V || echo '-')"
echo "  uv:        $(command -v uv &>/dev/null && uv --version || echo '-')"
echo "  git:       $(command -v git &>/dev/null && git --version || echo '-')"
echo "  gh:        $(command -v gh &>/dev/null && gh --version | head -1 || echo '-')"
echo "  wrangler:  $(command -v wrangler &>/dev/null && wrangler --version 2>/dev/null | head -1 || echo '-')"
echo "  claude:    $(command -v claude &>/dev/null && echo kurulu || echo '- (atlandi)')"
echo ""
if $CLAUDE_INSTALLED; then
  echo -e "${YELLOW}Son adim (elle, atlanamaz):${NC}"
  echo "  Terminalde 'claude' yazip calistirin — ilk seferde tarayici uzerinden"
  echo "  Claude/Anthropic hesabiniza giris yapmaniz istenecek."
fi
echo ""
