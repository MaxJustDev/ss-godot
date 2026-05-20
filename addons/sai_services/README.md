# SaiGame Services SDK (Godot)

Godot 4 port of `SaiGame-studio/ss-unity` v0.2.40d.

## Enable

**Project Settings → Plugins** → check `SaiGame Services SDK`.

Autoload `SaiServer` is registered automatically.

## Configure

Open `SaiServer` autoload in the inspector:

- `game_id` — your SaiGame game identifier.
- `use_local_endpoint` — toggle between `https://api.saigame.studio` (off) and `http://local-api.saigame.studio:82` (on).
- `request_timeout_sec` — HTTP timeout (default 30s).

## API surface

```gdscript
SaiServer.base_url() -> String
SaiServer.is_authenticated() -> bool
SaiServer.set_tokens(access: String, refresh: String) -> void
SaiServer.clear_tokens() -> void
```

Sub-services (M2+):

```gdscript
SaiServer.auth          # SaiAuth
SaiServer.progress      # GamerProgress
SaiServer.mailbox       # Mailbox
SaiServer.inventory     # PlayerContainer (item_container root)
SaiServer.shop          # Shop
SaiServer.quest         # Quest
SaiServer.journey       # PlayerEvent
SaiServer.leaderboard   # Leaderboard
SaiServer.battle        # BattleSessions
SaiServer.lua_script    # LuaScriptManager
```

## Signals

```gdscript
SaiServer.token_refreshed(access_token: String)
SaiServer.auth_required()
```

## Status

`v0.1.0-dev` — M0 skeleton. See [../../CHANGELOG.md](../../CHANGELOG.md) and [../../sdk_port_plan.html](../../sdk_port_plan.html).
