## Unit tests for Mailbox (M3b).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_sai_auth.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 2_Mailbox/Mailbox.cs
extends "res://addons/gut/test.gd"

const MAILBOX := preload("res://addons/sai_services/mailbox/mailbox.gd")

const GAME_ID := "g_test"
const MSG_ID := "m_001"

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
var _mailbox: Mailbox = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_mailbox = MAILBOX.new()
	_mailbox.name = "Mailbox"
	_server.add_child(_mailbox)


# =========================================================================
# list
# =========================================================================


func test_list_success_returns_typed_messages_and_emits_list_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"messages":
					[
						{
							"id": MSG_ID,
							"sender_id": "system",
							"subject": "Welcome",
							"body": "Hello",
							"message_type": "system",
							"status": "unread",
							"attachments": [],
							"expires_at": "",
							"read_at": "",
							"claimed_at": "",
							"created_at": "2026-05-20T00:00:00Z",
						},
					],
					"total": 1,
				},
			}
		)
	)
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.list(20, 0)

	assert_true(result.get("success", false), "list reports success")
	assert_signal_emitted(_mailbox, "list_loaded")
	var data: Dictionary = result["data"]
	assert_eq(int(data["total"]), 1, "total propagated")
	assert_eq((data["messages"] as Array).size(), 1, "one message decoded")
	var msg: MailboxMessage = (data["messages"] as Array)[0]
	assert_eq(msg.id, MSG_ID)
	assert_eq(msg.status, "unread")
	# Query params are forwarded.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages")
	assert_eq(int(call["query"]["limit"]), 20)
	assert_eq(int(call["query"]["offset"]), 0)


func test_list_failed_emits_list_failed_with_error_text() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.list(10, 5)

	assert_false(result.get("success", true))
	assert_signal_emitted(_mailbox, "list_failed")
	assert_signal_emitted_with_parameters(_mailbox, "list_failed", ["boom"])


func test_list_empty_game_id_fails_fast_without_network() -> void:
	_server.game_id = ""
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.list()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when game_id is empty")
	assert_signal_emitted(_mailbox, "list_failed")


func test_list_handles_attachments_as_typed_resources() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"messages":
					[
						{
							"id": MSG_ID,
							"attachments":
							[
								{
									"type": "item",
									"definition_id": "def_gold",
									"quantity": 100,
									"item_definition": {"name": "Gold"}
								},
							],
						},
					],
					"total": 1,
				},
			}
		)
	)

	var result: Dictionary = await _mailbox.list()

	var msg: MailboxMessage = (result["data"]["messages"] as Array)[0]
	assert_eq(msg.attachments.size(), 1, "attachment decoded")
	var att: MailboxAttachment = msg.attachments[0]
	assert_eq(att.definition_id, "def_gold")
	assert_eq(att.quantity, 100)
	# item_definition kept raw — M4 will swap in a typed DTO.
	assert_eq(String(att.item_definition.get("name", "")), "Gold")


# =========================================================================
# mark_read / mark_unread (one path, two bodies)
# =========================================================================


func test_mark_read_sends_patch_with_read_true_and_emits_read_changed() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"message": {"id": MSG_ID, "status": "read", "read_at": "2026-05-20T00:00:01Z"},
					"message_text": "ok",
				},
			}
		)
	)
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.mark_read(MSG_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_mailbox, "read_changed")
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "PATCH")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages/m_001")
	assert_true(bool(call["body"]["read"]), "body sends read=true")
	var data: Dictionary = result["data"]
	var msg: MailboxMessage = data["message"]
	assert_eq(msg.status, "read", "wrapped shape decoded via _extract_message")


func test_mark_unread_sends_patch_with_read_false_same_path() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": MSG_ID, "status": "unread", "read_at": ""},
			}
		)
	)
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.mark_unread(MSG_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_mailbox, "read_changed")
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "PATCH")
	# Same endpoint as mark_read — only the body literal differs.
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages/m_001")
	assert_false(bool(call["body"]["read"]), "body sends read=false")
	# Flat-shape response was extracted directly into MailboxMessage.
	var msg: MailboxMessage = result["data"]["message"]
	assert_eq(msg.id, MSG_ID)
	assert_eq(msg.status, "unread")


func test_mark_read_propagates_failure_without_emitting_read_changed() -> void:
	_server.queue_response({"success": false, "status": 404, "error": "not_found", "data": null})
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.mark_read(MSG_ID)

	assert_false(result.get("success", true))
	assert_signal_not_emitted(_mailbox, "read_changed")


# =========================================================================
# claim / unclaim
# =========================================================================


func test_claim_success_decodes_rewards_and_emits_claim_success() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"rewards":
					[
						{"type": "item", "definition_id": "def_sword", "quantity": 1},
						{"type": "currency", "definition_id": "gold", "quantity": 500},
					],
				},
			}
		)
	)
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.claim(MSG_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_mailbox, "claim_success")
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages/m_001/claim")
	# Body literal is `{}` per endpoints.md.
	assert_eq((call["body"] as Dictionary).size(), 0)
	var rewards: Array = result["data"]["rewards"]
	assert_eq(rewards.size(), 2)
	var first: ClaimReward = rewards[0]
	assert_eq(first.definition_id, "def_sword")
	assert_eq(first.quantity, 1)


func test_claim_failed_emits_claim_failed_with_message_id_and_error() -> void:
	_server.queue_response(
		{"success": false, "status": 409, "error": "already_claimed", "data": null}
	)
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.claim(MSG_ID)

	assert_false(result.get("success", true))
	assert_signal_emitted(_mailbox, "claim_failed")
	assert_signal_emitted_with_parameters(_mailbox, "claim_failed", [MSG_ID, "already_claimed"])


func test_unclaim_sends_delete_to_claim_endpoint_and_emits_unclaim_success() -> void:
	_server.queue_response({"success": true, "status": 200, "error": "", "data": null})
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.unclaim(MSG_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_mailbox, "unclaim_success")
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "DELETE")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages/m_001/claim")


# =========================================================================
# delete
# =========================================================================


func test_delete_success_emits_delete_success_with_message_id() -> void:
	_server.queue_response({"success": true, "status": 200, "error": "", "data": null})
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.delete(MSG_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_mailbox, "delete_success")
	assert_signal_emitted_with_parameters(_mailbox, "delete_success", [MSG_ID])
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "DELETE")
	# Same `{message_id}` path as PATCH, but no `/claim` suffix.
	assert_eq(String(call["path"]), "/api/v1/games/g_test/mailbox/messages/m_001")


func test_delete_failed_emits_delete_failed_with_error() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "io_error", "data": null})
	watch_signals(_mailbox)

	var result: Dictionary = await _mailbox.delete(MSG_ID)

	assert_false(result.get("success", true))
	assert_signal_emitted(_mailbox, "delete_failed")
	assert_signal_emitted_with_parameters(_mailbox, "delete_failed", [MSG_ID, "io_error"])
