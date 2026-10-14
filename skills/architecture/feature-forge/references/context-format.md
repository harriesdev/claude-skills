# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.

## File Structure

Each bounded context lives in its own folder named after the context (kebab-case):

```
/
├── .docs/
│   ├── context/
│   │   ├── CONTEXT-MAP.md          ← always present, lists every context
│   │   ├── ordering/
│   │   │   └── CONTEXT.md
│   │   └── billing/
│   │       └── CONTEXT.md
│   └── specs/
│       └── {feature_name}.spec.md
└── src/
```

`.docs/context/CONTEXT-MAP.md` is **always** created, even when there is only one context. It is the single entry point: it lists every context, where it lives, and how the contexts relate. With one context the Relationships section can read `- None yet (single context)`. When a later feature introduces a new context, it adds a line to the existing map and creates the new `{context-name}/CONTEXT.md` beside it.

Single-context example:

```md
# Context Map

## Contexts

- [Ordering](./ordering/CONTEXT.md) — receives and tracks customer orders

## Relationships

- None yet (single context)
```

Multi-context example:

```md
# Context Map

## Contexts

- [Ordering](./ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

How to proceed:

- If `.docs/context/CONTEXT-MAP.md` exists, read it to find the contexts
- If it doesn't exist, create it together with the first `.docs/context/{context-name}/CONTEXT.md` when the first term is resolved
- If a `{context-name}/CONTEXT.md` exists without a map (legacy repo), create `CONTEXT-MAP.md` pointing to it
- When a feature introduces a new context, add it to `CONTEXT-MAP.md` (Contexts and Relationships) and create its `CONTEXT.md`

Create files lazily — only when you have something to write, but never create a `CONTEXT.md` without its entry in `CONTEXT-MAP.md`. When multiple contexts exist, infer which one the current topic relates to. If unclear, ask.
