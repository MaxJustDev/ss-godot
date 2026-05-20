## RecipeInput - typed mirror of a recipe input ingredient.
##
## upstream: 3_ItemContainer/Crafting/Models/RecipeInput.cs:6
class_name RecipeInput
extends Resource

## upstream: RecipeInput.cs:8
@export var id: String = ""
## upstream: RecipeInput.cs:9
@export var recipe_id: String = ""
## upstream: RecipeInput.cs:10
@export var studio_id: String = ""
## upstream: RecipeInput.cs:11
@export var game_id: String = ""
## upstream: RecipeInput.cs:12
@export var item_definition_id: String = ""
## upstream: RecipeInput.cs:13
@export var quantity: int = 0
## upstream: RecipeInput.cs:14
@export var is_consumed: bool = false
## upstream: RecipeInput.cs:15
@export var created_at: String = ""
## upstream: RecipeInput.cs:16
@export var updated_at: String = ""
## upstream: RecipeInput.cs:17
@export var item_definition: ItemDefinitionData = null


static func from_dict(d: Variant) -> RecipeInput:
	var out := RecipeInput.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.recipe_id = String(dict.get("recipe_id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	out.quantity = int(dict.get("quantity", 0))
	out.is_consumed = bool(dict.get("is_consumed", false))
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
		"quantity": quantity,
		"is_consumed": is_consumed,
		"created_at": created_at,
		"updated_at": updated_at,
		"item_definition": item_definition.to_dict() if item_definition != null else {},
	}
