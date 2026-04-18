# Contributing to Slim-Corp

## Adding a New Persona

1. Create `skills/slim-corp-{name}/SKILL.md`
2. Add YAML frontmatter (see structure below)
3. Define the persona's responsibilities, input requirements, output format, and kill conditions
4. Add the skill name to the orchestrator's `metadata.requires` list in `skills/slim-corp/SKILL.md`
5. Wire it into the directive cascade at the appropriate phase in `skills/slim-corp/references/directive-cascade.md`
6. Run install.sh to link the new skill

## SKILL.md Structure

Every skill must have this frontmatter:

```yaml
---
name: slim-corp-{name}
description: One-line description of the persona's role.
license: MIT
compatibility: Designed for Claude Code. The agentskills.io format is portable.
metadata:
  role: {role-type}       # e.g., persona, orchestrator, protocol, utility
  author: slim-corp
  version: "1.0"
  requires: []            # list dependency skills if any
---
```

The body should include:
- **Identity**: Who this persona is and how they think
- **Input requirements**: What artifacts/context they need
- **Output format**: Exact structure of the artifact they produce
- **Kill conditions**: When this persona should reject or escalate
- **Memory integration**: What they read from and write to project memory

## agentskills.io Compliance Checklist

- [ ] SKILL.md exists at the skill directory root
- [ ] YAML frontmatter includes `name`, `description`, `license`, `compatibility`, `metadata`
- [ ] `metadata.role` is one of: orchestrator, persona, protocol, utility
- [ ] `metadata.version` follows semver
- [ ] `metadata.requires` lists all dependency skills by name
- [ ] Description is a single sentence under 200 characters
- [ ] No hardcoded file paths (use relative references or project-scoped paths)
- [ ] Kill conditions are explicit and actionable

## Testing

1. Install skills: `./install.sh`
2. Init a test project: `/slim-corp init "Test Project"`
3. Run a simple directive: `/slim-corp Add a login page`
4. Verify all 10 phases complete and artifacts are produced
5. Check that memory files are updated correctly
6. For individual personas, invoke them directly and verify output format

## Submitting a PR

1. Fork the repo and create a feature branch
2. Make your changes following the structure requirements above
3. Run through the testing checklist
4. Ensure all SKILL.md files pass the compliance checklist
5. Write a clear PR description explaining what the persona does and where it fits in the cascade
6. Submit the PR -- a maintainer will review for consistency with the existing skill pack
