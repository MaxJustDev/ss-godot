## QuestHistory - read-only access to the player's quest claim history and
## per-definition status snapshot.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/5_Quest/Claims/QuestHistory.cs:13`
## (upstream v0.2.40d). Wraps two GET endpoints:
##
##   - `history()` / `list_claims()` -> GET .../quest-claims
##   - `quest_status()`              -> GET .../quests/{quest_definition_id}
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) collapse into the
##     project-standard `{success, status, error, data}` envelope + parallel
##     signals (B.4 / B.5 in CLAUDE.md).
##   - The upstream "extract `operator` field manually" trick (QuestHistory.cs:212)
##     is unnecessary in Godot — `JSON.parse_string` preserves any key name.
##     The `operator` value comes through verbatim inside the parsed
##     `quest_definition.conditions` Dictionary.
##   - Auto-load-on-login (QuestHistory.cs:69) is not ported — call
##     `history()` from `SaiServer.auth.login_success` if you need that.
##   - This node is added as a child of `SaiServer` during M1's `_ready` hook.
##     Use `SaiServer.quest_history.*` from app code.
##
## upstream: 5_Quest/Claims/QuestHistory.cs:13
class_name QuestHistory
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: QuestHistory.cs:123
const PATH_CLAIMS := "/api/v1/games/{game_id}/quest-claims"
## upstream: QuestHistory.cs:199
const PATH_STATUS := "/api/v1/games/{game_id}/quests/{quest_id}"

const DEFAULT_LIMIT := 50
const DEFAULT_OFFSET := 0

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `history()` / `list_claims()`. `entries` is
## `Array[QuestClaimRecord]`, `total` mirrors the server count.
## upstream: QuestHistory.cs:16 (OnGetClaimsSuccess)
signal history_loaded(entries: Array, total: int)
## upstream: QuestHistory.cs:17 (OnGetClaimsFailure)
signal history_failed(error: String)

## Emitted on successful `quest_status()`. `data` is the raw response Dict
## `{progress, quest_definition, status}`.
## upstream: QuestHistory.cs:18 (OnGetQuestStatusSuccess)
signal quest_status_success(quest_definition_id: String, data: Dictionary)
## upstream: QuestHistory.cs:19 (OnGetQuestStatusFailure)
signal quest_status_failed(quest_definition_id: String, error: String)

# -------------------------------------------------------------------------
# State (cached last-known data)
# -------------------------------------------------------------------------

## Most recent claim list (typed). Each entry is a `QuestClaimRecord`.
## upstream: QuestHistory.cs:27 (currentClaimsResponse.claims)
var current_claims: Array = []
var _last_total: int = 0

## quest_definition_id -> raw status response Dictionary.
## upstream: QuestHistory.cs:28 (currentQuestStatusResponse)
var _status_cache: Dictionary = {}

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/quest-claims?limit=&offset=
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `entries`: Array[QuestClaimRecord]
##   - `total`:   int (server-reported total claim count)
##   - `limit`:   int
##   - `offset`:  int
##
## upstream: QuestHistory.cs:89 (GetClaims) / :116 (Coroutine)
func history(limit: int = DEFAULT_LIMIT, offset: int = DEFAULT_OFFSET) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		history_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: QuestHistory.cs:103-107 — refuse before sending.
		var err := "Not authenticated! Please login first."
		history_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_CLAIMS.replace("{game_id}", _game_id(server))
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_list: Variant = payload.get("claims", [])
			var entries: Array = []
			if raw_list is Array:
				for c in raw_list:
					if c is Dictionary:
						entries.append(QuestClaimRecord.from_dict(c))
			current_claims = entries
			_last_total = int(payload.get("total", entries.size()))
			var out: Dictionary = {
				"entries": entries,
				"total": _last_total,
				"limit": int(payload.get("limit", limit)),
				"offset": int(payload.get("offset", offset)),
			}
			result["data"] = out
			history_loaded.emit(entries, _last_total)
			return result
		var msg := "history response not a JSON object"
		history_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "history failed"))
	history_failed.emit(error_msg)
	return result


## Alias for `history` — matches upstream `GetClaims` name and is the
## descriptive form used by some call sites.
func list_claims(limit: int = DEFAULT_LIMIT, offset: int = DEFAULT_OFFSET) -> Dictionary:
	return await history(limit, offset)


## GET /api/v1/games/{game_id}/quests/{quest_definition_id}
##
## Returns the standard envelope. On success, `data` is the raw response
## Dictionary `{progress, quest_definition, status}`.
##
## upstream: QuestHistory.cs:164 (GetQuestStatus) / :193 (Coroutine)
func quest_status(quest_definition_id: String) -> Dictionary:
	if quest_definition_id.strip_edges().is_empty():
		var err := "Quest Definition ID is required."
		quest_status_failed.emit("", err)
		return _envelope_fail(err)

	var trimmed: String = quest_definition_id.strip_edges()
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		quest_status_failed.emit(trimmed, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: QuestHistory.cs:178-182 — refuse before sending.
		var err := "Not authenticated! Please login first."
		quest_status_failed.emit(trimmed, err)
		return _envelope_fail(err)

	var path: String = PATH_STATUS.replace("{game_id}", _game_id(server)).replace(
		"{quest_id}", trimmed
	)
	var result: Dictionary = await server.get_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			_status_cache[trimmed] = payload
			quest_status_success.emit(trimmed, payload)
			return result
		var msg := "quest_status response not a JSON object"
		quest_status_failed.emit(trimmed, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "quest_status failed"))
	quest_status_failed.emit(trimmed, error_msg)
	return result


## Drop locally cached claim list + status cache.
## upstream: QuestHistory.cs:249 (ClearClaims)
func clear_history() -> void:
	current_claims = []
	_last_total = 0
	_status_cache.clear()


# =========================================================================
# Convenience query helpers (parity with upstream QuestHistory.cs:274-301)
# =========================================================================


func get_claim_by_id(claim_id: String) -> Variant:
	for c in current_claims:
		if c is QuestClaimRecord and c.id == claim_id:
			return c
	return null


func get_claims_by_quest_definition_id(quest_definition_id: String) -> Array:
	var out: Array = []
	for c in current_claims:
		if c is QuestClaimRecord and c.quest_definition_id == quest_definition_id:
			out.append(c)
	return out


func get_cached_status(quest_definition_id: String) -> Variant:
	return _status_cache.get(quest_definition_id, null)


func last_total() -> int:
	return _last_total


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
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
		return String(server.game_id)
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
