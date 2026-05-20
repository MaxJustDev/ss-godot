## ItemTag - list game-level item tags + fetch items by tag.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Tag/ItemTag.cs:8`.
##
## Auto-load-on-login and ClearOnLogout are intentionally NOT ported — the
## app layer can subscribe to `SaiServer.auth.login_success` / `logout_success`
## and call `get_tags()` / clear the cache itself.
##
## upstream: 3_ItemContainer/Tag/ItemTag.cs:8
class_name ItemTag
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: ItemTag.cs:114
const PATH_TAGS := "/api/v1/games/{game_id}/item-tags"
## upstream: ItemTag.cs:218
const PATH_TAG_ITEMS := "/api/v1/games/{game_id}/item-tags/{tag_key}/items"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ItemTag.cs:11 (OnGetTagsSuccess)
signal tags_loaded(tags: Array, total: int)
## upstream: ItemTag.cs:12 (OnGetTagsFailure)
signal tags_failed(error: String)

signal tag_items_loaded(tag_key: String, items: Array, total: int)
signal tag_items_failed(tag_key: String, error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: ItemTag.cs:18 (currentTags)
var current_tags: Array[ItemTagData] = []
var _last_total: int = 0

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/item-tags?limit=&offset=
##
## upstream: ItemTag.cs:91 (GetTags), :111 (Coroutine)
func get_tags(limit: int = 50, offset: int = 0) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		tags_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		tags_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_TAGS.replace("{game_id}", _game_id(server))
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("tags", null)
			var typed: Array[ItemTagData] = []
			if raw is Array:
				for t in raw:
					typed.append(ItemTagData.from_dict(t))
			current_tags = typed
			_last_total = int((payload as Dictionary).get("total", 0))
			result["data"] = {
				"tags": typed,
				"total": _last_total,
				"limit": int((payload as Dictionary).get("limit", limit)),
				"offset": int((payload as Dictionary).get("offset", offset)),
			}
			tags_loaded.emit(typed, _last_total)
			return result
		var msg := "tags response not a JSON object"
		tags_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_tags failed"))
	tags_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/item-tags/{tag_key}/items
##
## upstream: ItemTag.cs:195 (GetItemsByTag), :215 (Coroutine)
func get_items_by_tag(tag_key: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		tag_items_failed.emit(tag_key, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		tag_items_failed.emit(tag_key, err)
		return _envelope_fail(err)

	if tag_key.is_empty():
		var err := "tag_key must not be empty."
		tag_items_failed.emit(tag_key, err)
		return _envelope_fail(err)

	var path: String = PATH_TAG_ITEMS.replace("{game_id}", _game_id(server)).replace(
		"{tag_key}", tag_key
	)
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_items: Variant = (payload as Dictionary).get("items", null)
			var typed: Array[InventoryItemData] = []
			if raw_items is Array:
				for it in raw_items:
					typed.append(InventoryItemData.from_dict(it))
			var total: int = int((payload as Dictionary).get("total", 0))
			result["data"] = {
				"items": typed,
				"total": total,
				"limit": int((payload as Dictionary).get("limit", 0)),
				"offset": int((payload as Dictionary).get("offset", 0)),
			}
			tag_items_loaded.emit(tag_key, typed, total)
			return result
		var msg := "tag items response not a JSON object"
		tag_items_failed.emit(tag_key, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_items_by_tag failed"))
	tag_items_failed.emit(tag_key, error_msg)
	return result


# ── Convenience query helpers ──────────────────────────────────────────────


## upstream: ItemTag.cs:182 (GetTagById)
func get_tag_by_id(tag_id: String) -> ItemTagData:
	for t in current_tags:
		if t.id == tag_id:
			return t
	return null


## upstream: ItemTag.cs:262 (GetTagByKey)
func get_tag_by_key(tag_key: String) -> ItemTagData:
	for t in current_tags:
		if t.tag_key == tag_key:
			return t
	return null


## upstream: ItemTag.cs:171 (ClearTags)
func clear_tags() -> void:
	current_tags = []
	_last_total = 0


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


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
