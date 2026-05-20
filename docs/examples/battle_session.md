# Example — Battle session

Track battles via server-hosted Lua scripts. Upstream `ss-unity` v0.2.40d exposes 2 wire endpoints: list past sessions, and a generic script dispatcher.

> **v0.1.0 architecture:** session lifecycle (create / send_event / finish) is implemented through `BattleScript.run_script(...)` calls to server-hosted Lua, not dedicated REST routes. The mock server recognises three magic script names (`create_session`, `send_event`, `finish_session`) so client code can use the high-level wrappers below or call `run_script` directly.

## High-level wrappers (call server-side Lua under the hood)

```gdscript
extends Node

var current_session_id: String = ""

func _ready() -> void:
    SaiServer.battle.session_created.connect(_on_session_created)
    SaiServer.battle.session_finished.connect(_on_session_finished)


func start_match(map_id: String) -> void:
    var result := await SaiServer.battle_script.run_script("create_session", {
        "map": map_id,
        "started_at": Time.get_unix_time_from_system(),
    })
    if result.success:
        current_session_id = result.data.raw.session_id


func on_enemy_killed(enemy_id: String) -> void:
    SaiServer.battle_script.run_script("send_event", {
        "session_id": current_session_id,
        "type": "kill",
        "payload": {"target": enemy_id, "ts": Time.get_unix_time_from_system()},
    })


func end_match(victory: bool) -> void:
    var summary := await SaiServer.battle_script.run_script("finish_session", {
        "session_id": current_session_id,
        "result": "win" if victory else "loss",
    })
    if summary.success:
        print("XP earned: %d" % summary.data.raw.xp_gained)
        print("Gold earned: %d" % summary.data.raw.gold_gained)
```

## List past sessions (read endpoint)

```gdscript
var result := await SaiServer.battle_sessions.list_sessions(20)  # limit
for session in result.data.sessions:
    # BattleData fields: id, status, started_at, ended_at, start_data, end_data.
    print(session.id, session.status, session.started_at)
```

## Generic battle script (any server-side logic)

`BattleScript.run_script` forwards request body opaquely and returns the response under `result.data.raw`. Define your script contracts server-side and document them in your game's docs:

```gdscript
var result := await SaiServer.battle_script.run_script("damage_calc", {
    "attacker": attacker_id,
    "defender": defender_id,
    "ability": "fireball",
})
if result.success:
    print("Damage dealt: %d" % result.data.raw.damage)
```

## Reserved client API (future-proofing)

`SaiServer.battle.create_session()`, `send_event()`, `finish_session()` are reserved signatures returning `{success: false, error: "not_implemented"}` until upstream ships dedicated routes. Subscribe to the matching signals so your code works transparently once they ship:

```gdscript
SaiServer.battle.session_created.connect(...)
SaiServer.battle.event_sent.connect(...)
SaiServer.battle.session_finished.connect(...)
```
