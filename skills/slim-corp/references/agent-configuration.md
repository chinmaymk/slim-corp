## Model Routing

### Planning Phase
| Role | Model | Rationale |
|------|-------|-----------|
| CEO | opus | Framing quality drives everything downstream |
| CTO | opus | Architectural decisions expensive to reverse |
| Product | opus | Bad PRD cascades into bad specs |
| Engineering | opus | Spec accuracy matters |
| CMO | sonnet | Valuable but less load-bearing |
| UX | sonnet | Lower architectural risk |
| Security | opus | Missed vulns are expensive |
| Docs | sonnet | Lowest risk |
| Debates | opus | Adversarial review needs deep reasoning |

### Execution Phase
| Skill | Model | Rationale |
|-------|-------|-----------|
| `slim-corp-executor` | opus | Code quality is the point |
| `slim-corp-qa` | sonnet | Structured validation, not creative |
| `slim-corp-security-review` | opus | Vuln detection needs deep reasoning |
| `slim-corp-ux-review` | sonnet | Comparison, not design |

### Tier Overrides
- **Fast**: all opus (few agents, quality > cost)
- **Standard**: use tables above
- **Deep**: all opus (thoroughness is the point)

---

## Prompt Construction

How the orchestrator builds the prompt for each agent determines output quality. Follow these rules:

### Rule 1: Lead with the actual user directive, always
Every agent prompt starts with the user's exact words. Not a summary, not a restatement — the raw directive. This keeps every role anchored to what the user actually asked for.

```
The user's directive: "{exact text}"
```

### Rule 2: Provide codebase context, not just artifacts
Before launching any agent, the orchestrator should scan the actual codebase and include relevant context:
- **What exists today**: key files, current tech stack (from package.json/Cargo.toml/etc.), directory structure overview
- **What's relevant to this directive**: existing code that will be modified or extended
- **What constraints are real**: language, framework, existing patterns the team follows

An agent working in a vacuum produces generic output. An agent that knows "this is a Next.js app with Prisma and PostgreSQL, and here's the current auth module" produces specific, actionable output.

### Rule 3: Frame with a sharp question, not just "produce artifact"
Bad: "You are the CEO. Produce vision.md."
Good: "The user wants to add OAuth. You're the CEO. What's the real problem they're solving? Is this about reducing signup friction, enabling enterprise SSO, or something else? Make a bet and define what success looks like."

Each role gets a framing question that forces them to THINK about the directive, not just fill in a template:

| Role | Framing Question |
|------|-----------------|
| CEO | "What's the real problem here, and what's the smallest bet that validates it?" |
| CTO | "Given what exists today, what's the simplest architecture that works? What breaks first?" |
| CMO | "Who specifically is desperate for this, and what are they doing right now instead?" |
| Product | "What are the 3-5 stories that, if they work, mean this directive is done?" |
| Engineering | "Given the tech stack and PRD, what's the module breakdown and where are the hidden gotchas?" |
| UX | "What's the user's flow from start to done? Where will they get confused?" |
| Security | "What's the attack surface here? What's the worst thing that happens if we get it wrong?" |
| Docs | "What will a new user's first 5 minutes look like? What questions will they have?" |

### Rule 4: Include standing rules and lessons
Append any standing rules from company `learned-rules.md` and project `project.md` that are relevant to this role. Be specific:
```
Learned from past directives:
- QA has found missing input validation in 4/6 past directives. Proactively validate all user inputs.
- Previous auth implementations missed rate limiting on login endpoints. Include rate limiting.
```

### Rule 5: Set the quality bar explicitly
Every agent prompt ends with:
```
Quality bar: Your output will be used directly by the next role in the pipeline. If it's vague, generic, or doesn't address the specific directive, everything downstream will be wrong. Be specific to THIS project, THIS codebase, THIS directive.
```

---

## Artifact Quality Rubric

The orchestrator checks each artifact against this rubric before passing it downstream. If an artifact scores "poor" on any dimension, re-run the agent with specific feedback.

### Specificity
- **Good**: "Use Prisma with PostgreSQL. The users table has id, email, password_hash, created_at. Auth via JWT stored in httpOnly cookie."
- **Poor**: "Use a database. Implement authentication."
- **Test**: Does the artifact name specific technologies, specific data structures, specific behaviors? Or could it apply to any project?

### Directive Alignment
- **Good**: Every section traces back to what the user asked for. No tangential features.
- **Poor**: Includes analysis of things the user didn't ask about. Scope creep from the role's own biases.
- **Test**: Remove the directive from the top — could this artifact have been written for a different directive? If yes, it's too generic.

### Actionability
- **Good**: The next role can start working immediately without asking questions.
- **Poor**: The next role has to guess what you meant, fill in gaps, or make assumptions.
- **Test**: Would an engineer read this and say "I know exactly what to build" or "I have 10 questions"?

### Opinionatedness
- **Good**: Takes clear positions. "We should do X because Y. We're NOT doing Z because it doesn't serve the core metric."
- **Poor**: Lists options without choosing. "We could do X or Y or Z." Hedges with "it depends."
- **Test**: Count the decisions vs. the open questions. Good artifacts have 5:1 ratio. Poor ones are 1:5.

---

## Tension Detection

The orchestrator — not an agent — compares two artifacts for tension:

1. **Priority conflicts**: one says P0, other says defer/out-of-scope
2. **Feasibility disagreements**: one assumes straightforward, other flags risky
3. **Timeline misalignment**: implied timelines differ >2x
4. **Arch vs. UX conflict**: tech choice creates UX friction, or UX requires expensive infra

0 tensions → skip debate. 1+ → debate those specific topics only.
