```markdown
---
role: qa
directive: {slug}
type: review-feedback
---

# QA Review: {Directive Title}

**Stories reviewed**: {US-001, US-002, ...}
**Verdict**: {all clear / has findings / blocks shipping}

## MUST FIX
### {Finding title}
- **AC**: {which acceptance criterion}
- **Expected**: {what the PRD says should happen}
- **Actual**: {what actually happens}
- **Repro**: {specific steps or test case to reproduce}

## SHOULD FIX
### {Finding title}
- **What**: {edge case or behavior issue}
- **Repro**: {steps}
- **Suggestion**: {specific fix}

## NOTED
- {Minor issue}: {why it's acceptable for now}

## Coverage Gaps
- {Missing test for specific scenario}
```
