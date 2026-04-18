```markdown
---
role: security
directive: {slug}
---

# Security Review: {Directive Title}

**Surface**: {1 sentence — what's exposed: endpoints, data types, trust boundaries}
**Verdict**: {clear / has findings / blocks shipping}

## Data Classification
- {data type}: {public/internal/confidential/restricted} — {handling requirement}

## Threat Model
{Only threats relevant to this directive's attack surface.}

### {Threat title}
- **Vector**: {how an attacker exploits this}
- **Impact**: {what they gain}
- **Mitigation**: {specific countermeasure}

## Auth & Access Control
- {Specific requirement, testable. e.g., "GET /api/users/:id returns 403 unless JWT sub matches :id"}

## Security Requirements

### MUST FIX (blocks shipping)
- {finding}: {specific fix}

### SHOULD FIX (before v2)
- {finding}: {specific fix}

### NOTED (accepted risk)
- {finding}: {why acceptable}

## Open Questions
- {Only questions that block progress}
```
