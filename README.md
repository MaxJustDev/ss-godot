# ss-godot

**SaiGame Services SDK for Godot 4** — REST client SDK port of [ss-unity](https://github.com/SaiGame-studio/ss-unity) v0.2.40d.

[![Godot](https://img.shields.io/badge/Godot-4.3%2B-478cbf)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-orange)](CHANGELOG.md)

> **Status: v0.1.0 — first public release.** Tracks ss-unity v0.2.40d. 62 distinct REST endpoints, 10 service modules. See [CHANGELOG](CHANGELOG.md).

<!-- TODO: add screenshot before v0.1.0 release -->

## Quick start

```gdscript
# Anywhere in your game (the SaiServer autoload is registered by the plugin).
SaiServer.auth.login_success.connect(func(user): print("Welcome ", user.username))
SaiServer.auth.login_failed.connect(func(error): push_error(error))
SaiServer.auth.login(username, password)
```

That's it — tokens persist automatically to `user://sai_server.cfg`, subsequent app launches start authenticated.

See [`docs/quick_start.md`](docs/quick_start.md) for full setup, [`docs/examples/`](docs/examples/) for a per-module example, and [`docs/api_reference.md`](docs/api_reference.md) for the full API.

## Features

| Module | Upstream | Status |
|--------|----------|--------|
| Core (HTTP, token mgmt, AES) | `SaiServer.cs` + `Common/` | Done |
| Auth | `0_Auth/` | Done |
| GamerProgress | `1_GamerProgress/` | Done |
| Mailbox | `2_Mailbox/` | Done |
| ItemContainer (Inventory) | `3_ItemContainer/` | Done |
| Shop | `4_Shop/` | Done |
| Quest | `5_Quest/` | Done |
| Journey | `6_Journey/` | Done |
| Leaderboard | `7_Leaderboard/` | Done |
| Battle Sessions | `8_Battle/` | Done |
| LuaScript | `9_LuaScript/` | Done |

## Modules at a glance

| Accessor | Class | One-liner |
|----------|-------|-----------|
| `SaiServer.auth` | `SaiAuth` | Register / login / refresh / logout / me. |
| `SaiServer.google_login` | `GoogleBackendLogin` | Google OAuth via backend-hosted session. |
| `SaiServer.progress` | `GamerProgress` | Per-player level / XP / gold / opaque game_data. |
| `SaiServer.mailbox` | `Mailbox` | Server-pushed messages with reward attachments. |
| `SaiServer.inventory` | `PlayerContainer` (+ 9 siblings) | Items, slots, crafting, gacha, presets, tags, generators. |
| `SaiServer.shop` | `Shop` | List shops, list items, purchase. |
| `SaiServer.quest` | `ChainQuest` (+ progressor / daily / history) | Chain, daily, progressor, history facade. |
| `SaiServer.journey` | `PlayerEvent` | Telemetry / analytics event stream. |
| `SaiServer.leaderboard` | `Leaderboard` | Ranked boards, top-N, my-rank. |
| `SaiServer.battle` | `BattleSessions` (+ `BattleScript`) | Battle session log + server-Lua RPC. |
| `SaiServer.lua_script` | `LuaScriptManager` | Generic server-Lua RPC + script admin. |

## Install (development, from this repo)

```bash
git clone https://github.com/MaxJustDev/ss-godot.git
# Copy or symlink addons/sai_services/ into your Godot project's addons/ folder.
```

## Install (after first release)

1. Godot editor → **AssetLib** → search `SaiGame Services SDK` → Download → Install.
2. **Project Settings → Plugins** → Enable `SaiGame Services SDK`.
3. Autoload `SaiServer` appears automatically.
4. Set `game_id` on the `SaiServer` autoload inspector.

## Project layout

```
addons/sai_services/   plugin (this is what AssetLib distributes)
demo/                  demo project showcasing the SDK
tests/                 GUT unit + integration tests + mock backend
docs/                  API reference, quick-start, examples, migration guide
sdk_port_plan.html     full port plan & roadmap
```

## Documentation

- [Quick start](docs/quick_start.md)
- [API reference](docs/api_reference.md)
- [Per-module examples](docs/examples/)
- [Endpoint reference (62 endpoints)](docs/endpoints.md)
- [Migration from Unity SDK](docs/migration_from_unity.md)
- [Asset Library submission notes](docs/asset_library_submission.md)
- [Release notes draft](docs/release_notes_v0.1.0_draft.md)
- [Port plan & roadmap](sdk_port_plan.html)

## License

[MIT](LICENSE). Port of `SaiGame-studio/ss-unity` published as derivative work.

> Upstream `ss-unity` does not include an explicit LICENSE file at the time of this port. See [LICENSE](LICENSE) "Upstream attribution" for full disclosure.

## Contributing

PRs welcome. Read [CLAUDE.md](CLAUDE.md) for AI-assisted workflow rules (mirrors upstream Unity project conventions, adapted for Godot/GDScript).
