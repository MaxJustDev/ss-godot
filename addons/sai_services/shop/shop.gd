## Shop - list shops / list shop items / purchase wrapper around the SaiGame
## shop REST endpoints.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/4_Shop/Shop.cs:8`
## (upstream v0.2.40d).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals so fire-and-forget subscribers still work
##     (B.4 in CLAUDE.md).
##   - Upstream exposes three endpoints (GetShops, GetShopItems, PurchaseItem).
##     We mirror them as `list()`, `items(shop_id)`, `purchase(...)`.
##   - Upstream has client-side helpers (`GetShopById`, `GetShopByKey`,
##     `GetShopsByType`, `GetActiveShops`, `ClearShops`, auto-load-on-login,
##     auto-refresh-after-purchase) that read/write a cached `currentShopResponse`.
##     We port the cache + filter helpers so callers can stay in parity; the
##     auto-load and auto-refresh side-effects are intentionally NOT ported in
##     M5a — they tangle with the M2 auth signals and are better driven by app
##     code (TODO M5b+).
##   - The `history()` method + `history_loaded` / `history_failed` signals
##     have no upstream endpoint yet (purchase history is reconstructed by the
##     caller from `purchase()` results). The method returns a "not implemented"
##     envelope and emits `history_failed` so existing app code can wire the
##     signal — see TODO M6+ in `history()`.
##   - `idempotency_key` for `purchase()` is generated client-side if the
##     caller omits one, mirroring upstream's expectation that every purchase
##     carries a key (`PurchaseRequest.idempotency_key`,
##     PurchaseRequest.cs:13).
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.shop` from app code.
##
## upstream: 4_Shop/Shop.cs:8
class_name Shop
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: Shop.cs:139
const PATH_SHOPS := "/api/v1/games/{game_id}/shops"

## upstream: Shop.cs:315
const PATH_SHOP_ITEMS := "/api/v1/games/{game_id}/shops/{shop_id}/items"

## upstream: Shop.cs:406
const PATH_PURCHASE := "/api/v1/games/{game_id}/shops/{shop_id}/purchase"

# -------------------------------------------------------------------------
# Defaults (mirror upstream Inspector fields)
# -------------------------------------------------------------------------

## upstream: Shop.cs:24 (shopLimit)
const DEFAULT_LIMIT := 20

## upstream: Shop.cs:25 (shopOffset)
const DEFAULT_OFFSET := 0

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `list()`. `shops` is `Array[ShopData]`, `total`
## mirrors the server-reported count.
## upstream: Shop.cs:11 (OnGetShopsSuccess)
signal list_loaded(shops: Array, total: int)
## upstream: Shop.cs:12 (OnGetShopsFailure)
signal list_failed(error: String)

## Emitted on successful `items(shop_id)`. `shop_items` is `Array[ShopItem]`.
## upstream: Shop.cs:13 (OnGetShopItemsSuccess)
signal items_loaded(shop_id: String, shop_items: Array)
## upstream: Shop.cs:14 (OnGetShopItemsFailure)
signal items_failed(shop_id: String, error: String)

## Emitted on successful `purchase()`. `record` is the typed PurchaseRecord.
## upstream: Shop.cs:15 (OnPurchaseSuccess)
signal purchase_success(record: PurchaseRecord)
## upstream: Shop.cs:16 (OnPurchaseFailure)
## Common error codes from the backend: `insufficient_balance`,
## `item_out_of_stock`, `item_not_owned_yet`, `purchase_limit_reached`.
signal purchase_failed(error: String)

## Reserved for the (currently-unimplemented) purchase-history endpoint.
## See `history()` for the deferred TODO.
signal history_loaded(records: Array, total: int)
signal history_failed(error: String)

# -------------------------------------------------------------------------
# Cached state (mirrors upstream's `currentShopResponse` / `currentShopItemsResponse`)
# -------------------------------------------------------------------------

## Last shop list returned by `list()`. Empty until first successful call.
## upstream: Shop.cs:23 (currentShopResponse)
var cached_shops: Array[ShopData] = []

## Server-reported total from the last `list()`.
## upstream: ShopResponse.cs:13 (total)
var cached_shops_total: int = 0

## Last shop-items list returned by `items()`. Keyed by `last_loaded_shop_id`.
## upstream: Shop.cs:28 (currentShopItemsResponse)
var cached_shop_items: Array[ShopItem] = []

## upstream: Shop.cs:29 (lastLoadedShopId)
var last_loaded_shop_id: String = ""

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/shops?limit=&offset=
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `shops`: Array[ShopData]
##   - `total`: int
##   - `limit`: int
##   - `offset`: int
##   - `raw`: original Dictionary as returned by the server.
##
## upstream: Shop.cs:105 (GetShops), Shop.cs:132 (GetShopsCoroutine)
func list(limit: int = DEFAULT_LIMIT, offset: int = DEFAULT_OFFSET) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		list_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		list_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SHOPS.replace("{game_id}", game_id)
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list shops failed"))
		list_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var shops: Array[ShopData] = []
	var raw_shops: Variant = raw.get("shops", null)
	if raw_shops is Array:
		for entry in raw_shops as Array:
			shops.append(ShopData.from_dict(entry))
	var total: int = int(raw.get("total", shops.size()))
	cached_shops = shops
	cached_shops_total = total
	list_loaded.emit(shops, total)

	# Re-wrap so callers get typed access without losing the raw payload.
	var out := result.duplicate(true)
	out["data"] = {
		"shops": shops,
		"total": total,
		"limit": int(raw.get("limit", limit)),
		"offset": int(raw.get("offset", offset)),
		"raw": raw,
	}
	return out


## GET /api/v1/games/{game_id}/shops/{shop_id}/items
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `items`: Array[ShopItem]
##   - `item_count`: int
##   - `shop_id`: String
##   - `raw`: original Dictionary as returned by the server.
##
## upstream: Shop.cs:280 (GetShopItems), Shop.cs:309 (GetShopItemsCoroutine)
func items(shop_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		items_failed.emit(shop_id, err)
		return _envelope_fail(err)

	if shop_id == null or String(shop_id).is_empty():
		# upstream: Shop.cs:300-303 — refuse before sending.
		var err := "shop_id cannot be empty"
		items_failed.emit(shop_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		items_failed.emit(shop_id, err)
		return _envelope_fail(err)

	var path: String = PATH_SHOP_ITEMS.replace("{game_id}", game_id).replace("{shop_id}", shop_id)
	var result: Dictionary = await server.get_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list shop items failed"))
		items_failed.emit(shop_id, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var parsed: Array[ShopItem] = []
	var raw_items: Variant = raw.get("items", null)
	if raw_items is Array:
		for entry in raw_items as Array:
			parsed.append(ShopItem.from_dict(entry))
	cached_shop_items = parsed
	last_loaded_shop_id = shop_id
	items_loaded.emit(shop_id, parsed)

	var out := result.duplicate(true)
	out["data"] = {
		"items": parsed,
		"item_count": int(raw.get("item_count", parsed.size())),
		"shop_id": String(raw.get("shop_id", shop_id)),
		"raw": raw,
	}
	return out


## POST /api/v1/games/{game_id}/shops/{shop_id}/purchase
## body: `{ shop_item_id, quantity, idempotency_key }`.
##
## `idempotency_key` defaults to a random UUID when omitted — upstream's
## C# caller is expected to provide one but the SDK never enforces it, and
## sending a blank key would let a network retry double-charge the player.
##
## On success, `data` is `{record: PurchaseRecord, raw: Dictionary}`.
##
## upstream: Shop.cs:359 (PurchaseItem), Shop.cs:397 (PurchaseItemCoroutine)
func purchase(
	shop_id: String,
	shop_item_id: String,
	quantity: int = 1,
	idempotency_key: String = "",
) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		purchase_failed.emit(err)
		return _envelope_fail(err)

	if shop_id == null or String(shop_id).is_empty():
		# upstream: Shop.cs:382-385
		var err := "shop_id cannot be empty"
		purchase_failed.emit(err)
		return _envelope_fail(err)
	if shop_item_id == null or String(shop_item_id).is_empty():
		# upstream: Shop.cs:388-391
		var err := "shop_item_id cannot be empty"
		purchase_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		purchase_failed.emit(err)
		return _envelope_fail(err)

	var key: String = idempotency_key if not idempotency_key.is_empty() else _new_idempotency_key()
	var path: String = PATH_PURCHASE.replace("{game_id}", game_id).replace("{shop_id}", shop_id)
	# upstream: Shop.cs:408-413 (PurchaseRequest)
	var body: Dictionary = {
		"shop_item_id": shop_item_id,
		"quantity": quantity,
		"idempotency_key": key,
	}
	var result: Dictionary = await server.post_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "purchase failed"))
		purchase_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var record: PurchaseRecord = _extract_purchase_record(raw)
	purchase_success.emit(record)

	var out := result.duplicate(true)
	out["data"] = {"record": record, "raw": raw}
	return out


## TODO M6+: no upstream / backend endpoint for purchase history yet.
##
## The signal pair `history_loaded` / `history_failed` is reserved so app code
## can wire it now; the method itself returns a failure envelope and emits
## `history_failed`. Callers that need a transient history today should
## listen to `purchase_success` and accumulate `PurchaseRecord`s locally.
func history(_limit: int = DEFAULT_LIMIT, _offset: int = DEFAULT_OFFSET) -> Dictionary:
	var err := "purchase history endpoint is not implemented in upstream v0.2.40d"
	history_failed.emit(err)
	return _envelope_fail(err)


# =========================================================================
# Convenience query helpers (operate on `cached_shops`)
# =========================================================================


## upstream: Shop.cs:203 (GetShopById)
func get_shop_by_id(shop_id: String) -> ShopData:
	for s in cached_shops:
		if s != null and s.id == shop_id:
			return s
	return null


## upstream: Shop.cs:218 (GetShopByKey)
func get_shop_by_key(shop_key: String) -> ShopData:
	for s in cached_shops:
		if s != null and s.shop_key == shop_key:
			return s
	return null


## upstream: Shop.cs:233 (GetShopsByType)
func get_shops_by_type(shop_type: String) -> Array[ShopData]:
	var result: Array[ShopData] = []
	for s in cached_shops:
		if s != null and s.shop_type == shop_type:
			result.append(s)
	return result


## upstream: Shop.cs:250 (GetActiveShops)
func get_active_shops() -> Array[ShopData]:
	var result: Array[ShopData] = []
	for s in cached_shops:
		if s != null and s.is_active:
			result.append(s)
	return result


## upstream: Shop.cs:179 (ClearShops)
func clear_shops() -> void:
	cached_shops = []
	cached_shops_total = 0


## True iff `cached_shops` is non-empty.
## upstream: Shop.cs:34 (HasShops)
func has_shops() -> bool:
	return cached_shops.size() > 0


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirrors SaiAuth._server (auth/sai_auth.gd:258-276): prefer parent, fall
	# back to autoload, then to the scene tree — keeps the class testable
	# under a fake-parent harness.
	var parent: Node = get_parent()
	if parent != null and parent.has_method("get_request"):
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
		return String(server.game_id).strip_edges()
	return ""


## Extract a `PurchaseRecord` from the dual-shape POST response. Upstream
## always returns `{purchase_record: {...}}` (PurchaseResponse.cs:12) but we
## tolerate a flat record too so retries / proxies that strip the wrapper
## don't break parsing.
func _extract_purchase_record(data: Variant) -> PurchaseRecord:
	if not (data is Dictionary):
		return PurchaseRecord.new()
	var dict: Dictionary = data
	# Wrapped: `{ "purchase_record": {...} }` (upstream PurchaseResponse.cs:12)
	var wrapped: Variant = dict.get("purchase_record", null)
	if wrapped is Dictionary:
		return PurchaseRecord.from_dict(wrapped)
	# Flat: PurchaseRecord at the top level.
	if String(dict.get("id", "")) != "":
		return PurchaseRecord.from_dict(dict)
	return PurchaseRecord.new()


## Generate a fresh idempotency key for a purchase. Format mirrors the
## multi-segment style used by other ss-unity SDK paths (gacha, crafting):
## `<unix>-<rand_hex>`. Caller-supplied keys are always preferred.
func _new_idempotency_key() -> String:
	var ts: int = int(Time.get_unix_time_from_system())
	var rand_hex: String = (
		"%08x%08x"
		% [
			randi() & 0xFFFFFFFF,
			randi() & 0xFFFFFFFF,
		]
	)
	return "shop-%d-%s" % [ts, rand_hex]


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
