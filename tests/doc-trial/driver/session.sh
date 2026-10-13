#!/bin/bash
# session.sh <workdir> <round> <prompt-file>
# Runs one clean Haiku turn in <workdir> (which holds guide.md, task.md and
# writes main.wf). Round 1 starts a session; later rounds resume the session
# id saved in <workdir>/session. Logs every tool call as stream-json so reads
# outside <workdir> can be audited.
set -u
dir=$1 round=$2 prompt=$3
cd "$dir"
resume=()
[ "$round" != 1 ] && resume=(--resume "$(cat session)")
claude -p --model haiku --restricted --tools "Read,Write,Edit,Glob" --strict-mcp-config \
  --permission-mode acceptEdits --output-format stream-json --verbose \
  ${resume[@]+"${resume[@]}"} < "$prompt" > "log-$round.jsonl" 2> "err-$round.txt"
python3 -I -c '
import json,sys
sid=None
for l in open(sys.argv[1]):
    try: e=json.loads(l)
    except Exception: continue
    sid=e.get("session_id") or sid
print(sid or "")' "log-$round.jsonl" > session
# audit: every Read/Write/Edit path
python3 -I -c '
import json,sys,os
d=os.path.realpath(sys.argv[2]); bad=[]
for l in open(sys.argv[1]):
    try: e=json.loads(l)
    except Exception: continue
    m=e.get("message") or {}
    for c in (m.get("content") or []) if isinstance(m,dict) else []:
        if isinstance(c,dict) and c.get("type")=="tool_use":
            p=(c.get("input") or {}).get("file_path","")
            rp=os.path.realpath(os.path.join(d,p))
            if not rp.startswith(d): bad.append(c["name"]+" "+p)
print("\n".join(bad))' "log-$round.jsonl" "$dir" > "outside-$round.txt"
