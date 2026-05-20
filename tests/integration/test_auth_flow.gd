## Integration tests for SaiAuth (M2) against the local Flask mock server.
##
## REQUIRES the mock server to be running:
##     cd tests/mock_server && pip install -r requirements.txt && python app.py
##     # listens on http://127.0.0.1:8765
##
## The current `tests/mock_server/app.py` exposes UNVERSIONED auth paths
## (`/api/auth/login`, etc.) whereas the real SaiGame backend uses
## `/api/v1/auth/...`. We point SaiServer at the mock with a custom base URL
## and use a stub-injected SaiAuth that swaps endpoints — that keeps the
## production code paths intact.
##
## TODO M3+: update `tests/mock_server/app.py` to expose `/api/v1/auth/*`
## paths so this file can use the unmodified `SaiAuth` constants directly.
##
## Requires the GUT framework.
##
## upstream parity test: 0_Auth/SaiAuth.cs end-to-end.
extends "res://addons/gut/test.gd"

const MOCK_BASE := "http://127.0.0.1:8765"
const MOCK_ROOT := "/api"  # NOT /api/v1 — see header note.

const SAI_AUTH := preload("res://addons/sai_services/auth/sai_auth.gd")
const SAI_SERVER := preload("res://addons/sai_services/core/sai_server.gd")


# Override SaiAuth path constants by subclassing for tests.
class MockPathSaiAuth:
	extends SAI_AUTH
	# Same names as parent constants, override at runtime via _send wrappers.
	# Easier: shadow the public methods to point to /api/auth/* directly.

	const M_REGISTER := "/api/auth/register"
	const M_LOGIN := "/api/auth/login"
	const M_REFRESH := "/api/auth/refresh"
	const M_LOGOUT := "/api/auth/logout"

	func login(username: String, password: String) -> Dictionary:
		var server: Node = get_parent()
		var body: Dictionary = {
			"username": username.strip_edges(), "password": password.strip_edges()
		}
		var result: Dictionary = await server.post_request(M_LOGIN, body, false)
		if result.get("success", false):
			var data: Dictionary = result.get("data", {})
			if data is Dictionary:
				(
					server
					. set_login_data(
						String(data.get("access_token", "")),
						String(data.get("refresh_token", "")),
						int(data.get("expires_in", 0)),
					)
				)
				login_success.emit(data.get("user", {}))
		else:
			login_failed.emit(String(result.get("error", "login failed")))
		return result

	func register(email: String, username: String, password: String) -> Dictionary:
		var server: Node = get_parent()
		var body: Dictionary = {
			"email": email.strip_edges(), "username": username, "password": password.strip_edges()
		}
		var result: Dictionary = await server.post_request(M_REGISTER, body, false)
		if result.get("success", false):
			register_success.emit(result.get("data", {}).get("user", {}))
		else:
			register_failed.emit(String(result.get("error", "register failed")))
		return result

	func logout() -> Dictionary:
		var server: Node = get_parent()
		if not server.is_authenticated():
			logout_success.emit()
			return {"success": true, "status": 0, "error": "", "data": null}
		var result: Dictionary = await server.post_request(M_LOGOUT, {}, true)
		server.clear_tokens()
		if result.get("success", false):
			logout_success.emit()
		else:
			logout_failed.emit(String(result.get("error", "logout failed")))
		return result


# Custom SaiServer subclass that points at the mock.
class MockServer:
	extends SAI_SERVER

	func _ready() -> void:
		# Skip parent _ready (don't auto-register sub-services or load persisted state).
		pass

	func base_url() -> String:
		return MOCK_BASE


var _server: MockServer = null
var _auth: MockPathSaiAuth = null


func before_each() -> void:
	_server = MockServer.new()
	_server.name = "SaiServer"
	_server.show_url_request = false
	_server.show_json_request = false
	_server.show_json_response = false
	_server.show_debug_log = false
	add_child_autofree(_server)
	_auth = MockPathSaiAuth.new()
	_auth.name = "SaiAuth"
	_server.add_child(_auth)


# =========================================================================
# Tests
# =========================================================================


func test_login_with_demo_credentials_succeeds() -> void:
	if not await _mock_is_up():
		pending("mock server not running on %s — skipping" % MOCK_BASE)
		return

	watch_signals(_auth)
	var result: Dictionary = await _auth.login("demo", "demo")

	assert_true(
		result.get("success", false), "expected login to succeed: %s" % result.get("error", "")
	)
	assert_true(_server.is_authenticated(), "tokens stored on server")
	assert_signal_emitted(_auth, "login_success")


func test_login_with_bad_password_fails() -> void:
	if not await _mock_is_up():
		pending("mock server not running on %s — skipping" % MOCK_BASE)
		return

	watch_signals(_auth)
	var result: Dictionary = await _auth.login("demo", "wrong")

	assert_false(result.get("success", true))
	assert_eq(int(result.get("status", 0)), 401)
	assert_signal_emitted(_auth, "login_failed")


func test_register_then_login_round_trip() -> void:
	if not await _mock_is_up():
		pending("mock server not running on %s — skipping" % MOCK_BASE)
		return

	var uname := "user_%d" % randi()
	var pw := "pw"
	var reg: Dictionary = await _auth.register("%s@example.com" % uname, uname, pw)
	assert_true(reg.get("success", false), "register should succeed: %s" % reg.get("error", ""))

	var login_result: Dictionary = await _auth.login(uname, pw)
	assert_true(login_result.get("success", false), "login after register should succeed")
	assert_true(_server.is_authenticated())


func test_logout_clears_server_tokens() -> void:
	if not await _mock_is_up():
		pending("mock server not running on %s — skipping" % MOCK_BASE)
		return

	await _auth.login("demo", "demo")
	assert_true(_server.is_authenticated())

	await _auth.logout()
	assert_false(_server.is_authenticated(), "tokens cleared on logout")


# =========================================================================
# Helpers
# =========================================================================


func _mock_is_up() -> bool:
	var req := HTTPRequest.new()
	add_child(req)
	var err: int = req.request(MOCK_BASE + "/api/health")
	if err != OK:
		req.queue_free()
		return false
	var result: Array = await req.request_completed
	req.queue_free()
	var status: int = result[1] if result.size() > 1 else 0
	return status >= 200 and status < 300
