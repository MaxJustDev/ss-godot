## CraftingOutputItem - typed mirror of a single crafting output entry.
##
## upstream: 3_ItemContainer/Crafting/Models/CraftingOutputItem.cs:6
class_name CraftingOutputItem
extends Resource

## upstream: CraftingOutputItem.cs:8
@export var item_definition_id: String = ""
## upstream: CraftingOutputItem.cs:9
@export var item_definition_name: String = ""
## upstream: CraftingOutputItem.cs:10
@export var quantity: int = 0


static func from_dict(d: Variant) -> CraftingOutputItem:
	var out := CraftingOutputItem.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.item_definition_name = String(dict.get("item_definition_name", ""))
	out.quantity = int(dict.get("quantity", 0))
	return out


func to_dict() -> Dictionary:
	return {
		"item_definition_id": item_definition_id,
		"item_definition_name": item_definition_name,
		"quantity": quantity,
	}
