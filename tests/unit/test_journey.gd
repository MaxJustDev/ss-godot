## Unit tests for PlayerEvent / Journey (M6a).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_mailbox.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 6_Journey/PlayerEvent.cs
extends "res://addons/gut/test.gd"

const PLAYER_EVENT := preload("res://addons/sai_services/journey/player_event.gd")

const GAME_ID := "g_test"

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

	func set_authenticated(flag: bool) -> void:
		_access_token = "AT_test" if flag else ""


# A minimal SaiAuth stand-in so PlayerEvent can subscribe to logout_success.
class FakeSaiAuth:
	extends Node

	signal logout_success


# =========================================================================
# Fixture
# =========================================================================

var _server: FakeSaiServer = null
var _journey: PlayerEvent = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_journey = PLAYER_EVENT.new()
	_journey.name = "PlayerEvent"
	_server.add_child(_journey)


# =========================================================================
# emit_event
# =========================================================================


func test_emit_event_success_posts_to_events_endpoint_with_session_id() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"message": "event tracked", "event_id": "ev_abc123"},
			}
		)
	)
	_journey.set_session_id("session_xyz")
	watch_signals(_journey)

	var payload: Dictionary = {"step": 3, "total_steps": 10, "seconds_in_step": 42.5}
	var result: Dictionary = await _journey.emit_event("tutorial_step_completed", payload)

	assert_true(result.get("success", false), "emit_event reports success")
	assert_signal_emitted(_journey, "event_emitted")

	# Path + body shape match endpoints.md ## Journey.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/events")
	var body: Dictionary = call["body"]
	assert_eq(String(body["event_type"]), "tutorial_step_completed")
	assert_eq(String(body["session_id"]), "session_xyz")
	# event_data is embedded raw — sub-dictionary preserved verbatim.
	var ed: Dictionary = body["event_data"]
	assert_eq(int(ed["step"]), 3)
	assert_eq(int(ed["total_steps"]), 10)

	# Typed response is decoded into EventData.
	var data: Dictionary = result["data"]
	var response: EventData = data["response"]
	assert_eq(response.event_id, "ev_abc123")
	assert_eq(response.message, "event tracked")
	assert_eq(String(data["event_type"]), "tutorial_step_completed")
	assert_eq(String(data["session_id"]), "session_xyz")


func test_emit_event_empty_session_id_generates_fallback_uuid() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"message": "ok", "event_id": "ev_1"},
			}
		)
	)
	# Skip set_session_id so the fallback kicks in (PlayerEvent.cs:109-113).
	assert_eq(_journey.get_session_id(), "")

	var result: Dictionary = await _journey.emit_event("session_start", {})

	assert_true(result.get("success", false))
	var call: Dictionary = _server.calls[0]
	var session_id: String = String(call["body"]["session_id"])
	# UUIDv4 layout: 8-4-4-4-12 hex.
	assert_true(session_id.length() == 36, "fallback uuid is 36 chars")
	assert_true(session_id.contains("-"), "fallback uuid contains hyphens")
	# Echoed back through `data.session_id` for caller visibility.
	assert_eq(String(result["data"]["session_id"]), session_id)


func test_emit_event_not_authenticated_fails_fast_without_network() -> void:
	_server.set_authenticated(false)
	watch_signals(_journey)

	var result: Dictionary = await _journey.emit_event("evt", {})

	assert_false(result.get("success", true))
	# upstream parity: PlayerEvent.cs:103 exact error string.
	assert_eq(String(result["error"]), "Not authenticated! Please login first.")
	assert_eq(_server.calls.size(), 0, "no HTTP call when not authenticated")
	assert_signal_emitted(_journey, "event_failed")


func test_emit_event_empty_game_id_fails_fast_without_network() -> void:
	_server.game_id = ""
	watch_signals(_journey)

	var result: Dictionary = await _journey.emit_event("evt", {})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when game_id is empty")
	assert_signal_emitted(_journey, "event_failed")


func test_emit_event_propagates_server_failure_and_emits_event_failed() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	_journey.set_session_id("session_a")
	watch_signals(_journey)

	var result: Dictionary = await _journey.emit_event("evt", {"k": "v"})

	assert_false(result.get("success", true))
	assert_signal_emitted(_journey, "event_failed")
	assert_signal_emitted_with_parameters(_journey, "event_failed", ["evt", "boom"])


# =========================================================================
# emit_batch
# =========================================================================


func test_emit_batch_iterates_each_entry_and_returns_aggregate() -> void:
	_server.queue_response(
		{"success": true, "status": 200, "error": "", "data": {"event_id": "ev_1"}}
	)
	_server.queue_response(
		{"success": true, "status": 200, "error": "", "data": {"event_id": "ev_2"}}
	)
	_journey.set_session_id("session_a")
	watch_signals(_journey)

	var events: Array[Dictionary] = [
		{"type": "ui_button_clicked", "payload": {"id": "play"}},
		{"type": "scene_loaded", "payload": {"name": "lobby"}},
	]
	var result: Dictionary = await _journey.emit_batch(events)

	assert_true(result.get("success", false))
	var data: Dictionary = result["data"]
	assert_eq(int(data["count"]), 2)
	assert_eq(int(data["failures"]), 0)
	# Two HTTP calls, one per entry (no wire-level batch endpoint).
	assert_eq(_server.calls.size(), 2)
	assert_eq(String(_server.calls[0]["body"]["event_type"]), "ui_button_clicked")
	assert_eq(String(_server.calls[1]["body"]["event_type"]), "scene_loaded")


func test_emit_batch_partial_failure_marks_aggregate_failed() -> void:
	_server.queue_response(
		{"success": true, "status": 200, "error": "", "data": {"event_id": "ev_1"}}
	)
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	_journey.set_session_id("session_a")

	var events: Array[Dictionary] = [
		{"type": "a", "payload": {}},
		{"type": "b", "payload": {}},
	]
	var result: Dictionary = await _journey.emit_batch(events)

	assert_false(result.get("success", true), "aggregate is failed when any entry fails")
	var data: Dictionary = result["data"]
	assert_eq(int(data["failures"]), 1)
	assert_eq((data["results"] as Array).size(), 2)


func test_emit_batch_empty_array_returns_success_with_zero_count() -> void:
	var result: Dictionary = await _journey.emit_batch([])

	assert_true(result.get("success", false))
	assert_eq(int(result["data"]["count"]), 0)
	assert_eq(_server.calls.size(), 0, "empty batch makes zero HTTP calls")


# =========================================================================
# session id lifecycle
# =========================================================================


func test_set_session_id_emits_session_id_changed() -> void:
	watch_signals(_journey)

	_journey.set_session_id("manual_id")

	assert_eq(_journey.get_session_id(), "manual_id")
	assert_signal_emitted(_journey, "session_id_changed")
	assert_signal_emitted_with_parameters(_journey, "session_id_changed", ["manual_id"])


func test_regenerate_session_id_produces_non_empty_id_and_emits() -> void:
	watch_signals(_journey)

	_journey.regenerate_session_id()

	var id: String = _journey.get_session_id()
	assert_true(id.length() == 36, "regenerated id is uuid-shaped")
	assert_signal_emitted(_journey, "session_id_changed")


func test_token_refreshed_signal_rotates_session_id_like_upstream_login() -> void:
	# PlayerEvent.cs:63-70 — fresh sessionId on every OnLoginSuccess.
	# We mirror that by subscribing to SaiServer.token_refreshed (fires from
	# set_login_data, which login() always calls on success).
	watch_signals(_journey)
	_journey.set_session_id("")

	_server.token_refreshed.emit("AT_after_login")
	# Let the connected handler run.
	await get_tree().process_frame

	var id: String = _journey.get_session_id()
	assert_true(id.length() == 36, "session id regenerated on token_refreshed")
	assert_signal_emitted(_journey, "session_id_changed")


func test_token_refreshed_with_empty_token_does_not_rotate() -> void:
	# Defensive: clear_tokens() also fires token_refreshed("") — that path
	# should not regenerate a fresh session id (logout is handled separately).
	_journey.set_session_id("keep_me")

	_server.token_refreshed.emit("")
	await get_tree().process_frame

	assert_eq(_journey.get_session_id(), "keep_me")


func test_sibling_auth_logout_clears_session_id() -> void:
	# Rebuild fixture with a sibling SaiAuth-shaped node so PlayerEvent can
	# wire `logout_success` (PlayerEvent.cs:72-78 parity).
	_journey.queue_free()
	await get_tree().process_frame

	var fake_auth := FakeSaiAuth.new()
	fake_auth.name = "SaiAuth"
	_server.add_child(fake_auth)

	_journey = PLAYER_EVENT.new()
	_journey.name = "PlayerEvent"
	_server.add_child(_journey)
	_journey.set_session_id("about_to_be_cleared")
	watch_signals(_journey)

	fake_auth.logout_success.emit()
	await get_tree().process_frame

	assert_eq(_journey.get_session_id(), "", "logout clears session id")
	assert_signal_emitted(_journey, "session_id_changed")
