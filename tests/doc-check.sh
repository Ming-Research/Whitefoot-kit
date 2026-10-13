#!/bin/bash
# Check the guide's byte limit and every complete triple-backtick whitefoot
# block. An optional input path lets the fixtures exercise the same check.
set -eu
kit=$(cd "$(dirname "$0")/.." && pwd)
document=${1:-"$kit/docs/writing.md"}
if [ "$#" -gt 1 ]; then
  echo "usage: bash tests/doc-check.sh [document]" >&2
  exit 1
fi
size=$(wc -c < "$document")
size=${size//[[:space:]]/}
if [ "$size" -gt 153600 ]; then
  echo "$document: $size bytes exceeds the 153600-byte limit" >&2
  exit 1
fi
: "${WHITEFOOTC:?set WHITEFOOTC to the compiler executable}"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/whitefoot-doc-check.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
trap 'exit 1' HUP INT TERM

# Other fences must be tracked too: a whitefoot-looking line in a text,
# tilde or longer-backtick fence is still just that fence's contents.
opening='^[[:space:]]*(`{3,}|~{3,})(.*)$'
closing='^[[:space:]]*(`{3,}|~{3,})[[:space:]]*$'
language='^[[:space:]]*whitefoot[[:space:]]*$'
fence=
whitefoot=0
count=0
line_number=0
failed=0
while IFS= read -r line || [ -n "$line" ]; do
  line_number=$((line_number + 1))
  # Use CRLF as a line ending when recognizing fences; retain it in source.
  match=${line%$'\r'}
  if [ -z "$fence" ]; then
    if [[ "$match" =~ $opening ]]; then
      fence=${BASH_REMATCH[1]}
      info=${BASH_REMATCH[2]}
      whitefoot=0
      if [[ "$info" =~ $language ]]; then
        whitefoot=1
        count=$((count + 1))
        printf '%s\n' "$line_number" > "$scratch/$count.line"
        : > "$scratch/$count.wf"
      fi
    fi
  elif [[ "$match" =~ $closing ]] &&
       [ "${BASH_REMATCH[1]:0:1}" = "${fence:0:1}" ] &&
       [ "${#BASH_REMATCH[1]}" -ge "${#fence}" ]; then
    fence=
    whitefoot=0
  elif [ "$whitefoot" = 1 ]; then
    printf '%s\n' "$line" >> "$scratch/$count.wf"
  fi
done < "$document"

if [ "$whitefoot" = 1 ]; then
  echo "$document:$(cat "$scratch/$count.line"): unclosed whitefoot fence" >&2
  failed=1
fi
for ((block = 1; block <= count; block++)); do
  if ! "$WHITEFOOTC" --check "$scratch/$block.wf" > "$scratch/$block.log" 2>&1; then
    echo "$document:$(cat "$scratch/$block.line"): whitefoot block $block failed:" >&2
    cat "$scratch/$block.log" >&2
    failed=1
  fi
done
echo "checked $count whitefoot block(s) in $document ($size bytes)"
exit "$failed"
