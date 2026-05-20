## QuestStep - one node inside a chain-quest tree response.
##
## Mirrors `QuestTreeNode` from the chains/tree endpoint, plus a derived
## `current_step` / `total_steps` projection used by `docs/examples/quest.md`.
## A `QuestStep` chain is a flattened pre-order walk of the tree, with
## `current_step` set to the first node whose status is `in_progress` (or the
## last completed node if none is active).
##
## upstream: 5_Quest/Chain/Models/QuestTreeNode.cs:11
class_name QuestStep
extends Resource

## upstream: QuestTreeNode.cs:13
@export var quest_id: String = ""
## upstream: QuestTreeNode.cs:14
@export var quest_name: String = ""
## upstream: QuestTreeNode.cs:15 — not_started | in_progress | completed | claimed
@export var status: String = ""
## Children QuestStep nodes (parsed recursively from the response). May be
## empty when the chain is linear.
## upstream: QuestTreeNode.cs:16
@export var children: Array = []

## Position of this step in the pre-order flattened chain (0-based).
## Computed locally; not part of the wire response.
@export var step_index: int = 0


## Build a single QuestStep from a raw `nodes[]` dictionary. Recurses into
## `children`. Missing keys default to zero values.
##
## upstream: behavioural parity with JsonUtility.FromJson<QuestTreeNode>.
static func from_dict(d: Dictionary) -> QuestStep:
	var s := QuestStep.new()
	if d == null:
		return s
	s.quest_id = String(d.get("quest_id", ""))
	s.quest_name = String(d.get("quest_name", ""))
	s.status = String(d.get("status", ""))
	var raw_children: Variant = d.get("children", [])
	if raw_children is Array:
		var out: Array = []
		for c in raw_children:
			if c is Dictionary:
				out.append(from_dict(c))
		s.children = out
	return s


## Flatten a tree (root array) to a pre-order list of QuestStep, assigning
## `step_index` along the way. Used to compute `current_step / total_steps`.
static func flatten(roots: Array) -> Array:
	var out: Array = []
	for r in roots:
		if r is QuestStep:
			_flatten_node(r, out)
	return out


static func _flatten_node(node: QuestStep, out: Array) -> void:
	node.step_index = out.size()
	out.append(node)
	for c in node.children:
		if c is QuestStep:
			_flatten_node(c, out)


func to_dict() -> Dictionary:
	var kids: Array = []
	for c in children:
		if c is QuestStep:
			kids.append(c.to_dict())
	return {
		"quest_id": quest_id,
		"quest_name": quest_name,
		"status": status,
		"children": kids,
		"step_index": step_index,
	}
