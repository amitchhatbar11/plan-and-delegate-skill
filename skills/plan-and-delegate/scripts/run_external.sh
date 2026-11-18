#!/usr/bin/env bash
# Runs a handoff with an external agent CLI on another provider.
# Usage: run_external.sh <opencode|codex|gemini|qwen|aider> <model> <handoff-file> [workdir]
# Prints the agent's output. Exit code is the CLI's (127 = CLI not installed).
set -u

BACKEND="${1:?backend}"; MODEL="${2:?model}"; FILE="${3:?handoff file}"; DIR="${4:-$PWD}"
[ -f "$FILE" ] || { echo "handoff file not found: $FILE" >&2; exit 2; }

find_bin() {
  command -v "$1" 2>/dev/null && return 0
  for d in "$HOME/.$1/bin" "$HOME/.local/bin" "$HOME/.npm-global/bin" "$HOME/.bun/bin"; do
    [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  return 1
}
B=$(find_bin "$BACKEND") || { echo "NOT_INSTALLED: $BACKEND (see references/backends.md)" >&2; exit 127; }

PROMPT="$(awk 'c>=2{print} /^---$/{c++}' "$(dirname "$0")/../agents/executor.md")

$(cat "$FILE")"

cd "$DIR" || exit 2
case "$BACKEND" in
  opencode) exec "$B" run --model "$MODEL" "$PROMPT" ;;
  codex)    exec "$B" exec --full-auto -m "$MODEL" "$PROMPT" ;;
  gemini)   exec "$B" --yolo -m "$MODEL" -p "$PROMPT" ;;
  qwen)     exec "$B" --yolo -m "$MODEL" -p "$PROMPT" ;;
  aider)    exec "$B" --yes-always --no-auto-commits --model "$MODEL" --message "$PROMPT" ;;
  *) echo "unknown backend: $BACKEND (use opencode, codex, gemini, qwen or aider)" >&2; exit 2 ;;
esac
