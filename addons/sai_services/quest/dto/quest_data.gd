## QuestData - typed mirror of the upstream `QuestDefinitionData` JSON plus
## the chain/member envelope fields used by the API responses.
##
## Used as the canonical DTO for a single quest (chain member, daily entry,
## or status snapshot). The `current_step`/`total_steps` projection asked
## for by `docs/examples/quest.md` is computed from `progress.status`+chain
## context at the call site — see `chain_quest.gd::_count_steps`.
##
## upstream: 5_Quest/Chain/Models/QuestDefinitionData.cs:11
class_name QuestData
extends Resource

## upstream: QuestDefinitionData.cs:12
@export var id: String = ""
## upstream: QuestDefinitionData.cs:13
@export var studio_id: String = ""
## upstream: QuestDefinitionData.cs:14
@export var game_id: String = ""
## upstream: QuestDefinitionData.cs:15
@export var code_name: String = ""
## Title shown to the player. Aliased as `title` in the example doc.
## upstream: QuestDefinitionData.cs:16
@export var name: String = ""
## upstream: QuestDefinitionData.cs:17
@export var description: String = ""
## upstream: QuestDefinitionData.cs:18
@export var quest_type: String = ""
## Raw JSON-as-Dictionary for the `conditions` block. Server-defined shape.
## upstream: QuestDefinitionData.cs:19
@export var conditions: Dictionary = {}
## Raw `rewards` array as parsed JSON. Each entry is `{reward_type, amount, quantity, item_definition_id}`.
## upstream: QuestDefinitionData.cs:20
@export var rewards: Array = []
## upstream: QuestDefinitionData.cs:21
@export var is_active: bool = true
## upstream: QuestDefinitionData.cs:22
@export var is_hidden: bool = false
## upstream: QuestDefinitionData.cs:23
@export var sort_order: int = 0
## upstream: QuestDefinitionData.cs:24
@export var created_at: String = ""
## upstream: QuestDefinitionData.cs:25
@export var updated_at: String = ""

## Per-player status when this quest is delivered through a list endpoint
## (chain members, daily entries). Not part of the raw definition. Empty
## when the source response does not carry a player status.
## upstream: 5_Quest/Chain/Models/ChainMemberData.cs:18 (status)
@export var status: String = ""

## Convenience alias used by `docs/examples/quest.md`. Always mirrors `name`.
@export var title: String = ""


## Build a QuestData from a raw quest-definition Dictionary. Missing keys
## default to the zero value of their type. Extra keys are ignored.
##
## upstream: behavioural parity with JsonUtility.FromJson<QuestDefinitionData>.
static func from_dict(d: Dictionary) -> QuestData:
	var q := QuestData.new()
	if d == null:
		return q
	q.id = String(d.get("id", ""))
	q.studio_id = String(d.get("studio_id", ""))
	q.game_id = String(d.get("game_id", ""))
	q.code_name = String(d.get("code_name", ""))
	q.name = String(d.get("name", ""))
	q.title = q.name
	q.description = String(d.get("description", ""))
	q.quest_type = String(d.get("quest_type", ""))
	var cnd: Variant = d.get("conditions", {})
	q.conditions = cnd if cnd is Dictionary else {}
	var rew: Variant = d.get("rewards", [])
	q.rewards = rew if rew is Array else []
	q.is_active = bool(d.get("is_active", true))
	q.is_hidden = bool(d.get("is_hidden", false))
	q.sort_order = int(d.get("sort_order", 0))
	q.created_at = String(d.get("created_at", ""))
	q.updated_at = String(d.get("updated_at", ""))
	q.status = String(d.get("status", ""))
	return q


## Inverse of `from_dict`.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"code_name": code_name,
		"name": name,
		"title": title,
		"description": description,
		"quest_type": quest_type,
		"conditions": conditions,
		"rewards": rewards,
		"is_active": is_active,
		"is_hidden": is_hidden,
		"sort_order": sort_order,
		"created_at": created_at,
		"updated_at": updated_at,
		"status": status,
	}
