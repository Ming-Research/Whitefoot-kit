#!/bin/bash
# Exercise the real document checker with the same compiler as the guide.
# Like tests/run.sh, each assertion prints PASS or FAIL and failures add up.
set -u
kit=$(cd "$(dirname "$0")/.." && pwd)
: "${WHITEFOOTC:?set WHITEFOOTC to the compiler executable}"
fixtures="$kit/tests/doc-check-fixtures"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/whitefoot-doc-fixtures.XXXXXX") || exit 1
trap 'rm -rf "$scratch"' EXIT
trap 'exit 1' HUP INT TERM
failures=0
check() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1: expected [$3], got [$2]"
    cat "$scratch/last.log"
    failures=$((failures + 1))
  fi
}
run() {
  bash "$kit/tests/doc-check.sh" "$@" > "$scratch/last.log" 2>&1
  echo $?
}

check "the current guide passes" "$(run)" 0
check "the complete valid source passes" "$(run "$fixtures/valid.md")" 0
check "the valid source is checked once" \
  "$(grep -c 'checked 1 whitefoot block(s)' "$scratch/last.log")" 1
check "the over-limit fixture fails" "$(run "$fixtures/too-long.md")" 1
check "the over-limit failure reports its actual size and limit" \
  "$(grep -c '153601 bytes exceeds the 153600-byte limit' "$scratch/last.log")" 1
head -c 153600 "$fixtures/too-long.md" > "$scratch/at-limit.md"
check "exactly 153600 bytes is within the limit" "$(run "$scratch/at-limit.md")" 0
check "the rejected source fails" "$(run "$fixtures/rejected.md")" 1
check "the rejection names the opening source line" \
  "$(grep -Fc "$fixtures/rejected.md:3: whitefoot block 1 failed:" "$scratch/last.log")" 1
check "the rejection includes the compiler's diagnostic" \
  "$(grep -q 'error\[' "$scratch/last.log" && echo yes || echo no)" yes

# Invalid code and nested whitefoot-looking fences in other fence types are
# ignored. Exactly one real block follows; its contents remain unchanged.
cat > "$scratch/ignored.md" <<'EOF'
```text
fn main( {
```whitefoot
```
````text
```whitefoot
fn main( {
```
````
~~~text
```whitefoot
fn main( {
```
~~~
``` whitefoot
fn main( {
```
EOF
cat "$fixtures/valid.md" >> "$scratch/ignored.md"
check "other fences hide Whitefoot-looking lines" "$(run "$scratch/ignored.md")" 0
check "only the real whitefoot block is checked" \
  "$(grep -c 'checked 1 whitefoot block(s)' "$scratch/last.log")" 1

printf '```whitefoot\nfn main( {\n```\n\n```whitefoot\nfn main( {\n```\n' > "$scratch/multiple.md"
check "multiple rejected blocks fail together" "$(run "$scratch/multiple.md")" 1
check "the first block's opening line is reported" \
  "$(grep -Fc "$scratch/multiple.md:1: whitefoot block 1 failed:" "$scratch/last.log")" 1
check "the second block's opening line is reported" \
  "$(grep -Fc "$scratch/multiple.md:5: whitefoot block 2 failed:" "$scratch/last.log")" 1
check "both compiler diagnostics are reported" \
  "$([ "$(grep -c 'error\[' "$scratch/last.log")" -ge 2 ] && echo yes || echo no)" yes

# Fence matching ignores indentation and trailing whitespace, including
# CRLF. The enclosed source keeps its canonical LF line endings verbatim.
sed 's/^```whitefoot$/  ```whitefoot  \r/; s/^```$/  ```  \r/' \
  "$fixtures/valid.md" > "$scratch/crlf.md"
check "indented fences with trailing whitespace and CRLF pass" "$(run "$scratch/crlf.md")" 0
check "the CRLF block is checked once" \
  "$(grep -c 'checked 1 whitefoot block(s)' "$scratch/last.log")" 1
sed '$d' "$fixtures/valid.md" > "$scratch/unclosed.md"
check "an unclosed whitefoot fence fails" "$(run "$scratch/unclosed.md")" 1
check "the unclosed fence reports its opening source line" \
  "$(grep -Fc "$scratch/unclosed.md:3: unclosed whitefoot fence" "$scratch/last.log")" 1

[ "$failures" = 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all document checks passed"
