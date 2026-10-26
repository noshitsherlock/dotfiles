#!/usr/bin/env bash
# Set up a new Mac from scratch. Idempotent — safe to re-run.
#
#   ./install.sh            run every step
#   ./install.sh dotfiles   run only the listed steps (see STEPS below)
#
# Put the private/ folder from the old machine (made by scripts/snapshot.sh)
# next to this file first, otherwise secrets/repos/app prefs are skipped.
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
PRIV="$REPO/private"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
STEPS=(brew shell node python dotfiles skills claude private macos editors)

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

# Copy a file into $HOME, backing up anything that differs and filling __HOME__.
place() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! sed "s|__HOME__|$HOME|g" "$src" | cmp -s - "$dst"; then
    mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
    cp -p "$dst" "$BACKUP/${dst#"$HOME"/}"
  fi
  sed "s|__HOME__|$HOME|g" "$src" > "$dst"
  [ -x "$src" ] && chmod +x "$dst"
}

# Like place, but also fills ${VARS} from private/secrets.env.
place_template() {
  local src="$1" dst="$2" tmp
  tmp="$(mktemp)"
  perl -pe 's/\$\{(\w+)\}/exists $ENV{$1} ? $ENV{$1} : $&/ge' "$src" > "$tmp"
  place "$tmp" "$dst"
  rm -f "$tmp"
  grep -q '\${[A-Z_]*}' "$dst" && warn "unfilled secrets in $dst (missing private/secrets.env?)"
}

step_brew() {
  log "Xcode Command Line Tools"
  xcode-select -p &>/dev/null || { xcode-select --install; read -rp "Press enter when the CLT install has finished..."; }

  log "Homebrew"
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  brew analytics off

  log "Brewfile (formulae, casks, fonts)"
  brew bundle --file="$REPO/Brewfile" || warn "some Brewfile entries failed — see above"
  log "Brewfile.extra (apps installed outside brew on the old Mac)"
  brew bundle --file="$REPO/Brewfile.extra" || warn "some Brewfile.extra entries failed — App Store entries need you signed in"
}

step_shell() {
  log "Oh My Zsh + Powerlevel10k + plugins"
  [ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  local custom="$HOME/.oh-my-zsh/custom"
  clone() { [ -d "$2" ] || git clone --depth=1 "$1" "$2"; }
  clone https://github.com/romkatv/powerlevel10k.git              "$custom/themes/powerlevel10k"
  clone https://github.com/zsh-users/zsh-autosuggestions.git      "$custom/plugins/zsh-autosuggestions"
  clone https://github.com/zsh-users/zsh-syntax-highlighting.git  "$custom/plugins/zsh-syntax-highlighting"

  log "tmux plugin manager"
  clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
}

step_node() {
  log "Node via fnm (22 default, 24) + global packages"
  eval "$(fnm env --shell bash)"
  fnm install 22 && fnm install 24 && fnm default 22 && fnm use 22
  corepack enable pnpm
  npm install -g \
    @openai/codex \
    @google/gemini-cli \
    @earendil-works/pi-coding-agent \
    @tobilu/qmd \
    bigpowers

  log "Bun"
  [ -x "$HOME/.bun/bin/bun" ] || curl -fsSL https://bun.sh/install | bash
}

step_python() {
  log "uv + uv tools"
  [ -x "$HOME/.local/bin/uv" ] || curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  uv tool install claude-monitor
}

step_dotfiles() {
  log "Dotfiles -> \$HOME (changed files backed up to $BACKUP)"
  (cd "$REPO/home" && find . -type f ! -name .DS_Store) | while read -r f; do
    place "$REPO/home/${f#./}" "$HOME/${f#./}"
  done

  log "Templates with secrets"
  if [ -f "$PRIV/secrets.env" ]; then set -a; . "$PRIV/secrets.env"; set +a; fi
  (cd "$REPO/templates" && find . -type f ! -name .DS_Store) | while read -r f; do
    place_template "$REPO/templates/${f#./}" "$HOME/${f#./}"
  done
  [ -d "$HOME/.config/opencode" ] && (cd "$HOME/.config/opencode" && npm install --silent)
  [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] && "$HOME/.tmux/plugins/tpm/bin/install_plugins"
}

step_skills() {
  log "Agent skills -> every agent's skills dir"
  local d
  for d in .agents .claude .codex .copilot .gemini; do
    mkdir -p "$HOME/$d/skills"
    cp -R "$REPO/skills/." "$HOME/$d/skills/"
  done

  log "bigpowers skills -> ~/.claude/skills (symlinks into the npm package)"
  local bp; bp="$(npm root -g 2>/dev/null)/bigpowers/skills"
  if [ -d "$bp" ]; then
    for s in align-grid assess-impact audit-code audit-plan build-epic change-request commit-message compose-workflow; do
      [ -d "$bp/$s" ] && ln -sfn "$bp/$s" "$HOME/.claude/skills/$s"
    done
  else
    warn "bigpowers not installed — run the node step first"
  fi
}

step_claude() {
  command -v claude &>/dev/null || { warn "claude not found, skipping"; return; }
  log "Claude Code marketplaces + plugins"
  claude plugin marketplace add openai/codex-plugin-cc
  for p in vercel@claude-plugins-official frontend-design@claude-plugins-official \
           typescript-lsp@claude-plugins-official codex@openai-codex; do
    claude plugin install "$p" || warn "failed: $p"
  done

  log "Claude Code user MCP servers"
  if [ -f "$PRIV/secrets.env" ]; then set -a; . "$PRIV/secrets.env"; set +a; fi
  claude mcp remove -s user context7 &>/dev/null
  claude mcp add -s user -t http context7 https://mcp.context7.com/mcp -H "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY:-}"
}

step_private() {
  [ -d "$PRIV" ] || { warn "no private/ folder — skipping secrets, repos, app prefs, launch agents"; return; }

  log "Claude local permissions"
  [ -f "$PRIV/claude-settings.local.json" ] && place "$PRIV/claude-settings.local.json" "$HOME/.claude/settings.local.json"

  log "Agent memory"
  [ -d "$PRIV/memory/claude-projects" ] && mkdir -p "$HOME/.claude/projects" && cp -Rn "$PRIV/memory/claude-projects/." "$HOME/.claude/projects/"
  [ -d "$PRIV/memory/pi" ] && mkdir -p "$HOME/.pi/agent/memory" && cp -Rn "$PRIV/memory/pi/." "$HOME/.pi/agent/memory/"

  log "App preferences (quit the apps first for these to stick)"
  for p in "$PRIV"/prefs/*.plist; do
    [ -f "$p" ] && defaults import "$(basename "$p" .plist)" "$p" && echo "  $(basename "$p" .plist)"
  done

  log "Git repos"
  if [ -f "$PRIV/repos.txt" ]; then
    while read -r dir url; do
      [ -d "$HOME/$dir" ] && continue
      mkdir -p "$(dirname "$HOME/$dir")"
      git clone "$url" "$HOME/$dir" || warn "clone failed: $url (gh auth login / ssh key?)"
    done < "$PRIV/repos.txt"
  fi

  log "Caddy"
  if [ -f "$PRIV/Caddyfile" ]; then
    cp "$PRIV/Caddyfile" "$(brew --prefix)/etc/Caddyfile" && brew services restart caddy
  fi

  log "LaunchAgents"
  for p in "$PRIV"/LaunchAgents/*.plist; do
    [ -f "$p" ] || continue
    local dst="$HOME/Library/LaunchAgents/$(basename "$p")"
    place "$p" "$dst"
    launchctl bootout "gui/$(id -u)" "$dst" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "$dst" && echo "  loaded $(basename "$p")"
  done
}

step_macos() {
  log "macOS defaults"
  bash "$REPO/macos.sh"
}

step_editors() {
  log "VS Code extensions"
  if command -v code &>/dev/null && [ -f "$REPO/vscode-extensions.txt" ]; then
    while read -r ext; do code --install-extension "$ext" --force >/dev/null && echo "  $ext"; done < "$REPO/vscode-extensions.txt"
  fi
}

selected=("$@")
[ ${#selected[@]} -eq 0 ] && selected=("${STEPS[@]}")
for s in "${selected[@]}"; do
  if declare -F "step_$s" >/dev/null; then "step_$s"; else warn "unknown step: $s (valid: ${STEPS[*]})"; fi
done

log "Done. Remaining manual steps are in README.md"
