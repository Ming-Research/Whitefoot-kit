#!/bin/bash
# trial.sh <hroot> <guide> <lang-dir> <rounds>: three independent Haiku
# sessions per set-1 case (<hroot>-s1..s3), each revised from its own CI
# result; attempts go to attempt/, attempt-2/, attempt-3/ on the trial branch.
set -u
S=$(cd "$(dirname "$0")" && pwd); HR=$1 G=$2 L=$3 N=$4; K=$(cd "$S/../../.." && pwd); R=$K/tests/doc-trial/${CASES_DIR:-cases}
cases=$(cd $R && ls -d [0-9][0-9]-* | grep -v '^00-')
for s in 1 2 3; do H=$HR-s$s; [ -e $H ] && { echo "$H exists" >&2; exit 1; }
  for c in $cases; do d=$H/$c; mkdir -p $d/attempt $d/lib; cp $G $d/guide.md; cp $R/$c/task.md $d/; cp -R $L/lib/std $d/lib/std; done; done
for c in $cases; do for a in attempt attempt-2 attempt-3; do rm -rf "${R:?}/${c:?}/$a"; mkdir -p $R/$c/$a; done; done
for round in $(seq 1 $N); do
  prev=$((round-1)); pids=()
  for s in 1 2 3; do H=$HR-s$s
    for c in $cases; do d=$H/$c
      [ "$(cat $d/verdict-$prev 2>/dev/null)" = pass ] && { echo pass > $d/verdict-$round; continue; }
      if [ $round = 1 ]; then cp $S/round1.md $d/prompt-1.md; else {
        echo "Round $prev result from CI:"
        if [ -s $d/diag-$prev.txt ]; then echo "The compiler rejected your program:"; echo '```'; cat $d/diag-$prev.txt; echo '```'
        else echo "It compiled and ran. $(cat $d/run-$prev.txt)"; fi
        echo "Revise the files under ./attempt/ accordingly (read only files in this directory). Reply with one line: DONE."
      } > $d/prompt-$round.md; fi
      bash $S/session.sh $d $round $d/prompt-$round.md & pids+=($!)
    done; done
  wait
  for s in 1 2 3; do a=attempt; [ $s != 1 ] && a=attempt-$s
    for c in $cases; do rm -rf "${R:?}/${c:?}/$a"; mkdir -p $R/$c/$a; cp -R $HR-s$s/$c/attempt/. $R/$c/$a/; done; done
  (cd $K && git add -A && git commit -q --allow-empty -m "Three-session trial round $round attempts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q) || exit 1
  sha=$(git -C $K rev-parse HEAD)
  until id=$(gh run list -R Ming-Research/Whitefoot-kit -w doc-trial -c $sha -L 1 --json databaseId -q '.[0].databaseId') && [ -n "$id" ] && [ "$(gh run view $id -R Ming-Research/Whitefoot-kit --json status -q .status)" = completed ]; do sleep 30; done
  A=$TMPDIR/trial-art-$(basename $HR)-r$round
  [ -e "$A" ] && { echo "artifact dir $A exists" >&2; exit 1; }
  gh run download $id -R Ming-Research/Whitefoot-kit -D $A || { echo "download failed for run $id" >&2; exit 1; }
  [ "$(gh run view $id -R Ming-Research/Whitefoot-kit --json headSha -q .headSha)" = "$sha" ] || { echo "run $id is not for $sha" >&2; exit 1; }
  echo "round $round run $id sha $sha"
  B=$A/doc-trial-results/build/results$([ "${CASES_DIR:-cases}" = cases-set2 ] && echo -set2)
  for s in 1 2 3; do H=$HR-s$s; key=""; [ $s != 1 ] && key="#$s"
    for c in $cases; do d=$H/$c; row=$(grep -F "| $c$key |" $B/summary.md)
      v=$(echo "$row" | awk -F'|' '{gsub(/ /,"",$5); print $5}'); a=$(echo "$row" | awk -F'|' '{gsub(/ /,"",$4); print $4}')
      echo $v > $d/verdict-$round
      sub=$c; [ $s != 1 ] && sub="$c/attempt-$s"
      t=$(ls -d $B/$c/attempt$([ $s != 1 ] && echo "-$s") 2>/dev/null | head -1)
      if [ "$a" = rejected ]; then cp $t/compile.txt $d/diag-$round.txt
      else : > $d/diag-$round.txt; o=$B/$c/original
        { echo "Exit status $(cat $t/status.txt 2>/dev/null) (expected $(cat $o/status.txt 2>/dev/null))."
          echo "Your stdout (hex, first 256 bytes): $(head -c 256 $t/stdout.txt 2>/dev/null | xxd -p | tr -d '\n')"
          [ -s $t/stderr.txt ] && echo "Your stderr: $(head -c 500 $t/stderr.txt)"
          [ -f $t/transcript.txt ] && echo "Driver observations: $(head -c 800 $t/transcript.txt)"
          echo "This does not match the required behavior in task.md."; } > $d/run-$round.txt; fi
      echo "round $round s$s $c: $a $v"
    done; done
done
