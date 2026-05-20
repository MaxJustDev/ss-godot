## DailyQuestData - one entry returned by the today-quest / assign-ahead
## responses. Bundles the assignment metadata, the underlying quest
## definition, the per-player progress snapshot, and the resolved rewards.
##
## Server response shape (`DailyQuestEntryData`):
##   { assignment, quest, status, progress, rewards[] }
##
## upstream: 5_Quest/Daily/Models/DailyQuestEntryData.cs:11
class_name DailyQuestData
extends Resource

## upstream: DailyQuestEntryData.cs:14
@export var status: String = ""
## upstream: DailyAssignmentData.cs:11 (id) — assignment.id
@export var assignment_id: String = ""
## upstream: DailyAssignmentData.cs:15 — pool_id
@export var pool_id: String = ""
## upstream: DailyAssignmentData.cs:17 — assigned_date (yyyy-MM-dd)
@export var assigned_date: String = ""
## upstream: DailyAssignmentData.cs:18 — expires_at
@export var expires_at: String = ""

## Underlying quest definition (id, name, conditions, rewards, ...).
## upstream: DailyQuestEntryData.cs:13 (quest)
@export var quest: QuestData = null

## Raw progress dictionary as returned by the server (status, completed_at,
## claimed_at, ...). progress_data inside is dynamic — preserved as a sub-key.
## upstream: DailyQuestProgressData.cs:11
@export var progress: Dictionary = {}

## Resolved reward list (objects with reward_type, quantity_min/max,
## item_definition_id, item_definition).
## upstream: DailyRewardData.cs:11
@export var rewards: Array = []

# ── Convenience aliases used by `docs/examples/quest.md` ────────────────────
@export var id: String = ""  # mirrors assignment_id for client code
@export var completed: bool = false  # status == "completed" or "claimed"
@export var claimed: bool = false  # status == "claimed"


static func from_dict(d: Dictionary) -> DailyQuestData:
	var dq := DailyQuestData.new()
	if d == null:
		return dq
	dq.status = String(d.get("status", ""))

	var ass: Variant = d.get("assignment", {})
	if ass is Dictionary:
		dq.assignment_id = String(ass.get("id", ""))
		dq.pool_id = String(ass.get("pool_id", ""))
		dq.assigned_date = String(ass.get("assigned_date", ""))
		dq.expires_at = String(ass.get("expires_at", ""))
		dq.id = dq.assignment_id

	var quest_dict: Variant = d.get("quest", {})
	if quest_dict is Dictionary:
		dq.quest = QuestData.from_dict(quest_dict)
		# Quest-level status field on QuestData mirrors entry-level status
		# so a single QuestData object carries player status when surfaced
		# in chain-member lists. Daily uses dq.status directly.
		if dq.quest != null and dq.quest.status.is_empty():
			dq.quest.status = dq.status

	var prog: Variant = d.get("progress", {})
	dq.progress = prog if prog is Dictionary else {}

	var rew: Variant = d.get("rewards", [])
	dq.rewards = rew if rew is Array else []

	dq.completed = dq.status == "completed" or dq.status == "claimed"
	dq.claimed = dq.status == "claimed"
	return dq


func to_dict() -> Dictionary:
	return {
		"id": id,
		"status": status,
		"assignment_id": assignment_id,
		"pool_id": pool_id,
		"assigned_date": assigned_date,
		"expires_at": expires_at,
		"quest": quest.to_dict() if quest != null else null,
		"progress": progress,
		"rewards": rewards,
		"completed": completed,
		"claimed": claimed,
	}
