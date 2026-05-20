## Unit tests for Leaderboard (M6b).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_shop.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 7_Leaderboard/Leaderboard.cs
extends "res://addons/gut/test.gd"

const LEADERBOARD_SCRIPT := preload("res://addons/sai_services/leaderboard/leaderboard.gd")

const GAME_ID := "g_test"
const BOARD_ID := "lb_001"
const BOARD_KEY := "global_xp"
const USER_ID := "u_001"

# =========================================================================
# Test double: minimal stand-in for the SaiServer autoload.
# =========================================================================


class FakeSaiServer:
	extends Node

	var _next_responses: Array = []
	var calls: Array = []

	var _access_token: String = "AT_test"
	var game_id: String = "g_test"

	signal token_refreshed(access_token: String)

	func queue_response(response: Dictionary) -> void:
		_next_responses.append(response)

	func _take_next() -> Dictionary:
		if _next_responses.is_empty():
			return {"success": false, "status": 0, "error": "no_canned_response", "data": null}
		return _next_responses.pop_front()

	func get_request(path: String, query: Dictionary = {}, auth: bool = true) -> Dictionary:
		calls.append({"method": "GET", "path": path, "query": query, "auth": auth})
		return _take_next()

	func post_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "POST", "path": path, "body": body, "auth": auth})
		return _take_next()

	func patch_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "PATCH", "path": path, "body": body, "auth": auth})
		return _take_next()

	func delete_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "DELETE", "path": path, "body": body, "auth": auth})
		return _take_next()

	func is_authenticated() -> bool:
		return not _access_token.is_empty()

	func access_token() -> String:
		return _access_token

	func normalized_game_id() -> String:
		return game_id


# =========================================================================
# Fixture
# =========================================================================

var _server: FakeSaiServer = null
var _leaderboard: Leaderboard = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_leaderboard = LEADERBOARD_SCRIPT.new()
	_leaderboard.name = "Leaderboard"
	_server.add_child(_leaderboard)


# =========================================================================
# list_boards
# =========================================================================


func test_list_boards_success_returns_typed_boards_and_emits_list_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"boards":
					[
						{
							"id": BOARD_ID,
							"studio_id": "st_demo",
							"game_id": GAME_ID,
							"board_key": BOARD_KEY,
							"name": "Global XP",
							"description": "Lifetime XP ranking",
							"score_mode": "max",
							"sort_direction": "desc",
							"reset_schedule": "never",
							"season_id": "",
							"is_active": true,
							"max_score_delta": 0.0,
							"score_source_type": "client_submit",
							"score_source_ref_id": "",
							"created_at": "2026-05-20T00:00:00Z",
							"updated_at": "2026-05-20T00:00:00Z",
						},
						{
							"id": "lb_002",
							"board_key": "weekly_arena",
							"is_active": false,
						},
					],
				},
			}
		)
	)
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.list_boards()

	assert_true(result.get("success", false), "list_boards reports success")
	assert_signal_emitted(_leaderboard, "list_loaded")
	var data: Dictionary = result["data"]
	assert_eq((data["boards"] as Array).size(), 2, "two boards decoded")
	var board: LeaderboardData = (data["boards"] as Array)[0]
	assert_eq(board.id, BOARD_ID)
	assert_eq(board.board_key, BOARD_KEY)
	assert_true(board.is_active)
	# Cache populated.
	assert_eq(_leaderboard.cached_boards.size(), 2)
	# Path stamped correctly.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["method"]), "GET")
	assert_eq(String(call["path"]), "/api/v1/games/g_test/leaderboards")


func test_list_boards_failed_emits_list_failed_with_error_text() -> void:
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.list_boards()

	assert_false(result.get("success", true))
	assert_signal_emitted(_leaderboard, "list_failed")
	assert_signal_emitted_with_parameters(_leaderboard, "list_failed", ["boom"])


func test_list_boards_empty_game_id_fails_fast_without_network() -> void:
	_server.game_id = ""
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.list_boards()

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when game_id is empty")
	assert_signal_emitted(_leaderboard, "list_failed")


# =========================================================================
# get_board (wrapped + flat response shapes)
# =========================================================================


func test_get_board_success_with_wrapped_response_extracts_board() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"board":
					{
						"id": BOARD_ID,
						"board_key": BOARD_KEY,
						"name": "Global XP",
						"is_active": true,
					},
				},
			}
		)
	)
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.get_board(BOARD_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_leaderboard, "board_loaded")
	var board: LeaderboardData = result["data"]["board"]
	assert_eq(board.id, BOARD_ID)
	assert_eq(board.board_key, BOARD_KEY)
	# UpsertBoard populates the cache.
	assert_eq(_leaderboard.cached_boards.size(), 1)
	# Path stamped correctly.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["path"]), "/api/v1/games/g_test/leaderboards/lb_001")


func test_get_board_success_with_flat_response_falls_back_to_flat_shape() -> void:
	# Upstream Leaderboard.cs:206-210 tries wrapped first then flat.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": BOARD_ID,
					"board_key": BOARD_KEY,
					"name": "Global XP",
					"is_active": true,
				},
			}
		)
	)

	var result: Dictionary = await _leaderboard.get_board(BOARD_ID)

	assert_true(result.get("success", false))
	var board: LeaderboardData = result["data"]["board"]
	assert_eq(board.id, BOARD_ID)


func test_get_board_empty_id_fails_fast_without_network() -> void:
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.get_board("")

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "no HTTP call when board_id is empty")
	assert_signal_emitted(_leaderboard, "board_failed")


# =========================================================================
# top
# =========================================================================


func test_top_success_returns_typed_entries_and_emits_top_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"entries":
					[
						{
							"rank": 1,
							"user_id": USER_ID,
							"display_name": "alice",
							"score": 12450.0,
							"metadata": "",
							"updated_at": "2026-05-20T00:00:00Z",
						},
						{
							"rank": 2,
							"user_id": "u_002",
							"display_name": "bob",
							"score": 9000.5,
							"metadata": "",
							"updated_at": "2026-05-20T00:00:00Z",
						},
					],
					"limit": 10,
					"total": 2,
				},
			}
		)
	)
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.top(BOARD_ID, 10)

	assert_true(result.get("success", false))
	assert_signal_emitted(_leaderboard, "top_loaded")
	var data: Dictionary = result["data"]
	assert_eq(int(data["total"]), 2)
	assert_eq(int(data["limit"]), 10)
	var entries: Array = data["entries"]
	assert_eq(entries.size(), 2)
	var first: LeaderboardEntry = entries[0]
	assert_eq(first.rank, 1)
	assert_eq(first.user_id, USER_ID)
	assert_eq(first.display_name, "alice")
	assert_almost_eq(first.score, 12450.0, 0.01)
	# Per-board cache populated.
	var cached: Dictionary = _leaderboard.get_cached_top(BOARD_ID)
	assert_eq(int(cached["total"]), 2)
	# Path + query.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["path"]), "/api/v1/games/g_test/leaderboards/lb_001/top")
	assert_eq(int(call["query"]["limit"]), 10)


func test_top_default_limit_used_when_caller_omits_one() -> void:
	_server.queue_response(
		{"success": true, "status": 200, "error": "", "data": {"entries": [], "total": 0}}
	)

	var _r: Dictionary = await _leaderboard.top(BOARD_ID)
	var call: Dictionary = _server.calls[0]
	assert_eq(int(call["query"]["limit"]), 10, "DEFAULT_TOP_N propagates")


func test_top_empty_board_id_fails_fast() -> void:
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.top("", 10)

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_leaderboard, "top_failed")


func test_top_failed_emits_top_failed_with_board_id_and_error() -> void:
	_server.queue_response(
		{"success": false, "status": 404, "error": "board_not_found", "data": null}
	)
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.top(BOARD_ID, 5)

	assert_false(result.get("success", true))
	assert_signal_emitted(_leaderboard, "top_failed")
	assert_signal_emitted_with_parameters(_leaderboard, "top_failed", [BOARD_ID, "board_not_found"])


# =========================================================================
# my_rank
# =========================================================================


func test_my_rank_success_returns_typed_rank_and_emits_my_rank_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"rank": 42,
					"user_id": USER_ID,
					"score": 5000.0,
					"metadata": "",
					"season": {"id": "season_3", "season_number": 3},
					"updated_at": "2026-05-20T00:00:00Z",
				},
			}
		)
	)
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.my_rank(BOARD_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_leaderboard, "my_rank_loaded")
	var rank: LeaderboardLocalRank = result["data"]["rank"]
	assert_eq(rank.rank, 42)
	assert_eq(rank.user_id, USER_ID)
	assert_almost_eq(rank.score, 5000.0, 0.01)
	assert_eq(int(rank.season.get("season_number", 0)), 3)
	# Per-board cache populated.
	var cached: LeaderboardLocalRank = _leaderboard.get_cached_my_rank(BOARD_ID)
	assert_not_null(cached)
	assert_eq(cached.rank, 42)
	# Path.
	var call: Dictionary = _server.calls[0]
	assert_eq(String(call["path"]), "/api/v1/games/g_test/leaderboards/lb_001/me")


func test_my_rank_empty_board_id_fails_fast() -> void:
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.my_rank("")

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0)
	assert_signal_emitted(_leaderboard, "my_rank_failed")


# =========================================================================
# Convenience helpers over the cache
# =========================================================================


func test_get_board_by_id_and_key_find_cached_entries() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"boards":
					[
						{"id": BOARD_ID, "board_key": BOARD_KEY, "is_active": true},
						{"id": "lb_002", "board_key": "weekly", "is_active": false},
					],
				},
			}
		)
	)
	await _leaderboard.list_boards()

	assert_eq(_leaderboard.get_board_by_id(BOARD_ID).board_key, BOARD_KEY)
	assert_eq(_leaderboard.get_board_by_key("weekly").id, "lb_002")
	assert_eq(_leaderboard.get_active_boards().size(), 1)
	assert_true(_leaderboard.has_boards())

	_leaderboard.clear_boards()
	assert_false(_leaderboard.has_boards())


# =========================================================================
# submit / around_me — deferred TODOs
# =========================================================================


func test_submit_returns_not_implemented_envelope_and_emits_submit_failed() -> void:
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.submit(BOARD_ID, 1234.0)

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "submit must not hit network until backend exists")
	assert_signal_emitted(_leaderboard, "submit_failed")


func test_around_me_returns_not_implemented_envelope_and_emits_around_me_failed() -> void:
	watch_signals(_leaderboard)

	var result: Dictionary = await _leaderboard.around_me(BOARD_ID, 10)

	assert_false(result.get("success", true))
	assert_eq(_server.calls.size(), 0, "around_me must not hit network until backend exists")
	assert_signal_emitted(_leaderboard, "around_me_failed")
