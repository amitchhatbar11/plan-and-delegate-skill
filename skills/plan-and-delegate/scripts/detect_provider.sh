#!/usr/bin/env bash
# Prints the Claude Code provider, tier->model mapping, and external agent CLIs
# (OpenCode, Codex, Gemini) that can run the executor on other providers. Read-only.
set -u

if   [ "${CLAUDE_CODE_USE_BEDROCK:-}" = "1" ]; then P="bedrock"
elif [ "${CLAUDE_CODE_USE_VERTEX:-}"  = "1" ]; then P="vertex"
elif [ "${CLAUDE_CODE_USE_FOUNDRY:-}" = "1" ]; then P="foundry"
elif [ -n "${ANTHROPIC_BASE_URL:-}" ];           then P="gateway (${ANTHROPIC_BASE_URL})"
else P="anthropic"; fi

echo "== Claude Code (subagent backend) =="
echo "provider: $P"
echo "session_model: ${ANTHROPIC_MODEL:-default (check /model)}"
echo "tier_opus:   ${ANTHROPIC_DEFAULT_OPUS_MODEL:-provider default}"
echo "tier_sonnet: ${ANTHROPIC_DEFAULT_SONNET_MODEL:-provider default}"
echo "tier_haiku:  ${ANTHROPIC_DEFAULT_HAIKU_MODEL:-${ANTHROPIC_SMALL_FAST_MODEL:-provider default}}"

for f in "$HOME/.claude/settings.json" ".claude/settings.json" ".claude/settings.local.json"; do
  [ -f "$f" ] && grep -Eo '"(ANTHROPIC_[A-Z_]*MODEL|model|availableModels)"[^,}]*' "$f" | sed "s|^|settings $f: |"
done

echo
echo "== External agent CLIs (any provider they are configured for) =="
found=0
find_bin() { command -v "$1" 2>/dev/null || { [ -x "$HOME/.$1/bin/$1" ] && echo "$HOME/.$1/bin/$1"; }; }
with_timeout() { if command -v timeout >/dev/null; then timeout 20 "$@"; else "$@"; fi; }

if B=$(find_bin opencode) && [ -n "$B" ]; then
  found=1; echo "backend: opencode ($B)"
  echo "models (provider/model, use exactly as listed):"
  with_timeout "$B" models 2>/dev/null | sed 's/^/  /' | head -100 || echo "  (could not list; run 'opencode models')"
fi
if B=$(find_bin codex) && [ -n "$B" ]; then
  found=1; echo "backend: codex ($B)"
  echo "  model: from ~/.codex/config.toml ($(grep -E '^model *=' "$HOME/.codex/config.toml" 2>/dev/null | head -1 || echo default)); any model your Codex provider accepts"
fi
if B=$(find_bin gemini) && [ -n "$B" ]; then
  found=1; echo "backend: gemini ($B)"
  echo "  models: any Gemini model ID your account has (e.g. a flash model for cheap execution)"
fi
[ "$found" = 0 ] && echo "none installed (install OpenCode, Codex or Gemini CLI to execute with non-Claude-Code providers)"

PREF="$HOME/.claude/plan-and-delegate.json"
echo
[ -f "$PREF" ] && echo "saved_preferences: $(tr -d '\n' < "$PREF")"
exit 0
