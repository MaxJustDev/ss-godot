## Mailbox - list / read / unread / claim / unclaim / delete wrapper around
## the SaiGame mailbox REST endpoints.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:8`
## (upstream v0.2.40d).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals so fire-and-forget subscribers still work
##     (B.4 in CLAUDE.md).
##   - `PATCH .../{message_id}` is one path with two bodies — `{"read": true}`
##     marks the message as read (`mark_read`), `{"read": false}` marks it
##     unread (`mark_unread`). The dual-shape response handling
##     (`ReadMessageResponse { message, message_text }` *or* a flat
##     `MailboxMessage`) is centralised in `_extract_message`, mirroring
##     upstream `ParseMailboxMessage` (Mailbox.cs:651-664).
##   - Auto-load-on-login and ClaimAll are intentionally NOT ported in M3b
##     (TODO M4+ once item definitions exist; ClaimAll just iterates `claim`
##     and can be done at the app layer).
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.mailbox` from app code.
##
## upstream: 2_Mailbox/Mailbox.cs:8
class_name Mailbox
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: Mailbox.cs:125
const PATH_MESSAGES := "/api/v1/games/{game_id}/mailbox/messages"

## upstream: Mailbox.cs:184, Mailbox.cs:257, Mailbox.cs:565
const PATH_MESSAGE := "/api/v1/games/{game_id}/mailbox/messages/{message_id}"

## upstream: Mailbox.cs:328, Mailbox.cs:401
const PATH_MESSAGE_CLAIM := "/api/v1/games/{game_id}/mailbox/messages/{message_id}/claim"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `list()`. `messages` is `Array[MailboxMessage]`,
## `total` mirrors the server-reported count.
## upstream: Mailbox.cs:11 (OnGetMessagesSuccess)
signal list_loaded(messages: Array, total: int)
## upstream: Mailbox.cs:12 (OnGetMessagesFailure)
signal list_failed(error: String)

## Fires after either `mark_read` or `mark_unread` succeeds.
## `read` is the bool sent in the request body, `message` is the post-update
## `MailboxMessage` extracted from the server response (may be null if the
## server omitted it).
## upstream: Mailbox.cs:13-16 (OnReadMessageSuccess / OnUnreadMessageSuccess)
signal read_changed(message_id: String, read: bool, message: MailboxMessage)

## Emitted on successful `claim()`. `rewards` is `Array[ClaimReward]`.
## upstream: Mailbox.cs:17 (OnClaimMessageSuccess)
signal claim_success(message_id: String, rewards: Array)
## upstream: Mailbox.cs:18 (OnClaimMessageFailure)
signal claim_failed(message_id: String, error: String)

## upstream: Mailbox.cs:19 (OnUnclaimMessageSuccess)
signal unclaim_success(message_id: String)

## upstream: Mailbox.cs:23 (OnDeleteMessageSuccess)
signal delete_success(message_id: String)
## upstream: Mailbox.cs:24 (OnDeleteMessageFailure)
signal delete_failed(message_id: String, error: String)

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/mailbox/messages?limit=&offset=
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `messages`: Array[MailboxMessage]
##   - `total`: int
##   - `raw`: original Dictionary as returned by the server (for callers
##     that need fields the typed DTOs do not cover yet).
##
## upstream: Mailbox.cs:99 (GetMessages), Mailbox.cs:122 (GetMessagesCoroutine)
func list(limit: int = 20, offset: int = 0) -> Dictionary:
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

	var path: String = PATH_MESSAGES.replace("{game_id}", game_id)
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list mailbox failed"))
		list_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var messages: Array[MailboxMessage] = []
	var raw_messages: Variant = raw.get("messages", null)
	if raw_messages is Array:
		for entry in raw_messages as Array:
			messages.append(MailboxMessage.from_dict(entry))
	var total: int = int(raw.get("total", messages.size()))
	list_loaded.emit(messages, total)

	# Re-wrap so callers get typed access without losing the raw payload.
	var out := result.duplicate(true)
	out["data"] = {"messages": messages, "total": total, "raw": raw}
	return out


## PATCH /api/v1/games/{game_id}/mailbox/messages/{message_id}
## body: `{"read": true}` literal.
##
## upstream: Mailbox.cs:162 (ReadMessage), Mailbox.cs:184 (ReadMessageCoroutine)
func mark_read(message_id: String) -> Dictionary:
	return await _patch_read(message_id, true)


## PATCH /api/v1/games/{game_id}/mailbox/messages/{message_id}
## body: `{"read": false}` literal — same path as `mark_read`, only the
## boolean in the body flips.
##
## upstream: Mailbox.cs:234 (UnreadMessage), Mailbox.cs:254 (UnreadMessageCoroutine)
func mark_unread(message_id: String) -> Dictionary:
	return await _patch_read(message_id, false)


## POST /api/v1/games/{game_id}/mailbox/messages/{message_id}/claim
## body: `{}` literal.
##
## On success, `data` is `{rewards: Array[ClaimReward], raw: Dictionary}`.
##
## upstream: Mailbox.cs:306 (ClaimMessage), Mailbox.cs:325 (ClaimMessageCoroutine)
func claim(message_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		claim_failed.emit(message_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		claim_failed.emit(message_id, err)
		return _envelope_fail(err)

	var path: String = PATH_MESSAGE_CLAIM.replace("{game_id}", game_id).replace(
		"{message_id}", message_id
	)
	var result: Dictionary = await server.post_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "claim message failed"))
		claim_failed.emit(message_id, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var rewards: Array[ClaimReward] = []
	var raw_rewards: Variant = raw.get("rewards", null)
	if raw_rewards is Array:
		for entry in raw_rewards as Array:
			rewards.append(ClaimReward.from_dict(entry))
	claim_success.emit(message_id, rewards)

	var out := result.duplicate(true)
	out["data"] = {"rewards": rewards, "raw": raw}
	return out


## DELETE /api/v1/games/{game_id}/mailbox/messages/{message_id}/claim
##
## Server-side rollback of a previous `claim()`. Body intentionally empty
## (upstream: Mailbox.cs:403 — `DeleteRequest` with no body).
##
## upstream: Mailbox.cs:378 (UnclaimMessage), Mailbox.cs:398 (UnclaimMessageCoroutine)
func unclaim(message_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		return _envelope_fail("SaiServer not found")

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		return _envelope_fail("game_id is empty — set SaiServer.game_id first")

	var path: String = PATH_MESSAGE_CLAIM.replace("{game_id}", game_id).replace(
		"{message_id}", message_id
	)
	var result: Dictionary = await server.delete_request(path, null, true)

	if result.get("success", false):
		unclaim_success.emit(message_id)
	return result


## DELETE /api/v1/games/{game_id}/mailbox/messages/{message_id}
##
## upstream: Mailbox.cs:542 (DeleteMessage), Mailbox.cs:562 (DeleteMessageCoroutine)
func delete(message_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		delete_failed.emit(message_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		delete_failed.emit(message_id, err)
		return _envelope_fail(err)

	var path: String = PATH_MESSAGE.replace("{game_id}", game_id).replace(
		"{message_id}", message_id
	)
	var result: Dictionary = await server.delete_request(path, null, true)

	if result.get("success", false):
		delete_success.emit(message_id)
	else:
		var error_msg: String = String(result.get("error", "delete message failed"))
		delete_failed.emit(message_id, error_msg)
	return result


# =========================================================================
# Internals
# =========================================================================


## Shared PATCH path for `mark_read` and `mark_unread`. Two methods, one
## endpoint, body differs only by the `read` boolean literal.
## upstream: Mailbox.cs:184-187 (read=true), Mailbox.cs:257-260 (read=false)
func _patch_read(message_id: String, read: bool) -> Dictionary:
	var server: Node = _server()
	if server == null:
		return _envelope_fail("SaiServer not found")

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		return _envelope_fail("game_id is empty — set SaiServer.game_id first")

	var path: String = PATH_MESSAGE.replace("{game_id}", game_id).replace(
		"{message_id}", message_id
	)
	var body: Dictionary = {"read": read}
	var result: Dictionary = await server.patch_request(path, body, true)

	if not result.get("success", false):
		return result

	var message: MailboxMessage = _extract_message(result.get("data", null))
	read_changed.emit(message_id, read, message)

	# Replace `data` with the typed message + raw fallback.
	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var out := result.duplicate(true)
	out["data"] = {"message": message, "raw": raw}
	return out


## Extract a `MailboxMessage` from the dual-shape PATCH response.
##
## Upstream `ParseMailboxMessage` (Mailbox.cs:651-664) first tries the
## wrapped form `{message: {...}, message_text: "..."}`, then falls back to
## a flat `MailboxMessage` object. We mirror that here so callers don't
## care which shape the server picked.
func _extract_message(data: Variant) -> MailboxMessage:
	if not (data is Dictionary):
		return null
	var dict: Dictionary = data
	# Wrapped: { "message": {...}, "message_text": "..." }
	var wrapped: Variant = dict.get("message", null)
	if wrapped is Dictionary:
		var inner: Dictionary = wrapped
		if String(inner.get("id", "")) != "":
			return MailboxMessage.from_dict(inner)
	# Flat: MailboxMessage at the top level.
	if String(dict.get("id", "")) != "":
		return MailboxMessage.from_dict(dict)
	return null


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


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
