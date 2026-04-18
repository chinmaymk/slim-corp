```markdown
---
role: cto
directive: {slug}
---

# Technical Strategy: {Directive Title}

**Approach**: {1-2 sentences — core architectural decision}
**Key risk**: {1 sentence — the thing most likely to go wrong}

## Feasibility
- **Go**: {aspects that are straightforward}
- **Go with caveats**: {aspect} — {caveat}
- **Blocked/unclear**: {aspect} — {why}

## Architecture
{Brief description of components and data flow. Use a simple diagram or list, not prose.}

### Data Model
{Core entities and relationships — keep it to what's essential}

## Tech Choices
- {area}: {choice} — {why in <10 words}

## Non-Functional Targets
- {requirement}: {target}

## Risks & Tech Debt
- {Only items that would change the approach or need explicit payoff plans}

## Open Questions
- {Only questions that block progress}
```
