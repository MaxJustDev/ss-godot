## ItemAddDeduct - add/deduct item quantity via the v2 inventory endpoint.
##
## This is the ONLY service in the SDK that uses the `/api/v2/` prefix; every
## other endpoint is v1. The prefix is hard-coded as `PATH_QTY` here so the
## v2 surface area is explicit.
##
## upstream: 3_ItemContainer/Item/ItemAddDeduct.cs:21
class_name ItemAddDeduct
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## The ONLY `/api/v2/` endpoint in the SDK. Hard-coded prefix; do not use the
## global `/api/v1/` template.
## upstream: ItemAddDeduct.cs:134
const PATH_QTY := "/api/v2/games/{game_id}/item-inventories/{item_definition_id}/qty"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ItemAddDeduct.cs:24 (OnAddDeductSuccess) — `data` is the raw
## response body (forwarded verbatim, not modelled).
signal add_deduct_success(data: Variant)
## upstream: ItemAddDeduct.cs:25 (OnAddDeductFailure)
signal add_deduct_failed(error: String)

# =========================================================================
# Public API
# =========================================================================


## PUT /api/v2/games/{game_id}/item-inventories/{item_definition_id}/qty
##
## `quantity > 0` = add. `quantity < 0` = deduct. `quantity == 0` is refused
## up-front. `container_id` is optional; when provided, it's added to the body.
##
## Response is forwarded raw (Variant) per endpoints.md.
##
## upstream: ItemAddDeduct.cs:76 (AddDeduct), :126 (Coroutine)
func add_deduct(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		add_deduct_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		add_deduct_failed.emit(err)
		return _envelope_fail(err)

	if item_definition_id.is_empty():
		var err := "item_definition_id must not be empty."
		add_deduct_failed.emit(err)
		return _envelope_fail(err)

	if quantity == 0:
		var err := "quantity must not be 0."
		add_deduct_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_QTY.replace("{game_id}", _game_id(server)).replace(
		"{item_definition_id}", item_definition_id
	)
	var body: Dictionary = {"quantity": quantity}
	if not container_id.is_empty():
		body["container_id"] = container_id

	var result: Dictionary = await server.put_request(path, body, true)
	if result.get("success", false):
		add_deduct_success.emit(result.get("data", null))
		return result

	var error_msg: String = String(result.get("error", "add_deduct failed"))
	add_deduct_failed.emit(error_msg)
	return result


## Convenience: positive delta == add.
func add(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary:
	return await add_deduct(item_definition_id, abs(quantity), container_id)


## Convenience: deduct sends a negative quantity.
func deduct(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary:
	return await add_deduct(item_definition_id, -abs(quantity), container_id)


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
