## GeneratorDefinition - typed mirror of a generator item's definition.
##
## upstream: 3_ItemContainer/Generator/GeneratorDefinition.cs:9
class_name GeneratorDefinition
extends Resource

## upstream: GeneratorDefinition.cs:11
@export var item_code: String = ""
## upstream: GeneratorDefinition.cs:12
@export var name: String = ""
## upstream: GeneratorDefinition.cs:13
@export var rarity: String = ""
## upstream: GeneratorDefinition.cs:14
@export var grid_width: int = 0
## upstream: GeneratorDefinition.cs:15
@export var grid_height: int = 0
## `base_stats` is freeform per upstream's empty BaseStats class — keep as Dict.
## upstream: GeneratorDefinition.cs:16
@export var base_stats: Dictionary = {}
## Wrapper containing `generator_config`.
## upstream: GeneratorDefinition.cs:17 + GeneratorDefinitionMetadata.cs:9
@export var generator_config: GeneratorConfig = null


static func from_dict(d: Variant) -> GeneratorDefinition:
	var out := GeneratorDefinition.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.item_code = String(dict.get("item_code", ""))
	out.name = String(dict.get("name", ""))
	out.rarity = String(dict.get("rarity", ""))
	out.grid_width = int(dict.get("grid_width", 0))
	out.grid_height = int(dict.get("grid_height", 0))
	var bs: Variant = dict.get("base_stats", null)
	if bs is Dictionary:
		out.base_stats = bs
	var meta: Variant = dict.get("metadata", null)
	if meta is Dictionary:
		var cfg: Variant = (meta as Dictionary).get("generator_config", null)
		if cfg is Dictionary:
			out.generator_config = GeneratorConfig.from_dict(cfg)
	return out


func to_dict() -> Dictionary:
	return {
		"item_code": item_code,
		"name": name,
		"rarity": rarity,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"base_stats": base_stats,
		"metadata":
		{
			"generator_config": generator_config.to_dict() if generator_config != null else {},
		},
	}
