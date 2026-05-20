## GeneratorOutputPool - one output entry in a generator's output pool.
##
## upstream: 3_ItemContainer/Generator/GeneratorOutputPool.cs:9
class_name GeneratorOutputPool
extends Resource

## upstream: GeneratorOutputPool.cs:11
@export var item_definition_id: String = ""
## upstream: GeneratorOutputPool.cs:12
@export var item_definition_metadata: ItemDefinitionMetadata = null
## upstream: GeneratorOutputPool.cs:13
@export var drop_rate: float = 0.0
## upstream: GeneratorOutputPool.cs:14
@export var quantity_min: int = 0
## upstream: GeneratorOutputPool.cs:15
@export var quantity_max: int = 0
## upstream: GeneratorOutputPool.cs:16
@export var collect_cap: int = 0
## upstream: GeneratorOutputPool.cs:17
@export var initial_output: int = 0


static func from_dict(d: Variant) -> GeneratorOutputPool:
	var out := GeneratorOutputPool.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.item_definition_id = String(dict.get("item_definition_id", ""))
	var meta: Variant = dict.get("item_definition_metadata", null)
	if meta is Dictionary:
		out.item_definition_metadata = ItemDefinitionMetadata.from_dict(meta)
	out.drop_rate = float(dict.get("drop_rate", 0.0))
	out.quantity_min = int(dict.get("quantity_min", 0))
	out.quantity_max = int(dict.get("quantity_max", 0))
	out.collect_cap = int(dict.get("collect_cap", 0))
	out.initial_output = int(dict.get("initial_output", 0))
	return out


func to_dict() -> Dictionary:
	return {
		"item_definition_id": item_definition_id,
		"item_definition_metadata":
		item_definition_metadata.to_dict() if item_definition_metadata != null else {},
		"drop_rate": drop_rate,
		"quantity_min": quantity_min,
		"quantity_max": quantity_max,
		"collect_cap": collect_cap,
		"initial_output": initial_output,
	}
