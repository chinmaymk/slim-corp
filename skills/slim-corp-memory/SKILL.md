---
name: slim-corp-memory
description: Memory manager reference for slim-corp. Defines read/write/prune protocols for company and project memory.
license: MIT
compatibility: Designed for Claude Code. Other agentskills.io-compatible tools may support individual persona features.
metadata:
  role: protocol
  parent: slim-corp
  invocation: orchestrator-only
  author: slim-corp
  version: "1.0"
---

# Memory Manager

Two-level memory: **company-wide** (shared across all projects) and **project-scoped** (isolated per project).

## Directory Structure

```
.slim-corp/
  company.json                          # registry: projects list, active project
  memory/                               # COMPANY-WIDE — shared across all projects
    identity.md                         # company mission, values, brand voice
    conventions.md                      # coding standards, naming, tech preferences
    learned-rules.md                    # cross-project patterns from retro
  projects/
    {project-slug}/
      project.json                      # project config, created date
      memory/                           # PROJECT-SCOPED — isolated per project
        project.md                      # project identity, tech stack, constraints
        decisions.md                    # append-only decision journal
        lessons.md                      # post-directive retrospectives
        architecture.md                 # ADR-style architecture decisions
        personas.md                     # user personas
        tech-debt.md                    # technical debt registry
      state/                            # directive progress tracking
        directive-{slug}.json
      artifacts/                        # per-directive outputs
        {directive-slug}/
```

## What's Company-Wide vs. Project-Scoped

| Level | What lives here | Example |
|-------|----------------|---------|
| **Company** | Things that apply to ALL projects | "We prefer TypeScript", "Always use Postgres", "Our API naming convention is..." |
| **Project** | Things specific to ONE project | "This project uses Python/FastAPI", "Decision: chose WebSocket over polling", "User persona: data engineer" |

**Rule**: If a learned rule from retro applies to ALL future projects (not just the current one), it goes in `memory/learned-rules.md`. If it's project-specific, it goes in `projects/{slug}/memory/project.md` under `## Learned Rules`.

## Read Protocol
1. Always read company memory first: `identity.md`, `conventions.md`, `learned-rules.md`
2. Then read project memory: `project.md` first (foundational context)
3. Read `decisions.md` before any debate (check prior decisions)
4. Role-specific: CTO/Engineering → `architecture.md` + `tech-debt.md`. CMO/UX → `personas.md`. Product → all.
5. Missing file = new company/project. Proceed without it.

## Write Protocol
- Roles **flag** memory updates in artifacts — they don't write directly.
- Debates append to project `decisions.md` after each resolution.
- Orchestrator processes all flagged updates in Finalize:
  - Project `decisions.md` ← debate resolutions
  - Project `architecture.md` ← new ADRs
  - Project `personas.md` ← refinements from CMO/UX
  - Project `tech-debt.md` ← new entries + NOTED items from reviewers
  - Project `project.md` ← only if fundamentally changed
  - Company `conventions.md` ← only if new company-wide convention discovered
  - Company `learned-rules.md` ← only via retro protocol (cross-project patterns)

## Anti-Re-Litigation
Before debate, check project `decisions.md` for prior rulings. Re-litigation requires concrete new evidence. "I disagree" is not sufficient.

## Prune Protocol
Move superseded decisions, resolved debt, and deprecated ADRs to `memory/archive/`. Report what was pruned. Works at project level only.

## Export Protocol
Produce single markdown with company + project memory, organized by level and category. Output to stdout.
