## Unit tests for BattleSessions + BattleScript (M6c).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_shop.gd` and `test_journey.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 8_Battle/BattleSessions.cs, 8_Battle/BattleScript.cs
extends "res://addons/gut/test.gd"

const BATTLE_SESSIONS_SCRIPT := preload("res://addons/sai_services/battle/battle_sessions.gd")
const BATTLE_SCRIPT_SCRIPT := preload("res://addons/sai_services/battle/battle_script.gd")

const GAME_ID := "g_test"
const SESSION_ID := "bs_001"

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


# =========================================================================
# Fixture
# =========================================================================

var _server: FakeSaiServer = null
var _battle: BattleSessions = null
var _script: BattleScript = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)

	_battle = BATTLE_SESSIONS_SCRIPT.new()
	_battle.name = "BattleSessions"
	_server.add_child(_battle)

	_script = BATTLE_SCRIPT_SCRIPT.new()
	_script.name = "BattleScript"
	_server.add_child(_script)


# =========================================================================
# list_sessions
# =========================================================================


func test_list_sessions_success_returns_typed_sessions_and_emits_sessions_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"sessions":
					[
						{
							"id": SESSION_ID,
							"game_id": GAME_ID,
							"player_id": "u_001",
							"status": "in_progress",
							"started_at": "2026-05-20T00:00:00Z",
							"expires_at": "2026-05-20T01:00:00Z",
							"ended_at": "",
							"start_data": {"turn": 1, "victory": false},
							"end_data": {},
						},
						{
							"id": "bs_002",
							"game_id": GAME_ID,
							"player_id": "u_001",
							"status": "finished",
							"started_at": "2026-05-19T00:00:00Z",
							"ended_at": "2026-05-19T00:10:00Z",
							"start_data": {},
							"end_data": {"kills": 5, "victory": true},
						},
					],
					"limit": 50,
					"offset": 0,
					"total": 2,
				},
			}
		)
	)
	watch_signals(_battle)

	var result: Dictionary = await _battle.list_sessions(50, 0)

	assert_true(result.get("success", false), "list_sessions reports success")
	assert_signal_emitted(_battle, "sessions_loaded")
	var data: Dictionary = result["data"]
	assert_eq(int(data["total"]), 2, "total propagated")
	var sessions: Array = data["sessions"]
	assert_eq(sessions.size(), 2, "two sessions decoded")
	var first: BattleData = sessions[0]
	assert_eq(first.id, SESSION_ID)
	assert_eq(first.status, "in_progress")
	# Nested dynamic payload preserved verbatim as Dictionary.
	assert_eq(int(first.start_data.get("turn", 0)), 1)
	# Cache populated.
	assert_eq(_battle.cached_sessions.size(), 2)
	assert_eq(_battle.cached_sessions_total, 2)
	# Path + query stamped per endpoints.md `## Battle` first row.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/me/battle-sessions")
	assert_eq(int(call["query"]["limit"]), 50)
	assert_eq(int(call["query"]["offset"]), 0)


func test_list_sessions_failed_emits_sessions_failed_with_error_text() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_battle)

	var result: Dictionary = await _battle.list_sessions(10, 5)

	assert_false(result.get("success", true))
	assert_signal_emitted(_battle, "sessions_failed")
	assert_signal_emitted_with_parameters(_battle, "sessions_failed", ["boom"])


func test_list_sessions_not_authenticated_fails_fast_without_network() -> void:
	_server.set_authenticated(false)
	watch_signals(_battle)

	var result: Dictionary = await _battle.list_sessions()

	assert_false(result.get("success", true))
	# upstream parity: BattleSessions.cs:106 exact error string.
	assert_eq(String(result["error"]), "Not authenticated! Please login first.")
	assert_eq(_server.calls.size(), 0, "no HTTP call when not authenticated")
	assert_signal_emitted(_battle, "sessions_failed")


func test_list_sessions_empty_game_id_fails_fast_without_network() -> void:
	_server.game_id = ""
	watch_signals(_battle)

	var result: Dictionary = await _battle.list_sessions()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when game_id is empty")
	assert_signal_emitted(_battle, "sessions_failed")


# =========================================================================
# Cache helpers
# =========================================================================


func test_get_session_by_id_finds_cached_entry_and_clear_sessions_resets() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"sessions":
					[
						{"id": SESSION_ID, "status": "in_progress"},
						{"id": "bs_002", "status": "finished"},
					],
					"total": 2,
				},
			}
		)
	)
	await _battle.list_sessions()

	assert_eq(_battle.get_session_by_id(SESSION_ID).status, "in_progress")
	assert_eq(_battle.get_session_by_id("bs_002").status, "finished")
	assert_null(_battle.get_session_by_id("does_not_exist"))
	assert_true(_battle.has_sessions())

	_battle.clear_sessions()
	assert_false(_battle.has_sessions())
	assert_eq(_battle.cached_sessions_total, 0)


# =========================================================================
# Deferred lifecycle stubs (create_session / send_event / finish_session)
# =========================================================================


func test_create_session_returns_not_implemented_envelope_and_emits_failed() -> void:
	# Per the M6c discovery note + docs/endpoints.md `## Battle`, upstream has
	# no create-session wire endpoint. The method must NOT touch the network.
	watch_signals(_battle)

	var result: Dictionary = await _battle.create_session({"map": "forest"})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "create_session must not hit network until backend exists")
	assert_signal_emitted(_battle, "session_create_failed")


func test_send_event_returns_not_implemented_envelope_and_emits_failed() -> void:
	watch_signals(_battle)

	var result: Dictionary = await _battle.send_event(SESSION_ID, "kill", {"target": "goblin"})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "send_event must not hit network until backend exists")
	assert_signal_emitted(_battle, "event_failed")


func test_finish_session_returns_not_implemented_envelope_and_emits_failed() -> void:
	watch_signals(_battle)

	var result: Dictionary = await _battle.finish_session(SESSION_ID, {"result": "win"})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "finish_session must not hit network until backend exists")
	assert_signal_emitted(_battle, "session_finish_failed")


# =========================================================================
# run_script (raw passthrough)
# =========================================================================


func test_run_script_success_forwards_raw_data_and_emits_script_success() -> void:
	# Per the M6c discovery note, the response is fully opaque to the SDK —
	# we just expose whatever the server returned under `data.raw`.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"damage": 42, "crit": true, "log": ["hit", "miss"]},
			}
		)
	)
	watch_signals(_script)

	var result: Dictionary = await (
		_script
		. run_script(
			"damage_calc",
			{
				"attacker": "u_001",
				"defender": "goblin",
				"ability": "fireball",
			}
		)
	)

	assert_true(result.get("success", false), "run_script reports success")
	assert_signal_emitted(_script, "script_success")

	# Path + body shape match endpoints.md `## Battle` second row.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts/damage_calc/run")
	# upstream: BattleScript.cs:17 — body wraps caller's params under `payload`.
	var body: Dictionary = call["body"]
	var payload: Dictionary = body["payload"]
	assert_eq(String(payload["attacker"]), "u_001")
	assert_eq(String(payload["ability"]), "fireball")

	# Data is forwarded raw — no typed decoding.
	var data: Dictionary = result["data"]
	assert_eq(String(data["name"]), "damage_calc")
	var raw: Dictionary = data["raw"]
	assert_eq(int(raw["damage"]), 42)
	assert_true(bool(raw["crit"]))
	assert_eq((raw["log"] as Array).size(), 2)


func test_run_script_empty_params_sends_default_payload_dict() -> void:
	_server.queue_response({"success": true, "status": 200, "error": "", "data": {}})

	var _ignored: Dictionary = await _script.run_script("noop", {})

	var body: Dictionary = _server.calls[0]["body"]
	# upstream default body: `{"payload": {}}` (BattleScript.cs:17).
	assert_true(body.has("payload"))
	assert_eq((body["payload"] as Dictionary).size(), 0)


func test_run_script_empty_script_name_fails_fast_without_network() -> void:
	watch_signals(_script)

	var result: Dictionary = await _script.run_script("", {})

	assert_false(result.get("success", true))
	# upstream parity: BattleScript.cs:55 exact error string.
	assert_eq(String(result["error"]), "Script name is empty!")
	assert_eq(_server.calls.size(), 0, "no HTTP call when script name is empty")
	assert_signal_emitted(_script, "script_failed")


func test_run_script_not_authenticated_fails_fast_without_network() -> void:
	_server.set_authenticated(false)
	watch_signals(_script)

	var result: Dictionary = await _script.run_script("damage_calc", {})

	assert_false(result.get("success", true))
	assert_eq(String(result["error"]), "Not authenticated! Please login first.")
	assert_eq(_server.calls.size(), 0, "no HTTP call when not authenticated")
	assert_signal_emitted(_script, "script_failed")


func test_run_script_failed_propagates_server_error_and_emits_script_failed() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "script_error", "data": null})
	watch_signals(_script)

	var result: Dictionary = await _script.run_script("damage_calc", {})

	assert_false(result.get("success", true))
	assert_signal_emitted(_script, "script_failed")
	assert_signal_emitted_with_parameters(_script, "script_failed", ["damage_calc", "script_error"])
