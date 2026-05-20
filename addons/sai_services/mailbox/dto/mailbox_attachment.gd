## MailboxAttachment - typed mirror of `MailBoxAttachment` JSON shape.
##
## Embedded inside `MailboxMessage.attachments`. `item_definition` is left as
## a raw Dictionary because the typed `ItemDefinitionData` resource lands in
## the M4 (ItemContainer) port; callers that want the full definition can
## upgrade once M4 is in.
##
## upstream: 2_Mailbox/Models/MailBoxAttachment.cs:9
class_name MailboxAttachment
extends Resource

## Reward category, e.g. "item", "currency".
## upstream: MailBoxAttachment.cs:11
@export var type: String = ""

## Server-side definition id for the granted entity.
## upstream: MailBoxAttachment.cs:12
@export var definition_id: String = ""

## How many of `definition_id` are granted.
## upstream: MailBoxAttachment.cs:13
@export var quantity: int = 0

## Full item definition payload — kept raw until M4 ItemDefinitionData lands.
## upstream: MailBoxAttachment.cs:14 (ItemDefinitionData item_definition)
@export var item_definition: Dictionary = {}


## Build a MailboxAttachment from a raw JSON Dictionary. Missing keys default
## to the zero-value of their type. Extra keys are preserved on
## `item_definition` if the server adds fields client doesn't know about.
##
## upstream: behavioural parity with `JsonUtility.FromJson<MailBoxAttachment>(...)`.
static func from_dict(d: Variant) -> MailboxAttachment:
	var a := MailboxAttachment.new()
	if not (d is Dictionary):
		return a
	var dict: Dictionary = d
	a.type = String(dict.get("type", ""))
	a.definition_id = String(dict.get("definition_id", ""))
	a.quantity = int(dict.get("quantity", 0))
	var raw_def: Variant = dict.get("item_definition", null)
	if raw_def is Dictionary:
		a.item_definition = raw_def
	else:
		a.item_definition = {}
	return a


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"type": type,
		"definition_id": definition_id,
		"quantity": quantity,
		"item_definition": item_definition,
	}
