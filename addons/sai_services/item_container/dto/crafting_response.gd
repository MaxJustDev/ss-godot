## CraftingResponse - typed mirror of the craft endpoint response.
##
## upstream: 3_ItemContainer/Crafting/Responses/CraftingResponse.cs:6
class_name CraftingResponse
extends Resource

## upstream: CraftingResponse.cs:8
@export var transaction_id: String = ""
## upstream: CraftingResponse.cs:9
@export var success: bool = false
## upstream: CraftingResponse.cs:10
@export var bonus_triggered: bool = false
## upstream: CraftingResponse.cs:11
@export var output_items: Array[CraftingOutputItem] = []
## upstream: CraftingResponse.cs:12
@export var materials_used: Array[CraftingMaterialItem] = []


static func from_dict(d: Variant) -> CraftingResponse:
	var out := CraftingResponse.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.transaction_id = String(dict.get("transaction_id", ""))
	out.success = bool(dict.get("success", false))
	out.bonus_triggered = bool(dict.get("bonus_triggered", false))
	var outs: Variant = dict.get("output_items", null)
	if outs is Array:
		var t1: Array[CraftingOutputItem] = []
		for o in outs:
			t1.append(CraftingOutputItem.from_dict(o))
		out.output_items = t1
	var mats: Variant = dict.get("materials_used", null)
	if mats is Array:
		var t2: Array[CraftingMaterialItem] = []
		for m in mats:
			t2.append(CraftingMaterialItem.from_dict(m))
		out.materials_used = t2
	return out


func to_dict() -> Dictionary:
	var oi: Array = []
	for o in output_items:
		oi.append(o.to_dict())
	var mu: Array = []
	for m in materials_used:
		mu.append(m.to_dict())
	return {
		"transaction_id": transaction_id,
		"success": success,
		"bonus_triggered": bonus_triggered,
		"output_items": oi,
		"materials_used": mu,
	}
