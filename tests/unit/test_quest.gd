## Unit tests for the M5b Quest sub-services (ChainQuest, QuestProgressor,
## QuestHistory, DailyQuest).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Mirrors the structure of `tests/unit/test_gamer_progress.gd`.
## Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 5_Quest/Chain/ChainQuest.cs, 5_Quest/Progress/QuestProgressor.cs,
##                  5_Quest/Claims/QuestHistory.cs, 5_Quest/Daily/DailyQuest.cs
extends "res://addons/gut/test.gd"

const CHAIN_QUEST := preload("res://addons/sai_services/quest/chain_quest.gd")
const QUEST_PROGRESSOR := preload("res://addons/sai_services/quest/quest_progressor.gd")
const QUEST_HISTORY := preload("res://addons/sai_services/quest/quest_history.gd")
const DAILY_QUEST := preload("res://addons/sai_services/quest/daily_quest.gd")

const GAME_ID := "g_test"
const CHAIN_ID := "ch_001"
const QUEST_ID := "q_001"
const POOL_ID := "pool_main"

# =========================================================================
# Test double — minimal stand-in for the SaiServer autoload.
# =========================================================================


class FakeSaiServer:
	extends Node

	var _next_responses: Array = []
	var calls: Array = []

	var _access_token: String = "AT_test"
	var game_id: String = "g_test"

	# Typed accessors so the production code's `server.quest_progressor`
	# lookup path is exercised in tests too.
	var chain_quest: Node = null
	var quest_progressor: Node = null
	var quest_history: Node = null
	var daily_quest: Node = null

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

	func set_unauthenticated() -> void:
		_access_token = ""


# =========================================================================
# Fixture
# =========================================================================

var _server: FakeSaiServer = null
var _chain: ChainQuest = null
var _progressor: QuestProgressor = null
var _history: QuestHistory = null
var _daily: DailyQuest = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)

	_chain = CHAIN_QUEST.new()
	_chain.name = "ChainQuest"
	_server.add_child(_chain)
	_server.chain_quest = _chain

	_progressor = QUEST_PROGRESSOR.new()
	_progressor.name = "QuestProgressor"
	_server.add_child(_progressor)
	_server.quest_progressor = _progressor

	_history = QUEST_HISTORY.new()
	_history.name = "QuestHistory"
	_server.add_child(_history)
	_server.quest_history = _history

	_daily = DAILY_QUEST.new()
	_daily.name = "DailyQuest"
	_server.add_child(_daily)
	_server.daily_quest = _daily


# =========================================================================
# ChainQuest.list_chain
# =========================================================================


func test_list_chain_happy_path_emits_success_and_caches_chains() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"chains":
					[
						{
							"id": CHAIN_ID,
							"chain_key": "main",
							"display_name": "Main",
							"is_active": true
						},
						{
							"id": "ch_002",
							"chain_key": "side",
							"display_name": "Side",
							"is_active": false
						},
					],
					"limit": 50,
					"offset": 0,
					"total": 2,
				},
			}
		)
	)
	watch_signals(_chain)

	var result: Dictionary = await _chain.list_chain(50, 0)

	assert_true(result.get("success", false), "list_chain should report success")
	assert_signal_emitted(_chain, "list_chain_success")
	assert_eq(_chain.current_chains.size(), 2, "chains cached")
	assert_eq(_chain.last_total(), 2)
	assert_eq(_server.calls[0]["method"], "GET")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/chains")
	assert_eq(_server.calls[0]["query"]["limit"], 50)
	assert_eq(_server.calls[0]["query"]["offset"], 0)
	# Convenience helpers work against the cache.
	var by_id: Variant = _chain.get_chain_by_id(CHAIN_ID)
	assert_true(by_id is Dictionary)
	assert_eq(String(by_id["chain_key"]), "main")


func test_list_chain_when_unauthenticated_fails_fast() -> void:
	_server.set_unauthenticated()
	watch_signals(_chain)

	var result: Dictionary = await _chain.list_chain()

	assert_false(result.get("success", true))
	assert_signal_emitted(_chain, "list_chain_failed")
	assert_eq(_server.calls.size(), 0, "must not hit network when unauthenticated")


func test_list_chain_server_error_emits_failed() -> void:
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 500,
				"error": "server_down",
				"data": null,
			}
		)
	)
	watch_signals(_chain)

	await _chain.list_chain()

	assert_signal_emitted(_chain, "list_chain_failed")
	assert_signal_emitted_with_parameters(_chain, "list_chain_failed", ["server_down"])


# =========================================================================
# ChainQuest.get_chain_detail / advance_chain (facade)
# =========================================================================


func test_get_chain_detail_flattens_tree_and_computes_steps() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"chain_id": CHAIN_ID,
					"chain_name": "Main",
					"nodes":
					[
						{
							"quest_id": "q1",
							"quest_name": "First",
							"status": "completed",
							"children":
							[
								{
									"quest_id": "q2",
									"quest_name": "Second",
									"status": "in_progress",
									"children":
									[
										{
											"quest_id": "q3",
											"quest_name": "Third",
											"status": "not_started",
											"children": []
										},
									],
								},
							],
						},
					],
				},
			}
		)
	)
	watch_signals(_chain)

	var result: Dictionary = await _chain.get_chain_detail(CHAIN_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_chain, "chain_advance_success")
	var payload: Dictionary = result.get("data", {})
	assert_eq(int(payload.get("total_steps", 0)), 3, "3 nodes flattened")
	assert_eq(int(payload.get("current_step", 0)), 2, "in_progress node is step 2")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/chains/ch_001/tree")


func test_advance_chain_facade_calls_progressor_start_endpoint() -> void:
	# Two queued responses: list_chain (unused here) is not needed — only the start.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "p_001",
					"quest_definition_id": QUEST_ID,
					"status": "in_progress",
					"version": 1,
				},
			}
		)
	)
	watch_signals(_chain)

	var result: Dictionary = await _chain.advance_chain(QUEST_ID)

	assert_true(result.get("success", false), "advance_chain (facade) succeeds")
	assert_signal_emitted(_chain, "chain_advance_success")
	# Must have hit the progressor's `start` endpoint.
	assert_eq(_server.calls[0]["method"], "POST")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/q_001/start")


func test_advance_chain_facade_emits_failed_when_progressor_missing() -> void:
	# Tear down the progressor sibling and rebuild only the chain to prove
	# the delegation guard fires `chain_advance_failed`.
	_progressor.queue_free()
	_server.quest_progressor = null
	await get_tree().process_frame
	watch_signals(_chain)

	var result: Dictionary = await _chain.advance_chain(QUEST_ID)

	assert_false(result.get("success", true))
	assert_signal_emitted(_chain, "chain_advance_failed")


# =========================================================================
# QuestProgressor.start_quest
# =========================================================================


func test_start_quest_happy_path() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "p_001",
					"studio_id": "s_1",
					"game_id": GAME_ID,
					"user_id": "u_001",
					"quest_definition_id": QUEST_ID,
					"status": "in_progress",
					"version": 1,
					"created_at": "2026-05-20T00:00:00Z",
					"updated_at": "2026-05-20T00:00:00Z",
				},
			}
		)
	)
	watch_signals(_progressor)

	var result: Dictionary = await _progressor.start_quest(QUEST_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_progressor, "start_quest_success")
	assert_eq(_server.calls[0]["method"], "POST")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/q_001/start")
	assert_eq(_progressor.last_started.get("id", ""), "p_001")


func test_start_quest_empty_id_fails_fast() -> void:
	watch_signals(_progressor)

	var result: Dictionary = await _progressor.start_quest("")

	assert_false(result.get("success", true))
	assert_signal_emitted(_progressor, "start_quest_failed")
	assert_eq(_server.calls.size(), 0)


# =========================================================================
# QuestProgressor.increment_progress (alias of check_quest with delta body)
# =========================================================================


func test_increment_progress_emits_quest_completed_when_status_completed() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"progress":
					{
						"id": "p_001",
						"quest_definition_id": QUEST_ID,
						"status": "completed",
						"version": 2,
					},
					"quest_definition": {"id": QUEST_ID, "name": "Kill 10 goblins"},
					"status": "completed",
				},
			}
		)
	)
	watch_signals(_progressor)

	var result: Dictionary = await _progressor.increment_progress("kill_goblin", 1)

	assert_true(result.get("success", false))
	assert_signal_emitted(_progressor, "check_quest_success")
	assert_signal_emitted(_progressor, "quest_completed")
	# Endpoint reuses the check path.
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/kill_goblin/check")
	assert_eq(int(_server.calls[0]["body"]["delta"]), 1)


func test_increment_progress_no_complete_signal_when_in_progress() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"progress": {"status": "in_progress"},
					"quest_definition": {"id": QUEST_ID, "name": "Collect 5 crystals"},
					"status": "in_progress",
				},
			}
		)
	)
	watch_signals(_progressor)

	await _progressor.increment_progress("collect_crystal", 3)

	assert_signal_emitted(_progressor, "check_quest_success")
	assert_signal_not_emitted(_progressor, "quest_completed")


# =========================================================================
# QuestProgressor.claim_quest -> QuestClaimRecord
# =========================================================================


func test_claim_quest_parses_record_and_emits_success() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "claim_001",
					"studio_id": "s_1",
					"game_id": GAME_ID,
					"user_id": "u_001",
					"quest_definition_id": QUEST_ID,
					"progress_id": "p_001",
					"idempotency_key": "idem_abc",
					"rewards_granted":
					[
						{
							"reward_type": "currency",
							"item_definition_id": "gold",
							"quantity": 100,
							"amount": 100
						},
					],
					"claimed_at": "2026-05-20T00:00:30Z",
				},
			}
		)
	)
	watch_signals(_progressor)

	var result: Dictionary = await _progressor.claim_quest(QUEST_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_progressor, "claim_quest_success")
	var record: QuestClaimRecord = result.get("data")
	assert_not_null(record, "data is a QuestClaimRecord")
	assert_eq(record.id, "claim_001")
	assert_eq(record.rewards_granted.size(), 1)
	assert_eq(_progressor.last_claimed.id, "claim_001")


# =========================================================================
# DailyQuest.claim_daily (proxy)
# =========================================================================


func test_claim_daily_calls_progressor_claim_path() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "claim_002",
					"quest_definition_id": QUEST_ID,
					"rewards_granted": [],
					"claimed_at": "2026-05-20T01:00:00Z",
				},
			}
		)
	)
	watch_signals(_daily)

	var result: Dictionary = await _daily.claim_daily(QUEST_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_daily, "daily_claim_success")
	assert_eq(_server.calls[0]["method"], "POST")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quests/q_001/claim")


func test_claim_daily_failure_emits_failed() -> void:
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 409,
				"error": "already_claimed",
				"data": null,
			}
		)
	)
	watch_signals(_daily)

	await _daily.claim_daily(QUEST_ID)

	assert_signal_emitted(_daily, "daily_claim_failed")
	assert_signal_emitted_with_parameters(
		_daily, "daily_claim_failed", [QUEST_ID, "already_claimed"]
	)


# =========================================================================
# DailyQuest.list_daily
# =========================================================================


func test_list_daily_parses_entries_and_emits_today_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"pool": {"id": POOL_ID, "display_name": "Main Pool"},
					"entries":
					[
						{
							"assignment":
							{
								"id": "a_1",
								"pool_id": POOL_ID,
								"assigned_date": "2026-05-20",
								"expires_at": ""
							},
							"quest": {"id": "q_1", "name": "Win 3 matches"},
							"status": "in_progress",
							"progress": {"status": "in_progress"},
							"rewards": [],
						},
						{
							"assignment":
							{
								"id": "a_2",
								"pool_id": POOL_ID,
								"assigned_date": "2026-05-20",
								"expires_at": ""
							},
							"quest": {"id": "q_2", "name": "Buy 1 item"},
							"status": "claimed",
							"progress": {"status": "claimed"},
							"rewards": [],
						},
					],
					"streak": {"current_streak": 3},
					"assigned_date": "2026-05-20",
				},
			}
		)
	)
	watch_signals(_daily)

	var result: Dictionary = await _daily.list_daily(POOL_ID)

	assert_true(result.get("success", false))
	assert_signal_emitted(_daily, "today_loaded")
	var data: Dictionary = result.get("data", {})
	var entries: Array = data.get("entries", [])
	assert_eq(entries.size(), 2)
	var first: DailyQuestData = entries[0]
	assert_eq(first.assignment_id, "a_1")
	assert_eq(first.quest.name, "Win 3 matches")
	assert_false(first.claimed)
	var second: DailyQuestData = entries[1]
	assert_true(second.claimed, "second entry status==claimed")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/daily-quests/pool_main")


# =========================================================================
# QuestHistory.history
# =========================================================================


func test_history_parses_claim_records_and_emits_loaded() -> void:
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"claims":
					[
						{
							"id": "claim_001",
							"quest_definition_id": "q_a",
							"rewards_granted": [],
							"claimed_at": "2026-05-19T20:00:00Z",
							"quest_definition": {"id": "q_a", "name": "Tutorial done"},
						},
					],
					"limit": 50,
					"offset": 0,
					"total": 1,
				},
			}
		)
	)
	watch_signals(_history)

	var result: Dictionary = await _history.history(50, 0)

	assert_true(result.get("success", false))
	assert_signal_emitted(_history, "history_loaded")
	var out: Dictionary = result.get("data", {})
	var entries: Array = out.get("entries", [])
	assert_eq(entries.size(), 1)
	var rec: QuestClaimRecord = entries[0]
	assert_eq(rec.id, "claim_001")
	assert_eq(rec.title, "Tutorial done")
	assert_eq(_history.last_total(), 1)
	assert_eq(_server.calls[0]["path"], "/api/v1/games/g_test/quest-claims")
