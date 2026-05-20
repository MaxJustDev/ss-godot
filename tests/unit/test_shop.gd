## Unit tests for Shop (M5a).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_mailbox.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 4_Shop/Shop.cs
extends "res://addons/gut/test.gd"

const SHOP_SCRIPT := preload("res://addons/sai_services/shop/shop.gd")

const GAME_ID := "g_test"
const SHOP_ID := "shop_001"
const SHOP_ITEM_ID := "si_001"
const PURCHASE_ID := "pr_001"

# =========================================================================
# Test double: minimal stand-in for the SaiServer autoload.
# =========================================================================


class FakeSaiServer:
	extends Node

	var _next_responses: Array = []
	var calls: Array = []

	var _access_token: String = "AT_test"
	var game_id: String = "g_test"

	signal token_refreshed(access_token: String)

	func queue_response(response: Dictionary) -> void:
		_next_responses.append(response)

	func _take_next() -> Dictionary:
		if _next_responses.is_empty():
			return {"success": false, "status": 0, "error": "no_canned_response", "data": null}
		return _next_responses.pop_front()

	func get_request(path: String, query: Dictionary = {}, auth: bool = true) -> Dictionary:
		calls.append({"method": "GET", "path": path, "query": query, "auth": auth})
		return _take_next()

	func post_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "POST", "path": path, "body": body, "auth": auth})
		return _take_next()

	func patch_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "PATCH", "path": path, "body": body, "auth": auth})
		return _take_next()

	func delete_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "DELETE", "path": path, "body": body, "auth": auth})
		return _take_next()

	func is_authenticated() -> bool:
		return not _access_token.is_empty()

	func access_token() -> String:
		return _access_token

	func normalized_game_id() -> String:
		return game_id


# =========================================================================
# Fixture
# =========================================================================

var _server: FakeSaiServer = null
var _shop: Shop = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_shop = SHOP_SCRIPT.new()
	_shop.name = "Shop"
	_server.add_child(_shop)


# =========================================================================
# list
# =========================================================================


func test_list_success_returns_typed_shops_and_emits_list_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"shops":
					[
						{
							"id": SHOP_ID,
							"studio_id": "st_1",
							"game_id": GAME_ID,
							"shop_key": "main_store",
							"name": "Main Store",
							"description": "everything in the world",
							"shop_type": "general",
							"is_active": true,
							"currency_item_def_id": "def_gold",
							"item_count": 7,
							"starts_at": "",
							"ends_at": "",
							"created_at": "2026-05-20T00:00:00Z",
							"updated_at": "2026-05-20T00:00:00Z",
						},
						{
							"id": "shop_002",
							"shop_key": "event_store",
							"shop_type": "event",
							"is_active": false,
						},
					],
					"limit": 20,
					"offset": 0,
					"total": 2,
				},
			}
		)
	)
	watch_signals(_shop)

	var result: Dictionary = await _shop.list(20, 0)

	assert_true(result.get("success", false), "list reports success")
	assert_signal_emitted(_shop, "list_loaded")
	var data: Dictionary = result["data"]
	assert_eq(int(data["total"]), 2, "total propagated")
	assert_eq((data["shops"] as Array).size(), 2, "two shops decoded")
	var shop: ShopData = (data["shops"] as Array)[0]
	assert_eq(shop.id, SHOP_ID)
	assert_eq(shop.shop_key, "main_store")
	assert_true(shop.is_active)
	# Cache populated.
	assert_eq(_shop.cached_shops.size(), 2)
	assert_eq(_shop.cached_shops_total, 2)
	# Query params are forwarded.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/shops")
	assert_eq(int(call["query"]["limit"]), 20)
	assert_eq(int(call["query"]["offset"]), 0)


func test_list_failed_emits_list_failed_with_error_text() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_shop)

	var result: Dictionary = await _shop.list(10, 5)

	assert_false(result.get("success", true))
	assert_signal_emitted(_shop, "list_failed")
	assert_signal_emitted_with_parameters(_shop, "list_failed", ["boom"])


func test_list_empty_game_id_fails_fast_without_network() -> void:
	_server.game_id = ""
	watch_signals(_shop)

	var result: Dictionary = await _shop.list()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when game_id is empty")
	assert_signal_emitted(_shop, "list_failed")


# =========================================================================
# Convenience helpers over the cache
# =========================================================================


func test_get_shop_by_id_and_key_find_cached_entries() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"shops":
					[
						{
							"id": SHOP_ID,
							"shop_key": "main_store",
							"shop_type": "general",
							"is_active": true
						},
						{
							"id": "shop_002",
							"shop_key": "event_store",
							"shop_type": "event",
							"is_active": false
						},
					],
					"total": 2,
				},
			}
		)
	)
	await _shop.list()

	assert_eq(_shop.get_shop_by_id(SHOP_ID).shop_key, "main_store")
	assert_eq(_shop.get_shop_by_key("event_store").id, "shop_002")
	assert_eq(_shop.get_shops_by_type("event").size(), 1)
	assert_eq(_shop.get_active_shops().size(), 1, "only one shop is active")
	assert_true(_shop.has_shops())

	_shop.clear_shops()
	assert_false(_shop.has_shops())
	assert_eq(_shop.cached_shops_total, 0)


# =========================================================================
# items
# =========================================================================


func test_items_success_returns_typed_shop_items_and_emits_items_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"items":
					[
						{
							"id": SHOP_ITEM_ID,
							"shop_id": SHOP_ID,
							"item_def_id": "def_sword",
							"display_name": "Iron Sword",
							"description": "+5 ATK",
							"price": 250,
							"currency_item_def_id": "def_gold",
							"purchase_limit_type": "player",
							"purchase_limit": 1,
							"restock_schedule": "",
							"stock": 99,
							"sort_order": 1,
							"is_active": true,
							"available_from": "",
							"available_until": "",
							"created_at": "2026-05-20T00:00:00Z",
							"updated_at": "2026-05-20T00:00:00Z",
							"purchased_count": 0,
						},
					],
					"item_count": 1,
					"shop_id": SHOP_ID,
				},
			}
		)
	)
	watch_signals(_shop)

	var result: Dictionary = await _shop.items(SHOP_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_shop, "items_loaded")
	var data: Dictionary = result["data"]
	assert_eq(int(data["item_count"]), 1)
	assert_eq(String(data["shop_id"]), SHOP_ID)
	var items: Array = data["items"]
	assert_eq(items.size(), 1)
	var item: ShopItem = items[0]
	assert_eq(item.id, SHOP_ITEM_ID)
	assert_eq(item.price, 250)
	assert_eq(item.currency_item_def_id, "def_gold")
	# Cache populated.
	assert_eq(_shop.cached_shop_items.size(), 1)
	assert_eq(_shop.last_loaded_shop_id, SHOP_ID)
	# Path stamped correctly.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/shops/shop_001/items")


func test_items_with_empty_shop_id_fails_fast() -> void:
	watch_signals(_shop)

	var result: Dictionary = await _shop.items("")

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when shop_id is empty")
	assert_signal_emitted(_shop, "items_failed")


func test_items_failed_emits_items_failed_with_shop_id_and_error() -> void:
	_server.queue_response(
		{"success": false, "status": 404, "error": "shop_not_found", "data": null}
	)
	watch_signals(_shop)

	var result: Dictionary = await _shop.items(SHOP_ID)

	assert_false(result.get("success", true))
	assert_signal_emitted(_shop, "items_failed")
	assert_signal_emitted_with_parameters(_shop, "items_failed", [SHOP_ID, "shop_not_found"])


# =========================================================================
# purchase
# =========================================================================


func test_purchase_success_decodes_record_and_emits_purchase_success() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"purchase_record":
					{
						"id": PURCHASE_ID,
						"shop_id": SHOP_ID,
						"shop_item_id": SHOP_ITEM_ID,
						"user_id": "u_001",
						"game_id": GAME_ID,
						"quantity": 1,
						"unit_price": 250,
						"total_price": 250,
						"idempotency_key": "client-key-123",
						"currency_item_def_id": "def_gold",
						"created_at": "2026-05-20T00:01:00Z",
					},
				},
			}
		)
	)
	watch_signals(_shop)

	var result: Dictionary = await _shop.purchase(SHOP_ID, SHOP_ITEM_ID, 1, "client-key-123")

	assert_true(result.get("success", false))
	assert_signal_emitted(_shop, "purchase_success")
	var record: PurchaseRecord = result["data"]["record"]
	assert_eq(record.id, PURCHASE_ID)
	assert_eq(record.total_price, 250)
	assert_eq(record.idempotency_key, "client-key-123")
	# Request body shape matches PurchaseRequest (Shop.cs:408-413).
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/shops/shop_001/purchase")
	var body: Dictionary = call["body"]
	assert_eq(String(body["shop_item_id"]), SHOP_ITEM_ID)
	assert_eq(int(body["quantity"]), 1)
	assert_eq(String(body["idempotency_key"]), "client-key-123")


func test_purchase_generates_idempotency_key_when_caller_omits_one() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"purchase_record": {"id": PURCHASE_ID, "shop_id": SHOP_ID}},
			}
		)
	)

	var _ignored: Dictionary = await _shop.purchase(SHOP_ID, SHOP_ITEM_ID, 1)

	var body: Dictionary = _server.calls[0]["body"]
	var key: String = String(body["idempotency_key"])
	assert_true(not key.is_empty(), "client generates a key when caller omits one")
	assert_true(key.begins_with("shop-"), "generated key uses shop-<ts>-<hex> format")


func test_purchase_failed_insufficient_balance_emits_purchase_failed() -> void:
	# Server returns the canonical "insufficient_balance" error documented in
	# docs/examples/shop.md. The Shop wrapper propagates it untouched.
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 402,
				"error": "insufficient_balance",
				"data": null,
			}
		)
	)
	watch_signals(_shop)

	var result: Dictionary = await _shop.purchase(SHOP_ID, SHOP_ITEM_ID, 1, "key-2")

	assert_false(result.get("success", true))
	assert_signal_emitted(_shop, "purchase_failed")
	assert_signal_emitted_with_parameters(_shop, "purchase_failed", ["insufficient_balance"])


func test_purchase_empty_shop_id_fails_fast() -> void:
	watch_signals(_shop)

	var result: Dictionary = await _shop.purchase("", SHOP_ITEM_ID)

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when shop_id is empty")
	assert_signal_emitted(_shop, "purchase_failed")


func test_purchase_empty_shop_item_id_fails_fast() -> void:
	watch_signals(_shop)

	var result: Dictionary = await _shop.purchase(SHOP_ID, "")

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when shop_item_id is empty")
	assert_signal_emitted(_shop, "purchase_failed")


# =========================================================================
# history (deferred)
# =========================================================================


func test_history_returns_not_implemented_envelope_and_emits_history_failed() -> void:
	watch_signals(_shop)

	var result: Dictionary = await _shop.history()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "history must not hit network until backend exists")
	assert_signal_emitted(_shop, "history_failed")
