#!/usr/bin/env bash
# Lists candidate files for an upload, newest first, ranked by how many keywords match.
# Usage: find_upload.sh <dir> [keyword ...]     e.g. find_upload.sh ~/Documents/uploads resume pdf
# Output: <matches> <modified date> <size> <absolute path>
set -u
DIR="${1:?dir}"; shift
DIR="${DIR/#\~/$HOME}"
[ -d "$DIR" ] || { echo "NO_DIR: $DIR"; exit 1; }

find "$DIR" -maxdepth 3 -type f ! -name '.*' -printf '%T@\t%TY-%Tm-%Td\t%s\t%p\n' 2>/dev/null |
while IFS=$'\t' read -r ts date size path; do
  n=0; name="$(basename "$path" | tr 'A-Z' 'a-z')"
  for k in "$@"; do case "$name" in *"$(echo "$k" | tr 'A-Z' 'a-z')"*) n=$((n+1));; esac; done
  [ "$#" -eq 0 ] || [ "$n" -gt 0 ] && printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$ts" "$date" "$size" "$path"
done | sort -t$'\t' -k1,1nr -k2,2nr | cut -f1,3- | head -20
