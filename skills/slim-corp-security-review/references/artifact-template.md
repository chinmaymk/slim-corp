```markdown
---
role: security-review
directive: {slug}
type: review-feedback
---

# Security Code Review: {Directive Title}

**Planning items verified**: {N of M MUST FIX items from security-review.md addressed}
**Verdict**: {all clear / has findings / blocks shipping}

## Unaddressed Planning Items
- {MUST FIX item from security-review.md}: not found in implementation

## MUST FIX
### {Finding title}
- **Where**: {file:line}
- **Exploit**: {specific attack scenario}
- **Fix**: {what to change}

## SHOULD FIX
### {Finding title}
- **Where**: {file:line}
- **Issue**: {what's wrong}
- **Fix**: {what to change}

## NOTED
- {Minor issue}: {why acceptable}
```
