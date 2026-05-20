## ChainQuest - list / inspect quest chains and their member tree.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/5_Quest/Chain/ChainQuest.cs:8`
## (upstream v0.2.40d). Wraps three GET endpoints:
##
##   - `list_chain()`           -> GET .../quests/chains
##   - `list_chain_members()`   -> GET .../quests/chains/{chain_id}/members
##   - `get_chain_detail()`     -> GET .../quests/chains/{chain_id}/tree
##                                  (aliased: `get_chain_tree()`)
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard `{success, status, error, data}` envelope plus
##     parallel signals (B.4 / B.5 in CLAUDE.md).
##   - The auto-load-on-login hook (ChainQuest.cs:61) is NOT ported in M5b;
##     consumers can subscribe to `SaiServer.auth.login_success` and call
##     `list_chain()` themselves.
##   - The cached `currentChainResponse` + `runtimeMembersCache` from upstream
##     are kept as `current_chains` / `_members_cache` for parity with the
##     convenience query helpers (`get_chain_by_id`, `get_chain_by_key`, ...).
##   - This node is added as a child of `SaiServer` during M1's `_ready` hook.
##     Use `SaiServer.quest.*` from app code (alias to this same node).
##
## upstream: 5_Quest/Chain/ChainQuest.cs:8
class_name ChainQuest
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: ChainQuest.cs:132
const PATH_LIST := "/api/v1/games/{game_id}/quests/chains"
## upstream: ChainQuest.cs:328
const PATH_MEMBERS := "/api/v1/games/{game_id}/quests/chains/{chain_id}/members"
## upstream: ChainQuest.cs:405
const PATH_TREE := "/api/v1/games/{game_id}/quests/chains/{chain_id}/tree"

const DEFAULT_LIMIT := 50
const DEFAULT_OFFSET := 0

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## upstream: ChainQuest.cs:11 (OnGetChainsSuccess) — emits raw response Dict
signal list_chain_success(data: Dictionary)
## upstream: ChainQuest.cs:12 (OnGetChainsFailure)
signal list_chain_failed(error: String)

## upstream: ChainQuest.cs:13 (OnGetChainMembersSuccess)
signal chain_members_success(chain_id: String, data: Dictionary)
## upstream: ChainQuest.cs:14 (OnGetChainMembersFailure)
signal chain_members_failed(chain_id: String, error: String)

## upstream: ChainQuest.cs:15 (OnGetChainTreeSuccess) — alias `chain_advance`
## per `docs/examples/quest.md`. Re-emitted as both names for parity.
signal chain_advance_success(chain_id: String, data: Dictionary)
## upstream: ChainQuest.cs:16 (OnGetChainTreeFailure)
signal chain_advance_failed(chain_id: String, error: String)

# -------------------------------------------------------------------------
# State (cached last-known data)
# -------------------------------------------------------------------------

## Raw `chains[]` from the last list call. Each entry is a Dictionary.
## upstream: ChainQuest.cs:22 (currentChainResponse.chains)
var current_chains: Array = []
var _last_total: int = 0
var _last_limit: int = DEFAULT_LIMIT
var _last_offset: int = DEFAULT_OFFSET

## chain_id -> ChainMembersResponse dict.
## upstream: ChainQuest.cs:271 (runtimeMembersCache)
var _members_cache: Dictionary = {}

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/quests/chains?limit=&offset=
##
## Returns the standard envelope. On success, `data` is the raw response
## Dictionary `{chains, limit, offset, total}` and `current_chains` is updated.
##
## upstream: ChainQuest.cs:98 (GetChains) / :125 (GetChainsCoroutine)
func list_chain(limit: int = DEFAULT_LIMIT, offset: int = DEFAULT_OFFSET) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		list_chain_failed.emit(err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: ChainQuest.cs:113-117 — refuse before sending.
		var err := "Not authenticated! Please login first."
		list_chain_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_LIST.replace("{game_id}", _game_id(server))
	var query: Dictionary = {"limit": limit, "offset": offset}
	var result: Dictionary = await server.get_request(path, query, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			var chains_var: Variant = payload.get("chains", [])
			current_chains = chains_var if chains_var is Array else []
			_last_total = int(payload.get("total", 0))
			_last_limit = int(payload.get("limit", limit))
			_last_offset = int(payload.get("offset", offset))
			list_chain_success.emit(payload)
			return result
		var msg := "list_chain response not a JSON object"
		list_chain_failed.emit(msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "list_chain failed"))
	list_chain_failed.emit(error_msg)
	return result


## GET /api/v1/games/{game_id}/quests/chains/{chain_id}/members
##
## Returns the standard envelope. On success, `data.members` is the raw
## member-list array and `_members_cache[chain_id]` is updated.
##
## upstream: ChainQuest.cs:293 (GetChainMembers) / :322 (Coroutine)
func list_chain_members(chain_id: String) -> Dictionary:
	if chain_id.is_empty():
		var err := "chain_id cannot be empty."
		chain_members_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		chain_members_failed.emit(chain_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: ChainQuest.cs:307-311 — refuse before sending.
		var err := "Not authenticated! Please login first."
		chain_members_failed.emit(chain_id, err)
		return _envelope_fail(err)

	var path: String = PATH_MEMBERS.replace("{game_id}", _game_id(server)).replace(
		"{chain_id}", chain_id
	)
	var result: Dictionary = await server.get_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			_members_cache[chain_id] = payload
			chain_members_success.emit(chain_id, payload)
			return result
		var msg := "list_chain_members response not a JSON object"
		chain_members_failed.emit(chain_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "list_chain_members failed"))
	chain_members_failed.emit(chain_id, error_msg)
	return result


## GET /api/v1/games/{game_id}/quests/chains/{chain_id}/tree
##
## Returns the standard envelope. On success, `data` is the raw tree
## response Dictionary `{chain_id, chain_name, nodes: QuestTreeNode[]}` with
## an extra `steps` key holding a flat `Array[QuestStep]` for the
## `current_step / total_steps` projection described in
## `docs/examples/quest.md`.
##
## Convenience alias: `get_chain_tree(chain_id)` returns the same shape.
## The `advance_chain(chain_id)` signal-style alias re-emits via
## `chain_advance_success`.
##
## upstream: ChainQuest.cs:370 (GetChainTree) / :399 (Coroutine)
func get_chain_detail(chain_id: String) -> Dictionary:
	if chain_id.is_empty():
		var err := "chain_id cannot be empty."
		chain_advance_failed.emit("", err)
		return _envelope_fail(err)

	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		chain_advance_failed.emit(chain_id, err)
		return _envelope_fail(err)

	if not server.is_authenticated():
		# upstream: ChainQuest.cs:384-388 — refuse before sending.
		var err := "Not authenticated! Please login first."
		chain_advance_failed.emit(chain_id, err)
		return _envelope_fail(err)

	var path: String = PATH_TREE.replace("{game_id}", _game_id(server)).replace(
		"{chain_id}", chain_id
	)
	var result: Dictionary = await server.get_request(path, {}, true)

	if result.get("success", false):
		var payload: Variant = result.get("data", null)
		if payload is Dictionary:
			# Flatten the tree into a step list for the `current/total` projection.
			var nodes_raw: Variant = payload.get("nodes", [])
			var roots: Array = []
			if nodes_raw is Array:
				for n in nodes_raw:
					if n is Dictionary:
						roots.append(QuestStep.from_dict(n))
			var flat: Array = QuestStep.flatten(roots)
			payload["steps"] = flat
			payload["total_steps"] = flat.size()
			payload["current_step"] = _compute_current_step(flat)
			chain_advance_success.emit(chain_id, payload)
			return result
		var msg := "get_chain_detail response not a JSON object"
		chain_advance_failed.emit(chain_id, msg)
		return _envelope_fail(msg, int(result.get("status", 0)), payload)

	var error_msg: String = String(result.get("error", "get_chain_detail failed"))
	chain_advance_failed.emit(chain_id, error_msg)
	return result


## Alias for `get_chain_detail` — kept for naming parity with upstream and
## with `docs/examples/quest.md` which uses both `advance_chain` (signal)
## and `get_chain_tree` (descriptive name).
func get_chain_tree(chain_id: String) -> Dictionary:
	return await get_chain_detail(chain_id)


## Drop all locally cached chain data (chains list + members cache).
## upstream: ChainQuest.cs:172 (ClearChains)
func clear_chains() -> void:
	current_chains = []
	_last_total = 0
	_members_cache.clear()


# =========================================================================
# Convenience query helpers (parity with upstream ChainQuest.cs:197-258)
# =========================================================================


## Locally cached chain Dictionary with the given id, or null.
## upstream: ChainQuest.cs:197 (GetChainById)
func get_chain_by_id(chain_id: String) -> Variant:
	for c in current_chains:
		if c is Dictionary and String(c.get("id", "")) == chain_id:
			return c
	return null


## Locally cached chain Dictionary with the given chain_key, or null.
## upstream: ChainQuest.cs:212 (GetChainByKey)
func get_chain_by_key(chain_key: String) -> Variant:
	for c in current_chains:
		if c is Dictionary and String(c.get("chain_key", "")) == chain_key:
			return c
	return null


## Cached members response for `chain_id`, or null if not loaded.
## upstream: ChainQuest.cs:274 (GetCachedMembers)
func get_cached_members(chain_id: String) -> Variant:
	return _members_cache.get(chain_id, null)


func last_total() -> int:
	return _last_total


# =========================================================================
# Facade delegation
# =========================================================================
#
# `docs/examples/quest.md` uses `SaiServer.quest.*` as a single entry point
# for all quest operations (chain, daily, progressor, history). `quest` is
# aliased to this ChainQuest instance in `sai_server.gd`, so the following
# delegations make daily / progressor / history methods reachable through
# the same name. Each delegator just forwards to the sibling sub-service.


## Delegate to QuestProgressor.advance_chain (alias of start_quest).
##
## Re-emits the outcome on `chain_advance_success` / `chain_advance_failed`
## so `SaiServer.quest.chain_advance_success.connect(...)` works the way
## `docs/examples/quest.md` shows.
func advance_chain(quest_definition_id: String) -> Dictionary:
	var p: Node = _sibling("QuestProgressor", "quest_progressor")
	if p == null:
		var err := "QuestProgressor not registered"
		chain_advance_failed.emit(quest_definition_id, err)
		return _envelope_fail(err)
	var result: Dictionary = await p.advance_chain(quest_definition_id)
	if result.get("success", false):
		var data: Variant = result.get("data", {})
		var payload: Dictionary = data if data is Dictionary else {}
		chain_advance_success.emit(quest_definition_id, payload)
	else:
		chain_advance_failed.emit(quest_definition_id, String(result.get("error", "")))
	return result


## Delegate to QuestProgressor.increment_progress.
func increment_progress(objective_code: String, delta: int = 1) -> Dictionary:
	var p: Node = _sibling("QuestProgressor", "quest_progressor")
	if p == null:
		return _envelope_fail("QuestProgressor not registered")
	return await p.increment_progress(objective_code, delta)


## Delegate to QuestProgressor.claim_quest (used for chain quest claims).
func claim_quest(quest_definition_id: String) -> Dictionary:
	var p: Node = _sibling("QuestProgressor", "quest_progressor")
	if p == null:
		return _envelope_fail("QuestProgressor not registered")
	return await p.claim_quest(quest_definition_id)


## Delegate to DailyQuest.list_daily.
func list_daily(pool_id: String) -> Dictionary:
	var d: Node = _sibling("DailyQuest", "daily_quest")
	if d == null:
		return _envelope_fail("DailyQuest not registered")
	return await d.list_daily(pool_id)


## Delegate to DailyQuest.claim_daily.
func claim_daily(quest_definition_id: String) -> Dictionary:
	var d: Node = _sibling("DailyQuest", "daily_quest")
	if d == null:
		return _envelope_fail("DailyQuest not registered")
	return await d.claim_daily(quest_definition_id)


## Delegate to DailyQuest.list_daily_pools.
func list_daily_pools() -> Dictionary:
	var d: Node = _sibling("DailyQuest", "daily_quest")
	if d == null:
		return _envelope_fail("DailyQuest not registered")
	return await d.list_daily_pools()


## Delegate to DailyQuest.assign_daily_ahead.
func assign_daily_ahead(
	pool_id: String, days_ahead: int = DailyQuest.DEFAULT_DAYS_AHEAD
) -> Dictionary:
	var d: Node = _sibling("DailyQuest", "daily_quest")
	if d == null:
		return _envelope_fail("DailyQuest not registered")
	return await d.assign_daily_ahead(pool_id, days_ahead)


## Delegate to QuestHistory.history.
func history(
	limit: int = QuestHistory.DEFAULT_LIMIT, offset: int = QuestHistory.DEFAULT_OFFSET
) -> Dictionary:
	var h: Node = _sibling("QuestHistory", "quest_history")
	if h == null:
		return _envelope_fail("QuestHistory not registered")
	return await h.history(limit, offset)


## Delegate to QuestHistory.quest_status.
func quest_status(quest_definition_id: String) -> Dictionary:
	var h: Node = _sibling("QuestHistory", "quest_history")
	if h == null:
		return _envelope_fail("QuestHistory not registered")
	return await h.quest_status(quest_definition_id)


# =========================================================================
# Internals
# =========================================================================


## Locate a sibling sub-service (child of the shared SaiServer parent).
func _sibling(node_name: String, prop_name: String) -> Node:
	var server: Node = _server()
	if server == null:
		return null
	if prop_name in server and server.get(prop_name) != null:
		return server.get(prop_name)
	return server.get_node_or_null(node_name)


## Reduce a flat list of QuestStep into a 1-based "current step" index for
## the `docs/examples/quest.md` projection.
##
## Heuristic (no upstream parity — projection added in M5b):
##   - First step whose status is `in_progress` -> that index + 1
##   - Otherwise: last completed step + 1 (capped at total_steps)
##   - Empty list -> 0
func _compute_current_step(flat: Array) -> int:
	if flat.is_empty():
		return 0
	var last_done: int = -1
	for i in flat.size():
		var s: QuestStep = flat[i]
		if s.status == "in_progress":
			return i + 1
		if s.status == "completed" or s.status == "claimed":
			last_done = i
	if last_done >= 0:
		return min(last_done + 1, flat.size())
	return 1


func _server() -> Node:
	# Mirror GamerProgress._server: prefer parent (for test doubles), fall
	# back to the SaiServer autoload.
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
