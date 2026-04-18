---
name: slim-corp-debate
description: Debate protocol reference for slim-corp. Defines steelman/objection/synthesis mechanics and escalation rules.
license: MIT
compatibility: Designed for Claude Code. Other agentskills.io-compatible tools may support individual persona features.
metadata:
  role: protocol
  parent: slim-corp
  invocation: orchestrator-only
  author: slim-corp
  version: "1.0"
---

# Debate Protocol

Invoked during C-Suite Debate (Phase 3) and Functional Debate (Phase 6).

## Principles
1. Debates produce **decisions**, not consensus.
2. "I agree with everything" is invalid. Stress-test the weakest assumption.
3. Evidence over opinion. "Might not scale" rejected. "Hits rate limits at 1000 users because 100 req/s" accepted.
4. Decisions are permanent until new evidence arrives.

## Structure

### Phase 1: Position Statements
Each participant writes independently (no anchoring):
```
### {Role} on {Topic}
**Stance**: {1 sentence}
**Why**: {1-2 sentences}
**Assumes**: {bullets}
**If wrong**: {consequence}
```

### Phase 2: Adversarial Review

**2a. Steelman** (required before objecting):
```
#### Steelman of {Role}'s position
{1-2 sentences — strongest version of the position you disagree with}
```

**2b. Objections** (min 1 per participant, concrete only):
```
#### Objection: {title}
**Scenario**: {concrete example where position fails}
**Severity**: blocking | concerning | noted
**Alternative**: {what to do instead}
```

**2c. Cross-blind-spot check**: Each participant identifies one risk the other's biases would miss.

### Phase 3: Resolution

**Synthesis** (preferred):
```
## Resolution: {Topic}
**Decision**: {what was decided}
**Tradeoff**: {what was sacrificed, why acceptable}
**Dissents**: {accepted risks, or "none"}
```

**Mediator Override** (after 2 rounds without synthesis):
The mediator (CEO for C-Suite, Product for Functional) makes the final call autonomously.
```
## Resolved by Override: {Topic}
**Decision**: {mediator's call}
**Overrode**: {which position was rejected and why}
**Tradeoff**: {what was sacrificed}
```
Only escalate to user if the mediator genuinely cannot decide (e.g., both positions have equal blocking-severity consequences). This should be rare.

## Pairings

**C-Suite** — CTO vs. CMO, CEO mediates. Topics from comparing `tech-strategy.md` vs `market-strategy.md`. CEO evaluates against `vision.md`, can override with documented rationale.

**Functional** — Engineering vs. UX, Product mediates. Topics from comparing `tech-spec.md` vs `ux-spec.md`. P0 features non-negotiable. P1/P2 can be simplified.

## Rules
- Max 2 adversarial rounds per topic. Then mediator overrides.
- Objections rejected if: hedge words without specifics, abstract concepts without grounding, no concrete scenario.
- Kill condition triggers → mandatory blocking objection, cannot be overridden by mediator.
- Every resolution → row in `decisions.md`: `| {date} | {topic} | {decision} | {rationale} | {sacrificed} | {decided-by} |`
