## GachaItemGranted - typed mirror of a single item granted from a gacha pull.
##
## upstream: 3_ItemContainer/Gacha/GachaItemGranted.cs:9
class_name GachaItemGranted
extends Resource

## upstream: GachaItemGranted.cs:11
@export var item_definition_id: String = ""
## upstream: GachaItemGranted.cs:12
@export var name: String = ""
## upstream: GachaItemGranted.cs:13
@export var category: String = ""
## upstream: GachaItemGranted.cs:14
@export var quantity: int = 0
## upstream: GachaItemGranted.cs:15
@export var quantity_min: int = 0
## upstream: GachaItemGranted.cs:16
@export var quantity_max: int = 0
## UUID of the newly-created inventory item, if immediately placed in inventory.
## upstream: GachaItemGranted.cs:18
@export var inventory_item_id: String = ""
## upstream: GachaItemGranted.cs:19
@export var drop_seed: String = ""
## upstream: GachaItemGranted.cs:20
@export var qty_seed: String = ""


static func from_dict(d: Variant) -> GachaItemGranted:
	var out := GachaItemGranted.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.name = String(dict.get("name", ""))
	out.category = String(dict.get("category", ""))
	out.quantity = int(dict.get("quantity", 0))
	out.quantity_min = int(dict.get("quantity_min", 0))
	out.quantity_max = int(dict.get("quantity_max", 0))
	out.inventory_item_id = String(dict.get("inventory_item_id", ""))
	out.drop_seed = String(dict.get("drop_seed", ""))
	out.qty_seed = String(dict.get("qty_seed", ""))
	return out


func to_dict() -> Dictionary:
	return {
		"item_definition_id": item_definition_id,
		"name": name,
		"category": category,
		"quantity": quantity,
		"quantity_min": quantity_min,
		"quantity_max": quantity_max,
		"inventory_item_id": inventory_item_id,
		"drop_seed": drop_seed,
		"qty_seed": qty_seed,
	}
