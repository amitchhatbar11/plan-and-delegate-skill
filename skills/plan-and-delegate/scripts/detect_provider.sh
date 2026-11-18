#!/usr/bin/env bash
# Prints the provider, session model and the model ID each tier maps to. Read-only.
set -u

if   [ "${CLAUDE_CODE_USE_BEDROCK:-}" = "1" ]; then P="bedrock"
elif [ "${CLAUDE_CODE_USE_VERTEX:-}"  = "1" ]; then P="vertex"
elif [ "${CLAUDE_CODE_USE_FOUNDRY:-}" = "1" ]; then P="foundry"
elif [ -n "${ANTHROPIC_BASE_URL:-}" ];           then P="gateway (${ANTHROPIC_BASE_URL})"
else P="anthropic"; fi

echo "provider: $P"
echo "session_model: ${ANTHROPIC_MODEL:-default (check /model)}"
echo "tier_opus:   ${ANTHROPIC_DEFAULT_OPUS_MODEL:-provider default}"
echo "tier_sonnet: ${ANTHROPIC_DEFAULT_SONNET_MODEL:-provider default}"
echo "tier_haiku:  ${ANTHROPIC_DEFAULT_HAIKU_MODEL:-${ANTHROPIC_SMALL_FAST_MODEL:-provider default}}"

# Settings files can set env vars / model too.
for f in "$HOME/.claude/settings.json" ".claude/settings.json" ".claude/settings.local.json"; do
  [ -f "$f" ] && grep -Eo '"(ANTHROPIC_[A-Z_]*MODEL|model|availableModels)"[^,}]*' "$f" | sed "s|^|settings $f: |"
done

PREF="$HOME/.claude/plan-and-delegate.json"
[ -f "$PREF" ] && echo "saved_preferences: $(tr -d '\n' < "$PREF")"
exit 0
