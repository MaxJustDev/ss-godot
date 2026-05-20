## PlayerEvent - telemetry / analytics event sink.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/6_Journey/PlayerEvent.cs:19`
## (upstream v0.2.40d).
##
## Sole endpoint: `POST /api/v1/games/{game_id}/events` — the body is a
## hand-built JSON object where `event_data` is dynamic JSON embedded raw
## (see endpoints.md `## Journey`).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals (CLAUDE.md B.4, B.5).
##   - Upstream tracks a per-login `sessionId` (regenerated on every
##     `OnLoginSuccess`, cleared on `OnLogoutSuccess`). We port that wiring
##     by subscribing to `SaiServer.token_refreshed` (login persists a token
##     via `set_login_data` → `token_refreshed` fires) and to `SaiAuth`'s
##     `logout_success` when an auth sibling is reachable. Callers can
##     override the session id explicitly via `set_session_id` or by passing
##     `session_id` in the per-call payload key.
##   - Upstream `TrackEvent` is exposed here as `emit_event`. A new
##     `emit_batch` helper iterates a list of `{type, payload}` dicts and
##     fires `emit_event` per entry — there is no batch endpoint upstream,
##     so this is a thin client-side loop (NOT a wire-level batch).
##   - `PlayerEvent.cs:128-132` builds the JSON by hand to keep `event_data`
##     raw. In GDScript `JSON.stringify` already embeds nested Dictionaries
##     verbatim, so we pass a normal Dictionary body to `post_request`.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.journey` (or `SaiServer.player_event`) from app code.
##
## upstream: 6_Journey/PlayerEvent.cs:19
class_name PlayerEvent
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: PlayerEvent.cs:126
const PATH_EVENTS := "/api/v1/games/{game_id}/events"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `emit_event()`. `event_type` mirrors the type passed
## in by the caller; `response` is the typed `EventData` parsed from the
## server reply (carries `event_id` + `message`).
## upstream: PlayerEvent.cs:22 (OnTrackEventSuccess)
signal event_emitted(event_type: String, response: EventData)

## Emitted on any failure path — pre-flight (no SaiServer / not authenticated
## / empty game_id) or wire-level (network / non-2xx).
## upstream: PlayerEvent.cs:23 (OnTrackEventFailure)
signal event_failed(event_type: String, error: String)

## Emitted whenever the in-memory session id changes (login regeneration,
## logout clear, or explicit `set_session_id`). Lets analytics overlays
## display the current session without polling.
## upstream: PlayerEvent.cs:66 (HandleLoginSuccess sets sessionId)
signal session_id_changed(session_id: String)

# -------------------------------------------------------------------------
# State
# -------------------------------------------------------------------------

## Current session id. Regenerated on every login, cleared on logout, or
## set manually via `set_session_id` / `regenerate_session_id`.
## upstream: PlayerEvent.cs:25 (sessionId field)
var _session_id: String = ""

# Cached references to the parent SaiServer + sibling SaiAuth so we can
# (un)subscribe cleanly in `_exit_tree`.
var _server_ref: Node = null
var _auth_ref: Node = null

# =========================================================================
# Lifecycle
# =========================================================================


func _ready() -> void:
	# Wire up login / logout listeners so session id behaves like upstream.
	# upstream: PlayerEvent.cs:33-52 (LoadComponents -> RegisterLoginListener
	# + RegisterLogoutListener).
	_server_ref = _server()
	if _server_ref != null and _server_ref.has_signal("token_refreshed"):
		_server_ref.token_refreshed.connect(_on_token_refreshed)
	_auth_ref = _sibling_auth()
	if _auth_ref != null and _auth_ref.has_signal("logout_success"):
		_auth_ref.logout_success.connect(_on_logout_success)


func _exit_tree() -> void:
	# upstream: PlayerEvent.cs:54-61 (OnDestroy unsubscribes).
	if _server_ref != null and _server_ref.has_signal("token_refreshed"):
		if _server_ref.token_refreshed.is_connected(_on_token_refreshed):
			_server_ref.token_refreshed.disconnect(_on_token_refreshed)
	if _auth_ref != null and _auth_ref.has_signal("logout_success"):
		if _auth_ref.logout_success.is_connected(_on_logout_success):
			_auth_ref.logout_success.disconnect(_on_logout_success)


# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/events
##
## `event_type` is a free-form tag (e.g. `"tutorial_step_completed"`).
## `payload` is embedded raw as the `event_data` field — server stores it
## verbatim (endpoints.md `## Journey`, PlayerEvent.cs:128-132).
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `response`: EventData (typed `{event_id, message, ...}`)
##   - `event_type`: String (echoes the input for fire-and-forget callers)
##   - `session_id`: String (the id used for this call — useful when a
##     fallback id was generated)
##   - `raw`: original Dictionary as returned by the server.
##
## upstream: PlayerEvent.cs:85 (TrackEvent), PlayerEvent.cs:118 (TrackEventCoroutine)
func emit_event(event_type: String, payload: Dictionary) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		event_failed.emit(event_type, err)
		return _envelope_fail(err)

	# upstream: PlayerEvent.cs:101-105 — refuse before sending when not
	# authenticated. SaiServer also fails fast in `_send` when `auth=true` +
	# no token, but checking here lets us emit `event_failed` with the
	# upstream-parity error string.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		event_failed.emit(event_type, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		event_failed.emit(event_type, err)
		return _envelope_fail(err)

	# upstream: PlayerEvent.cs:109-113 — fall back to a fresh GUID when the
	# stored session id is empty (no login fired, or test harness skipped it).
	var session_id: String = _session_id
	if session_id.is_empty():
		session_id = _new_uuid()

	var path: String = PATH_EVENTS.replace("{game_id}", game_id)
	# upstream: PlayerEvent.cs:128-132 builds the JSON by hand so event_data
	# is embedded raw. `JSON.stringify` on a Dictionary already preserves
	# nested objects verbatim, so a plain Dictionary body is correct here.
	var body: Dictionary = {
		"event_type": event_type,
		"session_id": session_id,
		"event_data": payload if payload != null else {},
	}
	var result: Dictionary = await server.post_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "track event failed"))
		event_failed.emit(event_type, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var response: EventData = EventData.from_dict(raw)
	event_emitted.emit(event_type, response)

	var out := result.duplicate(true)
	out["data"] = {
		"response": response,
		"event_type": event_type,
		"session_id": session_id,
		"raw": raw,
	}
	return out


## Convenience wrapper — iterates a list of `{type: String, payload: Dictionary}`
## entries and fires `emit_event` for each. Returns the standard envelope
## where `data` is `{count, results: Array[Dictionary], failures: int}`.
##
## NOTE: there is no batch endpoint upstream — this is a thin client-side
## loop, NOT a wire-level batch. Each entry is one HTTP POST.
##
## Each entry must carry at minimum a `type` key (String); `payload` defaults
## to an empty Dictionary if omitted. Unknown keys are ignored.
func emit_batch(events: Array[Dictionary]) -> Dictionary:
	if events.is_empty():
		return {
			"success": true,
			"status": 0,
			"error": "",
			"data": {"count": 0, "results": [], "failures": 0},
		}

	var results: Array[Dictionary] = []
	var failures: int = 0
	for entry in events:
		var event_type: String = String(entry.get("type", ""))
		var payload_variant: Variant = entry.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		var r: Dictionary = await emit_event(event_type, payload)
		results.append(r)
		if not r.get("success", false):
			failures += 1

	return {
		"success": failures == 0,
		"status": 0,
		"error": "" if failures == 0 else "%d of %d events failed" % [failures, events.size()],
		"data":
		{
			"count": events.size(),
			"results": results,
			"failures": failures,
		},
	}


## Read accessor for the current session id.
## upstream: PlayerEvent.cs:183 (GetSessionId)
func get_session_id() -> String:
	return _session_id


## Replace the current session id and emit `session_id_changed`.
## upstream: PlayerEvent.cs:179 (SetSessionId)
func set_session_id(id: String) -> void:
	_session_id = id
	session_id_changed.emit(_session_id)


## Force-regenerate a fresh session id. Use after a logical "act break"
## (e.g. user finishes a tutorial) when you want subsequent events grouped
## under a new id without going through a real login.
## upstream: PlayerEvent.cs:169 (RegenerateSessionId)
func regenerate_session_id() -> void:
	_session_id = _new_uuid()
	session_id_changed.emit(_session_id)


# =========================================================================
# Internals
# =========================================================================


## Login signal handler — mirrors `HandleLoginSuccess` (PlayerEvent.cs:63-70).
## SaiServer fires `token_refreshed(access_token)` whenever `set_login_data`
## (login / refresh / manual set) lands a new access token; we treat any
## non-empty access token as a "fresh login" and rotate the session id.
func _on_token_refreshed(access_token: String) -> void:
	if access_token.is_empty():
		return
	_session_id = _new_uuid()
	session_id_changed.emit(_session_id)


## Logout handler — mirrors `HandleLogoutSuccess` (PlayerEvent.cs:72-78).
func _on_logout_success() -> void:
	_session_id = ""
	session_id_changed.emit(_session_id)


## Generates a UUIDv4-ish string. GDScript ships no built-in `Guid.NewGuid`
## equivalent, so we synthesise one from `randi()` — sufficient for client-
## side correlation (server is the source of truth for `event_id`).
## upstream: PlayerEvent.cs:66 (Guid.NewGuid().ToString())
func _new_uuid() -> String:
	# 8-4-4-4-12 hex layout with version=4 nibble + RFC 4122 variant bits.
	var b: PackedByteArray = PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = randi() & 0xFF
	# Version 4 (random): set the high nibble of byte 6 to 0x4.
	b[6] = (b[6] & 0x0F) | 0x40
	# RFC 4122 variant: top two bits of byte 8 are 10.
	b[8] = (b[8] & 0x3F) | 0x80
	var hex: String = b.hex_encode()
	return (
		"%s-%s-%s-%s-%s"
		% [
			hex.substr(0, 8),
			hex.substr(8, 4),
			hex.substr(12, 4),
			hex.substr(16, 4),
			hex.substr(20, 12),
		]
	)


func _server() -> Node:
	# Mirrors SaiAuth._server: prefer parent, fall back to autoload, then to
	# the scene tree — keeps the class testable under a fake-parent harness.
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


## Locate a sibling `SaiAuth` node (added as a child of the same SaiServer).
## Returns null if not present — tests routinely skip the auth sibling.
func _sibling_auth() -> Node:
	var server: Node = _server()
	if server == null:
		return null
	# Prefer the typed accessor when it exists (real SaiServer).
	if "auth" in server:
		var typed: Variant = server.auth
		if typed is Node:
			return typed
	# Fall back to the documented child name.
	if server.has_node("SaiAuth"):
		return server.get_node("SaiAuth")
	return null


func _game_id(server: Node) -> String:
	if server.has_method("normalized_game_id"):
		return String(server.normalized_game_id())
	if "game_id" in server:
		return String(server.game_id).strip_edges()
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
