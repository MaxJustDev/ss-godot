# Quick start

## Install

### Option A — Godot Asset Library (after v0.1.0 release)

1. Open Godot 4.3+.
2. **AssetLib** tab → search `SaiGame Services SDK` → **Download** → **Install**.
3. **Project Settings → Plugins** → enable `SaiGame Services SDK`.
4. Autoload `SaiServer` appears under Project Settings → Globals.

### Option B — Manual

1. Download latest release zip from <https://github.com/MaxJustDev/ss-godot/releases>.
2. Extract `sai_services/` into your project's `addons/` folder.
3. Enable the plugin as in Option A.

## Configure

Open `SaiServer` autoload (Globals tab) and set:

| Field | Type | Description |
|-------|------|-------------|
| `game_id` | String | Your SaiGame game identifier (provided by SaiGame studio) |
| `use_local_endpoint` | bool | Toggle production / local dev base URL |
| `request_timeout_sec` | float | HTTP timeout (default 30s) |

## First call — login

```gdscript
extends Control

@onready var username_field: LineEdit = $Username
@onready var password_field: LineEdit = $Password

func _ready() -> void:
    SaiServer.auth.login_success.connect(_on_login_ok)
    SaiServer.auth.login_failed.connect(_on_login_err)

func _on_login_pressed() -> void:
    SaiServer.auth.login(username_field.text, password_field.text)

func _on_login_ok(user: Dictionary) -> void:
    print("Logged in as %s" % user.username)
    get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_login_err(error: String) -> void:
    push_error("Login failed: %s" % error)
```

## Common flows

### Fetch progress

```gdscript
var result := await SaiServer.progress.get_progress()
if result.success:
    print("XP: %d, Gold: %d" % [result.data.xp, result.data.gold])
```

### Save progress

```gdscript
SaiServer.progress.update_progress({"xp": 1500, "gold": 250})
```

### Buy item

```gdscript
SaiServer.shop.purchase_success.connect(func(item_id): print("Bought %s" % item_id))
SaiServer.shop.purchase("item_sword_01", 1)
```

### Start battle session

```gdscript
var session := await SaiServer.battle.create_session({"map": "arena_01"})
SaiServer.battle.send_event(session.id, "kill", {"target": "boss_01"})
await SaiServer.battle.finish_session(session.id, {"result": "win"})
```

## Next

- Full API: [api_reference.md](api_reference.md)
- Migration from Unity SDK: [migration_from_unity.md](migration_from_unity.md)
- Per-module examples: [examples/](examples/)
