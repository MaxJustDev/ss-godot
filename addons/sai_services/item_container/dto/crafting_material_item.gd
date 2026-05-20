## CraftingMaterialItem - typed mirror of a single crafting material entry.
##
## upstream: 3_ItemContainer/Crafting/Models/CraftingMaterialItem.cs:6
class_name CraftingMaterialItem
extends Resource

## upstream: CraftingMaterialItem.cs:8
@export var item_definition_id: String = ""
## upstream: CraftingMaterialItem.cs:9
@export var item_definition_name: String = ""
## upstream: CraftingMaterialItem.cs:10
@export var quantity: int = 0
## upstream: CraftingMaterialItem.cs:11
@export var was_consumed: bool = false


static func from_dict(d: Variant) -> CraftingMaterialItem:
	var out := CraftingMaterialItem.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.item_definition_name = String(dict.get("item_definition_name", ""))
	out.quantity = int(dict.get("quantity", 0))
	out.was_consumed = bool(dict.get("was_consumed", false))
	return out


func to_dict() -> Dictionary:
	return {
		"item_definition_id": item_definition_id,
		"item_definition_name": item_definition_name,
		"quantity": quantity,
		"was_consumed": was_consumed,
	}
