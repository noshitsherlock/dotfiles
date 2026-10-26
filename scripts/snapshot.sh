#!/usr/bin/env bash
# Capture this machine's setup into the repo. Run on the OLD machine,
# review `git diff`, commit, then copy private/ to the new machine.
#
# Public (committed):  Brewfile, home/, skills/, templates/
# Private (gitignored): private/ — secrets, repo list, app prefs, launch agents
set -euo pipefail

# Left behind on purpose — not wanted on the new machine.
#   headroom: context-compression proxy (also owns ANTHROPIC_BASE_URL=127.0.0.1:8787)
#   serena:   MCP server / Claude plugin
#   cursor:   editor, CLI, configs and Cursor's built-in skills
SKIP_SKILLS=(babysit canvas create-hook create-rule create-skill create-subagent
             migrate-to-skills shell statusline update-cli-config update-cursor-settings)

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HOME_OUT="$REPO/home"
PRIV="$REPO/private"
mkdir -p "$HOME_OUT" "$PRIV/prefs" "$PRIV/LaunchAgents"

# Copy $HOME/<path> into home/<path>, replacing the home dir with __HOME__.
grab() {
  local src="$HOME/$1" dst="$HOME_OUT/$1"
  [ -e "$src" ] || { echo "  skip (missing): $1"; return; }
  mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    rm -rf "$dst"; cp -R "$src" "$dst"
    { grep -rl "$HOME" "$dst" 2>/dev/null || true; } | while read -r f; do sed -i '' "s|$HOME|__HOME__|g" "$f"; done
  else
    sed "s|$HOME|__HOME__|g" "$src" > "$dst"
  fi
  echo "  $1"
}

echo "==> Brewfile"
brew bundle dump --file="$REPO/Brewfile" --force --no-vscode --no-uv --no-npm
# Drop Cursor casks together with the description comment brew puts above them.
awk '/^#/ { c = c $0 "\n"; next } /^cask "cursor(-cli)?"/ { c = ""; next } { printf "%s", c; c = ""; print }' \
  "$REPO/Brewfile" > "$REPO/Brewfile.tmp" && mv "$REPO/Brewfile.tmp" "$REPO/Brewfile"

echo "==> Editor extensions"
command -v code   >/dev/null && code --list-extensions   > "$REPO/vscode-extensions.txt"

echo "==> Shell, git, terminal"
grab .zshrc
grab .zprofile
grab .p10k.zsh
grab .gitconfig
grab .tmux.conf
grab .config/git/ignore
grab .config/tmux/tmux.reset.conf
grab .config/wezterm/wezterm.lua
grab .config/herdr/config.toml
grab .config/btop/btop.conf
grab .config/gh/config.yml
grab .config/ccstatusline/settings.json
grab .config/qmd/index.yml
grab .config/opencode/tui.jsonc
grab .config/opencode/package.json
grab "Library/Application Support/com.mitchellh.ghostty/config"
grab "Library/Application Support/Code/User/settings.json"

echo "==> AI agents"
grab .claude/settings.json
grab .claude/CLAUDE.md
grab .claude/RTK.md
grab .claude/rules
grab .claude/hooks
grab .claude/statusline-command.sh
grab .codex/AGENTS.md
grab .codex/hooks.json
grab .codex/hooks
grab .codex/herdr-agent-state.sh
grab .copilot/settings.json
grab .copilot/hooks
grab .gemini/settings.json
grab .pi/agent/settings.json
grab .pi/agent/pi-statusline.json
grab .pi/agent/zentui.json

# Strip headroom/serena: proxy URL, hooks, plugins, marketplace.
not_headroom='map(.hooks |= map(select(.command | test("headroom") | not))) | map(select(.hooks | length > 0))'
jq --indent 2 "del(.env.ANTHROPIC_BASE_URL) | if .env == {} then del(.env) else . end
  | .hooks |= map_values($not_headroom)
  | del(.enabledPlugins[\"serena@claude-plugins-official\", \"headroom@headroom-marketplace\"])
  | del(.extraKnownMarketplaces[\"headroom-marketplace\"])" \
  "$HOME_OUT/.claude/settings.json" > "$HOME_OUT/.tmp" && mv "$HOME_OUT/.tmp" "$HOME_OUT/.claude/settings.json"
jq --indent 2 ".hooks |= map_values($not_headroom)" \
  "$HOME_OUT/.codex/hooks.json" > "$HOME_OUT/.tmp" && mv "$HOME_OUT/.tmp" "$HOME_OUT/.codex/hooks.json"

echo "==> Templates (secrets replaced with \${VARS}, filled from private/secrets.env)"
T="$REPO/templates"
rm -rf "$T/.cursor"
mkdir -p "$T/.codex" "$T/.config/opencode" "$T/.pi/agent"
redact() {
  sed -E -e "s|$HOME|__HOME__|g" \
    -e 's|ctx7sk-[A-Za-z0-9-]+|${CONTEXT7_API_KEY}|g' \
    -e 's|sk-[A-Za-z0-9]{16,}|${SPARKS_API_KEY}|g' \
    -e 's|http://[0-9.]+:4000/v1|${SPARKS_BASE_URL}|g' \
    -e 's|http://[0-9.]+:4000/mcp/|${SPARKS_MCP_URL}|g'
}
# Codex: drop machine-generated state (projects, hook hashes, timestamps, ChatGPT app MCPs)
# and headroom/serena.
awk '
  /^\[/ { skip = ($0 ~ /^\[(projects|hooks\.state|tui|mcp_servers\.(node_repl|computer-use))/ || $0 ~ /local|openai-primary-runtime|openai-bundled\]|headroom|serena/) }
  /^ANTHROPIC_BASE_URL *=/ { next }
  /^(notify|last_updated|last_revision) *=/ { if ($0 ~ /\]$/ || $0 !~ /\[/) next; else { inarr=1; next } }
  inarr { if ($0 ~ /^\]/) inarr=0; next }
  !skip
' "$HOME/.codex/config.toml" | redact | cat -s > "$T/.codex/config.toml"
redact < "$HOME/.config/opencode/opencode.json" > "$T/.config/opencode/opencode.json"
redact < "$HOME/.pi/agent/mcp-adapter.json"    > "$T/.pi/agent/mcp-adapter.json"

echo "==> Skills (~/.agents/skills)"
rm -rf "$REPO/skills"; cp -R "$HOME/.agents/skills" "$REPO/skills"
for s in "${SKIP_SKILLS[@]}"; do rm -rf "${REPO:?}/skills/$s"; done

echo "==> Private: secrets"
ctx7=$(jq -r '.mcpServers.context7.headers.CONTEXT7_API_KEY // empty' "$HOME/.claude.json")
sparks_url=$(jq -r '.provider.sparks.options.baseURL // empty' "$HOME/.config/opencode/opencode.json" 2>/dev/null || true)
sparks_key=$(jq -r '.provider.sparks.options.apiKey // empty' "$HOME/.config/opencode/opencode.json" 2>/dev/null || true)
cat > "$PRIV/secrets.env" <<EOF
CONTEXT7_API_KEY=$ctx7
SPARKS_BASE_URL=$sparks_url
SPARKS_MCP_URL=${sparks_url%/v1}/mcp/
SPARKS_API_KEY=$sparks_key
EOF
chmod 600 "$PRIV/secrets.env"

echo "==> Private: git repos"
: > "$PRIV/repos.txt"
for d in "$HOME"/Development/*/ "$HOME"/Projects/*/; do
  url=$(git -C "$d" remote get-url origin 2>/dev/null) || continue
  echo "${d#"$HOME"/} $url" >> "$PRIV/repos.txt"
done

echo "==> Private: app preferences"
for domain in com.knollsoft.Rectangle com.mowglii.ItsycalApp eu.exelban.Stats com.dwarvesv.minimalbar com.googlecode.iterm2 leits.MeetingBar; do
  defaults export "$domain" "$PRIV/prefs/$domain.plist" 2>/dev/null && echo "  $domain"
done

echo "==> Private: Claude local permissions, launch agents, Caddyfile"
sed "s|$HOME|__HOME__|g" "$HOME/.claude/settings.local.json" > "$PRIV/claude-settings.local.json"
for p in "$HOME"/Library/LaunchAgents/com.*.plist; do
  case "$p" in *homebrew.mxcl*|*pc-print*) continue ;; esac
  sed "s|$HOME|__HOME__|g" "$p" > "$PRIV/LaunchAgents/$(basename "$p")"
done
[ -f /opt/homebrew/etc/Caddyfile ] && cp /opt/homebrew/etc/Caddyfile "$PRIV/Caddyfile"

echo
echo "Done. Review with 'git status' / 'git diff'."
echo "Copy $PRIV to the new machine (AirDrop / 1Password) — it is NOT committed."
