## ShopData - typed mirror of one entry in `ShopResponse.shops`.
##
## Returned by `GET /api/v1/games/{game_id}/shops` (list). Timestamp fields
## stay as ISO-8601 strings, matching upstream Unity which stores them as
## `string` and lets callers parse on demand.
##
## upstream: 4_Shop/Models/ShopData.cs:9
class_name ShopData
extends Resource

## Server-issued unique shop id.
## upstream: ShopData.cs:11
@export var id: String = ""

## upstream: ShopData.cs:12
@export var studio_id: String = ""

## upstream: ShopData.cs:13
@export var game_id: String = ""

## Stable human-readable key (e.g. "main_store").
## upstream: ShopData.cs:14
@export var shop_key: String = ""

## upstream: ShopData.cs:15
@export var name: String = ""

## upstream: ShopData.cs:16
@export var description: String = ""

## e.g. "general", "event", "limited".
## upstream: ShopData.cs:17
@export var shop_type: String = ""

## upstream: ShopData.cs:18
@export var is_active: bool = false

## Definition id of the currency item this shop charges in.
## upstream: ShopData.cs:19
@export var currency_item_def_id: String = ""

## Server-reported number of items currently listed.
## upstream: ShopData.cs:20
@export var item_count: int = 0

## ISO-8601. Empty string when the server omits it.
## upstream: ShopData.cs:21
@export var starts_at: String = ""

## ISO-8601. Empty string when the server omits it.
## upstream: ShopData.cs:22
@export var ends_at: String = ""

## ISO-8601.
## upstream: ShopData.cs:23
@export var created_at: String = ""

## ISO-8601.
## upstream: ShopData.cs:24
@export var updated_at: String = ""


## Build a ShopData from a raw JSON Dictionary. Missing keys default to the
## zero-value of their type; extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<ShopData>(...)`.
static func from_dict(d: Variant) -> ShopData:
	var s := ShopData.new()
	if not (d is Dictionary):
		return s
	var dict: Dictionary = d
	s.id = String(dict.get("id", ""))
	s.studio_id = String(dict.get("studio_id", ""))
	s.game_id = String(dict.get("game_id", ""))
	s.shop_key = String(dict.get("shop_key", ""))
	s.name = String(dict.get("name", ""))
	s.description = String(dict.get("description", ""))
	s.shop_type = String(dict.get("shop_type", ""))
	s.is_active = bool(dict.get("is_active", false))
	s.currency_item_def_id = String(dict.get("currency_item_def_id", ""))
	s.item_count = int(dict.get("item_count", 0))
	s.starts_at = String(dict.get("starts_at", ""))
	s.ends_at = String(dict.get("ends_at", ""))
	s.created_at = String(dict.get("created_at", ""))
	s.updated_at = String(dict.get("updated_at", ""))
	return s


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"shop_key": shop_key,
		"name": name,
		"description": description,
		"shop_type": shop_type,
		"is_active": is_active,
		"currency_item_def_id": currency_item_def_id,
		"item_count": item_count,
		"starts_at": starts_at,
		"ends_at": ends_at,
		"created_at": created_at,
		"updated_at": updated_at,
	}
