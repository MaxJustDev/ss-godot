## EventData - typed mirror of upstream `EventData` + `TrackEventResponse`.
##
## Journey's only endpoint (`POST /api/v1/games/{game_id}/events`) sends a
## hand-built JSON body where `event_data` is a dynamic JSON sub-tree embedded
## raw (see `PlayerEvent.cs:128-132`). Upstream defines two reference models
## that the SDK never actually serialises through `JsonUtility`:
##
##   - `EventData { source, timestamp: string }` — `EventData.cs:6`
##   - `TrackEventResponse { message, event_id: string }` — `TrackEventResponse.cs:6`
##
## Per CLAUDE.md C.1 we expose a single `Resource` that covers both reference
## shapes: the suggested-payload fields (`source`, `timestamp`) and the
## server-response fields (`event_id`, `message`). Either side can ignore the
## fields it doesn't need; the payload itself stays a plain `Dictionary` (the
## SDK treats `event_data` as dynamic JSON — endpoints.md `## Journey`).
##
## upstream: 6_Journey/EventData.cs:6, 6_Journey/TrackEventResponse.cs:6
class_name EventData
extends Resource

# -------------------------------------------------------------------------
# Suggested payload fields (mirror of `EventData.cs`).
# These are advisory — the wire-level `event_data` is free-form JSON.
# -------------------------------------------------------------------------

## upstream: EventData.cs:8
@export var source: String = ""
## upstream: EventData.cs:9
@export var timestamp: String = ""

# -------------------------------------------------------------------------
# Server response fields (mirror of `TrackEventResponse.cs`).
# Populated from the POST /events response so callers can read either field
# off the same typed wrapper without consulting the raw envelope.
# -------------------------------------------------------------------------

## upstream: TrackEventResponse.cs:8
@export var message: String = ""
## upstream: TrackEventResponse.cs:9
@export var event_id: String = ""


## Build an EventData from a raw JSON Dictionary. Missing keys default to
## the zero-value of their type. Extra keys are ignored.
##
## Accepts either the request-shaped dict (`{source, timestamp, ...}`) or the
## response-shaped dict (`{message, event_id}`); fields not present in the
## input simply keep their defaults.
##
## upstream: behavioural parity with `JsonUtility.FromJson<TrackEventResponse>`
##           in `PlayerEvent.cs:139`.
static func from_dict(d: Variant) -> EventData:
	var e := EventData.new()
	if not (d is Dictionary):
		return e
	var dict: Dictionary = d
	e.source = String(dict.get("source", ""))
	e.timestamp = String(dict.get("timestamp", ""))
	e.message = String(dict.get("message", ""))
	e.event_id = String(dict.get("event_id", ""))
	return e


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"source": source,
		"timestamp": timestamp,
		"message": message,
		"event_id": event_id,
	}
