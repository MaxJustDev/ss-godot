## EquippedItemData - typed mirror of one equipped item row.
##
## `slot_data_raw` mirrors upstream's manual JSON extraction. Server returns
## `slot_data` as an arbitrary JSON object; we keep both:
##   - `slot_data` is a Dictionary (parsed value, may be empty)
##   - `slot_data_raw` is the same value re-serialized as a JSON string for
##     callers that want to forward it verbatim.
##
## upstream: 3_ItemContainer/Slot/EquippedItemData.cs:7
class_name EquippedItemData
extends Resource

## upstream: EquippedItemData.cs:9
@export var slot_key: String = ""
## upstream: EquippedItemData.cs:10
@export var slot_name: String = ""
## upstream: EquippedItemData.cs:11
@export var item_id: String = ""
## upstream: EquippedItemData.cs:12
@export var item_definition_id: String = ""
## upstream: EquippedItemData.cs:13
@export var item_name: String = ""
## upstream: EquippedItemData.cs:14
@export var category: String = ""
## upstream: EquippedItemData.cs:15
@export var rarity: String = ""
## Parsed slot_data Dictionary.
@export var slot_data: Dictionary = {}
## Raw JSON string mirror of slot_data, for callers that want to forward verbatim.
## upstream: EquippedItemData.cs:18 (slot_data_raw)
@export var slot_data_raw: String = "{}"


static func from_dict(d: Variant) -> EquippedItemData:
	var out := EquippedItemData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.slot_key = String(dict.get("slot_key", ""))
	out.slot_name = String(dict.get("slot_name", ""))
	out.item_id = String(dict.get("item_id", ""))
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.item_name = String(dict.get("item_name", ""))
	out.category = String(dict.get("category", ""))
	out.rarity = String(dict.get("rarity", ""))
	var sd: Variant = dict.get("slot_data", null)
	if sd is Dictionary:
		out.slot_data = sd
		out.slot_data_raw = JSON.stringify(sd)
	elif sd is String and not (sd as String).is_empty():
		var parsed: Variant = JSON.parse_string(sd)
		if parsed is Dictionary:
			out.slot_data = parsed
		out.slot_data_raw = sd
	else:
		out.slot_data = {}
		out.slot_data_raw = "{}"
	return out


func to_dict() -> Dictionary:
	return {
		"slot_key": slot_key,
		"slot_name": slot_name,
		"item_id": item_id,
		"item_definition_id": item_definition_id,
		"item_name": item_name,
		"category": category,
		"rarity": rarity,
		"slot_data": slot_data,
		"slot_data_raw": slot_data_raw,
	}
