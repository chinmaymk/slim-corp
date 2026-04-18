## Setup Protocol (`/slim-corp setup`)

First-time setup for a new company. Creates the company-level structure.

1. Create `.slim-corp/` directory
2. Create `company.json`:
   ```json
   { "name": null, "active_project": null, "projects": {} }
   ```
3. Create company memory:
   ```
   .slim-corp/memory/
     identity.md       # "# Company Identity\n\n{To be defined}"
     conventions.md    # "# Conventions\n\n{To be defined}"
     learned-rules.md  # "# Learned Rules\n\n{None yet}"
   ```
4. Ask: "What's your company/org name?" → update `company.json` name
5. Optionally ask: "Any coding conventions or tech preferences?" → populate `conventions.md`
6. Report success. Suggest: `Run /slim-corp init "Project Name" to create your first project.`

## Init Protocol (`/slim-corp init "Project Name"`)

Create a new project within the company.

1. Check `.slim-corp/company.json` exists. If not, run Setup Protocol first.
2. Generate slug from project name (lowercase, hyphens)
3. Check slug doesn't already exist
4. Create project structure:
   ```
   .slim-corp/projects/{slug}/
     project.json
     memory/
       project.md, decisions.md, lessons.md,
       architecture.md, personas.md, tech-debt.md
     state/
     artifacts/
   ```
5. Create `project.json`: `{ "name": "...", "created": "ISO", "slug": "..." }`
6. Initialize project memory files with headers
7. Update `company.json`: add to `projects`, set as `active_project`
8. Report success

## List Protocol

1. Read `company.json`
2. Show company name, then each project: name, slug, created date, active flag
3. Show directive count per project

## Switch Protocol

1. Read `company.json`
2. Validate target slug exists in `projects`
3. Update `active_project`
4. Report the switch

## Status Protocol

1. Read `company.json` for company name and active project
2. Read company memory summary (conventions count, learned rules count)
3. Read active project's memory: identity, decision count, open tech debt, directive count
4. Check all state files in project's `state/`:
   - **In-progress**: current_step, tier, flags, review cycle
   - **Complete**: title, tier, date, story count
   - **Plan-only**: title, tier, note skipped
5. Show:
   ```
   ## Company: {name}
   Conventions: {N} | Learned rules: {N} | Projects: {N}

   ## Active Project: {project name}
   Decisions: {N} | Open debt: {N} | Directives: {N}

   | Directive | Tier | Status | Step | Branch |
   |-----------|------|--------|------|--------|
   | ... | ... | ... | ... | ... |
   ```

## Retro Protocol

Cross-directive pattern analysis. Run via `/slim-corp retro` or auto-triggered every 5th directive.

1. Read project `lessons.md`
2. Scan for recurring patterns (same issue type in 3+ directives)
3. For each pattern, generate a standing rule
4. **Scope the rule**:
   - Applies to this project only → append to project `memory/project.md` under `## Learned Rules`
   - Applies to ALL projects (e.g., "always validate inputs") → append to company `memory/learned-rules.md`
5. Present summary with patterns found, new rules, tier accuracy, avg review cycles

## Memory Prune Protocol

Follow prune protocol in `slim-corp-memory` skill. Operates on active project only.

## Memory Export Protocol

Follow export protocol in `slim-corp-memory` skill. Includes both company and project memory.
