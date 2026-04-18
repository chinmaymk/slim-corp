```markdown
---
role: ux-review
directive: {slug}
type: review-feedback
---

# UX Review: {Directive Title}

**Flows verified**: {list of interaction flows checked}
**Verdict**: {matches spec / has deviations / blocks shipping}

## MUST FIX
### {Finding title}
- **Spec says**: {expected behavior from ux-spec}
- **Actual**: {what the implementation does}
- **Suggestion**: {specific fix}

## SHOULD FIX
### {Finding title}
- **Spec says**: {expected}
- **Actual**: {what happens}
- **Suggestion**: {fix}

## NOTED
- {Deviation}: {improvement or acceptable difference}
```
