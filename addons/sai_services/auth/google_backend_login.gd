## GoogleBackendLogin - 2-step polling Google OAuth flow.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/0_Auth/Google/GoogleBackendLogin.cs:9`.
##
## Flow (matches upstream + endpoints.md "Notes / non-obvious behavior" §
## "Google login is a two-step polling flow"):
##   1. POST /api/v1/client/auth/google/session  -> session_id + auth_url + poll_interval_seconds + expires_at
##   2. Open `auth_url` in the system browser (OS.shell_open).
##   3. GET  /api/v1/client/auth/google/session/{session_id}  every poll_interval_seconds
##      until `status` becomes one of: completed | denied | expired | error.
##   4. On `completed`, the GET response includes full LoginResponse fields
##      (user, access_token, refresh_token, expires_in) — store via
##      `SaiServer.set_login_data` and emit `login_success(user)`.
##
## Translation notes:
##   - Unity coroutines (`StartCoroutine` + `WaitForSeconds`) become GDScript
##     `await get_tree().create_timer(...).timeout`.
##   - `Application.OpenURL(...)` becomes `OS.shell_open(...)`.
##   - `SystemInfo.deviceUniqueIdentifier` -> `OS.get_unique_id()` (caller may
##     also pass an explicit fingerprint to `start_session()`).
##   - Cancellation uses a bool flag (`_poll_cancelled`) rather than coroutine
##     stop, since GDScript can't forcibly abort an `await`.
##
## upstream: 0_Auth/Google/GoogleBackendLogin.cs:9
class_name GoogleBackendLogin
extends Node

# -------------------------------------------------------------------------
# Endpoints
# -------------------------------------------------------------------------

## POST to create, GET `/<session_id>` to poll.
## upstream: GoogleBackendLogin.cs:34
const PATH_SESSION := "/api/v1/client/auth/google/session"

## Status values returned by the poll endpoint.
## upstream: GoogleBackendLogin.cs:173-194
const STATUS_PENDING := "pending"
const STATUS_COMPLETED := "completed"
const STATUS_DENIED := "denied"
const STATUS_EXPIRED := "expired"
const STATUS_ERROR := "error"

## Fallback poll interval when server omits `poll_interval_seconds`.
## upstream: GoogleBackendLogin.cs:32 (defaultPollIntervalSeconds)
const DEFAULT_POLL_INTERVAL_SECONDS := 2

## Hard upper bound on the entire flow. Mirrors upstream
## `maxLoginDurationSeconds`.
## upstream: GoogleBackendLogin.cs:29
const MAX_LOGIN_DURATION_SECONDS := 300

# -------------------------------------------------------------------------
# Inspector
# -------------------------------------------------------------------------

@export_group("Behaviour")
## Open `auth_url` automatically with `OS.shell_open()`. Disable to drive
## the URL manually (e.g. embedded WebView, in-app browser, or test mode).
@export var auto_open_browser: bool = true

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Fired right after the POST returns. UI can display `auth_url` as a QR or
## copy-paste link if the system browser failed to open.
signal session_started(auth_url: String, expires_at: int)

## Fired once polling resolves to `completed`. `user` is the raw dict from
## the server. Tokens are already stored on `SaiServer` by the time this
## fires. Mirrors `SaiAuth.login_success` so callers can subscribe to one
## or the other.
signal login_success(user: Dictionary)

## Fired on denied / expired / error / timeout / cancelled.
signal login_failed(error: String)

## Fired on every poll tick with the current status string (incl. transient
## errors prefixed `poll_error:` for visibility).
signal poll_tick(status: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

var _session: GoogleSession = null
var _poll_cancelled: bool = false
var _poll_running: bool = false

# =========================================================================
# Public API
# =========================================================================


## True while a polling loop is active.
func is_polling() -> bool:
	return _poll_running


## Current session metadata or null if no active session.
func current_session() -> GoogleSession:
	return _session


## Step 1: POST `/api/v1/client/auth/google/session`.
##
## `platform` should be a short tag like `"windows"`, `"android"`, `"web"` —
## upstream sends `Application.platform.ToString()`.
## `client_fingerprint` defaults to `OS.get_unique_id()` if empty.
##
## Returns the raw envelope. The session is also cached on this node and
## emitted via `session_started`.
##
## upstream: GoogleBackendLogin.cs:121 (CreateSessionCoroutine)
func start_session(platform: String, client_fingerprint: String = "") -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		login_failed.emit(err)
		return _envelope_fail(err)

	var fingerprint: String = (
		client_fingerprint if not client_fingerprint.is_empty() else OS.get_unique_id()
	)
	var body: Dictionary = {
		# upstream: GoogleBackendLogin.cs:123-128 — game_id pulled from SaiServer.
		"game_id": server.normalized_game_id(),
		"platform": platform,
		"client_fingerprint": fingerprint,
	}

	var result: Dictionary = await server.post_request(PATH_SESSION, body, false)
	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "create_session_failed"))
		login_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	if not (data is Dictionary):
		var err := "create_session_failed: empty response"
		login_failed.emit(err)
		return _envelope_fail(err, int(result.get("status", 0)), data)

	_session = GoogleSession.from_create_dict(data)
	if _session.session_id.is_empty():
		var err := "create_session_failed: missing session_id"
		login_failed.emit(err)
		return _envelope_fail(err, int(result.get("status", 0)), data)

	session_started.emit(_session.auth_url, _session.expires_at)

	if auto_open_browser and not _session.auth_url.is_empty():
		# upstream: GoogleBackendLogin.cs:115 — Application.OpenURL.
		OS.shell_open(_session.auth_url)

	# Kick off polling in the background — caller awaits start_session only,
	# then listens for `login_success` / `login_failed`.
	_start_poll_loop()
	return result


## Cancel an in-flight polling loop. Safe to call when nothing is running.
##
## upstream: GoogleBackendLogin.cs:79 (CancelLogin)
func cancel_poll() -> void:
	if not _poll_running:
		return
	_poll_cancelled = true
	# `login_failed` is emitted from inside the poll loop once it observes
	# the cancellation flag (avoids emitting twice if it happened to be in
	# flight already).


# =========================================================================
# Internals
# =========================================================================


func _start_poll_loop() -> void:
	if _poll_running:
		return
	_poll_cancelled = false
	_poll_running = true
	# Fire-and-forget — caller does not await this.
	_poll_loop()


func _poll_loop() -> void:
	# Compute deadlines. Prefer the server-supplied `expires_at` when in the
	# future, otherwise fall back to MAX_LOGIN_DURATION_SECONDS.
	# upstream: GoogleBackendLogin.cs:154 (deadline)
	var now: int = int(Time.get_unix_time_from_system())
	var server_deadline: int = _session.expires_at if _session != null else 0
	var fallback_deadline: int = now + MAX_LOGIN_DURATION_SECONDS
	var deadline: int = server_deadline if server_deadline > now else fallback_deadline

	var interval: int = DEFAULT_POLL_INTERVAL_SECONDS
	if _session != null and _session.poll_interval_seconds > 0:
		interval = _session.poll_interval_seconds
	interval = max(1, interval)

	while not _poll_cancelled:
		if int(Time.get_unix_time_from_system()) >= deadline:
			_fail_login("session_expired")
			return

		# upstream: GoogleBackendLogin.cs:160 (yield return new WaitForSeconds)
		await get_tree().create_timer(float(interval)).timeout
		if _poll_cancelled:
			break

		var poll_result: Dictionary = await _poll_once()
		if _poll_cancelled:
			break

		if not poll_result.get("success", false):
			# Transient — keep polling. upstream: GoogleBackendLogin.cs:166-171.
			poll_tick.emit("poll_error:" + String(poll_result.get("error", "")))
			continue

		var data: Variant = poll_result.get("data", null)
		if not (data is Dictionary):
			poll_tick.emit("poll_error:not_a_dict")
			continue

		var status: String = String(data.get("status", STATUS_PENDING))
		if _session != null:
			_session.merge_poll_dict(data)
		poll_tick.emit(status)

		match status:
			STATUS_COMPLETED:
				_succeed_login(data)
				return
			STATUS_DENIED:
				_fail_login("user_denied:" + String(data.get("error", "")))
				return
			STATUS_EXPIRED:
				_fail_login("session_expired")
				return
			STATUS_ERROR:
				_fail_login("server_error:" + String(data.get("error", "")))
				return
			_:
				# pending / unknown -> keep polling.
				pass

	if _poll_cancelled:
		_fail_login("cancelled")


func _poll_once() -> Dictionary:
	var server: Node = _server()
	if server == null:
		return _envelope_fail("SaiServer not found")
	if _session == null or _session.session_id.is_empty():
		return _envelope_fail("no active session")
	# upstream: GoogleBackendLogin.cs:202 (UnityWebRequest.EscapeURL).
	var endpoint: String = PATH_SESSION + "/" + _session.session_id.uri_encode()
	return await server.get_request(endpoint, {}, false)


## upstream: GoogleBackendLogin.cs:224 (SucceedLogin)
func _succeed_login(data: Dictionary) -> void:
	var access: String = String(data.get("access_token", ""))
	var refresh: String = String(data.get("refresh_token", ""))
	var expires: int = int(data.get("expires_in", 0))
	var user: Dictionary = {}
	var raw_user: Variant = data.get("user", null)
	if raw_user is Dictionary:
		user = raw_user

	var server: Node = _server()
	if server != null and not access.is_empty():
		# upstream: GoogleBackendLogin.cs:293 (SetLoginData).
		server.set_login_data(access, refresh, expires)

	_reset_session_state()
	login_success.emit(user)


## upstream: GoogleBackendLogin.cs:250 (FailLogin)
func _fail_login(reason: String) -> void:
	_reset_session_state()
	login_failed.emit(reason)


## upstream: GoogleBackendLogin.cs:260 (ResetSessionState)
func _reset_session_state() -> void:
	_poll_running = false
	_poll_cancelled = false
	_session = null


func _server() -> Node:
	# Same lookup strategy as SaiAuth — see sai_auth.gd `_server()`.
	var parent: Node = get_parent()
	if parent != null and parent.has_method("post_request"):
		return parent
	if Engine.has_singleton("SaiServer"):
		return Engine.get_singleton("SaiServer")
	if is_inside_tree():
		var node: Node = get_tree().root.get_node_or_null("SaiServer")
		if node != null:
			return node
	return null


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
