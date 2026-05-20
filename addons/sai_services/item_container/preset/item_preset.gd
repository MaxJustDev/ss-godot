## ItemPreset - preset CRUD + slot add/remove for the `/presets` endpoints.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:8`.
##
## Special-case notes:
##   - The PATCH /presets/{preset_id} endpoint accepts two body shapes —
##     `{name: ...}` for rename and `{metadata: ...}` for metadata edits, or
##     both. We expose three methods: `rename_preset`, `update_preset_metadata`,
##     `update_preset` (combined). All hit the same path.
##   - After PUT/DELETE `.../slots/{slot_index}` upstream calls GET
##     `.../{preset_id}` to refresh. We port that client-side refresh —
##     `add_item_to_preset` and `remove_item_from_preset` return the refreshed
##     PresetData (with slots) on success.
##   - The preset list endpoint returns `PresetResponse { containers: [...] }`
##     where `containers` is the array of presets (yes, weird upstream naming).
##
## upstream: 3_ItemContainer/Preset/ItemPreset.cs:8
class_name ItemPreset
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: ItemPreset.cs:209 (POST), :494 (GET list)
const PATH_PRESETS := "/api/v1/games/{game_id}/presets"
## upstream: ItemPreset.cs:576 (GET one), :659 (DELETE), :730 (PATCH)
const PATH_PRESET := "/api/v1/games/{game_id}/presets/{preset_id}"
## upstream: ItemPreset.cs:297 (PUT), :401 (DELETE)
const PATH_PRESET_SLOT := "/api/v1/games/{game_id}/presets/{preset_id}/slots/{slot_index}"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ItemPreset.cs:11 (OnCreatePresetSuccess)
signal create_success(preset: PresetData)
signal create_failed(error: String)

## upstream: ItemPreset.cs:13 (OnGetPresetsSuccess)
signal list_loaded(presets: Array)
signal list_failed(error: String)

signal get_one_success(preset: PresetData)
signal get_one_failed(preset_id: String, error: String)

signal slot_added(preset_id: String, slot_index: int, preset: PresetData)
signal slot_add_failed(preset_id: String, slot_index: int, error: String)

signal slot_removed(preset_id: String, slot_index: int, preset: PresetData)
signal slot_remove_failed(preset_id: String, slot_index: int, error: String)

signal update_success(preset: PresetData)
signal update_failed(preset_id: String, error: String)

signal delete_success(preset_id: String)
signal delete_failed(preset_id: String, error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: ItemPreset.cs:20 (currentPresets — list of presets)
var current_presets: Array[PresetData] = []

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/presets — by code_name.
## Body: `{code_name, name?}`
##
## upstream: ItemPreset.cs:101 (CreatePresetByCodeName), :201 (Coroutine)
func create_by_code_name(code_name: String, preset_name: String = "") -> Dictionary:
	return await _create_internal("code_name", code_name, preset_name)


## POST /api/v1/games/{game_id}/presets — by definition_id.
## Body: `{definition_id, name?}`
##
## upstream: ItemPreset.cs:110 (CreatePresetByDefinitionId)
func create_by_definition_id(definition_id: String, preset_name: String = "") -> Dictionary:
	return await _create_internal("definition_id", definition_id, preset_name)


## GET /api/v1/games/{game_id}/presets
##
## On success, `data` is `{presets: Array[PresetData]}`. Server's response key
## is `containers` (upstream legacy); we expose it as `presets` for clarity.
##
## upstream: ItemPreset.cs:467 (GetPresets), :489 (Coroutine)
func list() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		list_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		list_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_PRESETS.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("containers", null)
			var typed: Array[PresetData] = []
			if raw is Array:
				for p in raw:
					typed.append(PresetData.from_dict(p))
			current_presets = typed
			result["data"] = {"presets": typed}
			list_loaded.emit(typed)
			return result
		var msg := "presets response not a JSON object"
		list_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "list failed"))
	list_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/presets/{preset_id}
##
## Server returns `{container: PresetData, slots: PresetSlotData[]}`. We merge
## `slots` into the returned PresetData (mirroring upstream behaviour at
## ItemPreset.cs:586).
##
## upstream: ItemPreset.cs:541 (GetPreset), :570 (Coroutine)
func get_one(preset_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		get_one_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		get_one_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if preset_id.is_empty():
		var err := "preset_id cannot be empty."
		get_one_failed.emit(preset_id, err)
		return _envelope_fail(err)

	var path: String = PATH_PRESET.replace("{game_id}", _game_id(server)).replace(
		"{preset_id}", preset_id
	)
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		var dto: PresetData = _extract_detail(payload)
		if dto != null:
			result["data"] = dto
			get_one_success.emit(dto)
			return result
		var msg := "preset detail response invalid"
		get_one_failed.emit(preset_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_one failed"))
	get_one_failed.emit(preset_id, error_msg)
	return result


## PUT /api/v1/games/{game_id}/presets/{preset_id}/slots/{slot_index}
##
## Body: `{inventory_item_id}`. After the PUT succeeds upstream re-fetches the
## preset (ItemPreset.cs:309) — we do the same.
##
## upstream: ItemPreset.cs:258 (AddItemToPreset), :289 (Coroutine)
func add_item_to_preset(
	preset_id: String, slot_index: int, inventory_item_id: String
) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		slot_add_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		slot_add_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	if preset_id.is_empty() or inventory_item_id.is_empty():
		var err := "preset_id and inventory_item_id cannot be empty."
		slot_add_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	var path: String = (
		PATH_PRESET_SLOT
		. replace("{game_id}", _game_id(server))
		. replace("{preset_id}", preset_id)
		. replace("{slot_index}", str(slot_index))
	)
	var body: Dictionary = {"inventory_item_id": inventory_item_id}
	var put_result: Dictionary = await server.put_request(path, body, true)
	if not put_result.get("success", false):
		var error_msg: String = String(put_result.get("error", "add_item_to_preset failed"))
		slot_add_failed.emit(preset_id, slot_index, error_msg)
		return put_result

	# upstream: ItemPreset.cs:309 — client-side refresh of the preset.
	var refreshed: Dictionary = await get_one(preset_id)
	if refreshed.get("success", false):
		var dto: PresetData = refreshed.get("data") as PresetData
		slot_added.emit(preset_id, slot_index, dto)
	else:
		slot_add_failed.emit(
			preset_id, slot_index, String(refreshed.get("error", "refresh failed"))
		)
	return refreshed


## DELETE /api/v1/games/{game_id}/presets/{preset_id}/slots/{slot_index}
##
## After DELETE succeeds upstream re-fetches the preset (ItemPreset.cs:413).
##
## upstream: ItemPreset.cs:364 (RemoveItemFromPreset), :394 (Coroutine)
func remove_item_from_preset(preset_id: String, slot_index: int) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		slot_remove_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		slot_remove_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	if preset_id.is_empty():
		var err := "preset_id cannot be empty."
		slot_remove_failed.emit(preset_id, slot_index, err)
		return _envelope_fail(err)

	var path: String = (
		PATH_PRESET_SLOT
		. replace("{game_id}", _game_id(server))
		. replace("{preset_id}", preset_id)
		. replace("{slot_index}", str(slot_index))
	)
	var del_result: Dictionary = await server.delete_request(path, null, true)
	if not del_result.get("success", false):
		var error_msg: String = String(del_result.get("error", "remove_item_from_preset failed"))
		slot_remove_failed.emit(preset_id, slot_index, error_msg)
		return del_result

	# upstream: ItemPreset.cs:413 — client-side refresh.
	var refreshed: Dictionary = await get_one(preset_id)
	if refreshed.get("success", false):
		var dto: PresetData = refreshed.get("data") as PresetData
		slot_removed.emit(preset_id, slot_index, dto)
	else:
		slot_remove_failed.emit(
			preset_id, slot_index, String(refreshed.get("error", "refresh failed"))
		)
	return refreshed


## PATCH /api/v1/games/{game_id}/presets/{preset_id} — rename only.
## Body: `{name}`
##
## upstream: ItemPreset.cs:691 (UpdatePreset) — rename body shape.
func rename_preset(preset_id: String, new_name: String) -> Dictionary:
	return await _update_internal(preset_id, new_name, null)


## PATCH /api/v1/games/{game_id}/presets/{preset_id} — metadata only.
## Body: `{metadata: ...}`
##
## upstream: ItemPreset.cs:691 (UpdatePreset) — metadata body shape.
func update_preset_metadata(preset_id: String, metadata: Variant) -> Dictionary:
	return await _update_internal(preset_id, "", metadata)


## PATCH /api/v1/games/{game_id}/presets/{preset_id} — combined.
##
## At least one of `new_name` (non-empty) or `metadata` (non-null) is required.
##
## upstream: ItemPreset.cs:691 (UpdatePreset), :722 (Coroutine)
func update_preset(
	preset_id: String, new_name: String = "", metadata: Variant = null
) -> Dictionary:
	return await _update_internal(preset_id, new_name, metadata)


## DELETE /api/v1/games/{game_id}/presets/{preset_id}
##
## Response body is forwarded raw. Cache entry is removed locally on success.
##
## upstream: ItemPreset.cs:624 (DeletePreset), :653 (Coroutine)
func delete_preset(preset_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		delete_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		delete_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if preset_id.is_empty():
		var err := "preset_id cannot be empty."
		delete_failed.emit(preset_id, err)
		return _envelope_fail(err)

	var path: String = PATH_PRESET.replace("{game_id}", _game_id(server)).replace(
		"{preset_id}", preset_id
	)
	var result: Dictionary = await server.delete_request(path, null, true)
	if result.get("success", false):
		_remove_cached(preset_id)
		delete_success.emit(preset_id)
		return result

	var error_msg: String = String(result.get("error", "delete_preset failed"))
	delete_failed.emit(preset_id, error_msg)
	return result


## upstream: ItemPreset.cs:799 (ClearPresets)
func clear_presets() -> void:
	current_presets = []


# ── Convenience query helpers ──────────────────────────────────────────────


## upstream: ItemPreset.cs:821 (GetPresetById)
func get_preset_by_id(preset_id: String) -> PresetData:
	for p in current_presets:
		if p.id == preset_id:
			return p
	return null


## upstream: ItemPreset.cs:836 (GetPresetsByType)
func get_presets_by_type(preset_type: String) -> Array[PresetData]:
	var out: Array[PresetData] = []
	for p in current_presets:
		if p.preset_type == preset_type:
			out.append(p)
	return out


# =========================================================================
# Internals
# =========================================================================


func _create_internal(key: String, identifier: String, preset_name: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		create_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		create_failed.emit(err)
		return _envelope_fail(err)

	if identifier.is_empty():
		var err := "%s cannot be empty." % key
		create_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_PRESETS.replace("{game_id}", _game_id(server))
	var body: Dictionary = {key: identifier}
	if not preset_name.is_empty():
		body["name"] = preset_name

	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := PresetData.from_dict(payload)
			result["data"] = dto
			create_success.emit(dto)
			return result
		var msg := "create preset response not a JSON object"
		create_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "create_preset failed"))
	create_failed.emit(error_msg)
	return result


func _update_internal(preset_id: String, new_name: String, metadata: Variant) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		update_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		update_failed.emit(preset_id, err)
		return _envelope_fail(err)

	if preset_id.is_empty():
		var err := "preset_id cannot be empty."
		update_failed.emit(preset_id, err)
		return _envelope_fail(err)

	var body: Dictionary = {}
	if not new_name.is_empty():
		body["name"] = new_name
	if metadata != null:
		body["metadata"] = _coerce_metadata(metadata)

	if body.is_empty():
		var err := "Nothing to update: both name and metadata are empty."
		update_failed.emit(preset_id, err)
		return _envelope_fail(err)

	var path: String = PATH_PRESET.replace("{game_id}", _game_id(server)).replace(
		"{preset_id}", preset_id
	)
	var result: Dictionary = await server.patch_request(path, body, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := PresetData.from_dict(payload)
			# upstream: ItemPreset.cs:764 — preserve cached slots since the PATCH
			# response does not include them.
			var cached: PresetData = get_preset_by_id(dto.id)
			if cached != null:
				dto.slots = cached.slots
				_replace_cached(dto)
			result["data"] = dto
			update_success.emit(dto)
			return result
		var msg := "update preset response not a JSON object"
		update_failed.emit(preset_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "update_preset failed"))
	update_failed.emit(preset_id, error_msg)
	return result


## Convert the server `{container, slots}` envelope into a single PresetData
## with `.slots` populated.
## upstream: ItemPreset.cs:586
func _extract_detail(payload: Variant) -> PresetData:
	if not (payload is Dictionary):
		return null
	var dict: Dictionary = payload
	var container: Variant = dict.get("container", null)
	if not (container is Dictionary):
		return null
	var dto := PresetData.from_dict(container)
	var raw_slots: Variant = dict.get("slots", null)
	if raw_slots is Array:
		var typed: Array[PresetSlotData] = []
		for s in raw_slots:
			typed.append(PresetSlotData.from_dict(s))
		dto.slots = typed
	return dto


func _coerce_metadata(value: Variant) -> Variant:
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


func _replace_cached(dto: PresetData) -> void:
	for i in current_presets.size():
		if current_presets[i].id == dto.id:
			current_presets[i] = dto
			return


func _remove_cached(preset_id: String) -> void:
	var keep: Array[PresetData] = []
	for p in current_presets:
		if p.id != preset_id:
			keep.append(p)
	current_presets = keep


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
