## GoogleSession - typed view of the Google OAuth 2-step polling state.
##
## Combines `GoogleSessionResponse` (initial POST) and `GoogleSessionPollResponse`
## (GET polled by interval). The `status` field follows upstream values:
##   "pending" | "completed" | "denied" | "expired" | "error"
##
## upstream: ss-unity/Assets/SaiGame/Scripts/0_Auth/Google/GoogleSessionResponse.cs:6
## upstream: ss-unity/Assets/SaiGame/Scripts/0_Auth/Google/GoogleSessionPollResponse.cs:6
class_name GoogleSession
extends Resource

@export var session_id: String = ""
@export var auth_url: String = ""
## Unix seconds when the session expires. Upstream type is `long`.
@export var expires_at: int = 0
@export var poll_interval_seconds: int = 0
@export var status: String = "pending"


## Build a GoogleSession from the initial POST response.
##
## upstream: GoogleSessionResponse.cs:6
static func from_create_dict(d: Dictionary) -> GoogleSession:
	var s := GoogleSession.new()
	if d == null:
		return s
	s.session_id = String(d.get("session_id", ""))
	s.auth_url = String(d.get("auth_url", ""))
	s.expires_at = int(d.get("expires_at", 0))
	s.poll_interval_seconds = int(d.get("poll_interval_seconds", 0))
	s.status = "pending"
	return s


## Update mutable fields (status, expires_at) from a poll response.
## Does NOT touch session_id / auth_url which the create response owns.
##
## upstream: GoogleSessionPollResponse.cs:6
func merge_poll_dict(d: Dictionary) -> void:
	if d == null:
		return
	if d.has("status"):
		status = String(d.get("status", status))
	if d.has("expires_at"):
		expires_at = int(d.get("expires_at", expires_at))
