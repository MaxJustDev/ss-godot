## ItemDefinitionMetadata - typed slice of an item definition's metadata blob.
##
## Server returns metadata as a nested JSON object embedded in the definition.
## Upstream only parses a handful of well-known keys; everything else is
## ignored. Unknown keys are dropped on `from_dict`.
##
## upstream: 3_ItemContainer/Item/Models/ItemDefinitionMetadata.cs:11
class_name ItemDefinitionMetadata
extends Resource

## upstream: ItemDefinitionMetadata.cs:13
@export var flavor_text: String = ""
## upstream: ItemDefinitionMetadata.cs:14
@export var icon: String = ""
## Multi-pack field — one gacha item can reference several gacha pack defs.
## upstream: ItemDefinitionMetadata.cs:16
@export var gacha_pack_ids: PackedStringArray = PackedStringArray()
## Recipe item: list of craft_recipe_input definition IDs this recipe unlocks.
## upstream: ItemDefinitionMetadata.cs:18
@export var craft_recipe_input_ids: PackedStringArray = PackedStringArray()
## upstream: ItemDefinitionMetadata.cs:20
@export var currency_code: String = ""
## upstream: ItemDefinitionMetadata.cs:21
@export var description: String = ""
## upstream: ItemDefinitionMetadata.cs:22
@export var is_default_currency: bool = false


static func from_dict(d: Variant) -> ItemDefinitionMetadata:
	var m := ItemDefinitionMetadata.new()
	if not (d is Dictionary):
		return m
	var dict: Dictionary = d
	m.flavor_text = String(dict.get("flavor_text", ""))
	m.icon = String(dict.get("icon", ""))
	var gids: Variant = dict.get("gacha_pack_ids", null)
	if gids is Array:
		m.gacha_pack_ids = PackedStringArray(gids)
	var rids: Variant = dict.get("craft_recipe_input_ids", null)
	if rids is Array:
		m.craft_recipe_input_ids = PackedStringArray(rids)
	m.currency_code = String(dict.get("currency_code", ""))
	m.description = String(dict.get("description", ""))
	m.is_default_currency = bool(dict.get("is_default_currency", false))
	return m


func to_dict() -> Dictionary:
	return {
		"flavor_text": flavor_text,
		"icon": icon,
		"gacha_pack_ids": Array(gacha_pack_ids),
		"craft_recipe_input_ids": Array(craft_recipe_input_ids),
		"currency_code": currency_code,
		"description": description,
		"is_default_currency": is_default_currency,
	}
