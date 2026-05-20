## RecipeMetadata - typed mirror of recipe metadata payload.
##
## upstream: 3_ItemContainer/Crafting/Models/RecipeMetadata.cs:6
class_name RecipeMetadata
extends Resource

## upstream: RecipeMetadata.cs:8
@export var difficulty: String = ""
## upstream: RecipeMetadata.cs:9
@export var icon: String = ""


static func from_dict(d: Variant) -> RecipeMetadata:
	var out := RecipeMetadata.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.difficulty = String(dict.get("difficulty", ""))
	out.icon = String(dict.get("icon", ""))
	return out


func to_dict() -> Dictionary:
	return {"difficulty": difficulty, "icon": icon}
