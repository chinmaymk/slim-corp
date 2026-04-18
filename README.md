# Slim-Corp

Ship software through structured debate. A multi-agent skill pack that models a company org — CEO, CTO, CMO, Product, Engineering, UX, Security, QA, and Docs — to autonomously plan, debate, build, review, and ship code from a single directive.

## Quick Start

```sh
./install.sh
/slim-corp add user authentication with OAuth and JWT
```

That's it. No setup, no init. Slim-Corp auto-detects your repo, creates the company and project, classifies complexity, plans, builds, reviews, and ships.

## How It Works

```
Directive → Classify → Plan → Build → Review → Fix → Ship
                                ↑                  |
                                └── max 2 cycles ──┘
```

### Adaptive Tiers

| Tier | When | Pipeline | Time |
|------|------|----------|------|
| **Fast** | "add X", "fix Y" | CEO → Product → Eng → Build → Self-validate | ~5 min |
| **Standard** | Moderate features | Full planning + conditional debates → Build → Review → Fix | ~10 min |
| **Deep** | Greenfield, high-stakes | Full planning + mandatory debates → Build → All reviewers → Fix | ~15 min |

Tier is auto-detected. Say `override deep` to change.

### Planning Roles

| Role | Output |
|------|--------|
| **CEO** | `vision.md` — strategic vision, scope, success metrics |
| **CTO** | `tech-strategy.md` — architecture, feasibility, tech choices |
| **CMO** | `market-strategy.md` — target users, positioning, differentiation |
| **Product** | `prd.md` — prioritized user stories with acceptance criteria |
| **Engineering** | `tech-spec.md` — modules, API contracts, test strategy |
| **UX** | `ux-spec.md` — interaction flows, accessibility |
| **Security** | `security-review.md` — threat model, auth requirements |
| **Docs** | `docs-plan.md` — documentation structure |

### Execution Roles

| Role | Job |
|------|-----|
| **Executor** | Writes all code, commits per story, addresses feedback |
| **QA** | Validates acceptance criteria, tests edge cases |
| **Security Review** | Reviews code for vulnerabilities |
| **UX Review** | Validates UI matches spec |

### Debates

CTO vs CMO (CEO mediates). Engineering vs UX (Product mediates). Steelman → objection → synthesis. Mediators make the final call autonomously.

## Commands

| Command | What it does |
|---------|-------------|
| `/slim-corp init "Name"` | Create additional project (first project auto-created) |
| `/slim-corp {directive}` | Run full plan → build → ship pipeline |
| `/slim-corp status` | Project state, directive progress, branches |
| `/slim-corp list` | List all projects |
| `/slim-corp switch "slug"` | Switch active project |
| `/slim-corp retro` | Analyze patterns across directives, generate standing rules |
| `/slim-corp memory prune` | Archive resolved decisions/debt |
| `/slim-corp memory export` | Export all memory as markdown |

## Autonomous by Default

The pipeline runs end-to-end without user input. You're only interrupted if:
- The directive is contradictory or uninterpretable
- A debate can't be resolved after 2 rounds (rare — mediators override)
- A critical fix requires architectural change beyond executor scope

Say `stop` or `revise` at any point to intervene.

## Resume on Interrupt

State is saved to disk after every step. If the session is interrupted, the next `/slim-corp` invocation auto-resumes from where it left off. Say `start fresh` to discard and restart.

## Git Strategy

- **Fast tier**: commits directly to current branch
- **Standard/Deep**: creates `slim-corp/{directive-slug}` branch, commits per story (`feat(US-001): ...`), creates PR at the end

## Directory Structure

```
.slim-corp/
  company.json                           # company registry, active project
  memory/                                # COMPANY-WIDE — shared across projects
    identity.md                          # mission, values, brand voice
    conventions.md                       # coding standards, tech preferences
    learned-rules.md                     # cross-project patterns from retro
  projects/
    {project-slug}/
      project.json                       # project config
      memory/                            # PROJECT-SCOPED — isolated per project
        project.md, decisions.md, architecture.md,
        personas.md, tech-debt.md, lessons.md
      state/                             # directive progress tracking
        directive-{slug}.json
      artifacts/                         # per-directive outputs
        {directive-slug}/
          vision.md, tech-strategy.md, prd.md, tech-spec.md, ...
          debates/
          reviews/cycle-{N}/
```

Company memory applies to all projects (conventions, learned rules). Project memory is isolated — projects don't see each other's decisions or architecture.

## Installation

### Claude Code Plugin Marketplace (recommended)

```sh
# Add the marketplace
/plugin marketplace add chinmaymk/slim-corp

# Install the plugin
/plugin install slim-corp@slim-corp
```

### Manual Install

```sh
git clone https://github.com/chinmaymk/slim-corp.git
cd slim-corp
./install.sh --force    # symlinks to ~/.claude/skills/, replaces existing
./install.sh --copy     # hard copies instead of symlinks
```

Skills use [agentskills.io](https://agentskills.io) format. Orchestration requires Claude Code; individual persona skills work standalone in any compatible tool.

## Customization

- **Edit a persona**: modify `skills/slim-corp-{name}/SKILL.md`
- **Edit artifact format**: modify `skills/slim-corp-{name}/references/artifact-template.md`
- **Adjust model routing**: edit `skills/slim-corp/references/agent-configuration.md`
- **Add a role**: create `skills/slim-corp-{name}/SKILL.md`, add to orchestrator's `requires` list, wire into cascade

## License

MIT
