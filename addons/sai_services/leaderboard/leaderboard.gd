## Leaderboard - list boards / get board / top rankings / my rank wrapper
## around the SaiGame leaderboard REST endpoints.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/7_Leaderboard/Leaderboard.cs:8`
## (upstream v0.2.40d).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals (B.4 in CLAUDE.md).
##   - Upstream exposes four endpoints: ListBoards, GetBoard, GetTopRankings,
##     GetLocalRanking (= "my rank"). We mirror them as `list_boards()`,
##     `get_board(board_id)`, `top(board_id, limit)`, `my_rank(board_id)`.
##   - `top()` aliases as the "leaderboard listing" call referenced in
##     `docs/examples/leaderboard.md` (Fetch top N). `my_rank()` is the
##     direct port of `GetLocalRanking` — see TODO below re: `around_me`.
##   - Upstream client-side helpers (`GetBoardByKey`, `GetBoardById`,
##     `UpsertBoard`, `GetBoardTopRankings`, `GetBoardMyRank`, `ClearBoards`,
##     `auto-load-on-login`, per-board caching) are ported as their direct
##     equivalents. The auto-load and auto-clear-on-logout side-effects are
##     intentionally NOT ported in M6b — they tangle with M2 auth signals
##     and are better driven by app code (TODO M7+).
##   - `submit(board_id, score)` and `around_me(board_id, window)` referenced
##     in `docs/examples/leaderboard.md` have NO upstream endpoint in
##     ss-unity v0.2.40d (discovery confirmed: 4 read-only endpoints only).
##     The methods + signals are reserved as TODOs and return a
##     "not implemented" envelope so app code can wire them now.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.leaderboard` from app code.
##
## upstream: 7_Leaderboard/Leaderboard.cs:8
class_name Leaderboard
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: Leaderboard.cs:131
const PATH_BOARDS := "/api/v1/games/{game_id}/leaderboards"

## upstream: Leaderboard.cs:199
const PATH_BOARD := "/api/v1/games/{game_id}/leaderboards/{board_id}"

## upstream: Leaderboard.cs:273
const PATH_TOP := "/api/v1/games/{game_id}/leaderboards/{board_id}/top"

## upstream: Leaderboard.cs:344
const PATH_ME := "/api/v1/games/{game_id}/leaderboards/{board_id}/me"

# -------------------------------------------------------------------------
# Defaults (mirror upstream Inspector fields)
# -------------------------------------------------------------------------

## upstream: Leaderboard.cs:31 (topN)
const DEFAULT_TOP_N := 10

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `list_boards()`. `boards` is `Array[LeaderboardData]`.
## upstream: Leaderboard.cs:11 (OnListBoardsSuccess)
signal list_loaded(boards: Array)
## upstream: Leaderboard.cs:12 (OnListBoardsFailure)
signal list_failed(error: String)

## Emitted on successful `get_board(board_id)`.
## upstream: Leaderboard.cs:13 (OnGetBoardSuccess)
signal board_loaded(board: LeaderboardData)
## upstream: Leaderboard.cs:14 (OnGetBoardFailure)
signal board_failed(board_id: String, error: String)

## Emitted on successful `top(board_id, limit)`. `entries` is
## `Array[LeaderboardEntry]`. `total` mirrors server-reported count.
## upstream: Leaderboard.cs:15 (OnGetTopRankingsSuccess)
signal top_loaded(board_id: String, entries: Array, total: int)
## upstream: Leaderboard.cs:16 (OnGetTopRankingsFailure)
signal top_failed(board_id: String, error: String)

## Emitted on successful `my_rank(board_id)`.
## upstream: Leaderboard.cs:17 (OnGetLocalRankingSuccess)
signal my_rank_loaded(board_id: String, rank: LeaderboardLocalRank)
## upstream: Leaderboard.cs:18 (OnGetLocalRankingFailure)
signal my_rank_failed(board_id: String, error: String)

## Reserved for the (currently-unimplemented) submit endpoint.
## See `submit()` for the deferred TODO.
signal submit_success(board_id: String, score: float)
signal submit_failed(board_id: String, error: String)

## Reserved for the (currently-unimplemented) around-me / window endpoint.
## See `around_me()` for the deferred TODO.
signal around_me_loaded(board_id: String, entries: Array)
signal around_me_failed(board_id: String, error: String)

# -------------------------------------------------------------------------
# Cached state (mirrors upstream's per-board dictionaries)
# -------------------------------------------------------------------------

## Last board list returned by `list_boards()`. Empty until first success.
## upstream: Leaderboard.cs:24 (currentBoards)
var cached_boards: Array[LeaderboardData] = []

## Per-board cached top rankings, keyed by board id. Values are
## `{entries: Array[LeaderboardEntry], total: int, limit: int}`.
## upstream: Leaderboard.cs:34 (boardTopRankings)
var cached_top_rankings: Dictionary = {}

## Per-board cached "my rank" responses, keyed by board id. Values are
## LeaderboardLocalRank instances.
## upstream: Leaderboard.cs:37 (boardMyRanks)
var cached_my_ranks: Dictionary = {}

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/leaderboards
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `boards`: Array[LeaderboardData]
##   - `raw`: original Dictionary as returned by the server.
##
## upstream: Leaderboard.cs:108 (ListBoards), Leaderboard.cs:128 (Coroutine)
func list_boards() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		list_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		list_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_BOARDS.replace("{game_id}", game_id)
	var result: Dictionary = await server.get_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list boards failed"))
		list_failed.emit(error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var boards: Array[LeaderboardData] = []
	var raw_boards: Variant = raw.get("boards", null)
	if raw_boards is Array:
		for entry in raw_boards as Array:
			boards.append(LeaderboardData.from_dict(entry))
	cached_boards = boards
	list_loaded.emit(boards)

	var out := result.duplicate(true)
	out["data"] = {
		"boards": boards,
		"raw": raw,
	}
	return out


## GET /api/v1/games/{game_id}/leaderboards/{board_id}
##
## Upstream tolerates two response shapes: `{board: {...}}` and a flat board.
## We try wrapped first then fall back to flat, matching Leaderboard.cs:206-210.
##
## On success, `data` is `{board: LeaderboardData, raw: Dictionary}`.
##
## upstream: Leaderboard.cs:170 (GetBoard), Leaderboard.cs:196 (Coroutine)
func get_board(board_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		board_failed.emit(board_id, err)
		return _envelope_fail(err)

	if board_id == null or String(board_id).is_empty():
		# upstream: Leaderboard.cs:187-191 — refuse before sending.
		var err := "board_id cannot be empty"
		board_failed.emit(board_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		board_failed.emit(board_id, err)
		return _envelope_fail(err)

	var path: String = PATH_BOARD.replace("{game_id}", game_id).replace("{board_id}", board_id)
	var result: Dictionary = await server.get_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "get board failed"))
		board_failed.emit(board_id, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var board: LeaderboardData = _extract_board(raw)
	_upsert_board(board)
	board_loaded.emit(board)

	var out := result.duplicate(true)
	out["data"] = {"board": board, "raw": raw}
	return out


## GET /api/v1/games/{game_id}/leaderboards/{board_id}/top?limit={limit}
##
## On success, `data` is `{entries: Array[LeaderboardEntry], total: int,
## limit: int, raw: Dictionary}`.
##
## upstream: Leaderboard.cs:243 (GetTopRankings), Leaderboard.cs:270 (Coroutine)
func top(board_id: String, limit: int = DEFAULT_TOP_N) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		top_failed.emit(board_id, err)
		return _envelope_fail(err)

	if board_id == null or String(board_id).is_empty():
		# upstream: Leaderboard.cs:260-264
		var err := "board_id cannot be empty"
		top_failed.emit(board_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		top_failed.emit(board_id, err)
		return _envelope_fail(err)

	var path: String = PATH_TOP.replace("{game_id}", game_id).replace("{board_id}", board_id)
	var query: Dictionary = {"limit": limit}
	var result: Dictionary = await server.get_request(path, query, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "top rankings failed"))
		top_failed.emit(board_id, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var entries: Array[LeaderboardEntry] = []
	var raw_entries: Variant = raw.get("entries", null)
	if raw_entries is Array:
		for entry in raw_entries as Array:
			entries.append(LeaderboardEntry.from_dict(entry))
	var total: int = int(raw.get("total", entries.size()))
	var actual_limit: int = int(raw.get("limit", limit))
	# upstream: Leaderboard.cs:284 — store per-board.
	cached_top_rankings[board_id] = {
		"entries": entries,
		"total": total,
		"limit": actual_limit,
	}
	top_loaded.emit(board_id, entries, total)

	var out := result.duplicate(true)
	out["data"] = {
		"entries": entries,
		"total": total,
		"limit": actual_limit,
		"raw": raw,
	}
	return out


## GET /api/v1/games/{game_id}/leaderboards/{board_id}/me
##
## On success, `data` is `{rank: LeaderboardLocalRank, raw: Dictionary}`.
##
## upstream: Leaderboard.cs:315 (GetLocalRanking), Leaderboard.cs:341 (Coroutine)
func my_rank(board_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		my_rank_failed.emit(board_id, err)
		return _envelope_fail(err)

	if board_id == null or String(board_id).is_empty():
		# upstream: Leaderboard.cs:332-336
		var err := "board_id cannot be empty"
		my_rank_failed.emit(board_id, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		my_rank_failed.emit(board_id, err)
		return _envelope_fail(err)

	var path: String = PATH_ME.replace("{game_id}", game_id).replace("{board_id}", board_id)
	var result: Dictionary = await server.get_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "my rank failed"))
		my_rank_failed.emit(board_id, error_msg)
		return result

	var data: Variant = result.get("data", null)
	var raw: Dictionary = data if data is Dictionary else {}
	var rank: LeaderboardLocalRank = LeaderboardLocalRank.from_dict(raw)
	# upstream: Leaderboard.cs:355 — store per-board.
	cached_my_ranks[board_id] = rank
	my_rank_loaded.emit(board_id, rank)

	var out := result.duplicate(true)
	out["data"] = {"rank": rank, "raw": raw}
	return out


## TODO M7+: no upstream endpoint for score submission in ss-unity v0.2.40d.
##
## Discovery (docs/endpoints.md `## Leaderboard`) confirmed only 4 read-only
## endpoints. `submit_success` / `submit_failed` are reserved so app code can
## wire signals now; this method returns a failure envelope and emits
## `submit_failed`. Once the backend ships a submit route, this is where the
## POST should land.
##
## See docs/examples/leaderboard.md `## Submit score` for the intended API.
func submit(board_id: String, _score: float) -> Dictionary:
	var err := "submit endpoint is not implemented in upstream v0.2.40d"
	submit_failed.emit(board_id, err)
	return _envelope_fail(err)


## TODO M7+: no upstream endpoint for player-centered window in ss-unity v0.2.40d.
##
## `around_me_loaded` / `around_me_failed` are reserved so app code can wire
## signals now; this method returns a failure envelope and emits
## `around_me_failed`. Callers who want a "window around me" today can
## combine `my_rank()` + `top()` client-side.
##
## See docs/examples/leaderboard.md `## Fetch around me` for the intended API.
func around_me(board_id: String, _window: int = 10) -> Dictionary:
	var err := "around_me endpoint is not implemented in upstream v0.2.40d"
	around_me_failed.emit(board_id, err)
	return _envelope_fail(err)


# =========================================================================
# Convenience query helpers (operate on `cached_boards`)
# =========================================================================


## upstream: Leaderboard.cs:456 (GetBoardById)
func get_board_by_id(board_id: String) -> LeaderboardData:
	for b in cached_boards:
		if b != null and b.id == board_id:
			return b
	return null


## upstream: Leaderboard.cs:442 (GetBoardByKey)
func get_board_by_key(board_key: String) -> LeaderboardData:
	for b in cached_boards:
		if b != null and b.board_key == board_key:
			return b
	return null


## Active-only filter — handy for UI listings.
func get_active_boards() -> Array[LeaderboardData]:
	var result: Array[LeaderboardData] = []
	for b in cached_boards:
		if b != null and b.is_active:
			result.append(b)
	return result


## upstream: Leaderboard.cs:500 (GetBoardTopRankings)
##
## Returns the cached top-rankings entry for `board_id`, or an empty
## Dictionary if `top(board_id, ...)` has not been called yet.
func get_cached_top(board_id: String) -> Dictionary:
	if board_id.is_empty():
		return {}
	var cached: Variant = cached_top_rankings.get(board_id, null)
	return cached if cached is Dictionary else {}


## upstream: Leaderboard.cs:511 (GetBoardMyRank)
func get_cached_my_rank(board_id: String) -> LeaderboardLocalRank:
	if board_id.is_empty():
		return null
	var cached: Variant = cached_my_ranks.get(board_id, null)
	return cached if cached is LeaderboardLocalRank else null


## upstream: Leaderboard.cs:386 (ClearBoards), Leaderboard.cs:522 (ClearBoardTopRankings)
func clear_boards() -> void:
	cached_boards = []
	cached_top_rankings.clear()
	cached_my_ranks.clear()


## True iff `cached_boards` is non-empty.
## upstream: Leaderboard.cs:40 (HasBoards)
func has_boards() -> bool:
	return cached_boards.size() > 0


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirrors Shop._server (shop/shop.gd:359-372): prefer parent, fall back
	# to autoload, then to the scene tree — keeps the class testable under a
	# fake-parent harness.
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


## Extract a LeaderboardData from the dual-shape GET response. Upstream tries
## wrapped first (`{board: {...}}`, LeaderboardBoardResponse.cs:7) and falls
## back to a flat board (Leaderboard.cs:206-210).
func _extract_board(data: Variant) -> LeaderboardData:
	if not (data is Dictionary):
		return LeaderboardData.new()
	var dict: Dictionary = data
	# Wrapped: `{ "board": {...} }`
	var wrapped: Variant = dict.get("board", null)
	if wrapped is Dictionary and String((wrapped as Dictionary).get("id", "")) != "":
		return LeaderboardData.from_dict(wrapped)
	# Flat: LeaderboardBoard at top level.
	if String(dict.get("id", "")) != "":
		return LeaderboardData.from_dict(dict)
	return LeaderboardData.new()


## Insert or replace `board` in `cached_boards`, keyed by `board.id`.
## upstream: Leaderboard.cs:406 (UpsertBoard)
func _upsert_board(board: LeaderboardData) -> void:
	if board == null or board.id.is_empty():
		return
	for i in cached_boards.size():
		if cached_boards[i] != null and cached_boards[i].id == board.id:
			cached_boards[i] = board
			return
	cached_boards.append(board)


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
