# Example — Quests (chain, daily, progressor, history)

Four quest sub-services, all reachable through the unified `SaiServer.quest` facade (alias of `chain_quest`) or their own dedicated accessors:

| Accessor | Class | Purpose |
|----------|-------|---------|
| `SaiServer.quest` (alias `chain_quest`) | `ChainQuest` | List chains + facade for daily / progressor / history. |
| `SaiServer.quest_progressor` | `QuestProgressor` | Start quests, increment progress, claim. |
| `SaiServer.daily_quest` | `DailyQuest` | Daily quest pools and today's roster. |
| `SaiServer.quest_history` | `QuestHistory` | Past claims and per-quest status. |

## List active chain quests

```gdscript
var result := await SaiServer.quest.list_chain()
if result.success:
    # `data.chains` is the raw chain list. Each entry is a Dictionary.
    for c in result.data.chains:
        print("%s (%s)" % [c.id, c.get("chain_key", "")])
```

## Chain detail / tree

```gdscript
var detail := await SaiServer.quest.get_chain_tree(chain_id)
if detail.success:
    # `data.steps` is Array[QuestStep], a flattened pre-order traversal.
    print("Step %d of %d" % [detail.data.current_step, detail.data.total_steps])
    for step in detail.data.steps:
        print("  %s — %s" % [step.quest_name, step.status])
```

## Advance / claim a chain quest

```gdscript
SaiServer.quest.chain_advance_success.connect(_on_advance)
await SaiServer.quest.advance_chain(quest_definition_id)
# Signal signature: chain_advance_success(chain_id: String, data: Dictionary)
func _on_advance(_chain_id: String, _data: Dictionary) -> void:
    pass

# Claim rewards from a completed chain quest.
await SaiServer.quest.claim_quest(quest_definition_id)
```

## Daily quests

```gdscript
# List configured daily pools.
var pools := await SaiServer.daily_quest.list_daily_pools()

# Fetch today's quests for one pool.
var today := await SaiServer.quest.list_daily(pool_id)
if today.success:
    for q in today.data.quests:
        # `q` is a DailyQuestData Resource.
        if q.is_completed and not q.is_claimed:
            await SaiServer.quest.claim_daily(q.quest_definition_id)
```

`SaiServer.quest.list_daily(pool_id)` is a facade for `SaiServer.daily_quest.list_daily(pool_id)`. Same return shape; pick whichever reads better in context.

## Progressor — increment objective counter

```gdscript
# Player killed a goblin (objective_code is server-defined).
await SaiServer.quest.increment_progress("kill_goblin", 1)

# Player collected 3 crystals.
await SaiServer.quest.increment_progress("collect_crystal", 3)
```

The same call lives at `SaiServer.quest_progressor.increment_progress(...)` if you'd rather hit the sub-service directly. Listen on the progressor for completion:

```gdscript
SaiServer.quest_progressor.quest_completed.connect(func(quest_id):
    print("Quest done: %s" % quest_id)
)
```

## Status / history

```gdscript
# Per-quest current status (cached after fetch).
var status := await SaiServer.quest.quest_status(quest_definition_id)

# Past claim log.
var hist := await SaiServer.quest.history(50)  # limit, offset
if hist.success:
    for claim in hist.data.entries:
        print(claim)  # raw Dictionary, server-defined shape
```
