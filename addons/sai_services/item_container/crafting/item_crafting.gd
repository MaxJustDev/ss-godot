## ItemCrafting - craft by recipe / craft by key / list history / fetch recipe.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Crafting/ItemCrafting.cs:8`.
##
## Translation notes:
##   - `idempotency_key` is optional in the caller signature; when omitted we
##     fall back to a UUID (Godot 4.4+) or a randi-based stand-in. Upstream uses
##     `Guid.NewGuid().ToString()`.
##   - Auto-load-on-login is not ported.
##
## upstream: 3_ItemContainer/Crafting/ItemCrafting.cs:8
class_name ItemCrafting
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6)
# -------------------------------------------------------------------------

## upstream: ItemCrafting.cs:161, :183
const PATH_CRAFT := "/api/v1/games/{game_id}/crafting/craft"
## upstream: ItemCrafting.cs:280
const PATH_HISTORY := "/api/v1/games/{game_id}/crafting/history"
## upstream: ItemCrafting.cs:362
const PATH_RECIPE_BY_KEY := "/api/v1/games/{game_id}/crafting/recipes-by-key/{recipe_key}"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ItemCrafting.cs:11 (OnCraftSuccess)
signal craft_success(response: CraftingResponse)
signal craft_failed(error: String)

## upstream: ItemCrafting.cs:14 (OnGetHistorySuccess)
signal history_loaded(transactions: Array, total: int)
signal history_failed(error: String)

## upstream: ItemCrafting.cs:17 (OnGetRecipeByKeySuccess)
signal recipe_loaded(recipe: RecipeDetail)
signal recipe_failed(recipe_key: String, error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: ItemCrafting.cs:24 (currentHistory)
var current_history: Array[CraftingHistoryTransaction] = []

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/crafting/craft — by recipe id.
##
## upstream: ItemCrafting.cs:102 (Craft), :154 (Coroutine)
func craft(recipe_id: String, idempotency_key: String = "") -> Dictionary:
	return await _craft_internal({"recipe_id": recipe_id}, idempotency_key)


## POST /api/v1/games/{game_id}/crafting/craft — by recipe key.
##
## upstream: ItemCrafting.cs:130 (CraftByKey), :176 (Coroutine)
func craft_by_key(recipe_key: String, idempotency_key: String = "") -> Dictionary:
	return await _craft_internal({"recipe_key": recipe_key}, idempotency_key)


## GET /api/v1/games/{game_id}/crafting/history?page=&page_size=[&recipe_id=][&status=]
##
## On success, `data` is `{transactions: Array[CraftingHistoryTransaction], page,
## page_size, total: int}`.
##
## upstream: ItemCrafting.cs:242 (GetCraftingHistory), :271 (Coroutine)
func get_history(
	page: int = 1, page_size: int = 20, recipe_id: String = "", status: String = ""
) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		history_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		history_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_HISTORY.replace("{game_id}", _game_id(server))
	var query: Dictionary = {"page": page, "page_size": page_size}
	if not recipe_id.is_empty():
		query["recipe_id"] = recipe_id
	if not status.is_empty():
		query["status"] = status

	var result: Dictionary = await server.get_request(path, query, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("transactions", null)
			var typed: Array[CraftingHistoryTransaction] = []
			if raw is Array:
				for t in raw:
					typed.append(CraftingHistoryTransaction.from_dict(t))
			current_history = typed
			var total: int = int((payload as Dictionary).get("total", 0))
			result["data"] = {
				"transactions": typed,
				"page": int((payload as Dictionary).get("page", page)),
				"page_size": int((payload as Dictionary).get("page_size", page_size)),
				"total": total,
			}
			history_loaded.emit(typed, total)
			return result
		var msg := "history response not a JSON object"
		history_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_history failed"))
	history_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/crafting/recipes-by-key/{recipe_key}
##
## upstream: ItemCrafting.cs:327 (GetRecipeByKey), :356 (Coroutine)
func get_recipe_by_key(recipe_key: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		recipe_failed.emit(recipe_key, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		recipe_failed.emit(recipe_key, err)
		return _envelope_fail(err)

	if recipe_key.is_empty():
		var err := "Recipe key cannot be empty."
		recipe_failed.emit(recipe_key, err)
		return _envelope_fail(err)

	var path: String = PATH_RECIPE_BY_KEY.replace("{game_id}", _game_id(server)).replace(
		"{recipe_key}", recipe_key
	)
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := RecipeDetail.from_dict(payload)
			result["data"] = dto
			recipe_loaded.emit(dto)
			return result
		var msg := "recipe response not a JSON object"
		recipe_failed.emit(recipe_key, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_recipe_by_key failed"))
	recipe_failed.emit(recipe_key, error_msg)
	return result


## upstream: ItemCrafting.cs:399 (ClearHistory)
func clear_history() -> void:
	current_history = []


# =========================================================================
# Internals
# =========================================================================


func _craft_internal(body_part: Dictionary, idempotency_key: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		craft_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		craft_failed.emit(err)
		return _envelope_fail(err)

	var key: String = idempotency_key
	if key.is_empty():
		key = _new_idempotency_key()

	var body: Dictionary = body_part.duplicate()
	body["idempotency_key"] = key

	var path: String = PATH_CRAFT.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := CraftingResponse.from_dict(payload)
			result["data"] = dto
			craft_success.emit(dto)
			return result
		var msg := "craft response not a JSON object"
		craft_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "craft failed"))
	craft_failed.emit(error_msg)
	return result


## Idempotency key generator. Uses Godot's `Crypto` for randomness when
## available; falls back to a randi-based stand-in.
## upstream: ItemCrafting.cs:165 (Guid.NewGuid)
func _new_idempotency_key() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	# Format as a UUIDv4-ish string for parity with .NET's Guid representation.
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12),
		]
	)


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
