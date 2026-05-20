# ss-godot — AI Workflow Rules

These rules are MANDATORY for all code contributions, mirroring upstream `ss-unity` conventions adapted for Godot 4 / GDScript.

---

## A. General

### A.1 Spec-first
Never implement features outside `sdk_port_plan.html` or the current task. If unsure, **ask first**.

### A.2 Act decisively
Execute clear follow-up work (delete orphan refs, fix compile errors, clean dead imports) without asking. Ask only when wrong choice is costly (touching public API, renaming exported fields, deleting shared scenes).

### A.3 Evidence-backed
Every claim about behavior must cite `file:line` or be marked *"not verified in code"*. Format: `[sai_server.gd:42](addons/sai_services/core/sai_server.gd#L42)`.

### A.4 Temporary scripts
Prefix `_temp_` or place in `addons/sai_services/editor/_temp/`. Remind user to delete after use.

### A.5 Language
Code, identifiers, comments: **English only**. Vietnamese permitted only in user-facing docs and chat.

---

## B. GDScript

### B.1 One class per file
Each `.gd` contains one top-level class. File name = `class_name` in snake_case.

### B.2 Folder = module
Folders mirror upstream `Assets/SaiGame/Scripts/` (without numeric prefix): `0_Auth/` → `auth/`, `3_ItemContainer/Container/` → `item_container/container/`.

### B.3 Static typing
All public methods: typed params + typed return. Avoid `Variant` unless return shape is genuinely dynamic JSON.

### B.4 Signals over callbacks
Async results emit signals: `<verb>_success(data)`, `<verb>_failed(error)`. No `await` callback chains.

### B.5 Return shape
Async methods that return data use `Dictionary` with `{success: bool, error: String, data: Variant}`. GDScript has no exceptions — error code only.

### B.6 No magic strings
Endpoint paths, signal names, autoload keys: declare as `const String` at top of file.

### B.7 Singleton pattern
Only `SaiServer` is autoload. All sub-services are child `Node` of `SaiServer`. Don't add new autoloads.

### B.8 Inspector
Use `@export` for inspector-visible config. Annotate non-obvious fields with `@export_group` + comment.

### B.9 No work in `_process`
HTTP, file I/O, lookups: do them once in `_ready()` or on-demand. Never per-frame.

---

## C. Assets

### C.1 Resources
Use `Resource` subclass for DTOs that need inspector editing. Plain `Dictionary` for JSON pass-through.

### C.2 Scene & prefab edits
Edit `.tscn` in Godot editor, not text editor. Flag unexpected text diffs.

### C.3 `.gdkeep`
Empty module dirs include `.gdkeep` marker so git tracks them.

---

## D. Testing

### D.1 On demand
Don't write tests during implementation unless task says so. When asked, use GUT framework.

### D.2 Location
- Unit: `tests/unit/test_<feature>.gd`
- Integration: `tests/integration/test_<flow>.gd`

### D.3 Naming
Test methods: `test_<method>_<scenario>_<expected>()`.

---

## E. Reporting

### E.1 Compliance footer
Start or end each response with **Compliance** (OK) or **Warning** (rule cannot be met). State source task ID.

### E.2 End-of-task
List: files changed, temp scripts to clean, follow-ups for user.

---

## F. Port-specific

### F.1 Upstream reference
When porting, link upstream file: `// upstream: ss-unity/Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:30`.

### F.2 Behavior parity first
Match upstream signature + behavior exactly. Refactor only after passing parity test.

### F.3 Endpoint changes
Adding/changing a path → update `docs/endpoints.md` in same commit.

### F.4 AES test vector
Any change to `util/aes_helper.gd` must pass cross-platform vector test against .NET output.
