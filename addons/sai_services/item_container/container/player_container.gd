## PlayerContainer - list containers / list container items / open gacha pack.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Container/PlayerContainer.cs:8`.
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) become the project-
##     standard envelope `{success, status, error, data}` plus parallel
##     signals (B.4 CLAUDE.md).
##   - Auto-load-on-login and ClearOnLogout are NOT ported; app layer should
##     subscribe to `SaiServer.auth.login_success` / `logout_success`.
##   - Idempotency key for gacha matches upstream's three-segment random
##     string (PlayerContainer.cs:398) but uses `randi_range`.
##   - This node is added as a child of `SaiServer` via `_register_sub_services`.
##     Use `SaiServer.inventory` (alias) or `get_node("PlayerContainer")`.
##
## upstream: 3_ItemContainer/Container/PlayerContainer.cs:8
class_name PlayerContainer
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: PlayerContainer.cs:129
const PATH_CONTAINERS := "/api/v1/games/{game_id}/containers"
## upstream: PlayerContainer.cs:327
const PATH_CONTAINER_ITEMS := "/api/v1/containers/{container_id}/items"
## upstream: PlayerContainer.cs:397
const PATH_GACHA := "/api/v1/games/{game_id}/gacha/{gacha_pack_id}"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: PlayerContainer.cs:11 (OnGetContainersSuccess)
signal containers_loaded(containers: Array, has_more: bool)
## upstream: PlayerContainer.cs:12 (OnGetContainersFailure)
signal containers_failed(error: String)

## Emitted after `get_items(container_id)` returns.
signal items_loaded(container_id: String, items: Array)
signal items_failed(container_id: String, error: String)

## upstream: PlayerContainer.cs:411 (gacha success path)
signal gacha_success(response: GachaResponse)
signal gacha_failed(error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## Most recent containers list returned by `get_containers()`.
## upstream: PlayerContainer.cs:18 (currentContainers)
var current_containers: Array[ContainerData] = []
var _last_has_more: bool = false
var _last_limit: int = 0
var _last_offset: int = 0

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/containers?limit=&offset=
##
## On success, `data` is `{containers: Array[ContainerData], has_more: bool,
## limit: int, offset: int}` and the cached `current_containers` is updated.
##
## upstream: PlayerContainer.cs:95 (GetContainers), :122 (Coroutine)
func get_containers(limit: int = 50, offset: int = 0) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		containers_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: PlayerContainer.cs:110-114
		var err := "Not authenticated! Please login first."
		containers_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		containers_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_CONTAINERS.replace("{game_id}", game_id)
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_containers: Variant = (payload as Dictionary).get("containers", null)
			var typed: Array[ContainerData] = []
			if raw_containers is Array:
				for c in raw_containers:
					typed.append(ContainerData.from_dict(c))
			current_containers = typed
			_last_has_more = bool((payload as Dictionary).get("has_more", false))
			_last_limit = int((payload as Dictionary).get("limit", limit))
			_last_offset = int((payload as Dictionary).get("offset", offset))
			result["data"] = {
				"containers": typed,
				"has_more": _last_has_more,
				"limit": _last_limit,
				"offset": _last_offset,
			}
			containers_loaded.emit(typed, _last_has_more)
			return result
		var msg := "containers response not a JSON object"
		containers_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_containers failed"))
	containers_failed.emit(error_msg)
	return result


## GET /api/v1/containers/{container_id}/items?limit=&offset=
##
## On success, `data` is `{container_id: String, items: Array[InventoryItemData]}`.
##
## upstream: PlayerContainer.cs:295 (GetContainerItems), :320 (Coroutine)
func get_items(container_id: String, limit: int = 50, offset: int = 0) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		items_failed.emit(container_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		items_failed.emit(container_id, err)
		return _envelope_fail(err)

	if container_id.is_empty():
		var err := "container_id must not be empty"
		items_failed.emit(container_id, err)
		return _envelope_fail(err)

	var path: String = PATH_CONTAINER_ITEMS.replace("{container_id}", container_id)
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_items: Variant = (payload as Dictionary).get("items", null)
			var typed: Array[InventoryItemData] = []
			if raw_items is Array:
				for it in raw_items:
					typed.append(InventoryItemData.from_dict(it))
			var server_cid: String = String(
				(payload as Dictionary).get("container_id", container_id)
			)
			result["data"] = {"container_id": server_cid, "items": typed}
			items_loaded.emit(server_cid, typed)
			return result
		var msg := "container items response not a JSON object"
		items_failed.emit(container_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_items failed"))
	items_failed.emit(container_id, error_msg)
	return result


## POST /api/v1/games/{game_id}/gacha/{gacha_pack_id}
##
## Body: `{idempotency_key, container_id}`. Returns `{success, status, error,
## data: GachaResponse}` on success.
##
## upstream: PlayerContainer.cs:366 (OpenGachaPack), :390 (Coroutine)
func open_gacha_pack(gacha_pack_def_id: String, container_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		gacha_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		gacha_failed.emit(err)
		return _envelope_fail(err)

	if gacha_pack_def_id.is_empty():
		var err := "Gacha Pack ID is empty!"
		gacha_failed.emit(err)
		return _envelope_fail(err)

	if container_id.is_empty():
		var err := "Container ID is empty!"
		gacha_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_GACHA.replace("{game_id}", _game_id(server)).replace(
		"{gacha_pack_id}", gacha_pack_def_id
	)
	var body: Dictionary = {
		"idempotency_key": _new_idempotency_key(),
		"container_id": container_id,
	}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GachaResponse.from_dict(payload)
			result["data"] = dto
			gacha_success.emit(dto)
			return result
		var msg := "gacha response not a JSON object"
		gacha_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "gacha failed"))
	gacha_failed.emit(error_msg)
	return result


# ── Convenience query helpers (local) ──────────────────────────────────────


## Returns the locally cached container with the given id, or null.
## upstream: PlayerContainer.cs:193 (GetContainerById)
func get_container_by_id(container_id: String) -> ContainerData:
	for c in current_containers:
		if c.id == container_id:
			return c
	return null


## Returns all locally cached containers that match the given container_type.
## upstream: PlayerContainer.cs:208 (GetContainersByType)
func get_containers_by_type(container_type: String) -> Array[ContainerData]:
	var out: Array[ContainerData] = []
	for c in current_containers:
		if c.container_type == container_type:
			out.append(c)
	return out


## Clears local container cache.
## upstream: PlayerContainer.cs:169 (ClearContainers)
func clear_containers() -> void:
	current_containers = []
	_last_has_more = false
	_last_limit = 0
	_last_offset = 0


# =========================================================================
# Internals
# =========================================================================


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


## Three random 7-digit segments joined with dashes, matching upstream.
## upstream: PlayerContainer.cs:398
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
