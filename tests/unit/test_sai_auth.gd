## Unit tests for SaiAuth (M2).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 0_Auth/SaiAuth.cs
extends "res://addons/gut/test.gd"

const SAI_AUTH := preload("res://addons/sai_services/auth/sai_auth.gd")

# =========================================================================
# Test double: minimal stand-in for the SaiServer autoload.
# =========================================================================


class FakeSaiServer:
	extends Node

	# Queued canned responses, one per call, in order.
	var _next_responses: Array = []
	# Recorded calls — each entry is `{method, path, body, auth}`.
	var calls: Array = []

	var _access_token: String = ""
	var _refresh_token: String = ""
	var _expires_in: int = 0
	var _game_id: String = "test_game"

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

	func is_authenticated() -> bool:
		return not _access_token.is_empty()

	func access_token() -> String:
		return _access_token

	func refresh_token() -> String:
		return _refresh_token

	func expires_in() -> int:
		return _expires_in

	func set_login_data(access: String, refresh: String, expires: int) -> void:
		_access_token = access
		_refresh_token = refresh
		_expires_in = expires
		token_refreshed.emit(access)

	func clear_tokens() -> void:
		_access_token = ""
		_refresh_token = ""
		_expires_in = 0

	func normalized_game_id() -> String:
		return _game_id


# =========================================================================
# Fixture helpers
# =========================================================================

var _server: FakeSaiServer = null
var _auth: SaiAuth = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_auth = SAI_AUTH.new()
	_auth.name = "SaiAuth"
	_server.add_child(_auth)


# =========================================================================
# Tests
# =========================================================================


func test_login_successful_emits_login_success_and_stores_tokens() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"user": {"id": "u_001", "username": "demo", "email": "demo@example.com"},
					"access_token": "AT_123",
					"refresh_token": "RT_456",
					"expires_in": 3600,
				},
			}
		)
	)
	watch_signals(_auth)

	var result: Dictionary = await _auth.login("demo", "demo")

	assert_true(result.get("success", false), "login should report success")
	assert_eq(_server._access_token, "AT_123", "access token stored on server")
	assert_eq(_server._refresh_token, "RT_456", "refresh token stored on server")
	assert_eq(_server._expires_in, 3600, "expires_in stored on server")
	assert_signal_emitted(_auth, "login_success")
	assert_eq(_server.calls[0]["path"], SaiAuth.PATH_LOGIN)
	assert_eq(_server.calls[0]["body"]["username"], "demo")


func test_login_failed_emits_login_failed_with_error_text() -> void:
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 401,
				"error": "invalid_credentials",
				"data": null,
			}
		)
	)
	watch_signals(_auth)

	var result: Dictionary = await _auth.login("bad", "wrong")

	assert_false(result.get("success", true))
	assert_signal_emitted(_auth, "login_failed")
	assert_signal_emitted_with_parameters(_auth, "login_failed", ["invalid_credentials"])
	assert_true(_server._access_token.is_empty(), "no tokens stored after failed login")


func test_register_success_emits_register_success_no_tokens() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 201,
				"error": "",
				"data": {"user": {"id": "u_002", "username": "alice", "email": "a@a.io"}},
			}
		)
	)
	watch_signals(_auth)

	var result: Dictionary = await _auth.register("a@a.io", "alice", "pw")

	assert_true(result.get("success", false))
	assert_signal_emitted(_auth, "register_success")
	# Register MUST NOT mint tokens — caller has to call login() next.
	assert_true(_server._access_token.is_empty(), "register does not log user in")
	assert_eq(_server.calls[0]["path"], SaiAuth.PATH_REGISTER)


func test_register_failed_emits_register_failed() -> void:
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 409,
				"error": "username_taken",
				"data": null,
			}
		)
	)
	watch_signals(_auth)

	await _auth.register("a@a.io", "demo", "pw")

	assert_signal_emitted(_auth, "register_failed")
	assert_signal_emitted_with_parameters(_auth, "register_failed", ["username_taken"])


func test_logout_clears_tokens_and_emits_logout_success() -> void:
	# Seed tokens first.
	_server.set_login_data("AT_old", "RT_old", 3600)
	_server.queue_response({"success": true, "status": 200, "error": "", "data": {}})
	watch_signals(_auth)

	var result: Dictionary = await _auth.logout()

	assert_true(result.get("success", false))
	assert_true(_server._access_token.is_empty(), "access token cleared")
	assert_true(_server._refresh_token.is_empty(), "refresh token cleared")
	assert_signal_emitted(_auth, "logout_success")
	assert_eq(_server.calls[0]["path"], SaiAuth.PATH_LOGOUT)


func test_logout_when_server_fails_still_clears_tokens() -> void:
	# Upstream parity: SaiAuth.cs:388-393 — clear local data even if server errors.
	_server.set_login_data("AT_old", "RT_old", 3600)
	_server.queue_response({"success": false, "status": 500, "error": "server_down", "data": null})
	watch_signals(_auth)

	await _auth.logout()

	assert_true(_server._access_token.is_empty(), "tokens cleared on failed logout")
	assert_signal_emitted(_auth, "logout_failed")


func test_refresh_updates_token_and_emits_refresh_success() -> void:
	_server.set_login_data("AT_old", "RT_old", 3600)
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"user": {"id": "u_001", "username": "demo"},
					"access_token": "AT_new",
					"refresh_token": "RT_new",
					"expires_in": 7200,
				},
			}
		)
	)
	watch_signals(_auth)

	await _auth.refresh()

	assert_eq(_server._access_token, "AT_new", "access token rotated")
	assert_eq(_server._refresh_token, "RT_new", "refresh token rotated")
	assert_eq(_server._expires_in, 7200)
	assert_signal_emitted(_auth, "refresh_success")
	assert_eq(_server.calls[0]["body"]["refresh_token"], "RT_old", "old refresh sent in body")


func test_refresh_without_token_fails_fast() -> void:
	# No tokens seeded.
	watch_signals(_auth)

	var result: Dictionary = await _auth.refresh()

	assert_false(result.get("success", true))
	assert_signal_emitted(_auth, "refresh_failed")
	assert_eq(_server.calls.size(), 0, "must not hit network when no refresh token")


func test_get_me_returns_user_and_emits_me_loaded() -> void:
	_server.set_login_data("AT", "RT", 3600)
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"user":
					{
						"id": "u_001",
						"username": "demo",
						"email": "demo@example.com",
						"display_name": "Demo",
						"is_active": true,
						"is_verified": true,
						"created_at": 1700000000,
					}
				},
			}
		)
	)
	watch_signals(_auth)

	var result: Dictionary = await _auth.get_me()

	assert_true(result.get("success", false))
	assert_signal_emitted(_auth, "me_loaded")
	assert_eq(_auth.get_current_user()["username"], "demo")
	assert_eq(_server.calls[0]["method"], "GET")
	assert_eq(_server.calls[0]["path"], SaiAuth.PATH_ME)


func test_get_me_without_token_fails_fast() -> void:
	# No tokens seeded.
	var result: Dictionary = await _auth.get_me()
	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "must not hit network when unauthenticated")
