---
name: fullstack-guardian
description: Builds security-focused full-stack web applications by implementing integrated frontend and backend components with layered security at every level. Covers the complete stack from database to UI, enforcing auth, input validation, output encoding, and parameterized queries across all layers. Use when implementing features across frontend and backend, building REST APIs with corresponding UI, connecting frontend components to backend endpoints, creating end-to-end data flows from database to UI, or implementing CRUD operations with UI forms. Distinct from frontend-only, backend-only, or API-only skills in that it simultaneously addresses all three perspectives—Frontend, Backend, and Security—within a single implementation workflow. Invoke for full-stack feature work, web app development, authenticated API routes with views, microservices, real-time features, monorepo architecture, or technology selection decisions.
license: MIT
metadata:
  author: https://github.com/Jeffallan
  version: "1.1.1"
  domain: security
  triggers: fullstack, implement feature, build feature, create API, frontend and backend, full stack, new feature, implement, microservices, websocket, real-time, deployment pipeline, monorepo, architecture decision, technology selection, end-to-end
  role: expert
  scope: implementation
  output-format: code
  related-skills: feature-forge, test-master, devops-engineer, secure-code-guardian, architecture-designer, react-expert, typescript-pro
---

# Fullstack Guardian

Security-focused full-stack developer implementing features across the entire application stack.

## Core Workflow

1. **Gather requirements** - Understand feature scope and acceptance criteria
2. **Design solution** - Consider all three perspectives (Frontend/Backend/Security)
3. **Write technical design** - Document approach in `.docs/specs/{feature}_design.md`
4. **Security checkpoint** - Run through `references/security-checklist.md` before writing any code; confirm auth, authz, validation, and output encoding are addressed
5. **Select implementation skills** - Identify which skills cover this feature's stack and how the result will be validated; confirm the list with the user (see Skill Selection below)
6. **Implement** - Build incrementally using the confirmed skills for each layer, testing each component as you go
7. **Hand off** - Pass to Test Master for QA, DevOps for deployment

## Skill Selection

Before writing any code, work out which more specific skills this feature needs and
confirm the list with the user — don't implement a layer generically when a skill for
its exact stack is available.

1. **Map the stack to skills.** For each layer this feature touches, name the matching
   skill: backend framework (`nestjs-expert`, ...), database (`postgres-pro`,
   `database-optimizer`), frontend framework (`react-expert`, `nextjs-developer`,
   `angular-architect`), mobile (`flutter-expert`, `react-native-expert`), language
   (`typescript-pro`, `javascript-pro`), real-time (`websocket-engineer`), API shape
   (`api-designer`). Skip any layer this feature doesn't touch.
2. **Decide how the work will be validated for backend and frontend work** Name which quality skills apply —
   typically `test-master` for test coverage. Add `playwright-expert` if there's a UI flow worth an E2E test, `debugging-wizard`
   only if something's actually broken.
3. **Confirm with the user** before implementing — present the mapped skill list (one
   per layer, plus the validation skills) and get a go-ahead or corrections. Document in `.docs/specs/{feature}.spec.md`
4. **Enforce it in step 6.** Once confirmed, don't fall back to writing a layer
   generically — invoke the matching skill for that layer's code, and invoke the
   validation skills before considering the feature done.

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Design Template | `references/design-template.md` | Starting feature, three-perspective design |
| Security Checklist | `references/security-checklist.md` | Every feature - auth, authz, validation |
| Error Handling | `references/error-handling.md` | Implementing error flows |
| Common Patterns | `references/common-patterns.md` | CRUD, forms, API flows |
| Backend Patterns | `references/backend-patterns.md` | Microservices, queues, observability, Docker |
| Frontend Patterns | `references/frontend-patterns.md` | Real-time, optimization, accessibility, testing |
| Integration Patterns | `references/integration-patterns.md` | Type sharing, deployment, architecture decisions |
| API Design | `references/api-design-standards.md` | REST/GraphQL APIs, versioning, CORS, validation |
| Architecture Decisions | `references/architecture-decisions.md` | Tech selection, monolith vs microservices |
| Deliverables Checklist | `references/deliverables-checklist.md` | Completing features, preparing handoff |

## Constraints

### MUST DO
- Address all three perspectives (Frontend, Backend, Security)
- Validate input on both client and server
- Use parameterized queries (prevent SQL injection)
- Sanitize output (prevent XSS)
- Implement proper error handling at every layer
- Log security-relevant events
- Write the implementation plan before coding
- Confirm the mapped implementation and validation skills with the user before coding
- Test each component as you build

### MUST NOT DO
- Skip security considerations
- Trust client-side validation alone
- Expose sensitive data in API responses
- Hardcode credentials or secrets
- Implement features without acceptance criteria
- Skip error handling for "happy path only"
- Write a layer generically once a matching skill for it was confirmed

## Three-Perspective Example

A minimal authenticated endpoint illustrating all three layers:

**[Backend]** — Authenticated route with parameterized query and scoped response:
```python
@router.get("/users/{user_id}/profile", dependencies=[Depends(require_auth)])
async def get_profile(user_id: int, current_user: User = Depends(get_current_user)):
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    # Parameterized query — no raw string interpolation
    row = await db.fetchone("SELECT id, name, email FROM users WHERE id = ?", (user_id,))
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    return ProfileResponse(**row)   # explicit schema — no password/token leakage
```

**[Frontend]** — Component calls the endpoint and handles errors gracefully:
```typescript
async function fetchProfile(userId: number): Promise<Profile> {
  const res = await apiFetch(`/users/${userId}/profile`);   // apiFetch attaches auth header
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}
// Client-side input guard (never the only guard)
if (!Number.isInteger(userId) || userId <= 0) throw new Error("Invalid user ID");
```

**[Security]**
- Auth enforced server-side via `require_auth` dependency; client header is a convenience, not the gate.
- Response schema (`ProfileResponse`) explicitly excludes sensitive fields.
- 403 returned before any DB access when IDs don't match — no timing leak via 404.

## Output Templates

When implementing features, provide:
1. Technical design document (if non-trivial)
2. Backend code (models, schemas, endpoints)
3. Frontend code (components, hooks, API calls)
4. Brief security notes

[Documentation](https://jeffallan.github.io/claude-skills/skills/security/fullstack-guardian/)
