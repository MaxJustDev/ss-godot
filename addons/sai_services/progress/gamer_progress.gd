## GamerProgress - create / read / update / delete the player's per-game
## progress record (level, experience, gold, opaque `game_data` JSON).
##
## Port of `ss-unity/Assets/SaiGame/Scripts/1_GamerProgress/GamerProgress.cs:8`.
##
## Translation notes:
##   - Unity uses `event Action<GamerProgressData>` + per-call success/error
##     callbacks. We collapse both into the project-standard pattern:
##       * `await` returns `{success, status, error, data}` where `data` is
##         a `GamerProgressData` Resource on success.
##       * Signals fire in parallel for fire-and-forget subscribers.
##   - Upstream auto-load-on-login + clear-on-logout is intentionally NOT
##     ported (it depended on SaiBehaviour lifecycle hooks). The app layer
##     should subscribe to `SaiServer.auth.login_success` / `logout_success`
##     and call `get_mine()` / clear local state itself.
##   - `ExtractGameDataFromJson` (raw-JSON-preserving substring scan) is
##     skipped: Godot's `JSON.parse_string` keeps the parsed object intact, so
##     `GamerProgressData.from_dict` re-serialises it back to the canonical
##     String form. Net contract for callers is identical.
##   - 401 -> auth_required lives on SaiServer (`_send`), so this node does
##     not listen for it.
##   - This node is added as a child of `SaiServer` during _ready() via
##     `_register_sub_services`. Use `SaiServer.progress` from app code.
##
## upstream: 1_GamerProgress/GamerProgress.cs:8
class_name GamerProgress
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## POST — create initial progress for the current user / game.
## upstream: GamerProgress.cs:240
const PATH_CREATE := "/api/v1/games/{game_id}/gamer-progress"
## GET — load the calling user's progress for the game.
## upstream: GamerProgress.cs:315
const PATH_GET_MINE := "/api/v1/games/{game_id}/my-gamer-progress"
## PATCH — apply experience/gold deltas + replace game_data.
## upstream: GamerProgress.cs:379
const PATH_UPDATE := "/api/v1/gamer-progress/{progress_id}"
## DELETE — wipe the user's progress (server-side reset).
## upstream: GamerProgress.cs:462
const PATH_DELETE_MINE := "/api/v1/games/{game_id}/my-gamer-progress"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: GamerProgress.cs:11 (OnCreateProgressSuccess)
signal create_success(data: Dictionary)
## upstream: GamerProgress.cs:12 (OnCreateProgressFailure)
signal create_failed(error: String)

## upstream: GamerProgress.cs:13 (OnGetProgressSuccess)
signal get_success(data: Dictionary)
## upstream: GamerProgress.cs:14 (OnGetProgressFailure)
signal get_failed(error: String)

## Upstream has no dedicated update signal — UpdateProgress only calls the
## per-call callbacks. We expose explicit signals here for consistency with
## the other CRUD methods.
## upstream: GamerProgress.cs:364 (UpdateProgress callbacks)
signal update_success(data: Dictionary)
signal update_failed(error: String)

## upstream: GamerProgress.cs:15 (OnDeleteProgressSuccess)
signal delete_success
## upstream: GamerProgress.cs:16 (OnDeleteProgressFailure)
signal delete_failed(error: String)

# -------------------------------------------------------------------------
# State (cached last-known progress)
# -------------------------------------------------------------------------

## Most recent progress record returned by create / get_mine / update.
## Empty (id == "") if never loaded or wiped via `delete_mine()`.
## upstream: GamerProgress.cs:22 (currentProgress)
var current_progress: GamerProgressData = null

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/gamer-progress
##
## `initial` is an optional Dictionary supplying any of:
##   - `experience` (int, default 0)
##   - `gold` (int, default 0)
##   - `game_data` (Dictionary or String — opaque per-game payload, default {})
##
## `user_id` is read from `SaiServer.auth.get_current_user()` and `game_id`
## from `SaiServer.game_id`, matching upstream behaviour.
##
## Returns the standard envelope. On success, `data` is a `GamerProgressData`
## Resource and `current_progress` is updated.
##
## upstream: GamerProgress.cs:218 (CreateProgress), GamerProgress.cs:237 (Coroutine)
func create(initial: Dictionary = {}) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		create_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: GamerProgress.cs:228-232 — refuse before sending.
		var err := "Not authenticated! Please login first."
		create_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	var user_id: String = _current_user_id(server)
	var path: String = PATH_CREATE.replace("{game_id}", game_id)

	# upstream: GamerProgress.cs:248-254 — hand-built JSON to embed game_data raw.
	# Godot's JSON.stringify handles nested Dictionaries fine, so we can use a
	# normal Dictionary here; behaviour is equivalent.
	var body: Dictionary = {
		"user_id": user_id,
		"game_id": game_id,
		"experience": int(initial.get("experience", 0)),
		"gold": int(initial.get("gold", 0)),
		"game_data": _coerce_game_data(initial.get("game_data", {})),
	}

	var result: Dictionary = await server.post_request(path, body, true)
	if result.get("success", false):
		# upstream: CreateGamerProgressResponse { data, message }
		var payload: Variant = result.get("data", null)
		var record: Variant = payload.get("data", null) if payload is Dictionary else null
		if record is Dictionary:
			var dto := GamerProgressData.from_dict(record)
			current_progress = dto
			result["data"] = dto
			create_success.emit(record)
			return result
		var msg := "create response missing `data` object"
		create_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "create failed"))
	create_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/my-gamer-progress
##
## Returns the standard envelope. On success, `data` is a `GamerProgressData`
## and `current_progress` is updated.
##
## upstream: GamerProgress.cs:293 (GetProgress), GamerProgress.cs:312 (Coroutine)
func get_mine() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		get_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: GamerProgress.cs:303-307 — refuse before sending.
		var err := "Not authenticated! Please login first."
		get_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_GET_MINE.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)
	if result.get("success", false):
		# upstream: GamerProgress.cs:324 — flat GamerProgressData (no wrapper).
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GamerProgressData.from_dict(payload)
			current_progress = dto
			result["data"] = dto
			get_success.emit(payload)
			return result
		var msg := "get_mine response not a JSON object"
		get_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_mine failed"))
	get_failed.emit(error_msg)
	return result


## PATCH /api/v1/gamer-progress/{progress_id}
##
## `deltas` keys (all optional, matching upstream UpdateGamerProgressRequest):
##   - `experience_delta` (int, default 0)
##   - `gold_delta`       (int, default 0)
##   - `game_data`        (Dictionary or String — replaces the stored blob)
##
## Returns the standard envelope. On success, `data` is a `GamerProgressData`
## and `current_progress` is updated.
##
## upstream: GamerProgress.cs:364 (UpdateProgress), GamerProgress.cs:377 (Coroutine)
func update(progress_id: String, deltas: Dictionary = {}) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		update_failed.emit(err)
		return _envelope_fail(err)

	if progress_id.is_empty():
		# upstream: GamerProgress.cs:368-372 — refuse without a record id.
		var err := "No progress id provided! Create or get progress first."
		update_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		update_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_UPDATE.replace("{progress_id}", progress_id)

	# upstream: GamerProgress.cs:388-392 — hand-built JSON; we use a Dictionary.
	var body: Dictionary = {
		"experience_delta": int(deltas.get("experience_delta", 0)),
		"gold_delta": int(deltas.get("gold_delta", 0)),
		"game_data": _coerce_game_data(deltas.get("game_data", {})),
	}

	var result: Dictionary = await server.patch_request(path, body, true)
	if result.get("success", false):
		# upstream: GamerProgress.cs:407 — flat GamerProgressData (no wrapper).
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var dto := GamerProgressData.from_dict(payload)
			current_progress = dto
			result["data"] = dto
			update_success.emit(payload)
			return result
		var msg := "update response not a JSON object"
		update_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "update failed"))
	update_failed.emit(error_msg)
	return result


## DELETE /api/v1/games/{game_id}/my-gamer-progress
##
## Always wipes `current_progress` locally, even if the server call fails —
## matches upstream `ClearProgressCoroutine` which calls `ClearLocalProgress`
## from both branches (GamerProgress.cs:467, 474).
##
## upstream: GamerProgress.cs:437 (ClearProgress), GamerProgress.cs:459 (Coroutine)
func delete_mine() -> Dictionary:
	var server: Node = _server()
	if server == null:
		# upstream: GamerProgress.cs:441-445 — wipe locally, no network call.
		_clear_local()
		delete_success.emit()
		return {"success": true, "status": 0, "error": "", "data": null}

	if not server.is_authenticated():
		# upstream: GamerProgress.cs:448-453 — wipe locally, no network call.
		_clear_local()
		delete_success.emit()
		return {"success": true, "status": 0, "error": "", "data": null}

	var path: String = PATH_DELETE_MINE.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.delete_request(path, null, true)
	# Always wipe locally regardless of outcome (parity with upstream).
	_clear_local()
	if result.get("success", false):
		delete_success.emit()
	else:
		delete_failed.emit(String(result.get("error", "delete failed")))
	return result


## Returns true iff `current_progress` is non-empty (has a server-side id).
## upstream: GamerProgress.cs:30 (HasProgress)
func has_progress() -> bool:
	return current_progress != null and not current_progress.id.is_empty()


## Returns the cached progress (or `null` if never loaded / freshly wiped).
## upstream: GamerProgress.cs:29 (CurrentProgress)
func get_current_progress() -> GamerProgressData:
	return current_progress


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirror SaiAuth._server: prefer parent (so this class is instantiable
	# under a fake-parent test harness), fall back to the SaiServer autoload.
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


func _game_id(server: Node) -> String:
	if server.has_method("normalized_game_id"):
		return String(server.normalized_game_id())
	# Fallback for test doubles that don't implement the helper.
	if "game_id" in server:
		return String(server.game_id)
	return ""


func _current_user_id(server: Node) -> String:
	# Upstream reads `SaiServer.Instance.CurrentUser?.id`. Here CurrentUser
	# lives on SaiAuth (sibling sub-service).
	# upstream: GamerProgress.cs:242
	if server == null:
		return ""
	var auth: Node = server.get_node_or_null("SaiAuth")
	if auth == null:
		# Direct property fallback for in-process wiring (and tests).
		if "auth" in server and server.auth != null:
			auth = server.auth
	if auth == null:
		return ""
	if auth.has_method("get_current_user"):
		var user: Variant = auth.get_current_user()
		if user is Dictionary:
			return String(user.get("id", ""))
	return ""


## Coerce caller-supplied `game_data` into the wire shape.
##
## Server accepts an object; we forward either a Dictionary verbatim (handled
## by JSON.stringify in SaiServer._send), or parse a String back into a
## Dictionary if it looks like JSON, or fall back to an empty object.
## upstream: GamerProgress.cs:245 (gameDataJson defaulting), :381 (fallback chain).
func _coerce_game_data(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value
	if value is String:
		var s: String = value
		if s.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(s)
		if parsed is Dictionary or parsed is Array:
			return parsed
		# Couldn't parse — preserve as raw string so server-side validators
		# can surface the error.
		return s
	return {}


## Reset cached progress to a brand-new empty record. Mirrors upstream
## `ClearLocalProgress` (GamerProgress.cs:482).
func _clear_local() -> void:
	current_progress = GamerProgressData.new()


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
