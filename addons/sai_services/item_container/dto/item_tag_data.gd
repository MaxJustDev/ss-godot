## ItemTagData - typed mirror of a single item tag record.
##
## `metadata` is kept as a raw JSON string.
##
## upstream: 3_ItemContainer/Tag/ItemTagData.cs:7
class_name ItemTagData
extends Resource

## upstream: ItemTagData.cs:9
@export var id: String = ""
## upstream: ItemTagData.cs:10
@export var studio_id: String = ""
## upstream: ItemTagData.cs:11
@export var game_id: String = ""
## upstream: ItemTagData.cs:12
@export var tag_key: String = ""
## upstream: ItemTagData.cs:13
@export var label: String = ""
## upstream: ItemTagData.cs:14
@export var color: String = ""
## Raw JSON string.
## upstream: ItemTagData.cs:15
@export var metadata: String = "{}"
## upstream: ItemTagData.cs:16
@export var created_by: String = ""
## upstream: ItemTagData.cs:17
@export var created_at: String = ""
## upstream: ItemTagData.cs:18
@export var updated_at: String = ""
## upstream: ItemTagData.cs:19
@export var item_count: int = 0


static func from_dict(d: Variant) -> ItemTagData:
	var out := ItemTagData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.tag_key = String(dict.get("tag_key", ""))
	out.label = String(dict.get("label", ""))
	out.color = String(dict.get("color", ""))
	var meta: Variant = dict.get("metadata", null)
	if meta is String:
		out.metadata = meta if not (meta as String).is_empty() else "{}"
	elif meta is Dictionary or meta is Array:
		out.metadata = JSON.stringify(meta)
	else:
		out.metadata = "{}"
	out.created_by = String(dict.get("created_by", ""))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	out.item_count = int(dict.get("item_count", 0))
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"tag_key": tag_key,
		"label": label,
		"color": color,
		"metadata": metadata,
		"created_by": created_by,
		"created_at": created_at,
		"updated_at": updated_at,
		"item_count": item_count,
	}
