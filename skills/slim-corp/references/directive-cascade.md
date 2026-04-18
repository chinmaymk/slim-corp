## Directive Cascade

A user directive flows through the org structure at a depth matched to its complexity: Plan → Gate → Execute → Finalize.

### Prerequisites

1. Check `.slim-corp/projects.json` exists and has an active project. If not, tell the user to run `/slim-corp init "Project Name"` first.
2. Generate a directive slug from the directive text.
3. Create `.slim-corp/projects/{project-slug}/artifacts/{directive-slug}/` and `debates/` subdirectory.
4. Create state file at `.slim-corp/projects/{project-slug}/state/directive-{directive-slug}.json`:
   ```json
   {
     "directive": "the user's text",
     "slug": "directive-slug",
     "project": "project-slug",
     "tier": null,
     "started": "ISO timestamp",
     "flags": {},
     "status": "in-progress",
     "current_step": "classify",
     "completed_steps": [],
     "artifacts": [],
     "execution": {
       "review_cycle": 0,
       "pending_findings": []
     }
   }
   ```

### State Management Rules

**After every step**, the orchestrator MUST update the state file before proceeding:
1. Move `current_step` to `completed_steps`
2. Set `current_step` to the next step name
3. Add any new artifact filenames to `artifacts`
4. Write state to disk immediately (not batched)

**Step names** follow a fixed vocabulary so recovery can map them:
- Planning: `classify`, `ceo-vision`, `cto-strategy`, `cmo-strategy`, `csuite-debate`, `product-prd`, `engineering-spec`, `ux-spec`, `security-review`, `functional-debate`, `docs-plan`
- Gate: `execution-gate`
- Execution: `ex-build`, `ex-review-{N}` (N=cycle number), `ex-fix-{N}`, `ex-verify-{N}`
- Finalize: `memory-write`, `summary`

**Artifacts on disk are the source of truth.** The state file tracks progress; the artifact files contain the actual content. On resume, the orchestrator reads both to reconstruct context.

---

## Phase 0: Classify & Load Memory

No agent needed — the orchestrator does this directly.

**Step 1a: Load company memory.** Read from `.slim-corp/memory/`:
- `identity.md` — company mission, values
- `conventions.md` — coding standards, tech preferences
- `learned-rules.md` — cross-project patterns from retro

**Step 1b: Load project memory.** Read from `.slim-corp/projects/{active}/memory/`:
- `project.md` (includes `## Learned Rules` if retro has been run), `decisions.md`, `lessons.md`, `architecture.md`, `personas.md`, `tech-debt.md`

**Step 1c: Extract standing rules.** Merge rules from two sources:
- Company `learned-rules.md` — applies to all projects
- Project `project.md` `## Learned Rules` — applies to this project only
These rules are injected into relevant role prompts throughout the cascade.

**Step 1d: Check retro trigger.** Count completed directives in project's `state/`. If multiple of 5, auto-run retro before proceeding.

**Step 2: Classify complexity.**

#### Fast signals (any 2+ → fast tier)
- Short directive (<2 sentences) with clear scope
- Single feature or change ("add X", "fix X", "refactor X")
- Backend/infrastructure only — no user-facing UI
- Incremental change to existing, well-understood system
- No conflict with prior decisions

#### Deep signals (any 2+ → deep tier)
- Multi-feature directive or vague scope ("build a platform for...")
- Greenfield project (empty `architecture.md`)
- Multiple user personas or complex user journeys
- High-stakes domain (security, payments, data migration, compliance)
- Contradicts prior decisions
- User explicitly requests thorough analysis

#### Standard: everything else.

**Step 3: Detect flags.**
- `has_ui`: user-facing interface? (triggers UX)
- `needs_security`: auth, user data, external APIs, payments, file uploads, trust boundaries? (triggers Security). Auto-set for deep tier.
- `needs_docs`: public-facing, creating APIs, or user asked? (triggers Docs)

**Step 4: Announce.**
Tell the user: `Running as {tier} ({reason}). Say "override {tier}" to change.`

Update state: `tier`, `flags`, add `"classify"` to `completed`

---

## Planning Phase

### Tier: Fast

**Pipeline**: CEO → Product → Engineering

Each step: update state (`current_step`, add artifact, move prior to `completed_steps`) **before launching the next agent**.

1. **CEO Vision** → `vision.md` · state: `ceo-vision` (kill check: if ambiguous, CEO makes best interpretation and notes assumptions. Only ask user if contradictory or truly uninterpretable.)
2. **Product PRD** → `prd.md` · state: `product-prd` (from vision + memory only, no CTO/CMO)
3. **Engineering Spec** → `tech-spec.md` · state: `engineering-spec` (from prd + memory)

### Tier: Standard

**Pipeline**: CEO → CTO+CMO → [debate?] → Product → Eng+UX? → Security? → [debate?] → Docs?

Each step: update state **before launching the next agent**.

1. **CEO Vision** → `vision.md` · state: `ceo-vision`
2. **CTO + CMO** (parallel, blind) → `tech-strategy.md` + `market-strategy.md` · state: `cto-strategy`/`cmo-strategy` (on resume: check which artifacts exist, only re-run missing)
3. **C-Suite Debate** (conditional) · state: `csuite-debate` — check for tension. Skip if aligned. 1 round max if tension. CEO mediates.
4. **Product PRD** → `prd.md` · state: `product-prd`
5. **Engineering + UX** (parallel, UX if `has_ui`) → `tech-spec.md` + `ux-spec.md` · state: `engineering-spec`/`ux-spec`
6. **Security** (if `needs_security`) → `security-review.md` · state: `security-review`. MUST FIX items feed into debate.
7. **Functional Debate** (conditional, only if UX invoked) · state: `functional-debate` — 1 round max. Product mediates.
8. **Docs** (if `needs_docs`) → `docs-plan.md` · state: `docs-plan`

### Tier: Deep

**Pipeline**: CEO → CTO+CMO → mandatory debate → Product → Eng+UX+Security → mandatory debate → Docs

Each step: update state **before launching the next agent**.

1. **CEO Vision** → `vision.md` · state: `ceo-vision`
2. **CTO + CMO** (parallel, blind) → `tech-strategy.md` + `market-strategy.md` · state: `cto-strategy`/`cmo-strategy`
3. **C-Suite Debate** (mandatory) · state: `csuite-debate` — full protocol, up to 2 rounds. CEO mediates and makes final call.
4. **Product PRD** → `prd.md` · state: `product-prd`
5. **Engineering + UX + Security** (all parallel) · state: `engineering-spec`/`ux-spec`/`security-review` — Security reviews architecture/PRD (no tech-spec since parallel). On resume: check which exist, only re-run missing.
6. **Functional Debate** (mandatory) · state: `functional-debate` — reads all three artifacts. Security MUST FIX non-negotiable. Up to 2 rounds. Product makes final call.
7. **Docs** → `docs-plan.md` · state: `docs-plan`

---

## Execution Gate

After planning completes, present a brief **Planning Summary** and auto-proceed to execution.

```
## Planning Complete: {directive title} [{tier}] — proceeding to execution

**Artifacts**: {list}
**Key decisions**: {top 3}
**Security**: {MUST FIX count, or "not reviewed"}
```

**Fast tier**: no gate — auto-proceed immediately.
**Standard/Deep tier**: show summary, auto-proceed after 3 seconds unless user intervenes.
**User can say "stop" or "revise"** at any point — this enters the [Revision Protocol](#revision-protocol) or marks the directive as plan-only.

---

## Git Strategy

The executor works on a **feature branch** per directive. The orchestrator manages git operations — the executor focuses on code.

### Branch lifecycle
1. **Before EX-1**: orchestrator creates branch `slim-corp/{directive-slug}` from current HEAD
2. **During execution**: executor commits after each completed story with message: `feat({story-id}): {story title}`
3. **After EX-3 (fix)**: executor commits fixes with: `fix: address {reviewer} findings cycle {N}`
4. **After Finalize**: orchestrator creates a commit summarizing the directive, then offers to create a PR or merge directly

### Commit convention
```
{type}({scope}): {description}

Slim-Corp directive: {directive-slug}
Tier: {tier} | Stories: {count} | Review cycles: {count}
```
Types: `feat` (new story), `fix` (reviewer findings), `refactor`, `test`, `docs`

### PR creation (Standard/Deep tiers)
After finalize, automatically create a PR with:
- Title: directive title
- Body: final summary (artifacts, decisions, tradeoffs, execution stats)
- Branch: `slim-corp/{directive-slug}` → main

**Fast tier**: commit directly to current branch (no PR — it's a small change).

---

## Execution Phase

The executor builds code. Reviewers validate. Executor fixes.

```
Branch → Build → Review (parallel) → Fix → Verify → PR/Merge
                    ↑                    |
                    └── max 2 cycles ────┘
```

### Tier: Fast — Execution

**EX-1: Build** · state: `ex-build`
Launch `slim-corp-executor`. Provide: `tech-spec.md`, `prd.md`, `security-review.md` (if exists), project memory, codebase. Implements P0 → P1 → P2, tests alongside.

**EX-2: Self-Validate** · state: `ex-verify-0`
Executor runs tests, verifies P0 ACs pass. Pass → Finalize. Fail → fix and re-run.

### Tier: Standard — Execution

**EX-1: Build** · state: `ex-build` — same as fast.

**EX-2: Review** · state: `ex-review-{N}` (N = `execution.review_cycle`, starts at 1)
Launch reviewers in parallel based on flags:
- **Always**: `slim-corp-qa`
- **If `needs_security`**: `slim-corp-security-review`
- **If `has_ui`**: `slim-corp-ux-review`

Write reviewer feedback to `artifacts/{directive-slug}/reviews/cycle-{N}/` (qa-feedback.md, security-feedback.md, ux-feedback.md). This ensures feedback survives interruption.

**EX-3: Fix** · state: `ex-fix-{N}`
Orchestrator reads feedback from `reviews/cycle-{N}/`, consolidates by severity. Launch executor with consolidated feedback. Executor fixes, re-runs tests.

**EX-4: Verify** · state: `ex-verify-{N}`
MUST FIX resolved? → Finalize. Still open? → increment `execution.review_cycle`, re-enter EX-2 (max 2 cycles). Stuck after 2? → escalate to user.

### Tier: Deep — Execution

Same as Standard, except:
- **EX-2**: All three reviewers always run regardless of flags.
- **EX-4**: P0 AND P1 ACs must pass. Security confirms all original MUST FIX addressed.

---

## Finalize

Runs once, after execution (or after planning if plan-only).

### Memory Write
- Append debate decisions to `decisions.md`
- Append new ADRs to `architecture.md`
- Update `personas.md` if flagged
- Append new tech debt + NOTED items from reviewers to `tech-debt.md`
- Update `project.md` if fundamentally changed

### Auto-Retrospective

The orchestrator generates a retrospective automatically by analyzing the directive's execution stats. No user input needed — this runs as part of finalize.

**Analyze these signals:**
- **Tier accuracy**: Did the classified tier feel right? Fast directive that needed 2 review cycles = should have been standard. Deep directive with no debate tensions = could have been standard.
- **Review cycle count**: 0 cycles = planning was solid. 2 cycles = planning missed something. Track what reviewers caught.
- **Finding patterns**: Categorize MUST FIX and SHOULD FIX findings by type (security, correctness, UX, edge cases). Recurring categories across directives = systematic gap.
- **Debate value**: Did debates produce changes to artifacts, or just confirm alignment? Debates that only confirmed = wasted time for this type of directive.
- **Spec-to-code drift**: Did the executor flag spec issues? What kind? (missing details, contradictions, infeasible requirements)

**Write to `lessons.md`:**
```markdown
## Directive: {slug} ({date}) [{tier}]

### Stats
- Review cycles: {N} | MUST FIX: {N} | SHOULD FIX: {N}
- Debates: {N} tensions, {N} resolved by synthesis, {N} by mediator override
- Spec issues flagged by executor: {N}

### What worked
- {auto-detected: e.g., "Security review caught auth bypass before shipping"}

### What to improve
- {auto-detected: e.g., "QA found 3 missing error handlers — engineering spec should require error state coverage"}

### Pattern signals
- {e.g., "2nd directive in a row where QA catches missing input validation — consider adding to executor rules"}
```

### Feed-Forward: How Lessons Improve Future Runs

Lessons are not just logged — they're **actively used**:

1. **Phase 0 (Classify)**: Read `lessons.md`. If patterns suggest the tier classifier is miscalibrating (e.g., "fast directives keep needing 2 review cycles"), adjust classification thresholds for this run.

2. **Role prompts**: When launching any agent, append relevant lessons as context:
   - Executor gets: "In past directives, QA consistently found {pattern}. Address proactively."
   - Engineering gets: "Past specs missed {pattern}. Ensure coverage."
   - Security gets: "Past reviews found {pattern} in similar directives."

3. **The orchestrator scans `lessons.md` for repeated patterns** (same issue appearing in 3+ directives) and promotes them to **standing rules** in `project.md` under a `## Learned Rules` section. Standing rules are always injected into relevant role prompts.

### Final Summary

```
## Done: {directive title} [{tier}]

**Artifacts**: .slim-corp/projects/{slug}/artifacts/{directive-slug}/
{list only what was produced}

**Key decisions** ({N} total):
- {top 3, 1 line each}

**Debates**: {summary or "skipped"}

**Execution**:
- Stories: {N P0, N P1, N P2}
- Review cycles: {N}
- Findings: {N MUST FIX, N SHOULD FIX addressed}
- Open: {N NOTED as tech debt, or "none"}

**Tradeoffs**:
- {top 2-3, 1 line each}
```

Update state: `"status": "complete"`, `"completed_at": "ISO timestamp"`

---

## Revision Protocol

When the user says "revise" at the gate or during planning:

1. **Ask what to revise**: "Which artifact or phase needs revision? (e.g., 'vision', 'tech-strategy', 'prd')"
2. **Ask for feedback**: "What should change?" — get specific user input.
3. **Re-run the target phase** with the user's feedback injected into the agent prompt alongside the original inputs.
4. **Cascade downstream**: any artifact that depends on the revised one must be re-run. The dependency chain:
   - `vision.md` revised → re-run CTO, CMO, and everything after
   - `tech-strategy.md` or `market-strategy.md` revised → re-run debate + Product + everything after
   - `prd.md` revised → re-run Engineering, UX, Security, and everything after
   - `tech-spec.md` or `ux-spec.md` revised → re-run debates and Docs only
5. **Return to Execution Gate** after revision cascade completes.

---

## Error Recovery & Resume Protocol

On every `/slim-corp` invocation, **before** processing the command:

### Step 1: Check for incomplete directives
Read all state files in `.slim-corp/projects/{active}/state/`. Any file with `"status": "in-progress"` is incomplete.

### Step 2: If incomplete found, offer resume
```
Found incomplete directive: "{directive}"
Last completed: {last item in completed_steps}
Next step: {current_step}
Artifacts so far: {artifacts list}

Resuming automatically. Say "start fresh" to discard and restart.
```

### Step 3: Resume procedure
1. Read the state file to get `tier`, `flags`, `current_step`, `completed_steps`, `execution.review_cycle`
2. Read all artifacts listed in `artifacts` array from the artifact directory
3. Determine the next step from `current_step` (this is what was interrupted)
4. **Re-run `current_step`** — the step that was in progress may have partially completed, so re-running it is safer than skipping. Artifacts from completed steps are on disk and won't be re-run.
5. Continue the cascade normally from there

### Step 4: If user says "start fresh"
1. Move the state file to `.slim-corp/projects/{slug}/state/archive/`
2. Move the artifact directory to `.slim-corp/projects/{slug}/artifacts/archive/{slug}-{timestamp}/`
3. Start the new directive from scratch

### Resume edge cases
- **Interrupted during parallel steps** (e.g., CTO+CMO): check which artifacts exist on disk. If only one was produced, re-run only the missing one.
- **Interrupted during execution review cycle**: `execution.review_cycle` tells which cycle. Re-enter at the current cycle's review step.
- **Interrupted during debate**: debates don't produce intermediate state — re-run the full debate round. Completed resolutions are already in the debate artifact.
- **State file exists but artifact directory is empty**: treat as "start fresh" — something went wrong before any work was done.
