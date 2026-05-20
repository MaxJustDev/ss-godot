## BattleSessions - list battle sessions wrapper + reserved lifecycle stubs.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/8_Battle/BattleSessions.cs:8`
## (upstream v0.2.40d).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals so fire-and-forget subscribers still work
##     (CLAUDE.md B.4, B.5).
##   - Upstream exposes ONE endpoint here:
##     `GET /api/v1/games/{game_id}/me/battle-sessions?limit=&offset=`
##     (BattleSessions.cs:87-123). We mirror it as `list_sessions(limit, offset)`.
##   - `create_session(data)`, `send_event(session_id, type, payload)`, and
##     `finish_session(session_id, result)` appear in
##     `docs/examples/battle_session.md` as the documented client-facing
##     lifecycle, but upstream v0.2.40d has no matching wire endpoints (see
##     `docs/endpoints.md` `## Battle` — only the two endpoints listed).
##     We expose them as stubs that return a `not_implemented` envelope and
##     fire the matching `*_failed` signal, mirroring how `Shop.history()`
##     reserves its API surface for a future backend endpoint (shop.gd:300).
##   - Upstream's auto-load-on-login behaviour
##     (BattleSessions.cs:56-75 — `HandleLoginSuccess`) is intentionally NOT
##     ported here. It tangles with M2 auth signals and is better driven by
##     app code; the `autoLoadOnLogin` flag in upstream defaults to `false`
##     (BattleSessions.cs:14), so parity with the default is preserved.
##   - The `clear_sessions()` / `get_session_by_id()` / `has_sessions()`
##     client-side cache helpers from upstream
##     (BattleSessions.cs:161-201) are ported verbatim so callers can stay
##     in parity with Unity.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.battle` (alias) or `SaiServer.battle_sessions` from app
##     code — both point at this instance.
##
## upstream: 8_Battle/BattleSessions.cs:8
class_name BattleSessions
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: BattleSessions.cs:123
const PATH_LIST_SESSIONS := "/api/v1/games/{game_id}/me/battle-sessions"

# -------------------------------------------------------------------------
# Defaults (mirror upstream Inspector fields)
# -------------------------------------------------------------------------

## upstream: BattleSessions.cs:20 (sessionLimit)
const DEFAULT_LIMIT := 50

## upstream: BattleSessions.cs:21 (sessionOffset)
const DEFAULT_OFFSET := 0

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `list_sessions()`. `sessions` is `Array[BattleData]`,
## `total` mirrors the server-reported count.
## upstream: BattleSessions.cs:10 (OnGetSessionsSuccess)
signal sessions_loaded(sessions: Array, total: int)
## upstream: BattleSessions.cs:11 (OnGetSessionsFailure)
signal sessions_failed(error: String)

## Reserved for the (currently-unimplemented) create-session endpoint.
## See `create_session()` for the deferred TODO.
signal session_created(session_id: String)
signal session_create_failed(error: String)

## Reserved for the (currently-unimplemented) send-event endpoint.
signal event_sent(session_id: String, event_type: String)
signal event_failed(session_id: String, event_type: String, error: String)

## Reserved for the (currently-unimplemented) finish-session endpoint.
signal session_finished(session_id: String, summary: Dictionary)
signal session_finish_failed(session_id: String, error: String)

# -------------------------------------------------------------------------
# Cached state (mirrors upstream's `currentSessions`)
# -------------------------------------------------------------------------

## Last sessions list returned by `list_sessions()`. Empty until first call.
## upstream: BattleSessions.cs:17 (currentSessions.sessions)
var cached_sessions: Array[BattleData] = []

## Server-reported total from the last `list_sessions()`.
## upstream: BattleSessions.cs:17 (currentSessions.total)
var cached_sessions_total: int = 0

## Server-echoed limit from the last `list_sessions()`.
var cached_sessions_limit: int = DEFAULT_LIMIT

## Server-echoed offset from the last `list_sessions()`.
var cached_sessions_offset: int = DEFAULT_OFFSET

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/me/battle-sessions?limit=&offset=
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `sessions`: Array[BattleData]
##   - `total`: int
##   - `limit`: int
##   - `offset`: int
##   - `raw`: original Dictionary as returned by the server.
##
## upstream: BattleSessions.cs:89 (GetSessions),
##           BattleSessions.cs:116 (GetSessionsCoroutine)
func list_sessions(limit: int = DEFAULT_LIMIT, offset: int = DEFAULT_OFFSET) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		sessions_failed.emit(err)
		return _envelope_fail(err)

	# upstream: BattleSessions.cs:104-108 — refuse before sending.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		sessions_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		sessions_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_LIST_SESSIONS.replace("{game_id}", game_id)
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list sessions failed"))
		sessions_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var sessions: Array[BattleData] = []
	var raw_sessions: Variant = raw.get("sessions", null)
	if raw_sessions is Array:
		for entry in raw_sessions as Array:
			sessions.append(BattleData.from_dict(entry))
	var total: int = int(raw.get("total", sessions.size()))
	cached_sessions = sessions
	cached_sessions_total = total
	cached_sessions_limit = int(raw.get("limit", limit))
	cached_sessions_offset = int(raw.get("offset", offset))
	sessions_loaded.emit(sessions, total)

	# Re-wrap so callers get typed access without losing the raw payload.
	var out := result.duplicate(true)
	out["data"] = {
		"sessions": sessions,
		"total": total,
		"limit": cached_sessions_limit,
		"offset": cached_sessions_offset,
		"raw": raw,
	}
	return out


## TODO M6c+: no upstream / backend endpoint for create-session yet.
##
## The example doc `docs/examples/battle_session.md` shows
## `SaiServer.battle.create_session({...})` returning `{data.session_id}`,
## but upstream v0.2.40d has no matching wire endpoint
## (endpoints.md `## Battle` lists only GET sessions + POST script run).
## This method returns a failure envelope and emits `session_create_failed`
## so existing app code can wire the signal now; callers that need a real
## session today should call `run_script("create_session", ...)` against
## a server-side Lua script that mints + persists the id.
func create_session(_data: Dictionary) -> Dictionary:
	var err := "create_session endpoint is not implemented in upstream v0.2.40d"
	session_create_failed.emit(err)
	return _envelope_fail(err)


## TODO M6c+: no upstream / backend endpoint for send-event yet.
##
## Companion to `create_session`. See the TODO there. Callers wanting wire-
## level event ingestion today should use `SaiServer.journey.emit_event` —
## per-battle events ride the same telemetry channel.
func send_event(session_id: String, event_type: String, _payload: Dictionary) -> Dictionary:
	var err := "send_event endpoint is not implemented in upstream v0.2.40d"
	event_failed.emit(session_id, event_type, err)
	return _envelope_fail(err)


## TODO M6c+: no upstream / backend endpoint for finish-session yet.
##
## Companion to `create_session`. See the TODO there. Callers that need a
## summary today should drive it via `run_script("finish_session", ...)`.
func finish_session(session_id: String, _result: Dictionary) -> Dictionary:
	var err := "finish_session endpoint is not implemented in upstream v0.2.40d"
	session_finish_failed.emit(session_id, err)
	return _envelope_fail(err)


# =========================================================================
# Convenience query helpers (operate on `cached_sessions`)
# =========================================================================


## upstream: BattleSessions.cs:183 (GetSessionById)
func get_session_by_id(session_id: String) -> BattleData:
	for s in cached_sessions:
		if s != null and s.id == session_id:
			return s
	return null


## upstream: BattleSessions.cs:161 (ClearSessions)
func clear_sessions() -> void:
	cached_sessions = []
	cached_sessions_total = 0


## True iff `cached_sessions` is non-empty.
## upstream: BattleSessions.cs:24 (HasSessions)
func has_sessions() -> bool:
	return cached_sessions.size() > 0


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirrors SaiAuth._server: prefer parent, fall back to autoload, then to
	# the scene tree — keeps the class testable under a fake-parent harness.
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
