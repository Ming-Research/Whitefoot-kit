#!/bin/bash
# Runs every trial case under cases/<id>/. A case holds original/ (the
# reference program taken from an existing repository) and, once a writer has
# answered, attempt/ (the program a fresh agent wrote from the dictation in
# task.md). Each side is built from its main.wf, or from the arguments in its
# build file (one per line, relative to that side's directory) when it is a
# module graph; flags, when present, adds compile flags such as --par. Each
# built side runs with the case's input on stdin and the arguments in args,
# under a 20-second limit. A case passes when the attempt is accepted and its
# stdout and exit status equal the original's. Results land under
# <out>/<id>/; summary.md lists every case.
set -u
whitefootc=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
rm -rf "$out" && mkdir -p "$out"
summary="$out/summary.md"
echo "| case | original | attempt | verdict |" > "$summary"
echo "|---|---|---|---|" >> "$summary"

side() {
  local case=$1 name=$2 dir="$1/$2" res=$3
  mkdir -p "$res"
  [ -d "$dir" ] || { echo absent; return; }
  local args=()
  if [ -f "$dir/build" ]; then
    while IFS= read -r a; do [ -n "$a" ] && args+=("$a"); done < "$dir/build"
  else
    args=(main.wf)
  fi
  local flags=()
  [ -f "$case/flags" ] && read -r -a flags < "$case/flags"
  (cd "$dir" && "$whitefootc" "${flags[@]}" "${args[@]}" -o "$res/bin") > "$res/compile.txt" 2>&1
  local cs=$?
  if [ $cs -ne 0 ]; then echo "rejected"; return; fi
  local run_args=()
  [ -f "$case/args" ] && read -r -a run_args < "$case/args"
  local input=/dev/null
  [ -f "$case/input" ] && input="$case/input"
  (cd "$dir" && timeout 20 "$res/bin" "${run_args[@]}" < "$input" > "$res/stdout.txt" 2> "$res/stderr.txt")
  echo $? > "$res/status.txt"
  echo "ran:$(cat "$res/status.txt")"
}

for case in "$here"/cases/*/; do
  case=${case%/}
  id=$(basename "$case")
  o=$(side "$case" original "$out/$id/original")
  a=$(side "$case" attempt "$out/$id/attempt")
  verdict=fail
  if [ "${o%%:*}" = ran ] && [ "${a%%:*}" = ran ] \
    && [ "$o" = "$a" ] \
    && cmp -s "$out/$id/original/stdout.txt" "$out/$id/attempt/stdout.txt"; then
    verdict=pass
  fi
  [ "$a" = absent ] && verdict=pending
  echo "| $id | $o | $a | $verdict |" >> "$summary"
done
cat "$summary"
