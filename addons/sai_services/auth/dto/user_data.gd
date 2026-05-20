## UserData - typed mirror of the upstream `UserData` JSON shape.
##
## Returned by `/api/v1/auth/me`, embedded in `/api/v1/auth/login` and
## `/api/v1/auth/refresh` responses, and inside the Google session poll
## response. SaiAuth still returns plain Dictionary payloads through the
## standard `{success, status, error, data}` envelope; this Resource is
## provided for inspector-friendly typed binding (e.g. `@export var`
## profile screens).
##
## upstream: ss-unity/Assets/SaiGame/Scripts/0_Auth/UserData.cs:6
class_name UserData
extends Resource

@export var id: String = ""
@export var email: String = ""
@export var username: String = ""
@export var display_name: String = ""
@export var is_active: bool = false
@export var is_verified: bool = false
## Unix seconds. Upstream type is `long`.
## upstream: UserData.cs:14
@export var created_at: int = 0


## Build a UserData from a raw JSON Dictionary. Missing keys default to the
## zero-value of their type (empty string, false, 0). Extra keys are ignored.
##
## upstream: behavioural parity with `JsonUtility.FromJson<UserData>(...)`.
static func from_dict(d: Dictionary) -> UserData:
	var u := UserData.new()
	if d == null:
		return u
	u.id = String(d.get("id", ""))
	u.email = String(d.get("email", ""))
	u.username = String(d.get("username", ""))
	u.display_name = String(d.get("display_name", ""))
	u.is_active = bool(d.get("is_active", false))
	u.is_verified = bool(d.get("is_verified", false))
	u.created_at = int(d.get("created_at", 0))
	return u


## Inverse of `from_dict`. Useful for tests and persistence.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"email": email,
		"username": username,
		"display_name": display_name,
		"is_active": is_active,
		"is_verified": is_verified,
		"created_at": created_at,
	}
