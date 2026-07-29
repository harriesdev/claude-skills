#!/usr/bin/env bash
# Checks that plugin.json's "skills" allowlist matches what's actually on disk,
# and that every SKILL.md's `name:` matches its folder name. Run before pushing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0

declared=$(grep -o '"\./skills/[^"]*"' .claude-plugin/plugin.json | tr -d '"' | sed 's#^\./##' | sort)
actual=$(find skills -name SKILL.md | sed 's#/SKILL.md##' | sort)

if [ "$declared" != "$actual" ]; then
  echo "MISMATCH between plugin.json skills[] and skills/ on disk:"
  diff <(echo "$declared") <(echo "$actual") | sed 's/^/  /'
  fail=1
else
  echo "ok: $(echo "$actual" | wc -l) skills declared and present"
fi

while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  folder=$(basename "$dir")
  name=$(sed -n 's/^name:[[:space:]]*//p' "$dir/SKILL.md" | head -1)
  if [ "$name" != "$folder" ]; then
    echo "MISMATCH: $dir declares name '$name'"
    fail=1
  fi
done <<< "$actual"

[ "$fail" -eq 0 ] && echo "all checks passed"
exit "$fail"
