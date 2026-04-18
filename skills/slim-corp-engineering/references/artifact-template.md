```markdown
---
role: engineering
directive: {slug}
---

# Tech Spec: {Directive Title}

**Approach**: {1-2 sentences — how we build this}

## File Structure
{Only if non-obvious. Otherwise omit.}

## Modules
### {Name}
- **Does**: {purpose in <10 words}
- **Exports**: {key interfaces}
- **Depends on**: {dependencies}

## API Contracts
### {Endpoint/Interface}
- In: {shape}
- Out: {shape}
- Errors: {error cases}

## Implementation Plan
- US-001: {modules} — {effort S/M/L} — {blocked by, if any}
- US-002: ...

## Test Strategy
- **Unit**: {what's tested and how}
- **Integration**: {key scenarios}
- **Acceptance**: {how ACs are verified}

## Risks & Debt
- {Only items that need attention}

## Open Questions
- {Only questions that block progress}
```
