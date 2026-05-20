## LeaderboardData - typed mirror of one `LeaderboardBoard` record.
##
## Returned by both `GET /api/v1/games/{game_id}/leaderboards` (wrapped in
## `{boards: [...]}`) and `GET /api/v1/games/{game_id}/leaderboards/{board_id}`
## (wrapped in `{board: {...}}` or flat).
##
## Timestamp fields stay as ISO-8601 strings, matching upstream Unity which
## stores them as `string` and lets callers parse on demand.
##
## upstream: 7_Leaderboard/Models/LeaderboardBoard.cs:5
class_name LeaderboardData
extends Resource

# -------------------------------------------------------------------------
# Board fields
# -------------------------------------------------------------------------

## Server-issued unique board id.
## upstream: LeaderboardBoard.cs:8
@export var id: String = ""

## upstream: LeaderboardBoard.cs:9
@export var studio_id: String = ""

## upstream: LeaderboardBoard.cs:10
@export var game_id: String = ""

## Stable human-readable key (e.g. "global_xp").
## upstream: LeaderboardBoard.cs:11
@export var board_key: String = ""

## upstream: LeaderboardBoard.cs:12
@export var name: String = ""

## upstream: LeaderboardBoard.cs:13
@export var description: String = ""

## How the server combines repeat scores: "max", "sum", "latest", etc.
## upstream: LeaderboardBoard.cs:14
@export var score_mode: String = ""

## Sort direction: "asc" or "desc".
## upstream: LeaderboardBoard.cs:15
@export var sort_direction: String = ""

## Reset cadence string ("daily", "weekly", "season", "never", ...).
## upstream: LeaderboardBoard.cs:16
@export var reset_schedule: String = ""

## Optional season id this board is bound to.
## upstream: LeaderboardBoard.cs:17
@export var season_id: String = ""

## upstream: LeaderboardBoard.cs:18
@export var is_active: bool = false

## Optional cap on per-submit delta (server-side anti-cheat).
## upstream: LeaderboardBoard.cs:19
@export var max_score_delta: float = 0.0

## How the server pulls scores: "client_submit", "currency", "stat", etc.
## upstream: LeaderboardBoard.cs:20
@export var score_source_type: String = ""

## upstream: LeaderboardBoard.cs:21
@export var score_source_ref_id: String = ""

## ISO-8601.
## upstream: LeaderboardBoard.cs:22
@export var created_at: String = ""

## ISO-8601.
## upstream: LeaderboardBoard.cs:23
@export var updated_at: String = ""


## Build a LeaderboardData from a raw JSON Dictionary. Missing keys default
## to the zero-value of their type; extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<LeaderboardBoard>(...)`.
static func from_dict(d: Variant) -> LeaderboardData:
	var b := LeaderboardData.new()
	if not (d is Dictionary):
		return b
	var dict: Dictionary = d
	b.id = String(dict.get("id", ""))
	b.studio_id = String(dict.get("studio_id", ""))
	b.game_id = String(dict.get("game_id", ""))
	b.board_key = String(dict.get("board_key", ""))
	b.name = String(dict.get("name", ""))
	b.description = String(dict.get("description", ""))
	b.score_mode = String(dict.get("score_mode", ""))
	b.sort_direction = String(dict.get("sort_direction", ""))
	b.reset_schedule = String(dict.get("reset_schedule", ""))
	b.season_id = String(dict.get("season_id", ""))
	b.is_active = bool(dict.get("is_active", false))
	b.max_score_delta = float(dict.get("max_score_delta", 0.0))
	b.score_source_type = String(dict.get("score_source_type", ""))
	b.score_source_ref_id = String(dict.get("score_source_ref_id", ""))
	b.created_at = String(dict.get("created_at", ""))
	b.updated_at = String(dict.get("updated_at", ""))
	return b


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"board_key": board_key,
		"name": name,
		"description": description,
		"score_mode": score_mode,
		"sort_direction": sort_direction,
		"reset_schedule": reset_schedule,
		"season_id": season_id,
		"is_active": is_active,
		"max_score_delta": max_score_delta,
		"score_source_type": score_source_type,
		"score_source_ref_id": score_source_ref_id,
		"created_at": created_at,
		"updated_at": updated_at,
	}
