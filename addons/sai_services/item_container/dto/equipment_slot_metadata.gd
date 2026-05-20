## EquipmentSlotMetadata - typed mirror of slot metadata subtype.
##
## upstream: 3_ItemContainer/Slot/EquipmentSlotMetadata.cs:7
class_name EquipmentSlotMetadata
extends Resource

## upstream: EquipmentSlotMetadata.cs:9
@export var icon: String = ""
## upstream: EquipmentSlotMetadata.cs:10
@export var slot_type: String = ""


static func from_dict(d: Variant) -> EquipmentSlotMetadata:
	var out := EquipmentSlotMetadata.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.icon = String(dict.get("icon", ""))
	out.slot_type = String(dict.get("slot_type", ""))
	return out


func to_dict() -> Dictionary:
	return {"icon": icon, "slot_type": slot_type}
