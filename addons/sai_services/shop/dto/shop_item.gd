## ShopItem - typed mirror of one entry in `ShopItemsResponse.items`.
##
## Returned by `GET /api/v1/games/{game_id}/shops/{shop_id}/items`.
## `purchased_count` is only populated on the wire when `purchase_limit_type`
## is set (per-player or global); upstream defaults it to 0 otherwise, which
## we mirror here.
##
## upstream: 4_Shop/Models/ShopItemData.cs:9
class_name ShopItem
extends Resource

## Server-issued shop-item id (NOT the underlying item definition id).
## upstream: ShopItemData.cs:11
@export var id: String = ""

## upstream: ShopItemData.cs:12
@export var shop_id: String = ""

## Definition id of the item granted on purchase.
## upstream: ShopItemData.cs:13
@export var item_def_id: String = ""

## upstream: ShopItemData.cs:14
@export var display_name: String = ""

## upstream: ShopItemData.cs:15
@export var description: String = ""

## Cost in `currency_item_def_id` units (per unit purchased).
## upstream: ShopItemData.cs:16
@export var price: int = 0

## Definition id of the currency this item costs.
## upstream: ShopItemData.cs:17
@export var currency_item_def_id: String = ""

## One of "" | "player" | "global" per upstream usage.
## upstream: ShopItemData.cs:18
@export var purchase_limit_type: String = ""

## Max purchases allowed under `purchase_limit_type`. 0 means unlimited.
## upstream: ShopItemData.cs:19
@export var purchase_limit: int = 0

## Cron-like or human-readable restock schedule string. May be empty.
## upstream: ShopItemData.cs:20
@export var restock_schedule: String = ""

## Current available stock. -1 (or any negative) typically means unlimited;
## upstream stores it as a plain int.
## upstream: ShopItemData.cs:21
@export var stock: int = 0

## Display ordering (lower = shown first).
## upstream: ShopItemData.cs:22
@export var sort_order: int = 0

## upstream: ShopItemData.cs:23
@export var is_active: bool = false

## ISO-8601. Empty string when the server omits it.
## upstream: ShopItemData.cs:24
@export var available_from: String = ""

## ISO-8601. Empty string when the server omits it.
## upstream: ShopItemData.cs:25
@export var available_until: String = ""

## ISO-8601.
## upstream: ShopItemData.cs:26
@export var created_at: String = ""

## ISO-8601.
## upstream: ShopItemData.cs:27
@export var updated_at: String = ""

## Only present in response when a limit type is set (player/global).
## upstream: ShopItemData.cs:29
@export var purchased_count: int = 0


## Build a ShopItem from a raw JSON Dictionary. Missing keys default to the
## zero-value of their type; extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<ShopItemData>(...)`.
static func from_dict(d: Variant) -> ShopItem:
	var i := ShopItem.new()
	if not (d is Dictionary):
		return i
	var dict: Dictionary = d
	i.id = String(dict.get("id", ""))
	i.shop_id = String(dict.get("shop_id", ""))
	i.item_def_id = String(dict.get("item_def_id", ""))
	i.display_name = String(dict.get("display_name", ""))
	i.description = String(dict.get("description", ""))
	i.price = int(dict.get("price", 0))
	i.currency_item_def_id = String(dict.get("currency_item_def_id", ""))
	i.purchase_limit_type = String(dict.get("purchase_limit_type", ""))
	i.purchase_limit = int(dict.get("purchase_limit", 0))
	i.restock_schedule = String(dict.get("restock_schedule", ""))
	i.stock = int(dict.get("stock", 0))
	i.sort_order = int(dict.get("sort_order", 0))
	i.is_active = bool(dict.get("is_active", false))
	i.available_from = String(dict.get("available_from", ""))
	i.available_until = String(dict.get("available_until", ""))
	i.created_at = String(dict.get("created_at", ""))
	i.updated_at = String(dict.get("updated_at", ""))
	i.purchased_count = int(dict.get("purchased_count", 0))
	return i


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"shop_id": shop_id,
		"item_def_id": item_def_id,
		"display_name": display_name,
		"description": description,
		"price": price,
		"currency_item_def_id": currency_item_def_id,
		"purchase_limit_type": purchase_limit_type,
		"purchase_limit": purchase_limit,
		"restock_schedule": restock_schedule,
		"stock": stock,
		"sort_order": sort_order,
		"is_active": is_active,
		"available_from": available_from,
		"available_until": available_until,
		"created_at": created_at,
		"updated_at": updated_at,
		"purchased_count": purchased_count,
	}
