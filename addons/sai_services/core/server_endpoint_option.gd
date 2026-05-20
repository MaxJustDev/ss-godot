## ServerEndpointOption - mirrors the upstream enum SaiServer uses to pick
## a base URL (local HTTP vs production HTTPS).
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/ServerEndpointOption.cs:3
class_name ServerEndpointOption
extends RefCounted

enum Value {
	LOCAL_HTTP = 0,
	PRODUCTION_HTTPS = 1,
}


static func to_string_value(v: int) -> String:
	match v:
		Value.LOCAL_HTTP:
			return "LocalHttp"
		Value.PRODUCTION_HTTPS:
			return "ProductionHttps"
		_:
			return "Unknown"
