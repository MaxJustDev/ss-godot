# Example — Gamer Progress

Track per-game player progress (level, XP, gold, arbitrary `game_data`).

## Endpoints

| Method | Path |
|--------|------|
| POST | `/api/v1/games/{game_id}/gamer-progress` |
| GET  | `/api/v1/games/{game_id}/my-gamer-progress` |
| PATCH | `/api/v1/gamer-progress/{progress_id}` |
| DELETE | `/api/v1/games/{game_id}/my-gamer-progress` |

## Create initial progress (after register / login)

```gdscript
var result := await SaiServer.progress.create({
    "experience": 0,
    "gold": 100,
    "game_data": {"tutorial_done": false},
})
if result.success:
    print("progress id: %s" % result.data.id)
```

## Fetch my progress

```gdscript
var result := await SaiServer.progress.get_mine()
if result.success:
    print("Level %d, XP %d, Gold %d" % [
        result.data.level, result.data.experience, result.data.gold,
    ])
```

## Apply deltas

```gdscript
SaiServer.progress.update_success.connect(_on_update_ok)
SaiServer.progress.update(progress_id, {
    "experience_delta": 250,
    "gold_delta": -50,
    "game_data": {"chapter": 2},
})
```

`game_data` is opaque JSON — store anything game-specific (saved scene state, settings, unlocked content).

## Reset

```gdscript
await SaiServer.progress.delete_mine()
# Server-side wipe. User can call `create()` again to restart.
```
