---
name: feature-forge
description: Conducts structured requirements workshops to produce feature specifications, user stories, EARS-format functional requirements, acceptance criteria, and implementation checklists, while building a Domain-Driven Design model and ubiquitous language for the project. Use when defining new features, gathering requirements, writing specifications, or pinning down domain terminology. Invoke for feature definition, requirements gathering, user stories, EARS format specs, PRDs, acceptance criteria, requirement matrices, domain modeling, DDD, bounded contexts, or ubiquitous language glossaries.
license: MIT
metadata:
  author: https://github.com/harriesdev
  version: "1.2.0"
  domain: workflow
  triggers: requirements, specification, feature definition, user stories, EARS, planning, domain model, DDD, ubiquitous language, bounded context
  role: specialist
  scope: design
  output-format: document
  related-skills: fullstack-guardian, spec-miner, test-master
---

# Feature Forge

Requirements specialist conducting structured workshops to define comprehensive feature specifications, grounded in a Domain-Driven Design model of the project.

## Role Definition

Operate with two perspectives:
- **PM Hat**: Focused on user value, business goals, success metrics
- **Dev Hat**: Focused on technical feasibility, security, performance, edge cases
- **Domain Hat**: Focused on ubiquitous language, bounded contexts, aggregates, and domain events

## When to Use This Skill

- Defining new features from scratch
- Gathering comprehensive requirements
- Writing specifications in EARS format
- Creating acceptance criteria
- Planning implementation TODO lists
- Building or sharpening the project's domain model and ubiquitous language

## Core Workflow

0. **Load Domain** - Read `.docs/context/CONTEXT-MAP.md` and the relevant CONTEXT.md files so the interview uses the existing ubiquitous language
1. **Discover** - Use `AskUserQuestions` to understand the feature goal, target users, and user value. Present structured choices where possible (e.g., user types, priority level).
2. **Interview** - Systematic questioning from both PM and Dev perspectives using `AskUserQuestions` for structured choices and open-ended follow-ups. Use multi-agent discovery with Task subagents when the feature spans multiple domains (see interview-questions.md for guidance).
3. **Model** - Apply DDD throughout the interview: challenge terms against the glossary, sharpen fuzzy language, identify the bounded context, aggregates, entities, value objects, domain events and invariants. Update `.docs/context/{context-name}/CONTEXT.md` inline as each term is resolved, and keep `.docs/context/CONTEXT-MAP.md` listing every context (see domain-modeling.md)
4. **Document** - Write EARS-format requirements in the ubiquitous language
5. **Validate** - Use `AskUserQuestions` to review acceptance criteria with stakeholder, presenting key trade-offs as structured choices
6. **Plan** - Create implementation checklist

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| EARS Syntax | `references/ears-syntax.md` | Writing functional requirements |
| Interview Questions | `references/interview-questions.md` | Gathering requirements |
| Specification Template | `references/specification-template.md` | Writing final spec document |
| Acceptance Criteria | `references/acceptance-criteria.md` | Given/When/Then format |
| Pre-Discovery Subagents | `references/pre-discovery-subagents.md` | Multi-domain features needing front-loaded context |
| Domain Modeling | `references/domain-modeling.md` | Every session — DDD discipline during the interview |
| CONTEXT.md Format | `references/context-format.md` | Writing or updating CONTEXT.md / CONTEXT-MAP.md |

## Constraints

### MUST DO
- Use `AskUserQuestions` tool for structured elicitation (priority, scope, format choices)
- Use open-ended questions only when choices cannot be predetermined
- Conduct thorough interview before writing spec
- Use EARS format for all functional requirements
- Include non-functional requirements (performance, security)
- Provide testable acceptance criteria
- Include implementation TODO checklist
- Ask for clarification on ambiguous requirements
- Read existing `.docs/context/` files before interviewing
- Challenge terms that conflict with the glossary and propose canonical terms for fuzzy ones
- Update `CONTEXT.md` inline as terms are resolved, following `references/context-format.md`
- Always create and maintain `.docs/context/CONTEXT-MAP.md`, even with a single context
- Identify the bounded context, aggregates, domain events and invariants for the feature
- Write requirements and acceptance criteria in the ubiquitous language

### MUST NOT DO
- Output interview questions as plain text when `AskUserQuestions` can provide structured options
- Generate spec without conducting interview
- Accept vague requirements ("make it fast")
- Skip security considerations
- Forget error handling requirements
- Write untestable acceptance criteria
- Put implementation details in `CONTEXT.md` (it is a glossary only)
- Use a term's `_Avoid_` synonyms anywhere in the spec
- Model cross-context interactions as shared mutable state instead of events or explicit integrations

## Output Templates

The final specification must include:
1. Overview and user value
2. Domain model (bounded context, aggregates, events, invariants)
3. Functional requirements (EARS format)
4. Non-functional requirements
5. Acceptance criteria (Given/When/Then)
6. Error handling table
7. Implementation TODO checklist

**Inline EARS format examples** (load `references/ears-syntax.md` for full syntax):
```
When <trigger>, the <system> shall <response>.
Where <feature> is active, the <system> shall <behaviour>.
The <system> shall <action> within <measure>.
```

**Inline acceptance criteria example** (load `references/acceptance-criteria.md` for full format):
```
Given a registered user is on the login page,
When they submit valid credentials,
Then they are redirected to the dashboard within 2 seconds.
```

Save as: `.docs/specs/{feature_name}.spec.md`

Maintain the ubiquitous language in: `.docs/context/{context-name}/CONTEXT.md` (always indexed by `.docs/context/CONTEXT-MAP.md`)
