#!/usr/bin/env bash
# Installs executor/reviewer subagents (plus per-tier fallbacks) into ~/.claude/agents.
# Never overwrites existing files. Set AGENTS_DIR to install elsewhere (e.g. .claude/agents).
set -eu

SRC="$(cd "$(dirname "$0")/../agents" && pwd)"
DEST="${AGENTS_DIR:-$HOME/.claude/agents}"
mkdir -p "$DEST"

installed=0
put() { # name content-file
  if [ ! -f "$DEST/$1.md" ]; then cp "$2" "$DEST/$1.md"; echo "installed: $DEST/$1.md"; installed=1; fi
}
tier() { # base tier
  local out="$DEST/$1-$2.md"
  if [ ! -f "$out" ]; then
    sed -e "s/^name: $1$/name: $1-$2/" -e "s/^model: inherit$/model: $2/" "$SRC/$1.md" > "$out"
    echo "installed: $out"; installed=1
  fi
}

for base in executor reviewer; do
  put "$base" "$SRC/$base.md"
  for t in haiku sonnet opus; do tier "$base" "$t"; done
done

[ "$installed" = 1 ] && echo "note: restart Claude Code to load new fallback agents" || echo "agents: already installed in $DEST"
