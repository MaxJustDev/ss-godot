## LeaderboardEntry - one row in `LeaderboardRankingsResponse.entries`.
##
## Returned by `GET /api/v1/games/{game_id}/leaderboards/{board_id}/top`.
## Numerical `score` stays as float (server may return decimals).
##
## upstream: 7_Leaderboard/Models/LeaderboardRankingEntry.cs:5
class_name LeaderboardEntry
extends Resource

## 1-based rank from the server. Matches upstream `rank` field directly.
## upstream: LeaderboardRankingEntry.cs:8
@export var rank: int = 0

## upstream: LeaderboardRankingEntry.cs:9
@export var user_id: String = ""

## Human-readable name. Upstream field is `display_name` (LeaderboardRankingEntry.cs:10).
## upstream: LeaderboardRankingEntry.cs:10
@export var display_name: String = ""

## Score value. Upstream stores as float so we keep parity.
## upstream: LeaderboardRankingEntry.cs:11
@export var score: float = 0.0

## Free-form metadata string. Upstream leaves it as `string`; callers may
## JSON-parse on demand.
## upstream: LeaderboardRankingEntry.cs:12
@export var metadata: String = ""

## ISO-8601 timestamp of the score that earned this rank.
## upstream: LeaderboardRankingEntry.cs:13
@export var updated_at: String = ""


## Build a LeaderboardEntry from a raw JSON Dictionary.
##
## upstream: behavioural parity with
##   `JsonUtility.FromJson<LeaderboardRankingEntry>(...)`.
static func from_dict(d: Variant) -> LeaderboardEntry:
	var e := LeaderboardEntry.new()
	if not (d is Dictionary):
		return e
	var dict: Dictionary = d
	e.rank = int(dict.get("rank", 0))
	e.user_id = String(dict.get("user_id", ""))
	e.display_name = String(dict.get("display_name", ""))
	e.score = float(dict.get("score", 0.0))
	# Metadata may arrive as a raw object — re-stringify so callers always
	# get a String, matching upstream behaviour.
	var meta_raw: Variant = dict.get("metadata", "")
	if meta_raw is Dictionary or meta_raw is Array:
		e.metadata = JSON.stringify(meta_raw)
	else:
		e.metadata = String(meta_raw)
	e.updated_at = String(dict.get("updated_at", ""))
	return e


func to_dict() -> Dictionary:
	return {
		"rank": rank,
		"user_id": user_id,
		"display_name": display_name,
		"score": score,
		"metadata": metadata,
		"updated_at": updated_at,
	}
