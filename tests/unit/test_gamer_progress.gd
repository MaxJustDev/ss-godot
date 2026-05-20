## Unit tests for GamerProgress (M3a).
##
## Runs against a FakeSaiServer + FakeSaiAuth test double — does NOT hit a
## real backend. Requires the GUT framework (https://github.com/bitwes/Gut).
##
## upstream parity: 1_GamerProgress/GamerProgress.cs
extends "res://addons/gut/test.gd"

const GAMER_PROGRESS := preload("res://addons/sai_services/progress/gamer_progress.gd")

# =========================================================================
# Test doubles
# =========================================================================


class FakeSaiAuth:
	extends Node

	var _user: Dictionary = {}

	func get_current_user() -> Dictionary:
		return _user

	func set_user(u: Dictionary) -> void:
		_user = u


class FakeSaiServer:
	extends Node

	# Queued canned responses, one per call, in order.
	var _next_responses: Array = []
	# Recorded calls — each entry is `{method, path, body, query, auth}`.
	var calls: Array = []

	var _access_token: String = ""
	var _game_id: String = "test_game"
	# Public typed accessor mirroring the real SaiServer.
	var auth: FakeSaiAuth = null

	func _ready() -> void:
		# Attach a default auth child the way the real SaiServer does.
		if auth == null:
			auth = FakeSaiAuth.new()
			auth.name = "SaiAuth"
			add_child(auth)

	func queue_response(response: Dictionary) -> void:
		_next_responses.append(response)

	func _take_next() -> Dictionary:
		if _next_responses.is_empty():
			return {"success": false, "status": 0, "error": "no_canned_response", "data": null}
		return _next_responses.pop_front()

	func get_request(path: String, query: Dictionary = {}, auth_flag: bool = true) -> Dictionary:
		calls.append({"method": "GET", "path": path, "query": query, "auth": auth_flag})
		return _take_next()

	func post_request(path: String, body: Variant = null, auth_flag: bool = true) -> Dictionary:
		calls.append({"method": "POST", "path": path, "body": body, "auth": auth_flag})
		return _take_next()

	func patch_request(path: String, body: Variant = null, auth_flag: bool = true) -> Dictionary:
		calls.append({"method": "PATCH", "path": path, "body": body, "auth": auth_flag})
		return _take_next()

	func delete_request(path: String, body: Variant = null, auth_flag: bool = true) -> Dictionary:
		calls.append({"method": "DELETE", "path": path, "body": body, "auth": auth_flag})
		return _take_next()

	func is_authenticated() -> bool:
		return not _access_token.is_empty()

	func access_token() -> String:
		return _access_token

	func normalized_game_id() -> String:
		return _game_id

	func set_login(access: String, user: Dictionary) -> void:
		_access_token = access
		if auth != null:
			auth.set_user(user)


# =========================================================================
# Fixture helpers
# =========================================================================

var _server: FakeSaiServer = null
var _progress: GamerProgress = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)
	_progress = GAMER_PROGRESS.new()
	_progress.name = "GamerProgress"
	_server.add_child(_progress)


func _seed_login() -> void:
	_server.set_login("AT_123", {"id": "u_001", "username": "demo"})


# =========================================================================
# create()
# =========================================================================


func test_create_happy_path_emits_success_and_caches_progress() -> void:
	_seed_login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 201,
				"error": "",
				"data":
				{
					"data":
					{
						"id": "prog_001",
						"user_id": "u_001",
						"game_id": "test_game",
						"level": 1,
						"experience": 0,
						"gold": 100,
						"game_data": {"tutorial_done": false},
						"created_at": 1700000000,
						"updated_at": 1700000000,
						"version": 1,
					},
					"message": "created",
				},
			}
		)
	)
	watch_signals(_progress)

	var result: Dictionary = await _progress.create(
		{"gold": 100, "game_data": {"tutorial_done": false}}
	)

	assert_true(result.get("success", false), "create should report success")
	assert_signal_emitted(_progress, "create_success")
	var dto: GamerProgressData = result.get("data")
	assert_eq(dto.id, "prog_001")
	assert_eq(dto.gold, 100)
	assert_true(_progress.has_progress(), "current_progress cached")
	# Path substitution + body contents.
	assert_eq(_server.calls[0]["method"], "POST")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/gamer-progress")
	assert_eq(_server.calls[0]["body"]["user_id"], "u_001")
	assert_eq(_server.calls[0]["body"]["game_id"], "test_game")
	assert_eq(_server.calls[0]["body"]["gold"], 100)


func test_create_when_unauthenticated_fails_fast() -> void:
	# No login seeded.
	watch_signals(_progress)

	var result: Dictionary = await _progress.create({})

	assert_false(result.get("success", true))
	assert_signal_emitted(_progress, "create_failed")
	assert_eq(_server.calls.size(), 0, "must not hit network when unauthenticated")


func test_create_server_error_emits_create_failed() -> void:
	_seed_login()
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
	watch_signals(_progress)

	var result: Dictionary = await _progress.create({})

	assert_false(result.get("success", true))
	assert_signal_emitted(_progress, "create_failed")
	assert_signal_emitted_with_parameters(_progress, "create_failed", ["server_down"])


# =========================================================================
# get_mine()
# =========================================================================


func test_get_mine_happy_path_returns_dto_and_emits_get_success() -> void:
	_seed_login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "prog_001",
					"user_id": "u_001",
					"game_id": "test_game",
					"level": 7,
					"experience": 1234,
					"gold": 250,
					"game_data": {"chapter": 2},
					"created_at": 1700000000,
					"updated_at": 1700001000,
					"version": 3,
				},
			}
		)
	)
	watch_signals(_progress)

	var result: Dictionary = await _progress.get_mine()

	assert_true(result.get("success", false))
	assert_signal_emitted(_progress, "get_success")
	var dto: GamerProgressData = result.get("data")
	assert_eq(dto.level, 7)
	assert_eq(dto.experience, 1234)
	assert_eq(_server.calls[0]["method"], "GET")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/my-gamer-progress")


func test_get_mine_when_unauthenticated_fails_fast() -> void:
	watch_signals(_progress)

	var result: Dictionary = await _progress.get_mine()

	assert_false(result.get("success", true))
	assert_signal_emitted(_progress, "get_failed")
	assert_eq(_server.calls.size(), 0)


func test_get_mine_server_404_emits_get_failed() -> void:
	_seed_login()
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 404,
				"error": "not_found",
				"data": null,
			}
		)
	)
	watch_signals(_progress)

	await _progress.get_mine()

	assert_signal_emitted(_progress, "get_failed")
	assert_signal_emitted_with_parameters(_progress, "get_failed", ["not_found"])


# =========================================================================
# update()
# =========================================================================


func test_update_happy_path_emits_update_success_and_replaces_cache() -> void:
	_seed_login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"id": "prog_001",
					"user_id": "u_001",
					"game_id": "test_game",
					"level": 2,
					"experience": 250,
					"gold": 50,
					"game_data": {"chapter": 2},
					"created_at": 1700000000,
					"updated_at": 1700002000,
					"version": 4,
				},
			}
		)
	)
	watch_signals(_progress)

	var result: Dictionary = await (
		_progress
		. update(
			"prog_001",
			{
				"experience_delta": 250,
				"gold_delta": -50,
				"game_data": {"chapter": 2},
			}
		)
	)

	assert_true(result.get("success", false))
	assert_signal_emitted(_progress, "update_success")
	var dto: GamerProgressData = result.get("data")
	assert_eq(dto.experience, 250)
	assert_eq(dto.gold, 50)
	# Path uses progress_id, NOT game_id.
	assert_eq(_server.calls[0]["method"], "PATCH")
	assert_eq(_server.calls[0]["path"], "/api/v1/gamer-progress/prog_001")
	assert_eq(_server.calls[0]["body"]["experience_delta"], 250)
	assert_eq(_server.calls[0]["body"]["gold_delta"], -50)


func test_update_without_progress_id_fails_fast() -> void:
	_seed_login()
	watch_signals(_progress)

	var result: Dictionary = await _progress.update("", {"experience_delta": 10})

	assert_false(result.get("success", true))
	assert_signal_emitted(_progress, "update_failed")
	assert_eq(_server.calls.size(), 0, "must not hit network without progress id")


func test_update_server_error_emits_update_failed() -> void:
	_seed_login()
	(
		_server
		. queue_response(
			{
				"success": false,
				"status": 409,
				"error": "version_conflict",
				"data": null,
			}
		)
	)
	watch_signals(_progress)

	await _progress.update("prog_001", {"experience_delta": 10})

	assert_signal_emitted(_progress, "update_failed")
	assert_signal_emitted_with_parameters(_progress, "update_failed", ["version_conflict"])


# =========================================================================
# delete_mine()
# =========================================================================


func test_delete_mine_happy_path_wipes_cache_and_emits_delete_success() -> void:
	_seed_login()
	# Pre-seed a cached progress so we can prove it gets wiped.
	_progress.current_progress = (
		GamerProgressData
		. from_dict(
			{
				"id": "prog_001",
				"level": 5,
				"experience": 999,
				"gold": 42,
			}
		)
	)
	_server.queue_response({"success": true, "status": 200, "error": "", "data": null})
	watch_signals(_progress)

	var result: Dictionary = await _progress.delete_mine()

	assert_true(result.get("success", false))
	assert_signal_emitted(_progress, "delete_success")
	assert_false(_progress.has_progress(), "cache wiped")
	assert_eq(_server.calls[0]["method"], "DELETE")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/my-gamer-progress")


func test_delete_mine_when_server_fails_still_wipes_cache() -> void:
	# upstream parity: GamerProgress.cs:472-477 — clear locally even on error.
	_seed_login()
	_progress.current_progress = GamerProgressData.from_dict({"id": "prog_001"})
	_server.queue_response({"success": false, "status": 500, "error": "boom", "data": null})
	watch_signals(_progress)

	await _progress.delete_mine()

	assert_false(_progress.has_progress(), "cache wiped despite server failure")
	assert_signal_emitted(_progress, "delete_failed")
	assert_signal_emitted_with_parameters(_progress, "delete_failed", ["boom"])


func test_delete_mine_when_unauthenticated_wipes_locally_no_network() -> void:
	# upstream parity: GamerProgress.cs:448-453 — wipe locally, skip network.
	_progress.current_progress = GamerProgressData.from_dict({"id": "prog_001"})
	watch_signals(_progress)

	var result: Dictionary = await _progress.delete_mine()

	assert_true(result.get("success", false))
	assert_false(_progress.has_progress())
	assert_signal_emitted(_progress, "delete_success")
	assert_eq(_server.calls.size(), 0, "must not hit network when unauthenticated")
