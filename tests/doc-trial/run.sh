#!/bin/bash
# See cases/README.md for the source, graph, environment and driver formats.
# Builds and runs happen in CI only. A missing attempt remains pending.
# CASES_DIR selects another case root; the default retains set 1 and its smokes.
set -u
whitefootc=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
cases_dir=${CASES_DIR:-"$here/cases"}
cases_dir=$(cd "$cases_dir" && pwd) || exit 1
whitefootc=$(cd "$(dirname "$whitefootc")" && pwd)/$(basename "$whitefootc")
mkdir -p "$out"
out=$(cd "$out" && pwd)
rm -rf "$out" && mkdir -p "$out"
summary="$out/summary.md"
sessions_summary="$out/summary-sessions.md"
: > "$sessions_summary"
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
for case in "$cases_dir"/*/; do
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
  sessions_passed=0
  for session in 1 2 3; do
    name=attempt
    row_id=$id
    smoke_expectation="$case/smoke-verdict"
    if [ "$session" -ne 1 ]; then
      name="attempt-$session"
      row_id="$id#$session"
      smoke_expectation="$case/smoke-verdict-$session"
      # An expectation without its attempt must fail, rather than skipping
      # the smoke that establishes this session was independently compared.
      [ -d "$case/$name" ] || [ -f "$smoke_expectation" ] || continue
    fi
    a=$(side "$case" "$name" "$out/$id/$name")
    verdict=fail
    if [ "${o%%:*}" = ran ] && [ "${a%%:*}" = ran ] \
      && [ "$o" = "$a" ] \
      && cmp -s "$out/$id/original/stdout.txt" "$out/$id/$name/stdout.txt"; then
      verdict=pass
    fi
    # Matching driver failures or two timed-out programs are not observations.
    if [ -f "$case/drive" ] && { [ "$o" != ran:0 ] || [ "$a" != ran:0 ]; }; then
      verdict=fail
    fi
    case "$a" in ran:124|ran:137) verdict=fail ;; esac
    [ "$a" = absent ] && verdict=pending
    echo "| $row_id | $reference | $a | $verdict |" >> "$summary"
    [ "$verdict" = pass ] && sessions_passed=$((sessions_passed + 1))
    if [ -f "$smoke_expectation" ]; then
      wanted=$(cat "$smoke_expectation")
      if [ "$verdict" != "$wanted" ]; then
        echo "Smoke $row_id: expected $wanted, observed $verdict" >&2
        smoke_errors=$((smoke_errors + 1))
      fi
      # A comparison smoke must reach execution: compiler rejection is only
      # the intended outcome of the dedicated rejection fixture.
      if [ "${o%%:*}" != ran ] || \
        { { [ "$id" != 00-smoke-rejected ] || [ "$session" -ne 1 ]; } && [ "${a%%:*}" != ran ]; } || \
        { [ "$id" = 00-smoke-rejected ] && [ "$session" -eq 1 ] && [ "$a" != rejected ]; }; then
        echo "Smoke $row_id did not reach its intended compilation/execution stage" >&2
        smoke_errors=$((smoke_errors + 1))
      fi
    fi
  done
  echo "$id $sessions_passed/3" >> "$sessions_summary"
done
cat "$summary"
if [ "$smoke_errors" -ne 0 ]; then exit 1; fi
