# ss-godot

**SaiGame Services SDK for Godot 4** — REST client SDK port of [ss-unity](https://github.com/SaiGame-studio/ss-unity) v0.2.40d.

[![Godot](https://img.shields.io/badge/Godot-4.3%2B-478cbf)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0--dev-orange)](CHANGELOG.md)

> ⚠ **Status: M0 skeleton (in development).** Not production-ready. See [CHANGELOG](CHANGELOG.md) and [roadmap](sdk_port_plan.html).

## Features (planned)

| Module | Upstream | Status |
|--------|----------|--------|
| Core (HTTP, token mgmt, AES) | `SaiServer.cs` + `Common/` | M1 |
| Auth | `0_Auth/` | M2 |
| GamerProgress | `1_GamerProgress/` | M3 |
| Mailbox | `2_Mailbox/` | M3 |
| ItemContainer (Inventory) | `3_ItemContainer/` | M4 |
| Shop | `4_Shop/` | M5 |
| Quest | `5_Quest/` | M5 |
| Journey | `6_Journey/` | M6 |
| Leaderboard | `7_Leaderboard/` | M6 |
| Battle Sessions | `8_Battle/` | M6 |
| LuaScript | `9_LuaScript/` | M6 |

## Quick start

### Install (after first release)

1. Godot editor → **AssetLib** → search `SaiGame Services SDK` → Download → Install.
2. **Project Settings → Plugins** → Enable `SaiGame Services SDK`.
3. Autoload `SaiServer` appears automatically.
4. Set `game_id` on `SaiServer` autoload inspector.

### Install (development, from this repo)

```bash
git clone https://github.com/MaxJustDev/ss-godot.git
# Copy addons/sai_services/ into your Godot project's addons/ folder
```

### Usage example

```gdscript
extends Control

func _on_login_pressed() -> void:
    var auth: SaiAuth = SaiServer.get_node("SaiAuth")
    auth.login_success.connect(_on_login_ok)
    auth.login_failed.connect(_on_login_err)
    auth.login(username_field.text, password_field.text)

func _on_login_ok(user: Dictionary) -> void:
    print("Welcome %s" % user.username)
    get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_login_err(error: String) -> void:
    show_toast("Login failed: %s" % error)
```

## Project layout

```
addons/sai_services/      ← plugin (this is what AssetLib distributes)
demo/                     ← demo project showcasing all modules
tests/                    ← GUT unit + integration tests
docs/                     ← API reference, migration guide, examples
sdk_port_plan.html        ← full port plan & roadmap
```

## Documentation

- [Port plan & roadmap](sdk_port_plan.html)
- [Agent dispatch plan](docs/agent_dispatch_plan.md)
- [Endpoint reference](docs/endpoints.md)
- [Migration from Unity SDK](docs/migration_from_unity.md) *(WIP)*

## License

[MIT](LICENSE). Port of `SaiGame-studio/ss-unity` published as derivative work.

> Upstream `ss-unity` does not include an explicit LICENSE file at the time of this port. See [LICENSE](LICENSE) "Upstream attribution" for full disclosure.

## Contributing

PRs welcome. Read [CLAUDE.md](CLAUDE.md) for AI-assisted workflow rules (mirrors upstream Unity project conventions, adapted for Godot/GDScript).
