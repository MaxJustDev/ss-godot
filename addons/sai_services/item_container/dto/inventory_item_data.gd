## InventoryItemData - typed mirror of a single inventory item instance.
##
## `custom_properties`, `private_properties`, and `public_properties` are
## kept as raw JSON strings to match upstream behaviour (`JsonUtility` cannot
## map arbitrary objects into C# string fields, so an explicit
## `InventoryJsonHelper.StringifyObjectFields` pre-step is used). On the Godot
## side we instead re-stringify any Dictionary/Array received via JSON.parse.
##
## upstream: 3_ItemContainer/Item/Models/InventoryItemData.cs:10
class_name InventoryItemData
extends Resource

## upstream: InventoryItemData.cs:12
@export var id: String = ""
## upstream: InventoryItemData.cs:13
@export var studio_id: String = ""
## upstream: InventoryItemData.cs:14
@export var game_id: String = ""
## upstream: InventoryItemData.cs:15
@export var user_id: String = ""
## upstream: InventoryItemData.cs:16
@export var item_definition_id: String = ""
## upstream: InventoryItemData.cs:17
@export var item_container_id: String = ""
## upstream: InventoryItemData.cs:18
@export var grid_x: int = 0
## upstream: InventoryItemData.cs:19
@export var grid_y: int = 0
## upstream: InventoryItemData.cs:20
@export var quantity: int = 0
## upstream: InventoryItemData.cs:21
@export var level: int = 0
## Raw JSON string. May be empty when the server sends null.
## upstream: InventoryItemData.cs:23
@export var custom_properties: String = ""
## upstream: InventoryItemData.cs:25
@export var private_properties: String = ""
## upstream: InventoryItemData.cs:26
@export var public_properties: String = ""
## upstream: InventoryItemData.cs:27
@export var acquired_at: String = ""
## upstream: InventoryItemData.cs:28
@export var last_modified_at: String = ""
## upstream: InventoryItemData.cs:29
@export var version: int = 0
## Embedded item definition. Empty resource if absent.
## upstream: InventoryItemData.cs:30
@export var definition: ItemDefinitionData = null


static func from_dict(d: Variant) -> InventoryItemData:
	var out := InventoryItemData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.user_id = String(dict.get("user_id", ""))
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.item_container_id = String(dict.get("item_container_id", ""))
	out.grid_x = int(dict.get("grid_x", 0))
	out.grid_y = int(dict.get("grid_y", 0))
	out.quantity = int(dict.get("quantity", 0))
	out.level = int(dict.get("level", 0))
	out.custom_properties = _coerce_json_string(dict.get("custom_properties", null))
	out.private_properties = _coerce_json_string(dict.get("private_properties", null))
	out.public_properties = _coerce_json_string(dict.get("public_properties", null))
	out.acquired_at = String(dict.get("acquired_at", ""))
	out.last_modified_at = String(dict.get("last_modified_at", ""))
	out.version = int(dict.get("version", 0))
	var def: Variant = dict.get("definition", null)
	if def is Dictionary:
		out.definition = ItemDefinitionData.from_dict(def)
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"user_id": user_id,
		"item_definition_id": item_definition_id,
		"item_container_id": item_container_id,
		"grid_x": grid_x,
		"grid_y": grid_y,
		"quantity": quantity,
		"level": level,
		"custom_properties": custom_properties,
		"private_properties": private_properties,
		"public_properties": public_properties,
		"acquired_at": acquired_at,
		"last_modified_at": last_modified_at,
		"version": version,
		"definition": definition.to_dict() if definition != null else {},
	}


static func _coerce_json_string(value: Variant) -> String:
	if value == null:
		return ""
	if value is String:
		return value
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	return ""
