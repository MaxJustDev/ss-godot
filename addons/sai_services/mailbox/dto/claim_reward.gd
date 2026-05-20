## ClaimReward - typed mirror of one entry in `ClaimMessageResponse.rewards`.
##
## Mailbox's `POST .../mailbox/messages/{message_id}/claim` returns
## `{ rewards: ClaimReward[] }`; this Resource gives callers a typed handle
## on each granted reward without forcing them to walk raw Dictionaries.
##
## upstream: 2_Mailbox/Models/ClaimReward.cs:9
class_name ClaimReward
extends Resource

## Reward category, e.g. "item", "currency".
## upstream: ClaimReward.cs:11
@export var type: String = ""

## Server-side definition id for the granted entity.
## upstream: ClaimReward.cs:12
@export var definition_id: String = ""

## How many of `definition_id` are granted.
## upstream: ClaimReward.cs:13
@export var quantity: int = 0


## Build a ClaimReward from a raw JSON Dictionary.
##
## upstream: behavioural parity with `JsonUtility.FromJson<ClaimReward>(...)`.
static func from_dict(d: Variant) -> ClaimReward:
	var r := ClaimReward.new()
	if not (d is Dictionary):
		return r
	var dict: Dictionary = d
	r.type = String(dict.get("type", ""))
	r.definition_id = String(dict.get("definition_id", ""))
	r.quantity = int(dict.get("quantity", 0))
	return r


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"type": type,
		"definition_id": definition_id,
		"quantity": quantity,
	}
