## LoginResponse - typed mirror of `/api/v1/auth/login` and
## `/api/v1/auth/refresh` JSON bodies.
##
## Provided for inspector-friendly typed binding. SaiAuth's public methods
## return plain Dictionary payloads through the standard envelope; this is
## an opt-in convenience for callers that want a typed Resource.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/0_Auth/LoginResponse.cs:6
class_name LoginResponse
extends Resource

@export var user: UserData
@export var access_token: String = ""
@export var refresh_token: String = ""
## Seconds until `access_token` expires. Upstream type is `int`.
## upstream: LoginResponse.cs:11
@export var expires_in: int = 0


## Build a LoginResponse from a raw JSON Dictionary.
##
## upstream: behavioural parity with `JsonUtility.FromJson<LoginResponse>(...)`.
static func from_dict(d: Dictionary) -> LoginResponse:
	var r := LoginResponse.new()
	if d == null:
		return r
	r.access_token = String(d.get("access_token", ""))
	r.refresh_token = String(d.get("refresh_token", ""))
	r.expires_in = int(d.get("expires_in", 0))
	var raw_user: Variant = d.get("user", null)
	if raw_user is Dictionary:
		r.user = UserData.from_dict(raw_user)
	else:
		r.user = UserData.new()
	return r


func to_dict() -> Dictionary:
	var u: Dictionary = user.to_dict() if user != null else {}
	return {
		"user": u,
		"access_token": access_token,
		"refresh_token": refresh_token,
		"expires_in": expires_in,
	}
