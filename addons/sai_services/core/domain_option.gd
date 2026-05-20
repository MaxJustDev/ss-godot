## DomainOption - mirrors the upstream enum used by the legacy server-field
## sync code in SaiServer. Kept as a tiny class with int constants so it can
## be referenced from `@export` enums (`@export var d: DomainOption.Value`).
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/DomainOption.cs:3
class_name DomainOption
extends RefCounted

enum Value {
	LOCAL = 0,
	PRODUCTION = 1,
}


static func to_string_value(v: int) -> String:
	match v:
		Value.LOCAL:
			return "Local"
		Value.PRODUCTION:
			return "Production"
		_:
			return "Unknown"
