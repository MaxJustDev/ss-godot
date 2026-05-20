# Example — Leaderboard

Read-only ranking by server-managed metric (XP, win count, kill count, etc.).

> **v0.1.0 limitation:** upstream `ss-unity` v0.2.40d exposes only **read** endpoints. `submit` + `around_me` are reserved on the client (signals exist) but currently no-op until backend ships them.

## List available boards

```gdscript
var result := await SaiServer.leaderboard.list_boards()
for board in result.data.boards:
    # LeaderboardData fields: id, board_key, name, description, score_mode,
    # sort_direction, reset_schedule, is_active, score_source_type, ...
    print("%s — %s" % [board.id, board.name])
```

## Get board metadata

```gdscript
var board := await SaiServer.leaderboard.get_board("global_xp")
if board.success:
    # `data` is a LeaderboardData Resource.
    print(board.data.name, board.data.score_source_type)
```

## Fetch top N

```gdscript
var result := await SaiServer.leaderboard.top("global_xp", 50)
for entry in result.data.entries:
    # LeaderboardEntry fields: rank, user_id, display_name, score, metadata, updated_at.
    print("%d. %s — %s" % [entry.rank, entry.display_name, entry.score])
```

## My current rank

```gdscript
var me := await SaiServer.leaderboard.my_rank("global_xp")
if me.success:
    # `data` is a LeaderboardLocalRank Resource (rank, user_id, score, ...).
    print("My rank: %d (score %s)" % [me.data.rank, me.data.score])
```

## Combine top + me for "around-me" UI

Until the backend ships a true `around_me` endpoint, compose two calls client-side:

```gdscript
var top := await SaiServer.leaderboard.top("global_xp", 100)
var me := await SaiServer.leaderboard.my_rank("global_xp")

# Render top list, highlight the row matching `me.data.user_id`.
# If `me.data.rank` is outside top 100, append a separator row + the player's entry.
```

## Score submission (future)

```gdscript
# Reserved API — currently returns {success: false, error: "...not in upstream v0.2.40d"}.
# Subscribe to the signal so it works transparently once the backend ships it.
SaiServer.leaderboard.submit_success.connect(_on_submit_ok)
SaiServer.leaderboard.submit("weekly_arena", 12450)
```

## Multiple boards

```gdscript
var board_ids := ["global_xp", "weekly_pvp", "guild_contrib"]
var results := []
for id in board_ids:
    results.append(await SaiServer.leaderboard.top(id, 10))
```
