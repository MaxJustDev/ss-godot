## MailboxMessage - typed mirror of one entry in `MailBoxResponse.messages`.
##
## Returned by `GET .../mailbox/messages` (list), `PATCH .../{message_id}`
## (mark read / unread when the server returns the flat shape), and used
## as the cached representation that Mailbox keeps in memory.
##
## Timestamp fields stay as ISO-8601 strings, matching upstream Unity which
## stores them as `string` and lets callers parse on demand.
##
## upstream: 2_Mailbox/Models/MailboxMessage.cs:9
class_name MailboxMessage
extends Resource

## Server-issued unique id.
## upstream: MailboxMessage.cs:11
@export var id: String = ""

## Who/what queued this message (system, GM, other player...).
## upstream: MailboxMessage.cs:12
@export var sender_id: String = ""

## upstream: MailboxMessage.cs:13
@export var subject: String = ""

## upstream: MailboxMessage.cs:14
@export var body: String = ""

## e.g. "system", "reward", "broadcast".
## upstream: MailboxMessage.cs:15
@export var message_type: String = ""

## One of "unread" | "read" | "claimed" per upstream filter helpers
## (Mailbox.cs:674-693, Mailbox.cs:726-731).
## upstream: MailboxMessage.cs:16
@export var status: String = ""

## Reward attachments. Empty array if message carries no rewards.
## upstream: MailboxMessage.cs:17
@export var attachments: Array[MailboxAttachment] = []

## ISO-8601. Empty string when the server omits it.
## upstream: MailboxMessage.cs:18
@export var expires_at: String = ""

## ISO-8601. Empty string while message is unread.
## upstream: MailboxMessage.cs:19
@export var read_at: String = ""

## ISO-8601. Empty string while message is unclaimed.
## upstream: MailboxMessage.cs:20
@export var claimed_at: String = ""

## ISO-8601.
## upstream: MailboxMessage.cs:21
@export var created_at: String = ""


## Build a MailboxMessage from a raw JSON Dictionary. Missing keys default
## to the zero-value of their type; extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<MailboxMessage>(...)`.
static func from_dict(d: Variant) -> MailboxMessage:
	var m := MailboxMessage.new()
	if not (d is Dictionary):
		return m
	var dict: Dictionary = d
	m.id = String(dict.get("id", ""))
	m.sender_id = String(dict.get("sender_id", ""))
	m.subject = String(dict.get("subject", ""))
	m.body = String(dict.get("body", ""))
	m.message_type = String(dict.get("message_type", ""))
	m.status = String(dict.get("status", ""))
	m.expires_at = String(dict.get("expires_at", ""))
	m.read_at = String(dict.get("read_at", ""))
	m.claimed_at = String(dict.get("claimed_at", ""))
	m.created_at = String(dict.get("created_at", ""))

	var raw_attachments: Variant = dict.get("attachments", null)
	var parsed: Array[MailboxAttachment] = []
	if raw_attachments is Array:
		for entry in raw_attachments as Array:
			parsed.append(MailboxAttachment.from_dict(entry))
	m.attachments = parsed
	return m


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	var attachments_raw: Array = []
	for a in attachments:
		if a != null:
			attachments_raw.append(a.to_dict())
	return {
		"id": id,
		"sender_id": sender_id,
		"subject": subject,
		"body": body,
		"message_type": message_type,
		"status": status,
		"attachments": attachments_raw,
		"expires_at": expires_at,
		"read_at": read_at,
		"claimed_at": claimed_at,
		"created_at": created_at,
	}
