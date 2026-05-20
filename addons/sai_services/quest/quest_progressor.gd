## QuestProgressor - start / check / claim a quest by its definition id.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/5_Quest/Progress/QuestProgressor.cs:8`
## (upstream v0.2.40d). Wraps three POST endpoints:
##
##   - `start_quest()`         -> POST .../quests/{id}/start
##                                (aliased as `advance_chain()` for chain UX)
##   - `check_quest()`         -> POST .../quests/{id}/check
##                                (aliased as `increment_progress()` for counters)
##   - `claim_quest()`         -> POST .../quests/{id}/claim
##
## Translation notes:
##   - Action-name aliases (`advance_chain`, `increment_progress`) match
##     `docs/examples/quest.md`. Both names hit the same underlying endpoint;
##     pick whichever reads better at the call site.
##   - The upstream `BuildQuestPickerEntries` editor helper is NOT ported —
##     it walked ChainQuest / DailyQuest caches purely for the inspector UI.
##     Equivalent flattening is available via `ChainQuest.list_chain_members`
##     + `DailyQuest.list_daily` data.
##   - Dynamic `progress_data` JSON (CheckQuestResponse.progress.progress_data)
##     is preserved verbatim by Godot's `JSON.parse_string` and surfaced as a
##     nested Dictionary in the returned envelope; no manual extract is needed
##     (parity note: upstream uses substring scan to bypass JsonUtility).
##   - This node is added as a child of `SaiServer` during M1's `_ready`
##     hook. Use `SaiServer.quest_progressor.*` from app code.
##
## upstream: 5_Quest/Progress/QuestProgressor.cs:8
class_name QuestProgressor
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: QuestProgressor.cs:197
const PATH_START := "/api/v1/games/{game_id}/quests/{quest_id}/start"
## upstream: QuestProgressor.cs:275
const PATH_CHECK := "/api/v1/games/{game_id}/quests/{quest_id}/check"
## upstream: QuestProgressor.cs:362
const PATH_CLAIM := "/api/v1/games/{game_id}/quests/{quest_id}/claim"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: QuestProgressor.cs:12 (OnStartQuestSuccess) — alias `chain_advance_success`
signal start_quest_success(quest_id: String, data: Dictionary)
## upstream: QuestProgressor.cs:13 (OnStartQuestFailure)
signal start_quest_failed(quest_id: String, error: String)

## upstream: QuestProgressor.cs:14 (OnCheckQuestSuccess) — alias `progress_updated`
signal check_quest_success(quest_id: String, data: Dictionary)
## upstream: QuestProgressor.cs:15 (OnCheckQuestFailure)
signal check_quest_failed(quest_id: String, error: String)

## upstream: QuestProgressor.cs:16 (OnClaimQuestSuccess)
signal claim_quest_success(quest_id: String, claim: QuestClaimRecord)
## upstream: QuestProgressor.cs:17 (OnClaimQuestFailure)
signal claim_quest_failed(quest_id: String, error: String)

## Emitted when a `check_quest` response reports `status == "completed"` or
## `"claimed"`. Surface name from `docs/examples/quest.md`.
signal quest_completed(quest_id: String)

# -------------------------------------------------------------------------
# State (last-known responses, parity with upstream)
# -------------------------------------------------------------------------

## upstream: QuestProgressor.cs:23 (lastStartedQuest)
var last_started: Dictionary = {}
## upstream: QuestProgressor.cs:26 (lastCheckedQuest)
var last_checked: Dictionary = {}
## upstream: QuestProgressor.cs:29 (lastClaimedQuest)
var last_claimed: QuestClaimRecord = null

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/quests/{quest_id}/start
##
## Returns the standard envelope. On success, `data` is the raw response
## Dictionary `{id, studio_id, game_id, user_id, quest_definition_id, status,
## version, created_at, updated_at}`.
##
## upstream: QuestProgressor.cs:162 (StartQuest) / :191 (Coroutine)
func start_quest(quest_definition_id: String) -> Dictionary:
	if quest_definition_id.is_empty():
		var err := "quest_definition_id cannot be empty."
		start_quest_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		start_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: QuestProgressor.cs:176-180 — refuse before sending.
		var err := "Not authenticated! Please login first."
		start_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	var path: String = PATH_START.replace("{game_id}", _game_id(server)).replace(
		"{quest_id}", quest_definition_id
	)
	var result: Dictionary = await server.post_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			last_started = payload
			start_quest_success.emit(quest_definition_id, payload)
			return result
		var msg := "start_quest response not a JSON object"
		start_quest_failed.emit(quest_definition_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "start_quest failed"))
	start_quest_failed.emit(quest_definition_id, error_msg)
	return result


## Alias for `start_quest` matching `docs/examples/quest.md`. Use when
## driving a chain forward.
func advance_chain(quest_definition_id: String) -> Dictionary:
	return await start_quest(quest_definition_id)


## POST /api/v1/games/{game_id}/quests/{quest_id}/check
##
## Returns the standard envelope. On success, `data` is the raw
## `CheckQuestResponse` `{progress, quest_definition, status}`. If
## `progress.status` is `completed`/`claimed`, the `quest_completed`
## signal also fires.
##
## upstream: QuestProgressor.cs:240 (CheckQuest) / :269 (Coroutine)
func check_quest(quest_definition_id: String) -> Dictionary:
	if quest_definition_id.is_empty():
		var err := "quest_definition_id cannot be empty."
		check_quest_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		check_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: QuestProgressor.cs:254-258 — refuse before sending.
		var err := "Not authenticated! Please login first."
		check_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	var path: String = PATH_CHECK.replace("{game_id}", _game_id(server)).replace(
		"{quest_id}", quest_definition_id
	)
	var result: Dictionary = await server.post_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			last_checked = payload
			check_quest_success.emit(quest_definition_id, payload)
			var prog: Variant = payload.get("progress", {})
			var status: String = ""
			if prog is Dictionary:
				status = String(prog.get("status", ""))
			if status == "completed" or status == "claimed":
				quest_completed.emit(quest_definition_id)
			return result
		var msg := "check_quest response not a JSON object"
		check_quest_failed.emit(quest_definition_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "check_quest failed"))
	check_quest_failed.emit(quest_definition_id, error_msg)
	return result


## Counter-style alias for `check_quest`. Per `docs/examples/quest.md` the
## quest server is the source of truth — clients fire `increment_progress`
## with an objective code + delta and the server returns the new state.
##
## `delta` is encoded into the POST body; the server ignores it on rules
## that derive progress from other events (e.g. inventory pickups).
func increment_progress(objective_code: String, delta: int = 1) -> Dictionary:
	if objective_code.is_empty():
		var err := "objective_code cannot be empty."
		check_quest_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		check_quest_failed.emit(objective_code, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		check_quest_failed.emit(objective_code, err)
		return _envelope_fail(err)

	var path: String = PATH_CHECK.replace("{game_id}", _game_id(server)).replace(
		"{quest_id}", objective_code
	)
	var body: Dictionary = {"delta": delta}
	var result: Dictionary = await server.post_request(path, body, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			last_checked = payload
			check_quest_success.emit(objective_code, payload)
			var prog: Variant = payload.get("progress", {})
			var status: String = ""
			if prog is Dictionary:
				status = String(prog.get("status", ""))
			if status == "completed" or status == "claimed":
				quest_completed.emit(objective_code)
			return result
		var msg := "increment_progress response not a JSON object"
		check_quest_failed.emit(objective_code, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "increment_progress failed"))
	check_quest_failed.emit(objective_code, error_msg)
	return result


## POST /api/v1/games/{game_id}/quests/{quest_id}/claim
##
## Returns the standard envelope. On success, `data` is a `QuestClaimRecord`
## Resource (parsed from the wire-shape ClaimQuestResponse).
##
## upstream: QuestProgressor.cs:327 (ClaimQuest) / :356 (Coroutine)
func claim_quest(quest_definition_id: String) -> Dictionary:
	if quest_definition_id.is_empty():
		var err := "quest_definition_id cannot be empty."
		claim_quest_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		claim_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: QuestProgressor.cs:341-345 — refuse before sending.
		var err := "Not authenticated! Please login first."
		claim_quest_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)

	var path: String = PATH_CLAIM.replace("{game_id}", _game_id(server)).replace(
		"{quest_id}", quest_definition_id
	)
	var result: Dictionary = await server.post_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var record := QuestClaimRecord.from_dict(payload)
			last_claimed = record
			result["data"] = record
			claim_quest_success.emit(quest_definition_id, record)
			return result
		var msg := "claim_quest response not a JSON object"
		claim_quest_failed.emit(quest_definition_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "claim_quest failed"))
	claim_quest_failed.emit(quest_definition_id, error_msg)
	return result


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
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
	if "game_id" in server:
		return String(server.game_id)
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
