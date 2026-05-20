## LeaderboardLocalRank - the calling player's own row.
##
## Returned by `GET /api/v1/games/{game_id}/leaderboards/{board_id}/me`.
## The `season` sub-object stays a Dictionary — upstream only reads `id` and
## `season_number` (LeaderboardSeason.cs:5), so a flat Dictionary keeps the
## port lean while preserving every field the server may add later.
##
## upstream: 7_Leaderboard/Responses/LeaderboardLocalRankingResponse.cs:5
class_name LeaderboardLocalRank
extends Resource

## 1-based rank in the board, or 0 if the player has no recorded score.
## upstream: LeaderboardLocalRankingResponse.cs:8
@export var rank: int = 0

## upstream: LeaderboardLocalRankingResponse.cs:9
@export var user_id: String = ""

## upstream: LeaderboardLocalRankingResponse.cs:10
@export var score: float = 0.0

## upstream: LeaderboardLocalRankingResponse.cs:11
@export var metadata: String = ""

## Season snapshot — `{id: String, season_number: int}` per upstream
## LeaderboardSeason.cs.
## upstream: LeaderboardLocalRankingResponse.cs:12
@export var season: Dictionary = {}

## ISO-8601.
## upstream: LeaderboardLocalRankingResponse.cs:13
@export var updated_at: String = ""


## Build a LeaderboardLocalRank from a raw JSON Dictionary.
##
## upstream: behavioural parity with
##   `JsonUtility.FromJson<LeaderboardLocalRankingResponse>(...)`.
static func from_dict(d: Variant) -> LeaderboardLocalRank:
	var r := LeaderboardLocalRank.new()
	if not (d is Dictionary):
		return r
	var dict: Dictionary = d
	r.rank = int(dict.get("rank", 0))
	r.user_id = String(dict.get("user_id", ""))
	r.score = float(dict.get("score", 0.0))
	var meta_raw: Variant = dict.get("metadata", "")
	if meta_raw is Dictionary or meta_raw is Array:
		r.metadata = JSON.stringify(meta_raw)
	else:
		r.metadata = String(meta_raw)
	var season_raw: Variant = dict.get("season", null)
	r.season = season_raw if season_raw is Dictionary else {}
	r.updated_at = String(dict.get("updated_at", ""))
	return r


func to_dict() -> Dictionary:
	return {
		"rank": rank,
		"user_id": user_id,
		"score": score,
		"metadata": metadata,
		"season": season,
		"updated_at": updated_at,
	}
