## RecipeDetail - typed mirror of the GET recipes-by-key response payload.
##
## upstream: 3_ItemContainer/Crafting/Models/RecipeDetail.cs:6
class_name RecipeDetail
extends Resource

## upstream: RecipeDetail.cs:8
@export var id: String = ""
## upstream: RecipeDetail.cs:9
@export var studio_id: String = ""
## upstream: RecipeDetail.cs:10
@export var game_id: String = ""
## upstream: RecipeDetail.cs:11
@export var recipe_key: String = ""
## upstream: RecipeDetail.cs:12
@export var name: String = ""
## upstream: RecipeDetail.cs:13
@export var description: String = ""
## upstream: RecipeDetail.cs:14
@export var category: String = ""
## upstream: RecipeDetail.cs:15
@export var success_rate: int = 0
## upstream: RecipeDetail.cs:16
@export var bonus_rate: int = 0
## upstream: RecipeDetail.cs:17
@export var is_active: bool = false
## upstream: RecipeDetail.cs:18
@export var metadata: RecipeMetadata = null
## upstream: RecipeDetail.cs:19
@export var created_by: String = ""
## upstream: RecipeDetail.cs:20
@export var created_at: String = ""
## upstream: RecipeDetail.cs:21
@export var updated_at: String = ""
## upstream: RecipeDetail.cs:22
@export var inputs: Array[RecipeInput] = []
## upstream: RecipeDetail.cs:23
@export var outputs: Array[RecipeOutput] = []


static func from_dict(d: Variant) -> RecipeDetail:
	var out := RecipeDetail.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.recipe_key = String(dict.get("recipe_key", ""))
	out.name = String(dict.get("name", ""))
	out.description = String(dict.get("description", ""))
	out.category = String(dict.get("category", ""))
	out.success_rate = int(dict.get("success_rate", 0))
	out.bonus_rate = int(dict.get("bonus_rate", 0))
	out.is_active = bool(dict.get("is_active", false))
	var meta: Variant = dict.get("metadata", null)
	if meta is Dictionary:
		out.metadata = RecipeMetadata.from_dict(meta)
	out.created_by = String(dict.get("created_by", ""))
	out.created_at = String(dict.get("created_at", ""))
	out.updated_at = String(dict.get("updated_at", ""))
	var inps: Variant = dict.get("inputs", null)
	if inps is Array:
		var t1: Array[RecipeInput] = []
		for i in inps:
			t1.append(RecipeInput.from_dict(i))
		out.inputs = t1
	var outs: Variant = dict.get("outputs", null)
	if outs is Array:
		var t2: Array[RecipeOutput] = []
		for o in outs:
			t2.append(RecipeOutput.from_dict(o))
		out.outputs = t2
	return out


func to_dict() -> Dictionary:
	var i_arr: Array = []
	for i in inputs:
		i_arr.append(i.to_dict())
	var o_arr: Array = []
	for o in outputs:
		o_arr.append(o.to_dict())
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"recipe_key": recipe_key,
		"name": name,
		"description": description,
		"category": category,
		"success_rate": success_rate,
		"bonus_rate": bonus_rate,
		"is_active": is_active,
		"metadata": metadata.to_dict() if metadata != null else {},
		"created_by": created_by,
		"created_at": created_at,
		"updated_at": updated_at,
		"inputs": i_arr,
		"outputs": o_arr,
	}
