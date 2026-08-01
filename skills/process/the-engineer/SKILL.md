---
name: the-engineer
description: Router from a vague idea to implemented code. Scopes whether the work is a new system or a feature/bug fix on an existing one, pulls in Jira context via MCP when available, sharpens the domain model, produces the right design artifacts, then implements. Use when starting substantial new work and unsure where to begin.
disable-model-invocation: true
---

# The Engineer

This skill is a router, not a workflow to follow line by line — it sequences other
skills and passes their artifacts forward. It doesn't replace them; each phase still
runs its full underlying skill.

Confirm with the user before moving from one phase to the next. Summarize what was
decided, name the artifact it produced, then ask to proceed.

## 1. Researcher

Ask the user first, before running anything: **is this a new system, or a feature /
bug fix on an existing one?**

A system is "new" if there's no existing codebase or `.docs/context/CONTEXT.md` for it
to extend — greenfield, or a service that doesn't share a domain with anything already
in the repo.

### New system

Run `/grill-with-docs` (which itself runs `/grilling` with `/domain-modeling`) to
interview the user and establish `.docs/context/CONTEXT.md` from scratch. Then go to 2a.

### Feature or bug fix

Ask whether this connects to a ticket in Jira and what the ticket number is. 

- **Yes** — use `claude_ai_Atlassian_Rovo` to retrieve the ticket (description, acceptance
  criteria, comments) and use that as the context for the work instead of running the
  grill. Still sharpen `.docs/context/CONTEXT.md`/`CONTEXT-MAP.md` with any terminology
  the ticket introduces, using `domain-modeling` inline rather than a full grill session.
- **No** — run `/grill-with-docs` as above to establish context through interview.

Either way, go to 2b.

## 2. Architect

Branches on the answer from step 1.

### 2a. New system → Architecture

Invoke `architecture-designer`. Give it the glossary and any decisions already made
during the grill so it isn't re-litigating settled terminology.

### 2b. Feature or bug fix → Requirements
Invoke `spec-miner` — map enough of the existing system to know what's already there and where the feature attaches. Skip only if the user confirms they already know the relevant area well and can specify relevant files to look at.

### 2c. Specify Work

Invoke `feature-forge` — turn that, the Jira ticket (if retrieved in step 1), and the
user's goal into a spec at `.docs/specs/{feature}.spec.md`. For a bug fix, this can be a
short spec — reproduction, root cause, and the expected behaviour — rather than a
full EARS workshop.

## 3. Builder

Invoke `fullstack-guardian`, briefed with whichever artifacts came out of step 2:
`.docs/context/CONTEXT.md` plus ADRs for a new system, or `.docs/context/CONTEXT.md`
plus the feature spec for a feature. Let it write its own
`.docs/specs/{feature}_design.md` as usual.

## 4. Reviewer

Invoke `secure-code-guardian`, `security-reviewer` for the security pass and `code-reviewer` before calling it done.