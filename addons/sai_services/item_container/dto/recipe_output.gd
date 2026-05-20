## RecipeOutput - typed mirror of a recipe output entry.
##
## upstream: 3_ItemContainer/Crafting/Models/RecipeOutput.cs:6
class_name RecipeOutput
extends Resource

## upstream: RecipeOutput.cs:8
@export var id: String = ""
## upstream: RecipeOutput.cs:9
@export var recipe_id: String = ""
## upstream: RecipeOutput.cs:10
@export var studio_id: String = ""
## upstream: RecipeOutput.cs:11
@export var game_id: String = ""
## upstream: RecipeOutput.cs:12
@export var item_definition_id: String = ""
## upstream: RecipeOutput.cs:13
@export var quantity_min: int = 0
## upstream: RecipeOutput.cs:14
@export var quantity_max: int = 0
## upstream: RecipeOutput.cs:15
@export var output_type: String = ""
## upstream: RecipeOutput.cs:16
@export var sort_order: int = 0
## upstream: RecipeOutput.cs:17
@export var created_at: String = ""
## upstream: RecipeOutput.cs:18
@export var updated_at: String = ""
## upstream: RecipeOutput.cs:19
@export var item_definition: ItemDefinitionData = null


static func from_dict(d: Variant) -> RecipeOutput:
	var out := RecipeOutput.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.recipe_id = String(dict.get("recipe_id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.quantity_min = int(dict.get("quantity_min", 0))
	out.quantity_max = int(dict.get("quantity_max", 0))
	out.output_type = String(dict.get("output_type", ""))
	out.sort_order = int(dict.get("sort_order", 0))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	var def: Variant = dict.get("item_definition", null)
	if def is Dictionary:
		out.item_definition = ItemDefinitionData.from_dict(def)
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"recipe_id": recipe_id,
		"studio_id": studio_id,
		"game_id": game_id,
		"item_definition_id": item_definition_id,
		"quantity_min": quantity_min,
		"quantity_max": quantity_max,
		"output_type": output_type,
		"sort_order": sort_order,
		"created_at": created_at,
		"updated_at": updated_at,
		"item_definition": item_definition.to_dict() if item_definition != null else {},
	}
