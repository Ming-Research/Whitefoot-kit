#!/bin/bash
# Checks whitefoot.mk as a project uses it, in a fresh scratch project under
# build/test/: the pin's parsing and one-line form, pin-ready, the WHITEFOOTC
# override, the default goal, and the download against local fake
# releases (RELEASES=file://...): its checks of the archive, the manifest and
# their checksums, the optional language package and failed-download cleanup,
# the reuse of a downloaded compiler, and the rebuild after a pin move.
# With KIT_DOWNLOAD_RELEASE=wf-<12 hex> it also downloads that real
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

print-language:
	@printf '%s\\n' "\$\$WHITEFOOT_LANGUAGE"

out: \$(BUILD)/out

\$(BUILD)/out: \$(PIN) \$(WHITEFOOTC)
	@mkdir -p \$(BUILD) && touch \$@ && echo built

# Depends on the compiler alone, to see that a fresh download is newer than
# what was built before it.
compiled: \$(BUILD)/compiled

\$(BUILD)/compiled: \$(WHITEFOOTC)
	@mkdir -p \$(BUILD) && touch \$@ && echo compiled
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
# The optional fifth argument names a language archive with repository paths.
release() {
  local tag=$1 commit=$2 llvm=${4:-} language=${5:-} dir="$releases/$1" assets='{}'
  mkdir -p "$dir/content"
  printf '#!/bin/sh\necho %s\n' "$tag" > "$dir/content/whitefootc"
  chmod +x "$dir/content/whitefootc"
  # A real release's compiler keeps its build time, older than any pin.
  touch -t 202001010000 "$dir/content/whitefootc"
  tar -czf "$dir/$asset" -C "$dir/content" whitefootc
  case "$llvm" in
    '') ;;
    null) llvm='"linux_llvm_major": null, ' ;;
    *) llvm="\"linux_llvm_major\": \"$llvm\", " ;;
  esac
  if [ -n "$language" ]; then
    mkdir -p "$dir/language/spec" "$dir/language/lib/std/io" "$dir/language/lib/std/collections/vector"
    printf 'spec %s\n' "$tag" > "$dir/language/spec/kernel-spec.md"
    printf 'modules %s\n' "$tag" > "$dir/language/lib/std/modules.wfg"
    printf 'io %s\n' "$tag" > "$dir/language/lib/std/io/module.wfm"
    printf 'vector %s\n' "$tag" > "$dir/language/lib/std/collections/vector/module.wfm"
    tar -czf "$dir/$language" -C "$dir/language" spec lib
    assets="{\"language\": \"$language\"}"
  fi
  printf '{"tag": "%s", "commit": "%s", "spec": "v0.93", "gate_run": "1", %s"assets": %s}\n' \
    "${3:-$tag}" "$commit" "$llvm" "$assets" > "$dir/whitefoot-release.json"
  (cd "$dir" && shasum -a 256 "$asset" whitefoot-release.json > SHA256SUMS)
  if [ -n "$language" ]; then
    (cd "$dir" && shasum -a 256 "$language" >> SHA256SUMS)
  fi
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

# The WHITEFOOTC override, on the command line or in the environment.
check "WHITEFOOTC on the command line accepts an executable" "$(local_run compiler WHITEFOOTC=/bin/echo)" 0
check "WHITEFOOTC in the environment accepts an executable" \
  "$(WHITEFOOTC=/bin/echo make --no-print-directory -C "$project" RELEASES="file://$releases" compiler > "$project/last.log" 2>&1; echo $?)" 0
check "the override downloads nothing" "$([ -e "$project/build/whitefoot" ] && echo downloaded || echo none)" none
check "WHITEFOOTC refuses a missing file" "$(local_run compiler WHITEFOOTC=/nonexistent/whitefootc)" 2

# The download, against fake releases.
release wf-aaaaaaaaaaaa aaaaaaaaaaaa0000000000000000000000000000
pin 'release = wf-aaaaaaaaaaaa\n'
check "a release downloads and passes its checks" "$(local_run compiler)" 0
check "a legacy release prints one note with the command at its commit" \
  "$(grep -F -c "wf-aaaaaaaaaaaa carries no language package; read the language at its commit with: gh api 'repos/Ming-Research/Whitefoot/contents/spec/kernel-spec.md?ref=aaaaaaaaaaaa0000000000000000000000000000' -H 'Accept: application/vnd.github.raw'" "$project/last.log")" 1
check "a legacy release creates no language directory" \
  "$([ -d "$project/build/whitefoot/wf-aaaaaaaaaaaa/language" ] && echo present || echo absent)" absent
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

release wf-121212121212 1212121212120000000000000000000000000000
pin 'release = wf-121212121212\n'
mkdir -p "$project/build"
touch -t 202101010000 "$project/build/compiled"
local_run compiler > /dev/null
check "an output older than the download, newer than its archive, is rebuilt" \
  "$(local_run compiled)$(grep -c '^compiled' "$project/last.log")" 01

release wf-131313131313 1313131313130000000000000000000000000000
(cd "$releases/wf-131313131313" && shasum -a 256 "$asset" "$asset" > SHA256SUMS)
printf ' ' >> "$releases/wf-131313131313/whitefoot-release.json"
pin 'release = wf-131313131313\n'
check "SHA256SUMS listing the archive twice and no manifest is refused" "$(local_run compiler)" 2

release wf-141414141414 1414141414140000000000000000000000000000
(cd "$releases/wf-141414141414" && shasum -a 256 whitefoot-release.json whitefoot-release.json > SHA256SUMS)
printf 'x' >> "$releases/wf-141414141414/$asset"
pin 'release = wf-141414141414\n'
check "SHA256SUMS listing the manifest twice and no archive is refused" "$(local_run compiler)" 2

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

# Language assets use the verified manifest's name and repository-relative paths.
language_asset=whitefoot-language.tar.gz
release wf-181818181818 1818181818180000000000000000000000000000 "" "" "$language_asset"
pin 'release = wf-181818181818\n'
check "a release with a language package downloads and passes its checks" "$(local_run compiler)" 0
language_dir="$project/build/whitefoot/wf-181818181818/language"
check "the language package unpacks the specification" "$(cat "$language_dir/spec/kernel-spec.md")" "spec wf-181818181818"
check "the language package unpacks the standard-library module graph" "$(cat "$language_dir/lib/std/modules.wfg")" "modules wf-181818181818"
check "the language package unpacks a standard-library interface" "$(cat "$language_dir/lib/std/io/module.wfm")" "io wf-181818181818"
check "the language package preserves nested interface paths" "$(cat "$language_dir/lib/std/collections/vector/module.wfm")" "vector wf-181818181818"
check "WHITEFOOT_LANGUAGE exports the language directory to recipes" \
  "$(make --no-print-directory -C "$project" print-language)" "$language_dir"

release wf-252525252525 2525252525250000000000000000000000000000 "" "" language-custom.tar.gz
pin 'release = wf-252525252525\n'
check "the language asset name comes from the manifest" "$(local_run compiler)" 0
check "an asset with another name unpacks the same repository paths" \
  "$(cat "$project/build/whitefoot/wf-252525252525/language/spec/kernel-spec.md")" "spec wf-252525252525"

language_absent() {
  check "$1 leaves no installed language directory" \
    "$([ -e "$project/build/whitefoot/$2/language" ] && echo present || echo absent)" absent
  check "$1 removes its staging directory" \
    "$([ -e "$project/build/whitefoot/$2.part" ] && echo present || echo absent)" absent
  check "$1 leaves no installed compiler" \
    "$([ -e "$project/build/whitefoot/$2/whitefootc" ] && echo present || echo absent)" absent
}

release wf-191919191919 1919191919190000000000000000000000000000 "" "" "$language_asset"
printf 'x' >> "$releases/wf-191919191919/$language_asset"
pin 'release = wf-191919191919\n'
check "a language archive that does not match SHA256SUMS is refused" "$(local_run compiler)" 2
check "a language checksum mismatch fails for the language checksum" \
  "$(grep -c 'language package does not match its SHA256SUMS' "$project/last.log")" 1
language_absent "a language checksum mismatch" wf-191919191919

release wf-202020202020 2020202020200000000000000000000000000000 "" "" "$language_asset"
(cd "$releases/wf-202020202020" && shasum -a 256 "$asset" whitefoot-release.json > SHA256SUMS)
pin 'release = wf-202020202020\n'
check "a manifest naming a language archive missing from SHA256SUMS is refused" "$(local_run compiler)" 2
check "a missing language checksum fails for the missing entry" \
  "$(grep -c "exactly one entry for $language_asset is required" "$project/last.log")" 1
language_absent "a missing language checksum" wf-202020202020

release wf-212121212121 2121212121210000000000000000000000000000 "" "" "$language_asset"
(cd "$releases/wf-212121212121" && shasum -a 256 "$language_asset" >> SHA256SUMS)
pin 'release = wf-212121212121\n'
check "a language archive listed twice in SHA256SUMS is refused" "$(local_run compiler)" 2
check "duplicate language checksums fail for the duplicate entry" \
  "$(grep -c "exactly one entry for $language_asset is required" "$project/last.log")" 1
language_absent "duplicate language checksums" wf-212121212121

release wf-232323232323 2323232323230000000000000000000000000000 "" "" "$language_asset"
rm "$releases/wf-232323232323/$language_asset"
pin 'release = wf-232323232323\n'
check "a missing language archive fails its download" "$(local_run compiler)" 2
check "a missing language archive fails for the language download" \
  "$(grep -c "cannot download $language_asset" "$project/last.log")" 1
language_absent "a failed language download" wf-232323232323

release wf-242424242424 2424242424240000000000000000000000000000 "" "" "$language_asset"
printf 'not a gzip archive\n' > "$releases/wf-242424242424/$language_asset"
(cd "$releases/wf-242424242424" && shasum -a 256 "$asset" whitefoot-release.json "$language_asset" > SHA256SUMS)
pin 'release = wf-242424242424\n'
check "a verified language archive that cannot be unpacked is refused" "$(local_run compiler)" 2
check "an invalid language archive reaches extraction after checksum verification" \
  "$(grep -F -c "$language_asset: OK" "$project/last.log")" 1
language_absent "a failed language extraction" wf-242424242424

# The toolchain check: a stand-in clang reports one LLVM major.
fake_clang() { printf '#!/bin/sh\necho %s\n' "$1" > "$project/clang"; chmod +x "$project/clang"; }
release wf-151515151515 1515151515150000000000000000000000000000
pin 'release = wf-151515151515\n'
fake_clang 18.1.3
check "a release that names no LLVM accepts any clang" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 0
release wf-161616161616 1616161616160000000000000000000000000000 "" 22
pin 'release = wf-161616161616\n'
fake_clang 22.1.8
check "a release's LLVM major is accepted" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 0
fake_clang 18.1.3
if [ "$asset" = whitefootc-linux-x86_64.tar.gz ]; then
  check "another LLVM major is refused on Linux" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 2
  check "the refusal names make toolchain" "$(grep -c 'install LLVM 22 with: make toolchain' "$project/last.log")" 1
else
  check "the LLVM major is not checked on macOS" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 0
fi
release wf-171717171717 1717171717170000000000000000000000000000 "" null
pin 'release = wf-171717171717\n'
check "a manifest whose LLVM major is null accepts any clang" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 0
pin 'release = wf-161616161616\n'
rm "$project/build/whitefoot/wf-161616161616/whitefoot-release.json"
if [ "$asset" = whitefootc-linux-x86_64.tar.gz ]; then
  check "an unreadable manifest fails the check on Linux" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 2
  check "the failure names the manifest" "$(grep -c 'cannot read the LLVM major' "$project/last.log")" 1
else
  check "an unreadable manifest is not read on macOS" "$(local_run toolchain-check HOST_CLANG="$project/clang")" 0
fi
check "a WHITEFOOTC override skips the toolchain check" \
  "$(local_run toolchain-check WHITEFOOTC=/bin/echo HOST_CLANG="$project/clang")" 0
check "make compiler itself does not check the toolchain" "$(local_run compiler HOST_CLANG="$project/clang")" 0

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
  manifest="$project/build/whitefoot/$KIT_DOWNLOAD_RELEASE/whitefoot-release.json"
  language=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("assets", {}).get("language") or "")' "$manifest")
  check "the real release manifest can be read for its language asset" "$?" 0
  if [ -n "$language" ]; then
    check "the real release's language package contains its specification" \
      "$([ -f "$project/build/whitefoot/$KIT_DOWNLOAD_RELEASE/language/spec/kernel-spec.md" ] && echo yes || echo no)" yes
  fi
fi

[ "$failures" = 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
