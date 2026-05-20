## EquipmentSlot - list / equip / unequip / list-equipped operations.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/3_ItemContainer/Slot/EquipmentSlot.cs:9`.
##
## Translation notes:
##   - `slot_data` in the equip body is a free-form JSON object. We accept
##     either a Dictionary (forwarded verbatim) or a JSON string (parsed back
##     into a Dictionary). The upstream "manual JSON splice" workaround for
##     keeping arbitrary objects intact is unnecessary because GDScript's
##     `JSON.stringify` handles nested objects natively.
##   - Response bodies for `equip` and `unequip` are forwarded raw per
##     endpoints.md.
##   - `slot_data_raw` on each `EquippedItemData` is populated from the parsed
##     object (re-stringified) inside `EquippedItemData.from_dict`.
##
## upstream: 3_ItemContainer/Slot/EquipmentSlot.cs:9
class_name EquipmentSlot
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: EquipmentSlot.cs:109
const PATH_SLOTS := "/api/v1/games/{game_id}/inventory/equipment-slots"
## upstream: EquipmentSlot.cs:171
const PATH_EQUIP := "/api/v1/games/{game_id}/inventory/equip"
## upstream: EquipmentSlot.cs:221
const PATH_UNEQUIP := "/api/v1/games/{game_id}/inventory/unequip"
## upstream: EquipmentSlot.cs:268
const PATH_EQUIPPED := "/api/v1/games/{game_id}/inventory/equipped"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: EquipmentSlot.cs:11 (OnGetSlotsSuccess)
signal slots_loaded(slots: Array, total: int)
signal slots_failed(error: String)

## upstream: EquipmentSlot.cs:13 (OnGetEquippedSuccess)
signal equipped_loaded(equipped: Array)
signal equipped_failed(error: String)

## upstream: EquipmentSlot.cs:15 (OnEquipSuccess) — `data` forwarded raw.
signal equip_success(data: Variant)
signal equip_failed(error: String)

## upstream: EquipmentSlot.cs:17 (OnUnequipSuccess)
signal unequip_success(data: Variant)
signal unequip_failed(error: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## upstream: EquipmentSlot.cs:26 (currentSlots)
var current_slots: Array[EquipmentSlotData] = []
## upstream: EquipmentSlot.cs:27 (currentEquipped)
var current_equipped: Array[EquippedItemData] = []

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/inventory/equipment-slots
##
## upstream: EquipmentSlot.cs:86 (GetSlots), :106 (Coroutine)
func get_slots() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		slots_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		slots_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SLOTS.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("slots", null)
			var typed: Array[EquipmentSlotData] = []
			if raw is Array:
				for s in raw:
					typed.append(EquipmentSlotData.from_dict(s))
			current_slots = typed
			var total: int = int((payload as Dictionary).get("total", 0))
			result["data"] = {"slots": typed, "total": total}
			slots_loaded.emit(typed, total)
			return result
		var msg := "slots response not a JSON object"
		slots_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_slots failed"))
	slots_failed.emit(error_msg)
	return result


## POST /api/v1/games/{game_id}/inventory/equip
##
## `slot_data` is freeform per endpoints.md. Accepts Dictionary or JSON String.
##
## upstream: EquipmentSlot.cs:146 (EquipItem), :167 (Coroutine)
func equip_item(item_id: String, slot_key: String, slot_data: Variant = {}) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		equip_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		equip_failed.emit(err)
		return _envelope_fail(err)

	if item_id.is_empty():
		var err := "item_id must not be empty."
		equip_failed.emit(err)
		return _envelope_fail(err)

	if slot_key.is_empty():
		var err := "slot_key must not be empty."
		equip_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_EQUIP.replace("{game_id}", _game_id(server))
	var body: Dictionary = {
		"item_id": item_id,
		"slot_key": slot_key,
		"slot_data": _coerce_slot_data(slot_data),
	}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		equip_success.emit(result.get("data", null))
		return result

	var error_msg: String = String(result.get("error", "equip_item failed"))
	equip_failed.emit(error_msg)
	return result


## POST /api/v1/games/{game_id}/inventory/unequip
##
## upstream: EquipmentSlot.cs:198 (UnequipItem), :218 (Coroutine)
func unequip_item(item_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		unequip_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		unequip_failed.emit(err)
		return _envelope_fail(err)

	if item_id.is_empty():
		var err := "item_id must not be empty."
		unequip_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_UNEQUIP.replace("{game_id}", _game_id(server))
	var body: Dictionary = {"item_id": item_id}
	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		unequip_success.emit(result.get("data", null))
		return result

	var error_msg: String = String(result.get("error", "unequip_item failed"))
	unequip_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/inventory/equipped
##
## upstream: EquipmentSlot.cs:245 (GetEquippedItems), :265 (Coroutine)
func get_equipped() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		equipped_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		equipped_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_EQUIPPED.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw: Variant = (payload as Dictionary).get("equipped", null)
			var typed: Array[EquippedItemData] = []
			if raw is Array:
				for e in raw:
					typed.append(EquippedItemData.from_dict(e))
			current_equipped = typed
			result["data"] = {"equipped": typed}
			equipped_loaded.emit(typed)
			return result
		var msg := "equipped response not a JSON object"
		equipped_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_equipped failed"))
	equipped_failed.emit(error_msg)
	return result


## upstream: EquipmentSlot.cs:306 (ClearSlots)
func clear_slots() -> void:
	current_slots = []
	current_equipped = []


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


func _coerce_slot_data(value: Variant) -> Variant:
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
