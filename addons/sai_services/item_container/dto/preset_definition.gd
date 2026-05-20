## PresetDefinition - typed mirror of the embedded preset template payload.
##
## upstream: 3_ItemContainer/Preset/Models/PresetDefinition.cs:6
class_name PresetDefinition
extends Resource

## upstream: PresetDefinition.cs:8
@export var id: String = ""
## upstream: PresetDefinition.cs:9
@export var code_name: String = ""
## upstream: PresetDefinition.cs:10
@export var preset_type: String = ""
## upstream: PresetDefinition.cs:11
@export var name: String = ""
## upstream: PresetDefinition.cs:12
@export var max_slots: int = 0
## upstream: PresetDefinition.cs:13
@export var created_at: String = ""
## upstream: PresetDefinition.cs:14
@export var updated_at: String = ""


static func from_dict(d: Variant) -> PresetDefinition:
	var out := PresetDefinition.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.code_name = String(dict.get("code_name", ""))
	out.preset_type = String(dict.get("preset_type", ""))
	out.name = String(dict.get("name", ""))
	out.max_slots = int(dict.get("max_slots", 0))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"code_name": code_name,
		"preset_type": preset_type,
		"name": name,
		"max_slots": max_slots,
		"created_at": created_at,
		"updated_at": updated_at,
	}
