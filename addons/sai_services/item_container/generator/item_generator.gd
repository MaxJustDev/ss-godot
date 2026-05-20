## ItemGenerator - list / check / collect generator instances.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Generator/ItemGenerator.cs:8`.
##
## Special-case notes:
##   - `GET /generators` returns a BARE JSON array (no wrapper). We handle the
##     bare-array case explicitly (the existing SaiServer envelope already
##     parses it as an Array on success).
##   - After ingesting fresh server data, `sync_checkpoint_to_now()` is called
##     on every GeneratorData so local-calculation helpers project from "now"
##     forward (matches upstream behaviour at ItemGenerator.cs:150).
##
## upstream: 3_ItemContainer/Generator/ItemGenerator.cs:8
class_name ItemGenerator
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6)
# -------------------------------------------------------------------------

## upstream: ItemGenerator.cs:122
const PATH_GENERATORS := "/api/v1/games/{game_id}/generators"
## upstream: ItemGenerator.cs:350
const PATH_GENERATOR := "/api/v1/games/{game_id}/generators/{inventory_item_id}"
## upstream: ItemGenerator.cs:454
const PATH_GENERATOR_COLLECT := "/api/v1/games/{game_id}/generators/{inventory_item_id}/collect"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ItemGenerator.cs:11 (OnGetGeneratorsSuccess)
signal generators_loaded(generators: Array)
signal generators_failed(error: String)

## upstream: ItemGenerator.cs:13 (OnCheckGeneratorSuccess)
signal generator_checked(generator: GeneratorData)
signal generator_check_failed(inventory_item_id: String, error: String)

## upstream: ItemGenerator.cs:15 (OnCollectGeneratorSuccess)
signal generator_collected(response: GeneratorCollectResponse)
signal generator_collect_failed(inventory_item_id: String, error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: ItemGenerator.cs:22 (currentGenerators)
var current_generators: Array[GeneratorData] = []

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/generators
##
## Server returns a BARE array of generators (no `{generators:...}` wrapper) —
## we handle that branch explicitly.
##
## upstream: ItemGenerator.cs:95 (GetGenerators), :117 (Coroutine)
func get_generators() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		generators_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		generators_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_GENERATORS.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		var raw_array: Variant = _coerce_bare_array(payload, "generators")
		if raw_array is Array:
			# Preserve per-generator local-calc settings across refreshes
			# (matches upstream ItemGenerator.cs:134-141).
			var preserved: Dictionary = {}
			for old in current_generators:
				preserved[old.inventory_item_id] = old.enable_local_calculation

			var typed: Array[GeneratorData] = []
			for g in raw_array:
				var gen := GeneratorData.from_dict(g)
				gen.sync_checkpoint_to_now()
				if preserved.has(gen.inventory_item_id):
					gen.enable_local_calculation = preserved[gen.inventory_item_id]
				typed.append(gen)
			current_generators = typed
			result["data"] = typed
			generators_loaded.emit(typed)
			return result
		var msg := "generators response is not an array"
		generators_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_generators failed"))
	generators_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/generators/{inventory_item_id}
##
## upstream: ItemGenerator.cs:321 (CheckGenerator), :344 (Coroutine)
func check_generator(inventory_item_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		generator_check_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		generator_check_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	if inventory_item_id.is_empty():
		var err := "inventory_item_id must not be empty."
		generator_check_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	var path: String = PATH_GENERATOR.replace("{game_id}", _game_id(server)).replace(
		"{inventory_item_id}", inventory_item_id
	)
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GeneratorData.from_dict(payload)
			# upstream: ItemGenerator.cs:375 — preserve local-calc, sync checkpoint.
			var existing: GeneratorData = get_generator_by_inventory_item_id(inventory_item_id)
			if existing != null:
				dto.enable_local_calculation = existing.enable_local_calculation
			dto.sync_checkpoint_to_now()
			_replace_cached(dto)
			result["data"] = dto
			generator_checked.emit(dto)
			return result
		var msg := "generator response not a JSON object"
		generator_check_failed.emit(inventory_item_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "check_generator failed"))
	generator_check_failed.emit(inventory_item_id, error_msg)
	return result


## POST /api/v1/games/{game_id}/generators/{inventory_item_id}/collect
##
## Body: `{}` literal. Upstream re-checks the generator after a successful
## collect — we do the same (fire-and-forget refresh).
##
## upstream: ItemGenerator.cs:425 (CollectGenerator), :448 (Coroutine)
func collect_generator(inventory_item_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		generator_collect_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		generator_collect_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	if inventory_item_id.is_empty():
		var err := "inventory_item_id must not be empty."
		generator_collect_failed.emit(inventory_item_id, err)
		return _envelope_fail(err)

	var path: String = PATH_GENERATOR_COLLECT.replace("{game_id}", _game_id(server)).replace(
		"{inventory_item_id}", inventory_item_id
	)
	var result: Dictionary = await server.post_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GeneratorCollectResponse.from_dict(payload)
			result["data"] = dto
			generator_collected.emit(dto)
			# upstream: ItemGenerator.cs:467 — refresh generator state after collect.
			# Fire-and-forget; ignore its return value.
			check_generator(inventory_item_id)
			return result
		var msg := "collect response not a JSON object"
		generator_collect_failed.emit(inventory_item_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "collect_generator failed"))
	generator_collect_failed.emit(inventory_item_id, error_msg)
	return result


# ── Convenience query helpers ──────────────────────────────────────────────


## upstream: ItemGenerator.cs:220 (GetGeneratorByInventoryItemId)
func get_generator_by_inventory_item_id(inventory_item_id: String) -> GeneratorData:
	for g in current_generators:
		if g.inventory_item_id == inventory_item_id:
			return g
	return null


## upstream: ItemGenerator.cs:235 (GetGeneratorByDefinitionId)
func get_generator_by_definition_id(definition_id: String) -> GeneratorData:
	for g in current_generators:
		if g.definition_id == definition_id:
			return g
	return null


## upstream: ItemGenerator.cs:284 (GetGeneratorsWithPendingUnits)
func get_generators_with_pending_units() -> Array[GeneratorData]:
	var out: Array[GeneratorData] = []
	for g in current_generators:
		if g.ticket_count > 0:
			out.append(g)
	return out


## upstream: ItemGenerator.cs:199 (ClearGenerators)
func clear_generators() -> void:
	current_generators = []


# =========================================================================
# Internals
# =========================================================================


## Accept either a bare Array (server's actual shape) or a wrapped
## `{<wrapper_key>: [...]}` Dictionary (defensive fallback).
##
## upstream: ItemGenerator.cs:130 — wraps array in `{generators: ...}` before
## passing to JsonUtility. We tolerate both.
func _coerce_bare_array(value: Variant, wrapper_key: String) -> Variant:
	if value is Array:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if d.has(wrapper_key) and d[wrapper_key] is Array:
			return d[wrapper_key]
	return null


func _replace_cached(dto: GeneratorData) -> void:
	for i in current_generators.size():
		if current_generators[i].inventory_item_id == dto.inventory_item_id:
			current_generators[i] = dto
			return
	current_generators.append(dto)


func _server() -> Node:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("post_request"):
		return parent
	if Engine.has_singleton("SaiServer"):
		return Engine.get_singleton("SaiServer")
	if is_inside_tree():
		var node: Node = get_tree().root.get_node_or_null("SaiServer")
		if node != null:
			return node
	return null


func _game_id(server: Node) -> String:
	if server.has_method("normalized_game_id"):
		return String(server.normalized_game_id())
	if "game_id" in server:
		return String(server.game_id)
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
