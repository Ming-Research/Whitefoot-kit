#!/bin/bash
# Checks whitefoot.mk as a project uses it, in a scratch project under
# build/test/: the pin's parsing, its one-line form, pin-ready, the local
# compiler override and the rebuild after a pin move. With
# KIT_DOWNLOAD_RELEASE=wf-<12 hex> it also downloads that real release and
# checks it, which needs the network. Every check prints PASS or FAIL; the
# script exits 1 when one failed.
set -u
kit=$(cd "$(dirname "$0")/.." && pwd)
# A fresh project per run, so no earlier run's build output is mistaken for
# this one's.
project="$kit/build/test/project-$$-$(date +%s)"
mkdir -p "$project"
failures=0

cat > "$project/Makefile" <<EOF
ROOT := \$(patsubst %/,%,\$(dir \$(abspath \$(lastword \$(MAKEFILE_LIST)))))
BUILD := \$(ROOT)/build
include $kit/whitefoot.mk

print:
	@echo "\$(RELEASE)|\$(RELEASE_COMMIT)|\$(RELEASE_DISPATCH)"

out: \$(BUILD)/out

\$(BUILD)/out: \$(PIN) \$(WHITEFOOTC)
	@mkdir -p \$(BUILD) && touch \$@
EOF

check() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1: expected [$3], got [$2]"
    failures=$((failures + 1))
  fi
}

pin() { printf "$1" > "$project/whitefoot.pin"; }
run() { make --no-print-directory -C "$project" "$@" > "$project/last.log" 2>&1; echo $?; }

pin 'release = wf-648338c31240\n'
check "main pin parses" "$(make --no-print-directory -C "$project" print)" \
  "wf-648338c31240|648338c31240|gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=648338c31240"
pin 'release = wf-exp-0123456789ab\n'
check "experiment pin parses" "$(make --no-print-directory -C "$project" print)" \
  "wf-exp-0123456789ab|0123456789ab|gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=0123456789ab -f experiment=true"

for case in \
  'accept|release = wf-648338c31240\n' \
  'accept|release = wf-exp-0123456789ab\n' \
  'accept|release = wf-648338c31240' \
  'reject|garbage\nrelease = wf-648338c31240\n' \
  'reject|release = wf-648338c31240\nrelease = wf-364f86c2fd16\n' \
  'reject|release = wf-648338c3124\n' \
  'reject|release = 648338c31240\n' \
  'reject|release = wf-648338C31240\n' \
  'reject|'; do
  want=${case%%|*}
  pin "${case#*|}"
  status=$(run pin-check)
  got=$([ "$status" = 0 ] && echo accept || echo reject)
  check "pin-check $want [$(printf "${case#*|}" | tr '\n' '/')]" "$got" "$want"
done

pin 'release = wf-648338c31240\n'
check "pin-ready accepts a main pin" "$(run pin-ready)" 0
pin 'release = wf-exp-0123456789ab\n'
check "pin-ready refuses an experiment pin" "$(run pin-ready)" 2

pin 'release = wf-648338c31240\n'
check "WHITEFOOTC override accepts an executable" "$(run compiler WHITEFOOTC=/bin/echo)" 0
check "WHITEFOOTC override downloads nothing" "$([ -e "$project/build/whitefoot" ] && echo downloaded || echo none)" none
check "WHITEFOOTC override refuses a missing file" "$(run compiler WHITEFOOTC=/nonexistent/whitefootc)" 2

# A downloaded compiler keeps its archive's timestamp; an output built
# before the pin moved must still be rebuilt.
mkdir -p "$project/build/whitefoot/wf-648338c31240"
printf '#!/bin/sh\n' > "$project/build/whitefoot/wf-648338c31240/whitefootc"
chmod +x "$project/build/whitefoot/wf-648338c31240/whitefootc"
touch -t 202601010000 "$project/build/whitefoot/wf-648338c31240/whitefootc"
touch -t 202602010000 "$project/build/out"
touch -t 202603010000 "$project/whitefoot.pin"
make --no-print-directory -C "$project" -q -o "$project/build/whitefoot/wf-648338c31240/whitefootc" out
check "an output older than the pin is rebuilt" "$?" 1
touch -t 202604010000 "$project/build/out"
make --no-print-directory -C "$project" -q -o "$project/build/whitefoot/wf-648338c31240/whitefootc" out
check "an output newer than the pin is kept" "$?" 0

if [ -n "${KIT_DOWNLOAD_RELEASE:-}" ]; then
  pin "release = $KIT_DOWNLOAD_RELEASE\n"
  check "make compiler downloads and checks $KIT_DOWNLOAD_RELEASE" "$(run compiler)" 0
  check "the downloaded whitefootc is executable" \
    "$([ -x "$project/build/whitefoot/$KIT_DOWNLOAD_RELEASE/whitefootc" ] && echo yes || echo no)" yes
fi

[ "$failures" = 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
