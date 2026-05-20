## PresetData - typed mirror of a single preset record.
##
## `metadata_json` is the post-parse raw JSON snippet matching upstream's
## `metadataJson` field (extracted manually because JsonUtility can't handle
## arbitrary objects). On the Godot side we just re-stringify the parsed
## `metadata` Dictionary.
##
## upstream: 3_ItemContainer/Preset/Models/PresetData.cs:6
class_name PresetData
extends Resource

## upstream: PresetData.cs:8
@export var id: String = ""
## upstream: PresetData.cs:9
@export var definition_id: String = ""
## upstream: PresetData.cs:10
@export var definition: PresetDefinition = null
## upstream: PresetData.cs:11
@export var preset_type: String = ""
## upstream: PresetData.cs:12
@export var name: String = ""
## upstream: PresetData.cs:13
@export var max_slots: int = 0
## upstream: PresetData.cs:14
@export var is_temp: bool = false
## upstream: PresetData.cs:15
@export var slots: Array[PresetSlotData] = []
## upstream: PresetData.cs:16
@export var created_at: String = ""
## upstream: PresetData.cs:17
@export var updated_at: String = ""
## Raw JSON sub-tree of the preset-level metadata field.
## upstream: PresetData.cs:19 (metadataJson)
@export var metadata_json: String = ""


static func from_dict(d: Variant) -> PresetData:
	var out := PresetData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.definition_id = String(dict.get("definition_id", ""))
	var def: Variant = dict.get("definition", null)
	if def is Dictionary:
		out.definition = PresetDefinition.from_dict(def)
	out.preset_type = String(dict.get("preset_type", ""))
	out.name = String(dict.get("name", ""))
	out.max_slots = int(dict.get("max_slots", 0))
	out.is_temp = bool(dict.get("is_temp", false))
	var raw_slots: Variant = dict.get("slots", null)
	if raw_slots is Array:
		var typed: Array[PresetSlotData] = []
		for s in raw_slots:
			typed.append(PresetSlotData.from_dict(s))
		out.slots = typed
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	var meta: Variant = dict.get("metadata", null)
	if meta is Dictionary or meta is Array:
		out.metadata_json = JSON.stringify(meta)
	elif meta is String:
		out.metadata_json = meta
	else:
		out.metadata_json = ""
	return out


func to_dict() -> Dictionary:
	var s: Array = []
	for sl in slots:
		s.append(sl.to_dict())
	return {
		"id": id,
		"definition_id": definition_id,
		"definition": definition.to_dict() if definition != null else {},
		"preset_type": preset_type,
		"name": name,
		"max_slots": max_slots,
		"is_temp": is_temp,
		"slots": s,
		"created_at": created_at,
		"updated_at": updated_at,
		"metadata_json": metadata_json,
	}
