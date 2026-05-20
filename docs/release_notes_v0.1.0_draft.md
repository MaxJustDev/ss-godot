# Release notes — v0.1.0 (draft)

> **Status:** draft, finalized at M8.

## ss-godot v0.1.0 — first public release

Godot 4 port of [`SaiGame-studio/ss-unity`](https://github.com/SaiGame-studio/ss-unity) v0.2.40d. Distributable via Godot Asset Library and direct GitHub release zip.

### Highlights

- **10 service modules**: Auth (incl. Google login 2-step polling), GamerProgress, Mailbox, Inventory (8 sub-modules: Container, Crafting, Gacha, Generator, Item, Preset, Slot, Tag), Shop, Quest (Chain, Daily, Progressor), Journey, Leaderboard, BattleSessions, LuaScript.
- **62 distinct REST endpoint paths** (73 method+path rows) — see `docs/endpoints.md` for the full table with upstream `file:line` refs.
- **Single autoload** (`SaiServer`) auto-registers every sub-service on plugin enable.
- **Async API**: every method returns `{success, status, error, data}` Dictionary via `await`.
- **Zero dependencies**: only Godot built-ins (`HTTPRequest`, `JSON`, `AESContext`, `ConfigFile`).
- **Token persistence** at `user://sai_server.cfg`.

### Install

#### Godot Asset Library

1. Godot 4.3+ → **AssetLib** tab → search `SaiGame Services SDK` → Download → Install.
2. **Project Settings → Plugins** → enable `SaiGame Services SDK`.
3. Set `game_id` on the `SaiServer` autoload inspector.

#### Manual

Download `sai_services-v0.1.0.zip`, extract into your project's `addons/` folder.

### Quick start

```gdscript
extends Control

func _ready() -> void:
    SaiServer.auth.login_success.connect(_on_login_ok)

func _on_login_pressed() -> void:
    SaiServer.auth.login("alice", "secret")

func _on_login_ok(user: Dictionary) -> void:
    print("Welcome %s" % user.username)
```

See `docs/quick_start.md` and `docs/examples/` for per-module guides.

### Migration from Unity SDK

See `docs/migration_from_unity.md` — covers naming convention (snake_case), async pattern (`await` vs coroutines), signal vs callback translation, DTO mapping.

### Known limitations

- Asset Library icon is placeholder — replaced before submission.
- Lua scripts execute server-side only; SDK is a thin RPC wrapper.
- Web export: HTTPRequest CORS coordination with SaiGame may be needed (see `sdk_port_plan.html` §14 risk row).
- AES test vector verification was run as M1 gate — see `tests/aes_vectors.md` for the verification report.

### Acknowledgements

- Upstream Unity SDK by [SaiGame Studio](https://github.com/SaiGame-studio).
- AI-assisted port via Claude Code parallel agent dispatch (see `docs/agent_dispatch_plan.md`).

### Versioning

This port uses independent SemVer. `v0.1.0` tracks upstream `ss-unity` v0.2.40d.

### License

MIT. See `LICENSE`.
