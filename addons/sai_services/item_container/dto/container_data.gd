## ContainerData - typed mirror of a single player container instance.
##
## `position_data` is kept as a raw JSON string to support arbitrary layout
## schemas (matches upstream `JsonUtility` handling).
##
## upstream: 3_ItemContainer/Container/ContainerData.cs:10
class_name ContainerData
extends Resource

## upstream: ContainerData.cs:12
@export var id: String = ""
## upstream: ContainerData.cs:13
@export var studio_id: String = ""
## upstream: ContainerData.cs:14
@export var game_id: String = ""
## upstream: ContainerData.cs:15
@export var owner_user_id: String = ""
## upstream: ContainerData.cs:16
@export var item_container_definition_id: String = ""
## upstream: ContainerData.cs:17
@export var container_type: String = ""
## Raw JSON string.
## upstream: ContainerData.cs:19
@export var position_data: String = "{}"
## upstream: ContainerData.cs:20
@export var created_at: String = ""
## upstream: ContainerData.cs:21
@export var updated_at: String = ""
## upstream: ContainerData.cs:22
@export var definition: ContainerDefinitionData = null


static func from_dict(d: Variant) -> ContainerData:
	var out := ContainerData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.owner_user_id = String(dict.get("owner_user_id", ""))
	out.item_container_definition_id = String(dict.get("item_container_definition_id", ""))
	out.container_type = String(dict.get("container_type", ""))
	var pos: Variant = dict.get("position_data", null)
	if pos is String:
		out.position_data = pos if not (pos as String).is_empty() else "{}"
	elif pos is Dictionary or pos is Array:
		out.position_data = JSON.stringify(pos)
	else:
		out.position_data = "{}"
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	var def: Variant = dict.get("definition", null)
	if def is Dictionary:
		out.definition = ContainerDefinitionData.from_dict(def)
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"owner_user_id": owner_user_id,
		"item_container_definition_id": item_container_definition_id,
		"container_type": container_type,
		"position_data": position_data,
		"created_at": created_at,
		"updated_at": updated_at,
		"definition": definition.to_dict() if definition != null else {},
	}
