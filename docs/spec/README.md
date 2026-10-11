# Project Experts — Spec

Status: draft v0.3 (3 review passes: consistency, lifecycle gaps, merge/concurrency edge cases). Normative words: MUST, MUST NOT, SHOULD, MAY.

Project-specific expert knowledge for coding agents. Experts live as markdown in the repo, are derived from the codebase, and are refined from evidence during conversations. An optional binary (`experts`) gates writes, detects similarity, and drives multi-step loops whose reasoning is done by the calling agent.

## Files

| File | Covers |
|---|---|
| [01-model.md](01-model.md) | Concepts, invariants, lifecycles (state machines) |
| [02-layout.md](02-layout.md) | Directory tree, what is committed/ignored |
| [03-formats.md](03-formats.md) | Grammars: IDs, evidence, EXPERT.md, lessons, inbox, registry, config, log |
| [04-cli.md](04-cli.md) | CLI conventions, output grammar, every command |
| [05-record.md](05-record.md) | `record` pipeline, decisions, `resolve` for decisions |
| [06-loops.md](06-loops.md) | Loop engine, task catalog, init/curate/spawn/verify/reflect |
| [07-similarity.md](07-similarity.md) | Normalization, scoring, clustering |
| [08-routing.md](08-routing.md) | `route`, `scan`, glob semantics |
| [09-protocol.md](09-protocol.md) | Agent behavior, with and without the binary |
| [10-integration.md](10-integration.md) | AGENTS.md block, per-agent pointers, `init` writes |
| [11-storage.md](11-storage.md) | Locking, transactions, crash recovery, git merges |
| [12-security.md](12-security.md) | Threat model, content lint, path confinement |
| [13-errors.md](13-errors.md) | Error and warning codes, exit codes |
| [14-distribution.md](14-distribution.md) | Build, install, versioning, migration |
| [15-conformance.md](15-conformance.md) | Required test scenarios |
| [16-decisions.md](16-decisions.md) | Design decisions and rationale; deferred items |

## Constraints

| # | Constraint | Consequence |
|---|---|---|
| C1 | Works with all major coding agents | Files + shell only. No agent-specific API required. |
| C2 | No background work | No daemon, cron, CI, hooks, MCP server, watcher. Every action is a foreground call inside a conversation. |
| C3 | No assumed system access | Binary optional. Every behavior has a no-binary path. |
| C4 | Binary is offline and model-free | No network, no LLM calls. Judgment goes back to the agent as questions. |
| C5 | Learning is visible | All writes land in the repo working tree. Curation, verification, spawning only on user request. |
| C6 | Repo is the only state | No user-global or machine state. Clone = full system. |

## Non-goals

User-level/global experts. Hosted service. Auto-commit. Editing code. Multiple `.experts/` roots per repo (deferred, see 16).

## Reading order

Implementers: 01 → 03 → 11 → 04 → 05 → 06 → 07 → 08 → 13 → 15.
Agent-protocol authors: 01 → 09 → 10.
