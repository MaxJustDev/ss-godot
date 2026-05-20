## GachaResponse - typed mirror of the gacha-pull response payload.
##
## upstream: 3_ItemContainer/Gacha/GachaResponse.cs:10
class_name GachaResponse
extends Resource

## True when the same idempotency_key was already processed.
## upstream: GachaResponse.cs:13
@export var is_duplicate: bool = false
## upstream: GachaResponse.cs:14
@export var items_granted: Array[GachaItemGranted] = []
## upstream: GachaResponse.cs:15
@export var mailbox_message_id: String = ""
## upstream: GachaResponse.cs:16
@export var transaction_id: String = ""


static func from_dict(d: Variant) -> GachaResponse:
	var out := GachaResponse.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.is_duplicate = bool(dict.get("is_duplicate", false))
	var raw_items: Variant = dict.get("items_granted", null)
	if raw_items is Array:
		var typed: Array[GachaItemGranted] = []
		for item in raw_items:
			typed.append(GachaItemGranted.from_dict(item))
		out.items_granted = typed
	out.mailbox_message_id = String(dict.get("mailbox_message_id", ""))
	out.transaction_id = String(dict.get("transaction_id", ""))
	return out


func to_dict() -> Dictionary:
	var items: Array = []
	for it in items_granted:
		items.append(it.to_dict())
	return {
		"is_duplicate": is_duplicate,
		"items_granted": items,
		"mailbox_message_id": mailbox_message_id,
		"transaction_id": transaction_id,
	}
