## DailyQuest - list daily quest pools, fetch today's pool entries, and
## assign quests ahead for the next N days.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/5_Quest/Daily/DailyQuest.cs:8`
## (upstream v0.2.40d). Wraps three endpoints:
##
##   - `list_daily_pools()`     -> GET .../daily-quest-pools
##   - `list_daily()`           -> GET .../daily-quests/{pool_id}
##                                 (aliased `get_today()`)
##   - `assign_daily_ahead()`   -> POST .../daily-quests/{pool_id}/assign-ahead
##
## Claim/complete of a daily quest goes through `QuestProgressor.claim_quest`
## using the underlying `quest_definition_id`. `claim_daily()` here is a
## thin proxy so callers can write `SaiServer.quest.claim_daily(id)`.
##
## Translation notes:
##   - Unity callback pairs collapse into the standard envelope + signals.
##   - Auto-load-on-login (DailyQuest.cs:65) is NOT ported — call
##     `list_daily_pools()` from `SaiServer.auth.login_success` if needed.
##   - The substring-scan for dynamic `progress_data` JSON (DailyQuest.cs:408)
##     is unnecessary: Godot's `JSON.parse_string` keeps the parsed object
##     intact, so each entry's `progress.progress_data` is a nested
##     Dictionary in the returned envelope.
##   - This node is added as a child of `SaiServer` during M1's `_ready` hook.
##     Use `SaiServer.daily_quest.*` from app code.
##
## upstream: 5_Quest/Daily/DailyQuest.cs:8
class_name DailyQuest
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: DailyQuest.cs:238
const PATH_POOLS := "/api/v1/games/{game_id}/daily-quest-pools"
## upstream: DailyQuest.cs:317
const PATH_TODAY := "/api/v1/games/{game_id}/daily-quests/{pool_id}"
## upstream: DailyQuest.cs:142
const PATH_ASSIGN_AHEAD := "/api/v1/games/{game_id}/daily-quests/{pool_id}/assign-ahead"

const DEFAULT_DAYS_AHEAD := 7

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: DailyQuest.cs:11 (OnGetPoolsSuccess)
signal pools_loaded(pools: Array)
## upstream: DailyQuest.cs:12 (OnGetPoolsFailure)
signal pools_failed(error: String)

## upstream: DailyQuest.cs:13 (OnGetTodayQuestsSuccess) — `entries` is `Array[DailyQuestData]`
signal today_loaded(pool_id: String, entries: Array)
## upstream: DailyQuest.cs:14 (OnGetTodayQuestsFailure)
signal today_failed(pool_id: String, error: String)

## upstream: DailyQuest.cs:15 (OnAssignAheadSuccess)
signal assign_ahead_success(pool_id: String, days: Array)
## upstream: DailyQuest.cs:16 (OnAssignAheadFailure)
signal assign_ahead_failed(pool_id: String, error: String)

## Surface name from `docs/examples/quest.md` — emitted when the proxy
## `claim_daily()` succeeds. Mirrors `QuestProgressor.claim_quest_success`.
signal daily_claim_success(quest_definition_id: String, claim: QuestClaimRecord)
signal daily_claim_failed(quest_definition_id: String, error: String)

# -------------------------------------------------------------------------
# State (cached last-known data)
# -------------------------------------------------------------------------

## Most recent pool list (raw response Dicts).
var current_pools: Array = []
## Most recent today response, by pool_id.
var _today_cache: Dictionary = {}
## Most recent assign-ahead response, by pool_id.
var _assign_ahead_cache: Dictionary = {}

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/daily-quest-pools
##
## Returns the standard envelope. On success, `data.pools` is the raw
## pool array from the server.
##
## upstream: DailyQuest.cs:211 (GetPools) / :233 (Coroutine)
func list_daily_pools() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		pools_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: DailyQuest.cs:223-227 — refuse before sending.
		var err := "Not authenticated! Please login first."
		pools_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_POOLS.replace("{game_id}", _game_id(server))
	var result: Dictionary = await server.get_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var pools: Variant = payload.get("pools", [])
			current_pools = pools if pools is Array else []
			pools_loaded.emit(current_pools)
			return result
		var msg := "list_daily_pools response not a JSON object"
		pools_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "list_daily_pools failed"))
	pools_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/daily-quests/{pool_id}
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `pool`:          raw pool Dictionary (or {} if absent)
##   - `entries`:       Array[DailyQuestData]
##   - `streak`:        raw streak Dictionary
##   - `assigned_date`: yyyy-MM-dd string
##
## upstream: DailyQuest.cs:280 (GetTodayQuests) / :311 (Coroutine)
func list_daily(pool_id: String) -> Dictionary:
	if pool_id.is_empty():
		var err := "pool_id cannot be empty."
		today_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		today_failed.emit(pool_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: DailyQuest.cs:294-298 — refuse before sending.
		var err := "Not authenticated! Please login first."
		today_failed.emit(pool_id, err)
		return _envelope_fail(err)

	var path: String = PATH_TODAY.replace("{game_id}", _game_id(server)).replace(
		"{pool_id}", pool_id
	)
	var result: Dictionary = await server.get_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var raw_entries: Variant = payload.get("entries", [])
			var entries: Array = []
			if raw_entries is Array:
				for e in raw_entries:
					if e is Dictionary:
						entries.append(DailyQuestData.from_dict(e))
			var out: Dictionary = {
				"pool": payload.get("pool", {}),
				"entries": entries,
				"streak": payload.get("streak", {}),
				"assigned_date": String(payload.get("assigned_date", "")),
				# Convenience alias for `docs/examples/quest.md`
				"quests": entries,
			}
			_today_cache[pool_id] = out
			result["data"] = out
			today_loaded.emit(pool_id, entries)
			return result
		var msg := "list_daily response not a JSON object"
		today_failed.emit(pool_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "list_daily failed"))
	today_failed.emit(pool_id, error_msg)
	return result


## Alias for `list_daily` — name parity with upstream `GetTodayQuests`.
func get_today(pool_id: String) -> Dictionary:
	return await list_daily(pool_id)


## POST /api/v1/games/{game_id}/daily-quests/{pool_id}/assign-ahead
##
## `days_ahead` defaults to 7. Returns the standard envelope. On success,
## `data` is the raw assign-ahead response with a `days[]` array, one entry
## per assigned day.
##
## upstream: DailyQuest.cs:101 (AssignAhead) / :135 (Coroutine)
func assign_daily_ahead(pool_id: String, days_ahead: int = DEFAULT_DAYS_AHEAD) -> Dictionary:
	if pool_id.is_empty():
		var err := "pool_id cannot be empty."
		assign_ahead_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		assign_ahead_failed.emit(pool_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: DailyQuest.cs:116-120 — refuse before sending.
		var err := "Not authenticated! Please login first."
		assign_ahead_failed.emit(pool_id, err)
		return _envelope_fail(err)

	var path: String = PATH_ASSIGN_AHEAD.replace("{game_id}", _game_id(server)).replace(
		"{pool_id}", pool_id
	)
	# upstream: DailyQuest.cs:144 — `AssignAheadRequest { days_ahead }`
	var body: Dictionary = {"days_ahead": days_ahead}
	var result: Dictionary = await server.post_request(path, body, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			_assign_ahead_cache[pool_id] = payload
			var days_var: Variant = payload.get("days", [])
			var days: Array = days_var if days_var is Array else []
			assign_ahead_success.emit(pool_id, days)
			return result
		var msg := "assign_daily_ahead response not a JSON object"
		assign_ahead_failed.emit(pool_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "assign_daily_ahead failed"))
	assign_ahead_failed.emit(pool_id, error_msg)
	return result


## Claim a completed daily quest. Thin proxy over
## `QuestProgressor.claim_quest()` so callers can write
## `SaiServer.quest.claim_daily(quest_definition_id)`.
##
## upstream: claim path is the same generic endpoint used by chain quests
## (QuestProgressor.cs:362).
func claim_daily(quest_definition_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		daily_claim_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	var progressor: Node = _progressor(server)
	if progressor == null:
		var err := "QuestProgressor not registered"
		daily_claim_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	var result: Dictionary = await progressor.claim_quest(quest_definition_id)
	if result.get("success", false):
		var data: Variant = result.get("data", null)
		if data is QuestClaimRecord:
			daily_claim_success.emit(quest_definition_id, data)
		else:
			daily_claim_success.emit(quest_definition_id, null)
	else:
		daily_claim_failed.emit(quest_definition_id, String(result.get("error", "")))
	return result


## Drop locally cached daily data.
## upstream: DailyQuest.cs:188 (ClearData)
func clear_daily() -> void:
	current_pools = []
	_today_cache.clear()
	_assign_ahead_cache.clear()


# =========================================================================
# Convenience query helpers (parity with upstream DailyQuest.cs:369-392)
# =========================================================================


func get_cached_today(pool_id: String) -> Variant:
	return _today_cache.get(pool_id, null)


func get_cached_assign_ahead(pool_id: String) -> Variant:
	return _assign_ahead_cache.get(pool_id, null)


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


func _progressor(server: Node) -> Node:
	# Find the sibling QuestProgressor sub-service. Prefer a typed accessor
	# on the server (real SaiServer), fall back to a named child for tests.
	if server == null:
		return null
	if "quest_progressor" in server and server.quest_progressor != null:
		return server.quest_progressor
	return server.get_node_or_null("QuestProgressor")


func _game_id(server: Node) -> String:
	if server.has_method("normalized_game_id"):
		return String(server.normalized_game_id())
	if "game_id" in server:
		return String(server.game_id)
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
