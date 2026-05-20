## BattleData - typed mirror of one entry in `BattleSessionsResponse.sessions`.
##
## Returned by `GET /api/v1/games/{game_id}/me/battle-sessions` (list). The
## upstream wire shape (`8_Battle/Models/BattleSessionData.cs`) carries an
## `id` plus identifiers, timestamp strings, and two nested sub-structures
## (`start_data` + `end_data`). The nested structures hold dynamic per-game
## battle state — we surface them as plain `Dictionary` so callers can stay
## flexible without us inventing a fixed schema.
##
## Per CLAUDE.md C.1 we keep timestamp fields as ISO-8601 / RFC-3339 strings
## (matching upstream Unity which stores them as `string`) and let callers
## parse on demand.
##
## upstream: 8_Battle/Models/BattleSessionData.cs:7
class_name BattleData
extends Resource

# -------------------------------------------------------------------------
# Identifier fields
# -------------------------------------------------------------------------

## Server-issued unique session id.
## upstream: 8_Battle/Models/BattleSessionData.cs:9
@export var id: String = ""

## upstream: 8_Battle/Models/BattleSessionData.cs:10
@export var game_id: String = ""

## upstream: 8_Battle/Models/BattleSessionData.cs:11
@export var player_id: String = ""

## Free-form server status (e.g. `"in_progress"`, `"finished"`).
## upstream: 8_Battle/Models/BattleSessionData.cs:12
@export var status: String = ""

# -------------------------------------------------------------------------
# Timestamps (ISO-8601 strings; empty when server omits)
# -------------------------------------------------------------------------

## upstream: 8_Battle/Models/BattleSessionData.cs:13
@export var started_at: String = ""

## upstream: 8_Battle/Models/BattleSessionData.cs:14
@export var expires_at: String = ""

## upstream: 8_Battle/Models/BattleSessionData.cs:15
@export var ended_at: String = ""

# -------------------------------------------------------------------------
# Nested payloads — kept as raw Dictionary so per-game schema stays flexible
# -------------------------------------------------------------------------

## Mirror of `BattleStartData`. Kept raw because upstream's reference shape
## (`{battle_log[], battle_over, enemies[], player_chars[], turn, victory}`,
## `BattleStartData.cs:8`) is a suggestion only — actual fields depend on
## the per-game battle script. Empty Dictionary when the server omits.
## upstream: 8_Battle/Models/BattleSessionData.cs:16
@export var start_data: Dictionary = {}

## Mirror of `BattleEndData`. Kept raw for the same reason as `start_data`.
## Reference shape: `{kills, summary, survival_pct, turns_taken, victory}`
## (`BattleEndData.cs:8`).
## upstream: 8_Battle/Models/BattleSessionData.cs:17
@export var end_data: Dictionary = {}


## Build a BattleData from a raw JSON Dictionary. Missing keys default to
## the zero-value of their type; extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<BattleSessionData>(...)`.
static func from_dict(d: Variant) -> BattleData:
	var b := BattleData.new()
	if not (d is Dictionary):
		return b
	var dict: Dictionary = d
	b.id = String(dict.get("id", ""))
	b.game_id = String(dict.get("game_id", ""))
	b.player_id = String(dict.get("player_id", ""))
	b.status = String(dict.get("status", ""))
	b.started_at = String(dict.get("started_at", ""))
	b.expires_at = String(dict.get("expires_at", ""))
	b.ended_at = String(dict.get("ended_at", ""))
	var raw_start: Variant = dict.get("start_data", null)
	b.start_data = raw_start if raw_start is Dictionary else {}
	var raw_end: Variant = dict.get("end_data", null)
	b.end_data = raw_end if raw_end is Dictionary else {}
	return b


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"game_id": game_id,
		"player_id": player_id,
		"status": status,
		"started_at": started_at,
		"expires_at": expires_at,
		"ended_at": ended_at,
		"start_data": start_data,
		"end_data": end_data,
	}
