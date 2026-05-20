## GeneratorConfig - runtime config delivered inside definition.metadata.
##
## upstream: 3_ItemContainer/Generator/GeneratorConfig.cs:9
class_name GeneratorConfig
extends Resource

## upstream: GeneratorConfig.cs:11
@export var collect_destination: String = ""
## upstream: GeneratorConfig.cs:12
@export var output_pool: Array[GeneratorOutputPool] = []
## upstream: GeneratorConfig.cs:13
@export var production_interval_seconds: int = 0
## upstream: GeneratorConfig.cs:14
@export var tick_capacity: int = 0


static func from_dict(d: Variant) -> GeneratorConfig:
	var out := GeneratorConfig.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.collect_destination = String(dict.get("collect_destination", ""))
	var pool: Variant = dict.get("output_pool", null)
	if pool is Array:
		var typed: Array[GeneratorOutputPool] = []
		for p in pool:
			typed.append(GeneratorOutputPool.from_dict(p))
		out.output_pool = typed
	out.production_interval_seconds = int(dict.get("production_interval_seconds", 0))
	out.tick_capacity = int(dict.get("tick_capacity", 0))
	return out


func to_dict() -> Dictionary:
	var arr: Array = []
	for p in output_pool:
		arr.append(p.to_dict())
	return {
		"collect_destination": collect_destination,
		"output_pool": arr,
		"production_interval_seconds": production_interval_seconds,
		"tick_capacity": tick_capacity,
	}
