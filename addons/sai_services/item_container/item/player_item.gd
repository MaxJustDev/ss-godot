## PlayerItem - inventory list / item-properties update / categories / move /
## swap.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Item/PlayerItem.cs:8`.
## Move and swap, which live in their own classes upstream (ItemMove.cs,
## ItemSwap.cs), are absorbed here as separate methods (`move_item`,
## `swap_items`) so the Godot service surface area matches the public API
## advertised in `docs/examples/inventory.md`.
##
## Translation notes:
##   - Unity's `InventoryJsonHelper.StringifyObjectFields` pre-processing is
##     not required because Godot's `JSON.parse_string` keeps nested objects
##     intact — `InventoryItemData.from_dict` re-serializes the raw fields.
##   - 24-hour PlayerPrefs cache for categories is intentionally NOT ported in
##     M4: it depends on PlayerPrefs and on startup auto-fetch behaviour. The
##     `get_categories()` method now hits the network every call. App code can
##     cache the result if needed.
##   - This node is added as a child of `SaiServer` via `_register_sub_services`.
##
## upstream: 3_ItemContainer/Item/PlayerItem.cs:8
class_name PlayerItem
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: PlayerItem.cs:201
const PATH_INVENTORY := "/api/v1/games/{game_id}/inventory"
## upstream: PlayerItem.cs:296
const PATH_INVENTORY_ITEM := "/api/v1/games/{game_id}/inventory-items/{item_id}"
## upstream: PlayerItem.cs:438
const PATH_CATEGORIES := "/api/v1/items/categories"
## upstream: ItemMove.cs:148
const PATH_INVENTORY_MOVE := "/api/v1/games/{game_id}/inventory/move"
## upstream: ItemSwap.cs:130
const PATH_INVENTORY_SWAP := "/api/v1/games/{game_id}/inventory/swap"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: PlayerItem.cs:11 (OnGetItemsSuccess)
signal items_loaded(items: Array, total: int)
## upstream: PlayerItem.cs:12 (OnGetItemsFailure)
signal items_failed(error: String)

signal update_properties_success(item: InventoryItemData)
signal update_properties_failed(error: String)

## upstream: PlayerItem.cs:32 (OnCategoriesLoaded)
signal categories_loaded(categories: PackedStringArray)
signal categories_failed(error: String)

## upstream: ItemMove.cs:22 (OnMoveSuccess)
signal move_success(data: Dictionary)
signal move_failed(error: String)

## upstream: ItemSwap.cs:22 (OnSwapSuccess)
signal swap_success(data: Dictionary)
signal swap_failed(error: String)

# -------------------------------------------------------------------------
# State (cached last list)
# -------------------------------------------------------------------------

## Most recent inventory items returned by `get_items()`.
## upstream: PlayerItem.cs:19 (currentInventory)
var current_items: Array[InventoryItemData] = []
var _last_total: int = 0
var _last_limit: int = 0
var _last_offset: int = 0

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/inventory?limit=&offset=&include_metadata=true[&category=]
##
## On success, `data` is `{items: Array[InventoryItemData], total, limit,
## offset: int}` and `current_items` is updated.
##
## upstream: PlayerItem.cs:164 (GetItems), :193 (Coroutine)
func get_items(limit: int = 50, offset: int = 0, category: String = "") -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		items_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		items_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_INVENTORY.replace("{game_id}", _game_id(server))
	var query: Dictionary = {
		"limit": limit,
		"offset": offset,
		"include_metadata": "true",
	}
	if not category.is_empty():
		query["category"] = category

	var result: Dictionary = await server.get_request(path, query, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_items: Variant = (payload as Dictionary).get("items", null)
			var typed: Array[InventoryItemData] = []
			if raw_items is Array:
				for it in raw_items:
					typed.append(InventoryItemData.from_dict(it))
			current_items = typed
			_last_total = int((payload as Dictionary).get("total", 0))
			_last_limit = int((payload as Dictionary).get("limit", limit))
			_last_offset = int((payload as Dictionary).get("offset", offset))
			result["data"] = {
				"items": typed,
				"total": _last_total,
				"limit": _last_limit,
				"offset": _last_offset,
			}
			items_loaded.emit(typed, _last_total)
			return result
		var msg := "inventory response not a JSON object"
		items_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_items failed"))
	items_failed.emit(error_msg)
	return result


## PATCH /api/v1/games/{game_id}/inventory-items/{item_id}
##
## `properties` is a Dictionary that will be merged server-side. Optimistically
## updates the cached item's `public_properties` to match upstream behaviour
## (PlayerItem.cs:309-319).
##
## upstream: PlayerItem.cs:259 (UpdateItemProperties), :289 (Coroutine)
func update_item_properties(item_id: String, properties: Variant) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		update_properties_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		update_properties_failed.emit(err)
		return _envelope_fail(err)

	if item_id.is_empty():
		var err := "itemId must not be empty."
		update_properties_failed.emit(err)
		return _envelope_fail(err)

	# upstream: PlayerItem.cs:299 — `version` field is required by schema but
	# ignored server-side for optimistic locking.
	var body: Dictionary = {
		"version": 0,
		"properties": _coerce_properties(properties),
	}
	var path: String = PATH_INVENTORY_ITEM.replace("{game_id}", _game_id(server)).replace(
		"{item_id}", item_id
	)
	var result: Dictionary = await server.patch_request(path, body, true)
	if result.get("success", false):
		var cached: InventoryItemData = _find_cached_item(item_id)
		if cached != null:
			# upstream: PlayerItem.cs:316 — optimistic merge of the sent JSON.
			cached.public_properties = JSON.stringify(body["properties"])
		update_properties_success.emit(cached)
		return result

	var error_msg: String = String(result.get("error", "update_item_properties failed"))
	update_properties_failed.emit(error_msg)
	return result


## GET /api/v1/items/categories
##
## On success, `data` is `PackedStringArray` of category names.
##
## upstream: PlayerItem.cs:404 (GetItemCategories), :434 (Coroutine)
func get_categories() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		categories_failed.emit(err)
		return _envelope_fail(err)

	var result: Dictionary = await server.get_request(PATH_CATEGORIES, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("categories", null)
			var arr: PackedStringArray = PackedStringArray()
			if raw is Array:
				arr = PackedStringArray(raw)
			result["data"] = arr
			categories_loaded.emit(arr)
			return result
		var msg := "categories response not a JSON object"
		categories_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_categories failed"))
	categories_failed.emit(error_msg)
	return result


## POST /api/v1/games/{game_id}/inventory/move
##
## Response body is forwarded raw (Dictionary) per endpoints.md.
##
## upstream: ItemMove.cs:78 (Move), :138 (Coroutine)
func move_item(
	item_id: String,
	target_container_id: String,
	quantity: int,
	grid_x: int = 0,
	grid_y: int = 0,
) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		move_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		move_failed.emit(err)
		return _envelope_fail(err)

	if item_id.is_empty():
		var err := "item_id must not be empty."
		move_failed.emit(err)
		return _envelope_fail(err)

	if target_container_id.is_empty():
		var err := "target_container_id must not be empty."
		move_failed.emit(err)
		return _envelope_fail(err)

	if quantity <= 0:
		var err := "quantity must be greater than 0."
		move_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_INVENTORY_MOVE.replace("{game_id}", _game_id(server))
	var body: Dictionary = {
		"item_id": item_id,
		"target_container_id": target_container_id,
		"quantity": quantity,
		"grid_x": grid_x,
		"grid_y": grid_y,
	}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		move_success.emit(payload if payload is Dictionary else {})
		return result

	var error_msg: String = String(result.get("error", "move_item failed"))
	move_failed.emit(error_msg)
	return result


## POST /api/v1/games/{game_id}/inventory/swap
##
## Response body is forwarded raw (Dictionary) per endpoints.md.
##
## upstream: ItemSwap.cs:69 (Swap), :123 (Coroutine)
func swap_items(item_a_id: String, item_b_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		swap_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		swap_failed.emit(err)
		return _envelope_fail(err)

	if item_a_id.is_empty():
		var err := "item_a_id must not be empty."
		swap_failed.emit(err)
		return _envelope_fail(err)

	if item_b_id.is_empty():
		var err := "item_b_id must not be empty."
		swap_failed.emit(err)
		return _envelope_fail(err)

	if item_a_id == item_b_id:
		var err := "item_a_id and item_b_id must not be the same."
		swap_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_INVENTORY_SWAP.replace("{game_id}", _game_id(server))
	var body: Dictionary = {"item_a_id": item_a_id, "item_b_id": item_b_id}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		swap_success.emit(payload if payload is Dictionary else {})
		return result

	var error_msg: String = String(result.get("error", "swap_items failed"))
	swap_failed.emit(error_msg)
	return result


# ── Convenience query helpers (local) ──────────────────────────────────────


## upstream: PlayerItem.cs:366 (GetItemById)
func get_item_by_id(item_id: String) -> InventoryItemData:
	return _find_cached_item(item_id)


## upstream: PlayerItem.cs:381 (GetItemsByCategory)
func get_items_by_category(category: String) -> Array[InventoryItemData]:
	var out: Array[InventoryItemData] = []
	for it in current_items:
		if it.definition != null and it.definition.category == category:
			out.append(it)
	return out


## upstream: PlayerItem.cs:343 (ClearInventory)
func clear_inventory() -> void:
	current_items = []
	_last_total = 0
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


func _find_cached_item(item_id: String) -> InventoryItemData:
	for it in current_items:
		if it.id == item_id:
			return it
	return null


## Coerce caller-supplied `properties` into a Dictionary.
##
## Accepts either a Dictionary (forwarded verbatim), or a JSON string (parsed
## back into a Dictionary). Anything else becomes an empty object so the
## server validators have something to chew on.
func _coerce_properties(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value
	if value is String:
		var s: String = value
		if s.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(s)
		if parsed is Dictionary or parsed is Array:
			return parsed
	return {}


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
