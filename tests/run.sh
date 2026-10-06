#!/bin/bash
# Checks whitefoot.mk as a project uses it, in a fresh scratch project under
# build/test/: the pin's parsing and one-line form, pin-ready, the local
# compiler override, the default goal, and the download against local fake
# releases (RELEASES=file://...): its checks of the archive, the manifest and
# their checksums, the reuse of a downloaded compiler, and the rebuild after a
# pin move. With KIT_DOWNLOAD_RELEASE=wf-<12 hex> it also downloads that real
# release, which needs the network. Every check prints PASS or FAIL; the
# script exits 1 when one failed.
set -u
kit=$(cd "$(dirname "$0")/.." && pwd)
# A fresh project per run, so no earlier run's build output is mistaken for
# this one's.
project="$kit/build/test/project-$$-$(date +%s)"
releases="$project/releases"
mkdir -p "$project" "$releases"
failures=0

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) asset=whitefootc-linux-x86_64.tar.gz ;;
  Darwin-arm64) asset=whitefootc-macos-arm64.tar.gz ;;
  *) echo "no Whitefoot release serves this host"; exit 1 ;;
esac

cat > "$project/Makefile" <<EOF
ROOT := \$(patsubst %/,%,\$(dir \$(abspath \$(lastword \$(MAKEFILE_LIST)))))
BUILD := \$(ROOT)/build
include $kit/whitefoot.mk

print:
	@echo "\$(RELEASE)|\$(RELEASE_COMMIT)|\$(RELEASE_DISPATCH)"

out: \$(BUILD)/out

\$(BUILD)/out: \$(PIN) \$(WHITEFOOTC)
	@mkdir -p \$(BUILD) && touch \$@ && echo built
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
local_run() { run RELEASES="file://$releases" "$@"; }

# A fake release: an archive holding an executable whitefootc, the manifest
# and SHA256SUMS over both, as Whitefoot's release workflow publishes them.
release() {
  local tag=$1 commit=$2 dir="$releases/$1"
  mkdir -p "$dir/content"
  printf '#!/bin/sh\necho %s\n' "$tag" > "$dir/content/whitefootc"
  chmod +x "$dir/content/whitefootc"
  # A real release's compiler keeps its build time, older than any pin.
  touch -t 202001010000 "$dir/content/whitefootc"
  tar -czf "$dir/$asset" -C "$dir/content" whitefootc
  printf '{"tag": "%s", "commit": "%s", "spec": "v0.93", "gate_run": "1", "assets": {}}\n' \
    "${3:-$tag}" "$commit" > "$dir/whitefoot-release.json"
  (cd "$dir" && shasum -a 256 "$asset" whitefoot-release.json > SHA256SUMS)
}

# Parsing.
pin 'release = wf-648338c31240\n'
check "main pin parses" "$(make --no-print-directory -C "$project" print)" \
  "wf-648338c31240|648338c31240|gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=648338c31240"
pin 'release = wf-exp-0123456789ab\n'
check "experiment pin parses" "$(make --no-print-directory -C "$project" print)" \
  "wf-exp-0123456789ab|0123456789ab|gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=0123456789ab -f experiment=true"

# The pin's one-line form.
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

# Readiness.
pin 'release = wf-648338c31240\n'
check "pin-ready accepts a main pin" "$(run pin-ready)" 0
pin 'release = wf-exp-0123456789ab\n'
check "pin-ready refuses an experiment pin" "$(run pin-ready)" 2

# The project's first target stays its default goal.
pin 'release = wf-648338c31240\n'
check "the project's first target is the default goal" \
  "$(make --no-print-directory -C "$project")" \
  "wf-648338c31240|648338c31240|gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=648338c31240"

# The local compiler override, on the command line or in the environment.
check "WHITEFOOTC on the command line accepts an executable" "$(local_run compiler WHITEFOOTC=/bin/echo)" 0
check "WHITEFOOTC in the environment accepts an executable" \
  "$(WHITEFOOTC=/bin/echo make --no-print-directory -C "$project" RELEASES="file://$releases" compiler > "$project/last.log" 2>&1; echo $?)" 0
check "the override downloads nothing" "$([ -e "$project/build/whitefoot" ] && echo downloaded || echo none)" none
check "WHITEFOOTC refuses a missing file" "$(local_run compiler WHITEFOOTC=/nonexistent/whitefootc)" 2

# The download, against fake releases.
release wf-aaaaaaaaaaaa aaaaaaaaaaaa0000000000000000000000000000
pin 'release = wf-aaaaaaaaaaaa\n'
check "a release downloads and passes its checks" "$(local_run compiler)" 0
check "the downloaded whitefootc runs" "$("$project/build/whitefoot/wf-aaaaaaaaaaaa/whitefootc")" wf-aaaaaaaaaaaa
mv "$releases/wf-aaaaaaaaaaaa" "$releases/gone"
check "a downloaded compiler is reused without the release" "$(local_run compiler)" 0
check "the reused compiler builds the project" "$(local_run out)$(grep -c built "$project/last.log")" 01
mv "$releases/gone" "$releases/wf-aaaaaaaaaaaa"
check "an unchanged project is not rebuilt" \
  "$(make --no-print-directory -C "$project" RELEASES="file://$releases" -n out | grep -c 'echo built')" 0

release wf-bbbbbbbbbbbb bbbbbbbbbbbb0000000000000000000000000000
# make 3.81 compares whole seconds; date the output before the pin moves.
touch -t 202601010000 "$project/build/out"
pin 'release = wf-bbbbbbbbbbbb\n'
check "a moved pin rebuilds the project" "$(local_run out)$(grep -c built "$project/last.log")" 01

release wf-cccccccccccc cccccccccccc0000000000000000000000000000
printf ' ' >> "$releases/wf-cccccccccccc/whitefoot-release.json"
pin 'release = wf-cccccccccccc\n'
check "a manifest that does not match SHA256SUMS is refused" "$(local_run compiler)" 2

release wf-dddddddddddd dddddddddddd0000000000000000000000000000
printf 'x' >> "$releases/wf-dddddddddddd/$asset"
pin 'release = wf-dddddddddddd\n'
check "an archive that does not match SHA256SUMS is refused" "$(local_run compiler)" 2

release wf-eeeeeeeeeeee eeeeeeeeeeee0000000000000000000000000000 wf-ffffffffffff
pin 'release = wf-eeeeeeeeeeee\n'
check "a manifest naming another release is refused" "$(local_run compiler)" 2

release wf-111111111111 2222222222220000000000000000000000000000
pin 'release = wf-111111111111\n'
check "a manifest naming another commit is refused" "$(local_run compiler)" 2

pin 'release = wf-exp-999999999999\n'
local_run compiler > /dev/null
check "a missing release names its dispatch command" \
  "$(grep -c 'gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=999999999999 -f experiment=true' "$project/last.log")" 1
check "a failed download leaves no compiler" \
  "$([ -e "$project/build/whitefoot/wf-exp-999999999999/whitefootc" ] && echo present || echo absent)" absent

if [ -n "${KIT_DOWNLOAD_RELEASE:-}" ]; then
  pin "release = $KIT_DOWNLOAD_RELEASE\n"
  check "make compiler downloads and checks $KIT_DOWNLOAD_RELEASE" "$(run compiler)" 0
  check "the downloaded whitefootc is executable" \
    "$([ -x "$project/build/whitefoot/$KIT_DOWNLOAD_RELEASE/whitefootc" ] && echo yes || echo no)" yes
fi

[ "$failures" = 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
