## ContainerDefinitionData - typed mirror of the container template payload.
##
## `metadata` is kept as a raw JSON string to match upstream behaviour.
##
## upstream: 3_ItemContainer/Container/ContainerDefinitionData.cs:10
class_name ContainerDefinitionData
extends Resource

## upstream: ContainerDefinitionData.cs:12
@export var id: String = ""
## upstream: ContainerDefinitionData.cs:13
@export var studio_id: String = ""
## upstream: ContainerDefinitionData.cs:14
@export var game_id: String = ""
## upstream: ContainerDefinitionData.cs:15
@export var name: String = ""
## upstream: ContainerDefinitionData.cs:16
@export var container_type: String = ""
## upstream: ContainerDefinitionData.cs:17
@export var grid_cols: int = 0
## upstream: ContainerDefinitionData.cs:18
@export var grid_rows: int = 0
## upstream: ContainerDefinitionData.cs:19
@export var is_portable: bool = false
## Raw JSON string.
## upstream: ContainerDefinitionData.cs:21
@export var metadata: String = "{}"
## upstream: ContainerDefinitionData.cs:22
@export var created_at: String = ""
## upstream: ContainerDefinitionData.cs:23
@export var updated_at: String = ""


static func from_dict(d: Variant) -> ContainerDefinitionData:
	var out := ContainerDefinitionData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.name = String(dict.get("name", ""))
	out.container_type = String(dict.get("container_type", ""))
	out.grid_cols = int(dict.get("grid_cols", 0))
	out.grid_rows = int(dict.get("grid_rows", 0))
	out.is_portable = bool(dict.get("is_portable", false))
	var meta: Variant = dict.get("metadata", null)
	if meta is String:
		out.metadata = meta if not (meta as String).is_empty() else "{}"
	elif meta is Dictionary or meta is Array:
		out.metadata = JSON.stringify(meta)
	else:
		out.metadata = "{}"
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"name": name,
		"container_type": container_type,
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
		"is_portable": is_portable,
		"metadata": metadata,
		"created_at": created_at,
		"updated_at": updated_at,
	}
