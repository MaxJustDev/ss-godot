## GamerProgressData - typed mirror of the upstream `GamerProgressData` JSON.
##
## Returned by the three GamerProgress endpoints that respond with progress
## state (POST create, GET my-gamer-progress, PATCH update). The wrapping
## differs between endpoints:
##   - POST create  -> `{data: GamerProgressData, message: string}`
##   - GET get_mine -> flat `GamerProgressData`
##   - PATCH update -> flat `GamerProgressData`
## Unwrapping is performed in `gamer_progress.gd` before calling `from_dict`.
##
## `game_data` is opaque per-game JSON. Upstream stores it as a String holding
## the raw JSON sub-tree (re-extracted by `ExtractGameDataFromJson` to bypass
## `JsonUtility` mangling). We preserve that contract: `game_data` is the raw
## JSON string. Callers that want a parsed view should `JSON.parse_string`
## the field themselves.
##
## upstream: 1_GamerProgress/Models/GamerProgressData.cs:11
class_name GamerProgressData
extends Resource

## upstream: GamerProgressData.cs:13
@export var id: String = ""
## upstream: GamerProgressData.cs:14
@export var user_id: String = ""
## upstream: GamerProgressData.cs:15
@export var game_id: String = ""
## upstream: GamerProgressData.cs:16
@export var level: int = 0
## upstream: GamerProgressData.cs:17
@export var experience: int = 0
## upstream: GamerProgressData.cs:18
@export var gold: int = 0
## Raw JSON sub-tree as a String. Defaults to "{}" so callers can always
## `JSON.parse_string(game_data)` without nil checks.
## upstream: GamerProgressData.cs:19
@export var game_data: String = "{}"
## Unix seconds. Upstream type is `long`.
## upstream: GamerProgressData.cs:20
@export var created_at: int = 0
## upstream: GamerProgressData.cs:21
@export var updated_at: int = 0
## upstream: GamerProgressData.cs:22
@export var version: int = 0


## Build a GamerProgressData from a raw JSON Dictionary. Missing keys default
## to the zero-value of their type. Extra keys are ignored.
##
## If `game_data` is a Dictionary (the server returned a parsed object),
## it is re-serialised back to a JSON string for storage parity with upstream.
## If it is already a String, it is stored verbatim.
##
## upstream: behavioural parity with `JsonUtility.FromJson<GamerProgressData>`
##           + `ExtractGameDataFromJson` (GamerProgress.cs:94, 261, 322, 405).
static func from_dict(d: Dictionary) -> GamerProgressData:
	var p := GamerProgressData.new()
	if d == null:
		return p
	p.id = String(d.get("id", ""))
	p.user_id = String(d.get("user_id", ""))
	p.game_id = String(d.get("game_id", ""))
	p.level = int(d.get("level", 0))
	p.experience = int(d.get("experience", 0))
	p.gold = int(d.get("gold", 0))
	var gd: Variant = d.get("game_data", "{}")
	if gd is String:
		p.game_data = gd if not (gd as String).is_empty() else "{}"
	elif gd is Dictionary or gd is Array:
		p.game_data = JSON.stringify(gd)
	else:
		p.game_data = "{}"
	p.created_at = int(d.get("created_at", 0))
	p.updated_at = int(d.get("updated_at", 0))
	p.version = int(d.get("version", 0))
	return p


## Inverse of `from_dict`. Used by tests and for persistence parity.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"user_id": user_id,
		"game_id": game_id,
		"level": level,
		"experience": experience,
		"gold": gold,
		"game_data": game_data,
		"created_at": created_at,
		"updated_at": updated_at,
		"version": version,
	}
