## GeneratorCollectResponse - response returned by /generators/{id}/collect.
##
## upstream: 3_ItemContainer/Generator/GeneratorCollectResponse.cs:9
class_name GeneratorCollectResponse
extends Resource

## upstream: GeneratorCollectResponse.cs:11
@export var units_collected: int = 0
## upstream: GeneratorCollectResponse.cs:12
@export var output_item_code: String = ""
## upstream: GeneratorCollectResponse.cs:13
@export var output_inventory_item_id: String = ""


static func from_dict(d: Variant) -> GeneratorCollectResponse:
	var out := GeneratorCollectResponse.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.units_collected = int(dict.get("units_collected", 0))
	out.output_item_code = String(dict.get("output_item_code", ""))
	out.output_inventory_item_id = String(dict.get("output_inventory_item_id", ""))
	return out


func to_dict() -> Dictionary:
	return {
		"units_collected": units_collected,
		"output_item_code": output_item_code,
		"output_inventory_item_id": output_inventory_item_id,
	}
