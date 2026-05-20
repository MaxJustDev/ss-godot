## QuestClaimRecord - one entry returned by the quest-claims history endpoint
## and by `POST .../claim` itself.
##
## Server shape:
##   { id, studio_id, game_id, user_id, quest_definition_id, progress_id,
##     idempotency_key, rewards_granted[], claimed_at, quest_definition }
##
## upstream: 5_Quest/Claims/Models/QuestClaimRecord.cs:10
class_name QuestClaimRecord
extends Resource

## upstream: QuestClaimRecord.cs:12
@export var id: String = ""
## upstream: QuestClaimRecord.cs:13
@export var studio_id: String = ""
## upstream: QuestClaimRecord.cs:14
@export var game_id: String = ""
## upstream: QuestClaimRecord.cs:15
@export var user_id: String = ""
## upstream: QuestClaimRecord.cs:16
@export var quest_definition_id: String = ""
## upstream: QuestClaimRecord.cs:17
@export var progress_id: String = ""
## upstream: QuestClaimRecord.cs:18
@export var idempotency_key: String = ""
## Raw `rewards_granted` array as parsed JSON. Each entry is a
## `ClaimQuestGrantedReward` Dictionary.
## upstream: QuestClaimRecord.cs:20 / ClaimQuestGrantedReward.cs:9
@export var rewards_granted: Array = []
## upstream: QuestClaimRecord.cs:21
@export var claimed_at: String = ""
## Embedded quest definition. Optional — may be null for compact responses.
## upstream: QuestClaimRecord.cs:23
@export var quest_definition: QuestData = null

# ── Convenience aliases used by the history projection ─────────────────────
@export var completed_at: String = ""  # mirrors claimed_at
@export var title: String = ""  # mirrors quest_definition.name


static func from_dict(d: Dictionary) -> QuestClaimRecord:
	var c := QuestClaimRecord.new()
	if d == null:
		return c
	c.id = String(d.get("id", ""))
	c.studio_id = String(d.get("studio_id", ""))
	c.game_id = String(d.get("game_id", ""))
	c.user_id = String(d.get("user_id", ""))
	c.quest_definition_id = String(d.get("quest_definition_id", ""))
	c.progress_id = String(d.get("progress_id", ""))
	c.idempotency_key = String(d.get("idempotency_key", ""))
	var rew: Variant = d.get("rewards_granted", [])
	c.rewards_granted = rew if rew is Array else []
	c.claimed_at = String(d.get("claimed_at", ""))
	c.completed_at = c.claimed_at
	var qd: Variant = d.get("quest_definition", null)
	if qd is Dictionary:
		c.quest_definition = QuestData.from_dict(qd)
		c.title = c.quest_definition.name
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"user_id": user_id,
		"quest_definition_id": quest_definition_id,
		"progress_id": progress_id,
		"idempotency_key": idempotency_key,
		"rewards_granted": rewards_granted,
		"claimed_at": claimed_at,
		"completed_at": completed_at,
		"title": title,
		"quest_definition": quest_definition.to_dict() if quest_definition != null else null,
	}
