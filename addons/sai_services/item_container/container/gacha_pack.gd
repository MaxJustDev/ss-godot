## GachaPack - dedicated gacha service.
##
## Upstream has both `PlayerContainer.OpenGachaPack` and a standalone
## `GachaPack` class with two methods (by-id and by-code). We expose the same
## two methods here so callers can use whichever flow they prefer.
##
## Files note: the project layout (per task plan) keeps GachaPack co-located
## in the `container/` folder for symmetry with upstream's "gacha is bundled
## in container" usage pattern, but the original Unity directory was
## `3_ItemContainer/Gacha/GachaPack.cs`. The `gacha/` Godot folder remains
## with a .gdkeep marker.
##
## upstream: 3_ItemContainer/Gacha/GachaPack.cs:8
class_name GachaPack
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6)
# -------------------------------------------------------------------------

## upstream: GachaPack.cs:77 (PlayerContainer.cs:397 mirror)
const PATH_GACHA_BY_ID := "/api/v1/games/{game_id}/gacha/{gacha_pack_id}"
## upstream: GachaPack.cs:167
const PATH_GACHA_BY_CODE := "/api/v1/games/{game_id}/gacha/by-code/{code}"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: GachaPack.cs:11 (OnOpenGachaSuccess)
signal open_success(response: GachaResponse)
## upstream: GachaPack.cs:12 (OnOpenGachaFailure)
signal open_failed(error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: GachaPack.cs:20 (lastResponse)
var last_response: GachaResponse = null

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/gacha/{gacha_pack_id}
##
## upstream: GachaPack.cs:31 (OpenGachaPack)
func open_by_id(gacha_pack_def_id: String, container_id: String) -> Dictionary:
	return await _open_internal(
		PATH_GACHA_BY_ID.replace("{gacha_pack_id}", gacha_pack_def_id),
		gacha_pack_def_id,
		container_id,
		"Gacha Pack ID is empty!",
	)


## POST /api/v1/games/{game_id}/gacha/by-code/{code}
##
## upstream: GachaPack.cs:121 (OpenGachaPackByCode)
func open_by_code(code: String, container_id: String) -> Dictionary:
	return await _open_internal(
		PATH_GACHA_BY_CODE.replace("{code}", code),
		code,
		container_id,
		"Gacha Pack Code is empty!",
	)


func clear_last_response() -> void:
	last_response = null


# =========================================================================
# Internals
# =========================================================================


func _open_internal(
	template_path: String,
	identifier: String,
	container_id: String,
	identifier_error: String,
) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		open_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		open_failed.emit(err)
		return _envelope_fail(err)

	if identifier.is_empty():
		open_failed.emit(identifier_error)
		return _envelope_fail(identifier_error)

	if container_id.is_empty():
		var err := "Container ID is empty!"
		open_failed.emit(err)
		return _envelope_fail(err)

	var path: String = template_path.replace("{game_id}", _game_id(server))
	var body: Dictionary = {
		"idempotency_key": _new_idempotency_key(),
		"container_id": container_id,
	}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GachaResponse.from_dict(payload)
			last_response = dto
			result["data"] = dto
			open_success.emit(dto)
			return result
		var msg := "gacha response not a JSON object"
		open_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "gacha failed"))
	open_failed.emit(error_msg)
	return result


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


## upstream: GachaPack.cs:78 — three 7-digit random segments joined with `-`.
func _new_idempotency_key() -> String:
	return (
		"%d-%d-%d"
		% [
			randi_range(1000000, 9999999),
			randi_range(1000000, 9999999),
			randi_range(1000000, 9999999),
		]
	)


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
