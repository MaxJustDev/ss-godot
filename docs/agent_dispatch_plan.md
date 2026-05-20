# Agent Dispatch Plan — ss-godot port

How AI subagents are dispatched to parallelize the port of `ss-unity` v0.2.40d → Godot 4.

## Principles

- **Critical path serial, leaves parallel.** Core (M1) blocks every module. Once core is stable, modules port independently in parallel.
- **One module = one agent.** Each subagent owns a single top-level folder under `Assets/SaiGame/Scripts/` (Auth, Progress, etc.). Avoids cross-module merge conflicts.
- **DTO + service in same dispatch.** Subagent ports both `RequestX.cs` and DTOs in one task to keep schema + caller consistent.
- **Discovery before port.** Dedicated agent extracts endpoint table from upstream before any module port begins (prevents N agents independently re-discovering the same routes).
- **Verification gate.** Each module agent must run GUT tests + emit a checklist before marking task complete. Use `superpowers:verification-before-completion`.

## Dispatch graph

```
                         [discovery]
                              |
                              v
                          [M1 core] ----------------------+
                              |                            |
              +---------------+---------------+            |
              |               |               |            |
              v               v               v            |
          [M2 auth] (BLOCKS everything below — token mgmt) |
              |                                            |
   +----------+----------+----------+----------+----------+----------+----------+
   |          |          |          |          |          |          |          |
   v          v          v          v          v          v          v          v
[progress] [mailbox] [inventory] [shop]    [quest]  [journey] [leaderbd] [battle] [lua_script]
   M3        M3        M4         M5        M5         M6        M6        M6        M6
                       (largest — 8 subdirs)
   |          |          |          |          |          |          |          |
   +----------+----------+----------+----------+----------+----------+----------+
                              |
                              v
                       [M7 docs polish]
                              |
                              v
                  [M8 Asset Library submit]
```

## Agent assignments

| Milestone | Tasks | Agent type | Parallelism | Background? |
|-----------|-------|------------|-------------|-------------|
| M0 setup | Repo skeleton, license, README, CHANGELOG, gitignore | (main thread) | — | no |
| Discovery | Endpoint extraction from upstream | `general-purpose` (web + grep) | 1 | yes |
| M1 core | `sai_server.gd`, `aes_helper.gd`, `json_helper.gd`, base classes | `general-purpose` | 1 (critical path) | no |
| M1 AES test | Cross-platform test vectors vs .NET | `general-purpose` | 1 | yes (parallel to M1 core) |
| M2 auth | `sai_auth.gd`, `google_backend_login.gd`, DTOs | `general-purpose` | 1 (blocks rest) | no |
| M3+ modules | One agent per module | `general-purpose` | 9 in parallel | yes |
| Tests per module | GUT unit + mock-server integration | bundled with module agent | parallel | yes |
| M7 docs | API ref auto-gen, migration guide, examples | `general-purpose` | 1–3 parallel | yes |
| M8 submit | Asset Library checklist | (main thread) | — | no |

## Subagent prompt template

```
PORT TASK: <upstream_path> → <godot_path>

Context:
- Upstream is C# Unity. Target is GDScript Godot 4.3+.
- Follow design rules in addons/sai_services/README.md and sdk_port_plan.html §4.
- All public API: signals, snake_case, static typing, Dictionary return {success, error, data}.
- Use SaiServer.* helpers (already implemented in core/).

Files to read first:
- ss-unity upstream: <list .cs files>
- Existing port: <list any sibling .gd already done>

Deliverables:
1. <module>/<name>.gd implementing all public methods from upstream.
2. <module>/dto/*.gd for typed DTOs (Resource subclass when inspector needed, plain Dictionary otherwise).
3. tests/unit/test_<name>.gd with GUT cases covering happy path + error path + signal emission.
4. docs/examples/<name>.md with minimal usage snippet.

Constraints:
- No new dependencies.
- No business logic beyond upstream feature parity.
- English-only code + comments (upstream rule A.6).
- One top-level class per file (upstream rule B.1).
- Mark task complete only after: lint passes (gdtoolkit), GUT tests pass, demo scene smoke-tested.

Out of scope:
- API redesign — port 1:1 to start, refactor later.
- Cross-module coupling — keep this module self-contained.
```

## Concurrency limits

- **Max 4 parallel module agents** at a time to avoid exhausting context budget and creating merge churn.
- Use `git` branches per agent: `port/m4-inventory`, `port/m5-quest`, etc. PR back to `main` only after agent self-verifies.
- Run module agents in **background mode** when possible — main thread reviews completed agents and merges.

## Coordination state

Tracked in this repo:

- `docs/endpoints.md` — single source of truth for HTTP routes. Updated by discovery agent only.
- `CHANGELOG.md [Unreleased]` — each module agent appends its entry.
- `tests/integration/test_end_to_end.gd` — main thread maintains.

## Risk-driven adjustments

| Risk (from plan §14) | Mitigation in dispatch |
|----------------------|------------------------|
| AES Godot ↔ .NET mismatch | Dedicated M1 AES test-vector agent — runs **parallel** to M1 core, blocks M2 if mismatch. |
| HTTPRequest Web export quirks | M2 auth agent tests Web export early; if broken, opens follow-up issue rather than blocking. |
| Effort overrun | Path B: ship M2+M3+M4 first (Auth + Progress + Inventory). M5–M6 post-launch. Dispatch order in roadmap reflects this priority. |
| API breaking change upstream | Nightly smoke agent (CronCreate) — `general-purpose` against staging API. |

## Status tracking

Use `TaskCreate` / `TaskUpdate` per dispatched agent. Each task records:
- `subject`: module name
- `description`: deliverables + verification gate
- `owner`: agent id
- `blockedBy`: dependency tasks (M1 blocks all module tasks)

Re-read `TaskList` between dispatches to spot newly unblocked work.
