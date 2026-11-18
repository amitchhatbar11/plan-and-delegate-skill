#!/usr/bin/env bash
# Lists every way this machine can run an executor: the Claude Code provider and its tiers,
# installed external agent CLIs with their providers/models, and provider API keys found in
# the environment (names only, never values). Read-only.
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
echo "== External agent CLIs =="
find_bin() {
  command -v "$1" 2>/dev/null && return 0
  for d in "$HOME/.$1/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin" "$HOME/.bun/bin"; do
    [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  return 1
}
t() { if command -v timeout >/dev/null; then timeout 20 "$@"; else "$@"; fi; }
missing=""

for cli in opencode codex gemini qwen aider; do
  if B=$(find_bin "$cli"); then
    echo "backend: $cli ($B)"
    case "$cli" in
      opencode)
        echo "  connected providers:"; t "$B" auth list 2>/dev/null | sed 's/^/    /' | head -30
        echo "  models (use exactly as listed):"; t "$B" models 2>/dev/null | sed 's/^/    /' | head -150 ;;
      codex)
        echo "  configured model: $(grep -E '^model *=' "$HOME/.codex/config.toml" 2>/dev/null | head -1 || echo default)"
        [ -f "$HOME/.codex/auth.json" ] && echo "  logged in: yes" || echo "  logged in: unknown (run 'codex login')" ;;
      gemini) [ -d "$HOME/.gemini" ] && echo "  signed in/configured: likely (~/.gemini exists)" || echo "  not signed in yet (run 'gemini')" ;;
      qwen)   [ -d "$HOME/.qwen" ] && echo "  configured: likely (~/.qwen exists)" || echo "  not signed in yet (run 'qwen')" ;;
      aider)  echo "  uses provider API keys from the environment (see below)" ;;
    esac
  else
    missing="$missing $cli"
  fi
done
[ -n "$missing" ] && echo "not installed:$missing (see references/backends.md to install)"

echo
echo "== Provider API keys in environment (names only) =="
keys=$(env | cut -d= -f1 | grep -E '^(OPENAI|OPENROUTER|DEEPSEEK|GEMINI|GOOGLE|GROQ|MISTRAL|XAI|TOGETHER|FIREWORKS|DASHSCOPE|MOONSHOT|ZHIPU|CEREBRAS|OPENCODE|AZURE_OPENAI|ANTHROPIC)_API_KEY$|^AWS_PROFILE$|^OLLAMA_HOST$' | sort)
[ -n "$keys" ] && echo "$keys" | sed 's/^/  /' || echo "  none"
command -v ollama >/dev/null && { echo "local: ollama models:"; t ollama list 2>/dev/null | sed 's/^/    /' | head -20; }

PREF="$HOME/.claude/plan-and-delegate.json"
echo
[ -f "$PREF" ] && echo "saved_preferences: $(tr -d '\n' < "$PREF")"
if command -v python3 >/dev/null; then python3 -I "$(dirname "$0")/telegram.py" status 2>/dev/null; else echo "telegram: needs python3"; fi
echo "tools: npm=$(command -v npm >/dev/null && echo yes || echo no) python3=$(command -v python3 >/dev/null && echo yes || echo no) curl=$(command -v curl >/dev/null && echo yes || echo no)"
exit 0
