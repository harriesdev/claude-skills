#!/usr/bin/env bash
# Checks that plugin.json and marketplace.json match the skills on disk (i.e. that
# scripts/build-marketplace.py has been run), and that every SKILL.md's `name:`
# matches its folder name. Run before pushing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
tmp=$(mktemp -d)
trap 'cp "$tmp"/*.json .claude-plugin/; rm -rf "$tmp"' EXIT
cp .claude-plugin/plugin.json .claude-plugin/marketplace.json "$tmp"/

python3 scripts/build-marketplace.py > /dev/null || exit 1
for f in plugin.json marketplace.json; do
  if ! diff -q "$tmp/$f" ".claude-plugin/$f" > /dev/null; then
    echo "OUT OF DATE: .claude-plugin/$f — run: python3 scripts/build-marketplace.py"
    diff "$tmp/$f" ".claude-plugin/$f" | sed 's/^/  /'
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "ok: manifests match $(find skills -name SKILL.md | wc -l) skills on disk"

while IFS= read -r skill_md; do
  dir=$(dirname "$skill_md")
  name=$(sed -n 's/^name:[[:space:]]*//p' "$skill_md" | head -1)
  if [ "$name" != "$(basename "$dir")" ]; then
    echo "MISMATCH: $dir declares name '$name'"
    fail=1
  fi
done < <(find skills -name SKILL.md | sort)

[ "$fail" -eq 0 ] && echo "all checks passed"
exit "$fail"
