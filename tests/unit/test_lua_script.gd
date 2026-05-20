## Unit tests for LuaScriptManager (M6d).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_battle.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 9_LuaScript/LuaScriptManager.cs (+ 8_Battle/BattleScript.cs
## for the `run` endpoint which is shared across both SDK classes).
extends "res://addons/gut/test.gd"

const LUA_SCRIPT_MANAGER_SCRIPT := preload(
	"res://addons/sai_services/lua_script/lua_script_manager.gd"
)

const GAME_ID := "g_test"
const SCRIPT_ID := "ls_001"
const SCRIPT_NAME := "battle_start"

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
var _lua: LuaScriptManager = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)

	_lua = LUA_SCRIPT_MANAGER_SCRIPT.new()
	_lua.name = "LuaScriptManager"
	_server.add_child(_lua)


# =========================================================================
# list() — wrapper-shape tolerance
# =========================================================================


func _make_record(id: String, name: String) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": "",
		"script_body": "return 1",
		"version": 1,
		"is_active": true,
		"is_library": false,
		"created_by": "u_001",
		"created_at": "2026-05-20T00:00:00Z",
		"updated_at": "2026-05-20T00:00:00Z",
	}


func test_list_success_bare_array_response_unwraps_records() -> void:
	# upstream parity: LuaScriptManager.cs:332-335 — bare `[...]` is the
	# canonical form. SaiServer's generic JSON parser hands it to us as an
	# Array. We must accept it as-is.
	var records := [_make_record(SCRIPT_ID, SCRIPT_NAME), _make_record("ls_002", "battle_end")]
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": records,
			}
		)
	)
	watch_signals(_lua)

	var result: Dictionary = await _lua.list()

	assert_true(result.get("success", false), "list reports success")
	assert_signal_emitted(_lua, "list_loaded")
	var data: Dictionary = result["data"]
	var scripts: Array = data["scripts"]
	assert_eq(scripts.size(), 2, "two records unwrapped from bare array")
	assert_eq(String((scripts[0] as Dictionary)["id"]), SCRIPT_ID)
	assert_eq(_lua.cached_scripts.size(), 2, "cache populated")
	# Path matches endpoints.md `## LuaScript` first row.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts")


func test_list_success_scripts_wrapper_response_unwraps_records() -> void:
	# upstream: LuaScriptManager.cs:347-349 — `response.scripts` wins first.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"scripts": [_make_record(SCRIPT_ID, SCRIPT_NAME)]},
			}
		)
	)

	var result: Dictionary = await _lua.list()

	assert_true(result.get("success", false))
	var scripts: Array = result["data"]["scripts"]
	assert_eq(scripts.size(), 1, "scripts wrapper unwrapped")
	assert_eq(String((scripts[0] as Dictionary)["id"]), SCRIPT_ID)


func test_list_success_data_wrapper_response_unwraps_records() -> void:
	# upstream: LuaScriptManager.cs:352-354 — `response.data` second.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"data":
					[_make_record(SCRIPT_ID, SCRIPT_NAME), _make_record("ls_002", "battle_end")]
				},
			}
		)
	)

	var result: Dictionary = await _lua.list()

	var scripts: Array = result["data"]["scripts"]
	assert_eq(scripts.size(), 2, "data wrapper unwrapped")


func test_list_success_items_wrapper_response_unwraps_records() -> void:
	# upstream: LuaScriptManager.cs:356-357 — `response.items` last fallback.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"items": [_make_record(SCRIPT_ID, SCRIPT_NAME)]},
			}
		)
	)

	var result: Dictionary = await _lua.list()

	var scripts: Array = result["data"]["scripts"]
	assert_eq(scripts.size(), 1, "items wrapper unwrapped")


func test_list_failed_emits_list_failed_with_error_text() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_lua)

	var result: Dictionary = await _lua.list()

	assert_false(result.get("success", true))
	assert_signal_emitted(_lua, "list_failed")
	assert_signal_emitted_with_parameters(_lua, "list_failed", ["boom"])


func test_list_not_authenticated_fails_fast_without_network() -> void:
	_server.set_authenticated(false)
	watch_signals(_lua)

	var result: Dictionary = await _lua.list()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when not authenticated")
	assert_signal_emitted(_lua, "list_failed")


# =========================================================================
# create_script
# =========================================================================


func test_create_script_success_returns_id_and_emits_create_success() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": SCRIPT_ID, "name": SCRIPT_NAME},
			}
		)
	)
	watch_signals(_lua)

	var body: Dictionary = {
		"name": SCRIPT_NAME,
		"description": "Start of battle hook.",
		"script_body": "function on_start() return true end",
	}
	var result: Dictionary = await _lua.create_script(body)

	assert_true(result.get("success", false))
	assert_signal_emitted(_lua, "create_success")
	assert_eq(String(result["data"]["id"]), SCRIPT_ID)
	# Path matches endpoints.md `## LuaScript` second row (POST /scripts).
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts")
	# upstream: LuaScriptManager.cs:587 — body forwards `name/description/script_body`.
	var sent: Dictionary = call["body"]
	assert_eq(String(sent["name"]), SCRIPT_NAME)
	assert_eq(String(sent["script_body"]), "function on_start() return true end")


func test_create_script_blank_name_fails_fast_without_network() -> void:
	watch_signals(_lua)

	var result: Dictionary = await _lua.create_script({"name": "   ", "script_body": ""})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_lua, "create_failed")


# =========================================================================
# update_script (full-body PATCH)
# =========================================================================


func test_update_script_success_sends_full_body_and_emits_update_success() -> void:
	# Same path as set_flags but the body shape differs — see the M6d discovery
	# note. Caller is responsible for which shape to send; we mirror that.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": SCRIPT_ID},
			}
		)
	)
	watch_signals(_lua)

	var body: Dictionary = {
		"description": "updated",
		"script_body": "return 2",
		"is_active": true,
		"is_library": false,
	}
	var result: Dictionary = await _lua.update_script(SCRIPT_ID, body)

	assert_true(result.get("success", false))
	assert_signal_emitted(_lua, "update_success")
	assert_eq(String(result["data"]["id"]), SCRIPT_ID)
	# Path: /api/v1/games/{game_id}/scripts/{script_id}
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "PATCH")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts/ls_001")
	# upstream: LuaScriptManager.cs:594 — full UpdateRequest shape.
	var sent: Dictionary = call["body"]
	assert_eq(String(sent["description"]), "updated")
	assert_eq(String(sent["script_body"]), "return 2")
	assert_true(bool(sent["is_active"]))
	assert_false(bool(sent["is_library"]))


func test_update_script_empty_id_fails_fast_without_network() -> void:
	watch_signals(_lua)

	var result: Dictionary = await _lua.update_script("", {"script_body": "x"})

	assert_false(result.get("success", true))
	# upstream parity: LuaScriptManager.cs:187 exact error string.
	assert_eq(String(result["error"]), "Script Id is required for update.")
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_lua, "update_failed")


# =========================================================================
# set_flags (flags-only PATCH — SHARES path with update_script)
# =========================================================================


func test_set_flags_success_sends_flags_only_body_and_emits_flags_success() -> void:
	# Same path constant as update_script — only the body shape differs.
	# upstream: LuaScriptManager.cs:603 — FlagsRequest is `{is_active, is_library}`.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": SCRIPT_ID},
			}
		)
	)
	watch_signals(_lua)

	var result: Dictionary = await _lua.set_flags(
		SCRIPT_ID, {"is_active": false, "is_library": true}
	)

	assert_true(result.get("success", false))
	assert_signal_emitted(_lua, "flags_success")
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "PATCH")
	assert_eq(
		String(call["path"]),
		"/api/v1/games/g_test/scripts/ls_001",
		"set_flags shares the same path constant as update_script"
	)
	var sent: Dictionary = call["body"]
	# Flags-only body must NOT carry full-update fields.
	assert_false(sent.has("script_body"), "flags-only body omits script_body")
	assert_false(sent.has("description"), "flags-only body omits description")
	assert_false(bool(sent["is_active"]))
	assert_true(bool(sent["is_library"]))


func test_set_flags_enabled_alias_maps_to_is_active() -> void:
	# docs/examples/lua_script.md shows `{"enabled": false}` — make sure the
	# alias survives the wire shape conversion.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": SCRIPT_ID},
			}
		)
	)

	var _r: Dictionary = await _lua.set_flags(SCRIPT_ID, {"enabled": false})

	var sent: Dictionary = _server.calls[0]["body"]
	assert_true(sent.has("is_active"), "enabled alias rewrites to is_active")
	assert_false(bool(sent["is_active"]))


func test_set_flags_empty_id_fails_fast_without_network() -> void:
	watch_signals(_lua)

	var result: Dictionary = await _lua.set_flags("", {"is_active": true})

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_lua, "flags_failed")


# =========================================================================
# delete_script
# =========================================================================


func test_delete_script_success_emits_delete_success_with_id() -> void:
	_server.queue_response({"success": true, "status": 200, "error": "", "data": null})
	watch_signals(_lua)

	var result: Dictionary = await _lua.delete_script(SCRIPT_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_lua, "delete_success")
	assert_signal_emitted_with_parameters(_lua, "delete_success", [SCRIPT_ID])
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "DELETE")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts/ls_001")


# =========================================================================
# run() — RPC into server-side Lua (raw passthrough)
# =========================================================================


func test_run_success_forwards_raw_data_and_emits_run_success() -> void:
	# Per the M6d discovery note, body + response are dynamic — the SDK only
	# wraps the caller's params under `payload` and surfaces `data.raw` as-is.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"result": 42, "log": ["ok"]},
			}
		)
	)
	watch_signals(_lua)

	var result: Dictionary = await (
		_lua
		. run(
			"damage_calc",
			{
				"attacker": "u_001",
				"defender": "goblin",
			}
		)
	)

	assert_true(result.get("success", false))
	assert_signal_emitted(_lua, "run_success")
	# Path is the shared Lua run endpoint (also used by BattleScript).
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "POST")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/scripts/damage_calc/run")
	# Body wraps caller input under `payload`.
	var sent: Dictionary = call["body"]
	assert_true(sent.has("payload"))
	var payload: Dictionary = sent["payload"]
	assert_eq(String(payload["attacker"]), "u_001")
	# Raw response surfaced under data.raw — no decoding.
	var raw: Dictionary = result["data"]["raw"]
	assert_eq(int(raw["result"]), 42)


func test_run_empty_script_name_fails_fast_without_network() -> void:
	watch_signals(_lua)

	var result: Dictionary = await _lua.run("", {})

	assert_false(result.get("success", true))
	# upstream parity: BattleScript.cs:55 exact error string.
	assert_eq(String(result["error"]), "Script name is empty!")
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_lua, "run_failed")


func test_run_failed_propagates_server_error_and_emits_run_failed() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "script_error", "data": null})
	watch_signals(_lua)

	var result: Dictionary = await _lua.run("damage_calc", {})

	assert_false(result.get("success", true))
	assert_signal_emitted(_lua, "run_failed")
	assert_signal_emitted_with_parameters(_lua, "run_failed", ["damage_calc", "script_error"])


# =========================================================================
# Cache helpers
# =========================================================================


func test_get_script_by_name_finds_cached_entry_and_clear_scripts_resets() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				[_make_record(SCRIPT_ID, SCRIPT_NAME), _make_record("ls_002", "battle_end")],
			}
		)
	)
	await _lua.list()

	var found: Variant = _lua.get_script_by_name(SCRIPT_NAME)
	assert_true(found is Dictionary)
	assert_eq(String((found as Dictionary)["id"]), SCRIPT_ID)
	assert_null(_lua.get_script_by_name("does_not_exist"))
	assert_true(_lua.has_scripts())

	_lua.clear_scripts()
	assert_false(_lua.has_scripts())
