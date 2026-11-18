#!/usr/bin/env bash
# Runs a handoff with an external agent CLI on another provider.
# Usage: run_external.sh <opencode|codex|gemini> <model> <handoff-file> [workdir]
# Prints the agent's final output. Exit code is the CLI's.
set -u

BACKEND="${1:?backend}"; MODEL="${2:?model}"; FILE="${3:?handoff file}"; DIR="${4:-$PWD}"
[ -f "$FILE" ] || { echo "handoff file not found: $FILE" >&2; exit 2; }

PROMPT="$(awk 'c>=2{print} /^---$/{c++}' "$(dirname "$0")/../agents/executor.md")

$(cat "$FILE")"

cd "$DIR" || exit 2
case "$BACKEND" in
  opencode) B=$(command -v opencode || echo "$HOME/.opencode/bin/opencode")
            exec "$B" run --model "$MODEL" "$PROMPT" ;;
  codex)    exec codex exec --full-auto -m "$MODEL" "$PROMPT" ;;
  gemini)   exec gemini --yolo -m "$MODEL" -p "$PROMPT" ;;
  *) echo "unknown backend: $BACKEND (use opencode, codex or gemini)" >&2; exit 2 ;;
esac
