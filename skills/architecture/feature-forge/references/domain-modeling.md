# Domain Modeling

Every feature is designed through a Domain-Driven Design (DDD) lens. While you gather requirements, actively build and sharpen the project's domain model: challenge terms, invent edge-case scenarios, and write the glossary down the moment terms crystallise.

Two outputs come from this work:

| Output | Location | Contains |
|--------|----------|----------|
| Ubiquitous language | `.docs/context/{context-name}/CONTEXT.md` | Glossary of domain terms only (see `references/context-format.md`) |
| Domain model for the feature | `## Domain Model` section of the spec | Bounded context, aggregates, entities, value objects, domain events, invariants |

## Before the Interview

1. Read `.docs/context/CONTEXT-MAP.md` to find the bounded contexts and their relationships.
   - No map → you'll create `CONTEXT-MAP.md` and the first `{context-name}/CONTEXT.md` together when the first term is resolved.
   - A `CONTEXT.md` exists without a map → create the map pointing to it.
2. Read the `CONTEXT.md` of every context the feature touches. Use its terms in all questions, requirements and acceptance criteria.
3. If it is unclear which bounded context the feature belongs to, ask with `AskUserQuestions` (list the existing contexts plus "New context").

## During the Interview

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately: "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term: "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Push DDD building blocks

Steer the conversation toward the tactical patterns. For each key concept, establish which it is:

| Building block | Question to ask |
|----------------|-----------------|
| **Bounded context** | Which part of the business owns this language? Does the term mean something different elsewhere? |
| **Aggregate** | What must change together in one consistent transaction? What is the root everything is accessed through? |
| **Entity** | Does this have an identity that persists while its attributes change? |
| **Value object** | Is this defined only by its attributes, immutable and replaceable? |
| **Domain event** | What happened in the past tense that other parts of the system care about? (`OrderPlaced`, `InvoiceIssued`) |
| **Invariant** | What rule must always hold true inside the aggregate? |
| **Domain service** | Is there behaviour that doesn't naturally belong to a single entity or value object? |

Prefer rich domain behaviour (`order.cancel()`) over anaemic data structures manipulated by services. When a requirement crosses bounded contexts, model the interaction as a domain event or an explicit integration rather than shared mutable state.

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in `references/context-format.md`.

`CONTEXT.md` must be totally devoid of implementation details. It is not a spec, a scratch pad, or a place for implementation decisions. It is a glossary and nothing else. Aggregates, events and invariants for the feature go in the spec's `## Domain Model` section.

### Document relationships

`.docs/context/CONTEXT-MAP.md` always exists, even with a single context, so every new context is just another entry. When a feature introduces a new bounded context, add it to the map and record how it relates to the others (events, shared kernel, customer/supplier, anti-corruption layer).

## In the Spec

Write requirements in the ubiquitous language: EARS statements and Given/When/Then criteria use the exact terms from `CONTEXT.md`, never their `_Avoid_` synonyms. Fill in the `## Domain Model` section of the spec template.
