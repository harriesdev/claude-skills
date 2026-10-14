#!/usr/bin/env python3
"""Regenerates the skill lists in .claude-plugin/ from what is on disk.

- plugin.json skills[]: every skill, for the all-in-one `all-skills` plugin.
- marketplace.json plugins[]: the `all-skills` bundle first, then one plugin per
  skill so each can be installed on its own.

A skill folder containing a `.wip` file is left out of both. Run after adding,
removing or renaming a skill; scripts/verify.sh fails if this is out of date.
"""
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
PLUGIN_JSON = ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_JSON = ROOT / ".claude-plugin" / "marketplace.json"
BUNDLE = "all-skills"
MAX_DESCRIPTION = 200


def frontmatter(skill_md: Path) -> dict:
    match = re.match(r"^---\n(.*?)\n---", skill_md.read_text(), re.S)
    if not match:
        sys.exit(f"{skill_md}: missing frontmatter")
    return yaml.safe_load(match.group(1))


def short(description: str) -> str:
    text = " ".join(description.split())
    sentence = re.split(r"(?<=\.)\s", text, maxsplit=1)[0]
    if len(sentence) > MAX_DESCRIPTION:
        sentence = sentence[: MAX_DESCRIPTION - 1].rsplit(" ", 1)[0] + "…"
    return sentence


def skills() -> list[dict]:
    found = []
    for skill_md in sorted(ROOT.glob("skills/*/*/SKILL.md")):
        folder = skill_md.parent
        if (folder / ".wip").exists():
            continue
        meta = frontmatter(skill_md)
        found.append(
            {
                "name": meta["name"],
                "path": "./" + folder.relative_to(ROOT).as_posix(),
                "category": folder.parent.name,
                "description": short(meta["description"]),
            }
        )
    return found


def write(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    found = skills()

    plugin = json.loads(PLUGIN_JSON.read_text())
    plugin["skills"] = [skill["path"] for skill in found]
    write(PLUGIN_JSON, plugin)

    marketplace = json.loads(MARKETPLACE_JSON.read_text())
    bundle = next(p for p in marketplace["plugins"] if p["name"] == BUNDLE)
    marketplace["plugins"] = [bundle] + [
        {
            "name": skill["name"],
            "source": skill["path"],
            "description": skill["description"],
            "category": skill["category"],
            "skills": ["./"],
        }
        for skill in found
    ]
    write(MARKETPLACE_JSON, marketplace)

    print(f"{len(found)} skills written to plugin.json and marketplace.json")


if __name__ == "__main__":
    main()
