## PurchaseRecord - typed mirror of `PurchaseResponse.purchase_record`.
##
## Returned by `POST /api/v1/games/{game_id}/shops/{shop_id}/purchase`. The
## record is the server's receipt for the transaction; clients keep it for
## history / receipt UI even though there is no GET-history endpoint yet
## (see Shop.history() TODO in `shop.gd`).
##
## upstream: 4_Shop/Models/PurchaseRecord.cs:9
class_name PurchaseRecord
extends Resource

## Server-issued unique purchase record id.
## upstream: PurchaseRecord.cs:11
@export var id: String = ""

## upstream: PurchaseRecord.cs:12
@export var shop_id: String = ""

## Shop-item id (NOT the underlying item definition id).
## upstream: PurchaseRecord.cs:13
@export var shop_item_id: String = ""

## upstream: PurchaseRecord.cs:14
@export var user_id: String = ""

## upstream: PurchaseRecord.cs:15
@export var game_id: String = ""

## upstream: PurchaseRecord.cs:16
@export var quantity: int = 0

## Per-unit price charged at the time of purchase.
## upstream: PurchaseRecord.cs:17
@export var unit_price: int = 0

## Total cost (= quantity * unit_price, server-authoritative).
## upstream: PurchaseRecord.cs:18
@export var total_price: int = 0

## Client-supplied idempotency key. Echoed by server for replay-detection.
## upstream: PurchaseRecord.cs:19
@export var idempotency_key: String = ""

## Definition id of the currency the price was paid in.
## upstream: PurchaseRecord.cs:20
@export var currency_item_def_id: String = ""

## ISO-8601 timestamp of the purchase.
## upstream: PurchaseRecord.cs:21
@export var created_at: String = ""


## Build a PurchaseRecord from a raw JSON Dictionary.
##
## upstream: behavioural parity with `JsonUtility.FromJson<PurchaseRecord>(...)`.
static func from_dict(d: Variant) -> PurchaseRecord:
	var r := PurchaseRecord.new()
	if not (d is Dictionary):
		return r
	var dict: Dictionary = d
	r.id = String(dict.get("id", ""))
	r.shop_id = String(dict.get("shop_id", ""))
	r.shop_item_id = String(dict.get("shop_item_id", ""))
	r.user_id = String(dict.get("user_id", ""))
	r.game_id = String(dict.get("game_id", ""))
	r.quantity = int(dict.get("quantity", 0))
	r.unit_price = int(dict.get("unit_price", 0))
	r.total_price = int(dict.get("total_price", 0))
	r.idempotency_key = String(dict.get("idempotency_key", ""))
	r.currency_item_def_id = String(dict.get("currency_item_def_id", ""))
	r.created_at = String(dict.get("created_at", ""))
	return r


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"shop_id": shop_id,
		"shop_item_id": shop_item_id,
		"user_id": user_id,
		"game_id": game_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_price": total_price,
		"idempotency_key": idempotency_key,
		"currency_item_def_id": currency_item_def_id,
		"created_at": created_at,
	}
