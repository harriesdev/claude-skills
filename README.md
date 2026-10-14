# claude-skills

Private Claude Code marketplace carrying personal agent skills. Install them all as one
plugin, or any skill on its own — every skill is also its own plugin.

## Install on any computer

Add the marketplace once:

```
claude plugin marketplace add harriesdev/claude-skills
```

Then install everything:

```
claude plugin install all-skills@claude-skills
```

or only the skills you want, by skill name:

```
claude plugin install nestjs-expert@claude-skills
claude plugin install feature-forge@claude-skills
```

`/plugin` inside a session lists them all. Don't install `all-skills` alongside individual
skills — you'd get each of those skills twice. Restart the Claude Code session afterwards;
plugins load at startup.

The repo is private, so the clone uses your normal git credentials. If
`git clone git@github.com:harriesdev/claude-skills.git` works in a plain terminal on that
machine, the marketplace add will too — which means an SSH key registered with GitHub, or
a credential helper holding a token if you switch the remote to HTTPS.

The bundle used to be called `claude-skills@claude-skills`. That name is reserved for
Anthropic, so it is now `all-skills`; the marketplace's `renames` entry moves existing
installs over on the next update.

## Update

Push here, then on each machine:

```
claude plugin marketplace update claude-skills
```

Restart the session to pick up changes.

## Remove

```
claude plugin uninstall all-skills@claude-skills      # or <skill-name>@claude-skills
claude plugin marketplace remove claude-skills
```

## Layout

```
.claude-plugin/
  marketplace.json      the all-skills bundle, then one plugin entry per skill (generated)
  plugin.json           the all-skills plugin manifest, including skills[] (generated)
scripts/
  build-marketplace.py  regenerates both skill lists from skills/ on disk
  verify.sh             fails if the manifests are stale or a name doesn't match its folder
skills/
  architecture/
  backend/
  frontend/
  languages/
  mobile/
  quality/
  review/
```

### How the manifests are built

A plugin discovers skills at `skills/<name>/SKILL.md` by default — one level deep. The
category folders here are one level deeper, so both lists are explicit:

- `plugin.json` `skills[]` lists every skill path, for the `all-skills` bundle (source `./`).
- Each per-skill entry in `marketplace.json` uses the skill's own folder as its source,
  with `"skills": ["./"]`, so installing it copies only that skill.

Both are generated, so **adding a skill** is: create `skills/<category>/<name>/SKILL.md`,
run `python3 scripts/build-marketplace.py`, commit. The per-skill description is the first
sentence of the skill's `description`, and its category is the folder it sits in.

To **park a work-in-progress skill**, put an empty `.wip` file in its folder; the generator
leaves it out of both lists.

Run `bash scripts/verify.sh` before pushing, and `claude plugin validate .` to check the
manifests against Claude Code itself.

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
