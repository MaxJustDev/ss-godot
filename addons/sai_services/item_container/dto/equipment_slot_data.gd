## EquipmentSlotData - typed mirror of a single equipment slot definition.
##
## upstream: 3_ItemContainer/Slot/EquipmentSlotData.cs:7
class_name EquipmentSlotData
extends Resource

## upstream: EquipmentSlotData.cs:9
@export var id: String = ""
## upstream: EquipmentSlotData.cs:10
@export var studio_id: String = ""
## upstream: EquipmentSlotData.cs:11
@export var game_id: String = ""
## upstream: EquipmentSlotData.cs:12
@export var slot_key: String = ""
## upstream: EquipmentSlotData.cs:13
@export var name: String = ""
## upstream: EquipmentSlotData.cs:14
@export var description: String = ""
## upstream: EquipmentSlotData.cs:15
@export var allowed_categories: PackedStringArray = PackedStringArray()
## upstream: EquipmentSlotData.cs:16
@export var allowed_item_definition_ids: PackedStringArray = PackedStringArray()
## upstream: EquipmentSlotData.cs:17
@export var metadata: EquipmentSlotMetadata = null
## upstream: EquipmentSlotData.cs:18
@export var is_active: bool = false
## upstream: EquipmentSlotData.cs:19
@export var created_by: String = ""
## upstream: EquipmentSlotData.cs:20
@export var created_at: String = ""
## upstream: EquipmentSlotData.cs:21
@export var updated_at: String = ""


static func from_dict(d: Variant) -> EquipmentSlotData:
	var out := EquipmentSlotData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.slot_key = String(dict.get("slot_key", ""))
	out.name = String(dict.get("name", ""))
	out.description = String(dict.get("description", ""))
	var cats: Variant = dict.get("allowed_categories", null)
	if cats is Array:
		out.allowed_categories = PackedStringArray(cats)
	var defs: Variant = dict.get("allowed_item_definition_ids", null)
	if defs is Array:
		out.allowed_item_definition_ids = PackedStringArray(defs)
	var meta: Variant = dict.get("metadata", null)
	if meta is Dictionary:
		out.metadata = EquipmentSlotMetadata.from_dict(meta)
	out.is_active = bool(dict.get("is_active", false))
	out.created_by = String(dict.get("created_by", ""))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"slot_key": slot_key,
		"name": name,
		"description": description,
		"allowed_categories": Array(allowed_categories),
		"allowed_item_definition_ids": Array(allowed_item_definition_ids),
		"metadata": metadata.to_dict() if metadata != null else {},
		"is_active": is_active,
		"created_by": created_by,
		"created_at": created_at,
		"updated_at": updated_at,
	}
