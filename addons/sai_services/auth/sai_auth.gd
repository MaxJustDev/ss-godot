## SaiAuth - registration / login / refresh / logout / get_me wrapper.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:8` (v0.2.40d).
##
## Translation notes:
##   - Unity uses callback pairs `Action<T> onSuccess, Action<string> onError`.
##     We swap those for the project-standard pattern:
##       * `await` on the method returns `{success, status, error, data}`.
##       * Signals fire in parallel for fire-and-forget subscribers.
##   - Auto-refresh / token-expiration polling is intentionally NOT ported in M2
##     (TODO M3+: drive expiry via `SaiServer.token_refreshed` + a Timer).
##   - The 401 -> auth_required signal lives on SaiServer (see `_send`),
##     so SaiAuth itself does not re-listen for it.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.auth` from app code.
##
## upstream: 0_Auth/SaiAuth.cs:8
class_name SaiAuth
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

const PATH_REGISTER := "/api/v1/auth/register"
const PATH_LOGIN := "/api/v1/auth/login"
const PATH_REFRESH := "/api/v1/auth/refresh"
const PATH_LOGOUT := "/api/v1/auth/logout"
const PATH_ME := "/api/v1/auth/me"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## `user` is the raw `UserData` dictionary as returned by the server.
## upstream: SaiAuth.cs:11 (OnLoginSuccess)
signal login_success(user: Dictionary)
## upstream: SaiAuth.cs:12 (OnLoginFailure)
signal login_failed(error: String)

## upstream: SaiAuth.cs:13 (OnRegisterSuccess)
signal register_success(user: Dictionary)
## upstream: SaiAuth.cs:14 (OnRegisterFailure)
signal register_failed(error: String)

## upstream: SaiAuth.cs:19 (OnLogoutSuccess)
signal logout_success
## upstream: SaiAuth.cs:20 (OnLogoutFailure)
signal logout_failed(error: String)

## Tokens have been rotated (access + refresh). SaiServer also emits
## `token_refreshed` via `set_login_data` — subscribe to whichever is more
## convenient.
## upstream: SaiAuth.cs:15 (OnRefreshTokenSuccess)
signal refresh_success
## upstream: SaiAuth.cs:16 (OnRefreshTokenFailure)
signal refresh_failed(error: String)

## Emitted after a successful `get_me()` returns a fresh profile.
## upstream: SaiAuth.cs:17 (OnGetProfileSuccess)
signal me_loaded(user: Dictionary)

# -------------------------------------------------------------------------
# State (cached last-known user; tokens live on SaiServer)
# -------------------------------------------------------------------------

## Last user object returned by login / get_me / refresh. Empty dict if
## never loaded. Tokens themselves are NOT mirrored here — single source of
## truth is `SaiServer.access_token()`.
## upstream: SaiAuth.cs:27 (userData)
var current_user: Dictionary = {}

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/auth/register
##
## Returns `{success, status, error, data}` where `data` is the server's
## RegisterResponse — usually `{user: {...}}`. No tokens are issued; caller
## must call `login()` next.
##
## upstream: SaiAuth.cs:153 (Register), SaiAuth.cs:171 (RegisterCoroutine)
func register(email: String, username: String, password: String) -> Dictionary:
	var body: Dictionary = {
		"email": _normalize(email),
		"username": username,
		"password": _normalize(password),
	}
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		register_failed.emit(err)
		return _envelope_fail(err)

	var result: Dictionary = await server.post_request(PATH_REGISTER, body, false)
	if result.get("success", false):
		var user: Dictionary = _extract_user(result.get("data", {}))
		register_success.emit(user)
		return result

	var error_msg: String = String(result.get("error", "register failed"))
	register_failed.emit(error_msg)
	return result


## POST /api/v1/auth/login
##
## On success, stores tokens via `SaiServer.set_login_data` (which also
## persists to disk and fires `SaiServer.token_refreshed`).
##
## upstream: SaiAuth.cs:216 (Login), SaiAuth.cs:232 (LoginCoroutine)
func login(username: String, password: String) -> Dictionary:
	var body: Dictionary = {
		"username": _normalize(username),
		"password": _normalize(password),
	}
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		login_failed.emit(err)
		return _envelope_fail(err)

	var result: Dictionary = await server.post_request(PATH_LOGIN, body, false)
	if result.get("success", false):
		var data: Variant = result.get("data", null)
		if data is Dictionary:
			_apply_login_payload(data)
			var user: Dictionary = _extract_user(data)
			login_success.emit(user)
		else:
			# Server returned 2xx but payload not a JSON object — treat as failure.
			var msg := "login response not a JSON object"
			login_failed.emit(msg)
			return _envelope_fail(msg, 200, data)
		return result

	var error_msg: String = String(result.get("error", "login failed"))
	login_failed.emit(error_msg)
	return result


## POST /api/v1/auth/refresh
##
## Uses the stored refresh token from `SaiServer.refresh_token()`. On success,
## both tokens are replaced via `set_login_data` (server may rotate refresh).
##
## upstream: SaiAuth.cs:287 (RefreshAuthToken), SaiAuth.cs:306 (RefreshTokenCoroutine)
func refresh() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		refresh_failed.emit(err)
		return _envelope_fail(err)

	var refresh_token: String = server.refresh_token()
	if refresh_token.is_empty():
		# upstream: SaiAuth.cs:297-301 — guard against missing refresh token.
		var err := "No refresh token available! Please login first."
		refresh_failed.emit(err)
		return _envelope_fail(err)

	var body: Dictionary = {"refresh_token": refresh_token}
	var result: Dictionary = await server.post_request(PATH_REFRESH, body, false)
	if result.get("success", false):
		var data: Variant = result.get("data", null)
		if data is Dictionary:
			_apply_login_payload(data)
			refresh_success.emit()
		else:
			var msg := "refresh response not a JSON object"
			refresh_failed.emit(msg)
			return _envelope_fail(msg, 200, data)
		return result

	var error_msg: String = String(result.get("error", "refresh failed"))
	refresh_failed.emit(error_msg)
	return result


## POST /api/v1/auth/logout
##
## Always clears local tokens, even if the server call fails (matches
## upstream behaviour at SaiAuth.cs:388-393 — "even if server logout fails,
## clear local data").
##
## upstream: SaiAuth.cs:370 (Logout), SaiAuth.cs:377 (LogoutCoroutine)
func logout() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		logout_failed.emit(err)
		return _envelope_fail(err)

	# Upstream skips the network call entirely when not authenticated and
	# fires success — preserve that branch (SaiAuth.cs:396-401).
	if not server.is_authenticated():
		current_user = {}
		logout_success.emit()
		return {"success": true, "status": 0, "error": "", "data": null}

	var result: Dictionary = await server.post_request(PATH_LOGOUT, {}, true)
	# Always wipe tokens, regardless of result.
	server.clear_tokens()
	current_user = {}

	if result.get("success", false):
		logout_success.emit()
	else:
		# upstream: SaiAuth.cs:391 — failure path still clears, but emits failed.
		logout_failed.emit(String(result.get("error", "logout failed")))
	return result


## GET /api/v1/auth/me
##
## Requires an active access token. Returns `{success, status, error, data}`
## where `data` is `{user: {...}}` per endpoints.md.
##
## upstream: SaiAuth.cs:420 (GetMyProfile), SaiAuth.cs:433 (GetMyProfileCoroutine)
func get_me() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: SaiAuth.cs:424-428 — refuse before sending.
		return _envelope_fail("Not authenticated! Please login first.")

	var result: Dictionary = await server.get_request(PATH_ME, {}, true)
	if result.get("success", false):
		var user: Dictionary = _extract_user(result.get("data", {}))
		current_user = user
		me_loaded.emit(user)
	return result


## Returns the cached profile (from the last successful login / get_me /
## refresh). Empty Dictionary if never loaded.
func get_current_user() -> Dictionary:
	return current_user


## True iff `SaiServer` has an access token. Delegates to SaiServer to keep
## a single source of truth.
## upstream: SaiAuth.cs:44 (IsAuthenticated)
func is_authenticated() -> bool:
	var server: Node = _server()
	if server == null:
		return false
	return server.is_authenticated()


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Sub-services live as direct children of the SaiServer autoload node,
	# so the parent IS the server. We use this indirection (rather than the
	# global `SaiServer`) so the class is also instantiable in unit tests
	# under a fake-parent harness.
	# upstream: equivalent of `SaiServer.Instance` lookup in SaiAuth.cs
	var parent: Node = get_parent()
	if parent != null and parent.has_method("post_request"):
		return parent
	# Autoload fallback (handles cases where SaiAuth was not added as a child).
	if Engine.has_singleton("SaiServer"):
		return Engine.get_singleton("SaiServer")
	# Tree-based fallback for tests where the autoload is reachable via the
	# scene tree but not via Engine.get_singleton.
	if is_inside_tree():
		var node: Node = get_tree().root.get_node_or_null("SaiServer")
		if node != null:
			return node
	return null


## upstream: SaiAuth.cs:50 (NormalizeInput)
func _normalize(value: String) -> String:
	return value.strip_edges() if value != null else ""


## Apply a LoginResponse-shaped payload: persist tokens, cache user.
## upstream: SaiAuth.cs:249-256 (token + user assignment)
func _apply_login_payload(data: Dictionary) -> void:
	var access: String = String(data.get("access_token", ""))
	var refresh_str: String = String(data.get("refresh_token", ""))
	var expires: int = int(data.get("expires_in", 0))
	current_user = _extract_user(data)
	var server: Node = _server()
	if server != null and not access.is_empty():
		server.set_login_data(access, refresh_str, expires)


func _extract_user(data: Variant) -> Dictionary:
	if data is Dictionary:
		var dict: Dictionary = data
		var user: Variant = dict.get("user", null)
		if user is Dictionary:
			return user
		# Some endpoints (notably register) return the bare user fields
		# without a wrapper. Treat any dict carrying an "id" or "username"
		# as a user record.
		if dict.has("id") or dict.has("username"):
			return dict
	return {}


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
