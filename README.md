# claude-skills

Private Claude Code marketplace carrying 29 personal agent skills. The repo root **is**
the plugin — marketplace `claude-skills`, plugin `claude-skills`.

## Install on any computer

```
claude plugin marketplace add harriesdev/claude-skills
claude plugin install claude-skills@claude-skills
```

Restart the Claude Code session afterwards — plugins load at startup.

The repo is private, so the clone uses your normal git credentials. If
`git clone git@github.com:harriesdev/claude-skills.git` works in a plain terminal on that
machine, the marketplace add will too — which means an SSH key registered with GitHub, or
a credential helper holding a token if you switch the remote to HTTPS.

## Update

Push here, then on each machine:

```
claude plugin marketplace update claude-skills
```

Restart the session to pick up changes.

## Remove

```
claude plugin uninstall claude-skills@claude-skills
claude plugin marketplace remove claude-skills
```

## Layout

```
.claude-plugin/
  marketplace.json      marketplace manifest; the plugin's source is "./"
  plugin.json           plugin manifest, including the skills[] allowlist
scripts/verify.sh       checks allowlist vs. disk before you push
skills/
  architecture/         4
  backend/              5
  frontend/             3
  languages/            2
  misc/                 2
  mobile/               2
  process/              4   design-process skills, see process/NOTICE.md
  quality/              7
```

### Why skills[] is explicit

By default a plugin discovers skills at `skills/<name>/SKILL.md` — one level deep. The
category subfolders here are one level deeper than that, so `plugin.json` lists each skill
path explicitly. Two consequences:

- **Adding a skill is two steps**: create `skills/<category>/<name>/SKILL.md`, then add
  `"./skills/<category>/<name>"` to `skills[]` in `plugin.json`. A skill that is on disk
  but missing from the array will not load.
- **The array doubles as a ship/don't-ship switch.** To park a work-in-progress skill,
  leave it in the tree and omit it from the array.

Run `bash scripts/verify.sh` to catch drift between the two.

## Skill requirements

Each skill is a folder containing `SKILL.md` with frontmatter:

```markdown
---
name: my-skill          # must match the folder name
description: What it does and when to use it — this is what Claude matches against.
---

Body, loaded only once the skill is invoked.
```

Optional `tools:` restricts which tools the skill may use. Supporting files (references,
scripts, templates) live beside `SKILL.md` and are referenced by relative path.

## Adding commands and agents

Alongside `skills/`, the plugin root can hold:

```
commands/<name>.md      slash command, invoked as /<name>
agents/<name>.md        subagent definition
.mcp.json               MCP servers this plugin provides
```

These use default discovery, so no manifest entry is needed. In `.mcp.json`, use
`${CLAUDE_PLUGIN_ROOT}` for paths to files inside the plugin so they resolve wherever the
marketplace was cloned.

## Caution

Everything committed here is cloned onto every machine that installs the plugin, and skill
descriptions are read into context automatically. Keep secrets and machine-specific paths
out of it — private visibility is not a substitute.
