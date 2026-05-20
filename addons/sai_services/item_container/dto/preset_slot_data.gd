## PresetSlotData - typed mirror of a single preset slot row.
##
## upstream: 3_ItemContainer/Preset/Models/PresetSlotData.cs:6
class_name PresetSlotData
extends Resource

## upstream: PresetSlotData.cs:8
@export var slot_index: int = 0
## upstream: PresetSlotData.cs:9
@export var inventory_item_id: String = ""


static func from_dict(d: Variant) -> PresetSlotData:
	var out := PresetSlotData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.slot_index = int(dict.get("slot_index", 0))
	out.inventory_item_id = String(dict.get("inventory_item_id", ""))
	return out


func to_dict() -> Dictionary:
	return {"slot_index": slot_index, "inventory_item_id": inventory_item_id}
