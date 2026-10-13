#!/bin/bash
# See cases/README.md for the source, graph, environment and driver formats.
# Builds and runs happen in CI only. A missing attempt remains pending.
set -u
whitefootc=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
whitefootc=$(cd "$(dirname "$whitefootc")" && pwd)/$(basename "$whitefootc")
mkdir -p "$out"
out=$(cd "$out" && pwd)
rm -rf "$out" && mkdir -p "$out"
summary="$out/summary.md"
echo "| case | original | attempt | verdict |" > "$summary"
echo "|---|---|---|---|" >> "$summary"

side() {
  local case=$1 name=$2 dir="$1/$2" res=$3
  mkdir -p "$res"
  [ -d "$dir" ] || { echo absent; return; }
  local case_env=() assignment
  if [ -f "$case/env" ]; then
    while IFS= read -r assignment || [ -n "$assignment" ]; do
      [ -z "$assignment" ] && continue
      if [[ ! "$assignment" =~ ^[a-zA-Z_][a-zA-Z_0-9]*= ]]; then
        echo "Invalid KEY=VALUE line in $case/env" > "$res/compile.txt"
        echo config-error
        return
      fi
      case_env+=("$assignment")
    done < "$case/env"
  fi
  local args=()
  if [ -f "$dir/build" ]; then
    while IFS= read -r a || [ -n "$a" ]; do [ -n "$a" ] && args+=("$a"); done < "$dir/build"
  else
    args=(main.wf)
  fi
  local flags=()
  [ -f "$case/flags" ] && read -r -a flags < "$case/flags"
  (cd "$dir" && env "${case_env[@]}" "$whitefootc" "${flags[@]}" "${args[@]}" -o "$res/bin") > "$res/compile.txt" 2>&1
  local cs=$?
  if [ $cs -ne 0 ]; then echo "rejected"; return; fi
  local run_args=()
  [ -f "$case/args" ] && read -r -a run_args < "$case/args"
  local input=/dev/null
  [ -f "$case/input" ] && input="$case/input"
  if [ -f "$case/drive" ]; then
    if [ ! -x "$case/drive" ]; then echo config-error; return; fi
    (cd "$dir" && env "${case_env[@]}" timeout --kill-after=2 20 "$case/drive" "$res/bin" "$res" < /dev/null > "$res/stdout.txt" 2> "$res/stderr.txt")
  else
    (cd "$dir" && env "${case_env[@]}" timeout --kill-after=2 20 "$res/bin" "${run_args[@]}" < "$input" > "$res/stdout.txt" 2> "$res/stderr.txt")
  fi
  echo $? > "$res/status.txt"
  echo "ran:$(cat "$res/status.txt")"
}

smoke_errors=0
for case in "$here"/cases/*/; do
  case=${case%/}
  id=$(basename "$case")
  if [ -f "$case/expected" ] && [ ! -d "$case/original" ]; then
    mkdir -p "$out/$id/original"
    cp "$case/expected" "$out/$id/original/stdout.txt"
    echo 0 > "$out/$id/original/status.txt"
    o=ran:0
    reference=expected
  else
    o=$(side "$case" original "$out/$id/original")
    reference=$o
  fi
  a=$(side "$case" attempt "$out/$id/attempt")
  verdict=fail
  if [ "${o%%:*}" = ran ] && [ "${a%%:*}" = ran ] \
    && [ "$o" = "$a" ] \
    && cmp -s "$out/$id/original/stdout.txt" "$out/$id/attempt/stdout.txt"; then
    verdict=pass
  fi
  # Matching driver failures or two timed-out programs are not observations.
  if [ -f "$case/drive" ] && { [ "$o" != ran:0 ] || [ "$a" != ran:0 ]; }; then
    verdict=fail
  fi
  case "$a" in ran:124|ran:137) verdict=fail ;; esac
  [ "$a" = absent ] && verdict=pending
  echo "| $id | $reference | $a | $verdict |" >> "$summary"
  if [ -f "$case/smoke-verdict" ]; then
    wanted=$(cat "$case/smoke-verdict")
    if [ "$verdict" != "$wanted" ]; then
      echo "Smoke $id: expected $wanted, observed $verdict" >&2
      smoke_errors=$((smoke_errors + 1))
    fi
    # A comparison smoke must reach execution: compiler rejection is only
    # the intended outcome of the dedicated rejection fixture.
    if [ "${o%%:*}" != ran ] || \
      { [ "$id" != 00-smoke-rejected ] && [ "${a%%:*}" != ran ]; } || \
      { [ "$id" = 00-smoke-rejected ] && [ "$a" != rejected ]; }; then
      echo "Smoke $id did not reach its intended compilation/execution stage" >&2
      smoke_errors=$((smoke_errors + 1))
    fi
  fi
done
cat "$summary"
if [ "$smoke_errors" -ne 0 ]; then exit 1; fi
