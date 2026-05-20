## ItemDefinitionData - typed mirror of the item definition payload.
##
## `base_stats` and `metadata` are kept as raw JSON strings to match upstream's
## `JsonUtility` workaround for arbitrary object fields. Callers that want
## structured access to `metadata` can use `parsed_metadata()`.
##
## upstream: 3_ItemContainer/Item/Models/ItemDefinitionData.cs:12
class_name ItemDefinitionData
extends Resource

## upstream: ItemDefinitionData.cs:14
@export var id: String = ""
## upstream: ItemDefinitionData.cs:15
@export var studio_id: String = ""
## upstream: ItemDefinitionData.cs:16
@export var game_id: String = ""
## upstream: ItemDefinitionData.cs:17
@export var item_code: String = ""
## upstream: ItemDefinitionData.cs:18
@export var name: String = ""
## upstream: ItemDefinitionData.cs:19
@export var category: String = ""
## upstream: ItemDefinitionData.cs:20
@export var rarity: String = ""
## Raw JSON string of base_stats.
## upstream: ItemDefinitionData.cs:22
@export var base_stats: String = "{}"
## Raw JSON string of metadata.
## upstream: ItemDefinitionData.cs:24
@export var metadata: String = "{}"
## upstream: ItemDefinitionData.cs:29
@export var is_stackable: bool = false
## upstream: ItemDefinitionData.cs:30
@export var max_stack_size: int = 0
## upstream: ItemDefinitionData.cs:31
@export var grid_width: int = 0
## upstream: ItemDefinitionData.cs:32
@export var grid_height: int = 0
## upstream: ItemDefinitionData.cs:33
@export var client_writable: bool = false
## upstream: ItemDefinitionData.cs:34
@export var allow_client_update_qty: bool = false
## upstream: ItemDefinitionData.cs:35
@export var created_by: String = ""
## upstream: ItemDefinitionData.cs:36
@export var created_at: String = ""
## upstream: ItemDefinitionData.cs:37
@export var updated_at: String = ""


static func from_dict(d: Variant) -> ItemDefinitionData:
	var out := ItemDefinitionData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.item_code = String(dict.get("item_code", ""))
	out.name = String(dict.get("name", ""))
	out.category = String(dict.get("category", ""))
	out.rarity = String(dict.get("rarity", ""))
	out.base_stats = _coerce_json_string(dict.get("base_stats", null), "{}")
	out.metadata = _coerce_json_string(dict.get("metadata", null), "{}")
	out.is_stackable = bool(dict.get("is_stackable", false))
	out.max_stack_size = int(dict.get("max_stack_size", 0))
	out.grid_width = int(dict.get("grid_width", 0))
	out.grid_height = int(dict.get("grid_height", 0))
	out.client_writable = bool(dict.get("client_writable", false))
	out.allow_client_update_qty = bool(dict.get("allow_client_update_qty", false))
	out.created_by = String(dict.get("created_by", ""))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	return out


## Parse `metadata` as `ItemDefinitionMetadata` for typed access.
## Returns a fresh empty resource if the JSON is empty / malformed.
## upstream: ItemDefinitionData.cs:27 (ParsedMetadata)
func parsed_metadata() -> ItemDefinitionMetadata:
	if metadata.is_empty():
		return ItemDefinitionMetadata.new()
	var parsed: Variant = JSON.parse_string(metadata)
	if parsed is Dictionary:
		return ItemDefinitionMetadata.from_dict(parsed)
	return ItemDefinitionMetadata.new()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"item_code": item_code,
		"name": name,
		"category": category,
		"rarity": rarity,
		"base_stats": base_stats,
		"metadata": metadata,
		"is_stackable": is_stackable,
		"max_stack_size": max_stack_size,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"client_writable": client_writable,
		"allow_client_update_qty": allow_client_update_qty,
		"created_by": created_by,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func _coerce_json_string(value: Variant, fallback: String) -> String:
	if value is String:
		return value if not (value as String).is_empty() else fallback
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return fallback
