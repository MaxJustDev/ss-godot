## JsonHelper - tiny wrapper around Godot's JSON API.
##
## Goals:
##   - Provide stringify / parse helpers that never throw and never return
##     null at call sites (caller gets a typed empty default on failure).
##   - Offer snake_case <-> camelCase converters for upstream APIs whose
##     JSON payloads use camelCase keys. The SaiGame backend is expected
##     to use snake_case so the converters are opt-in helpers only.
##
## upstream: there is no direct Unity equivalent — Unity SDK uses
##           JsonUtility.ToJson / JsonUtility.FromJson<T> inline.
class_name JsonHelper
extends RefCounted


## Encode a Variant to a JSON string. Returns "" if the value cannot be
## serialized (e.g. contains an Object reference).
static func stringify(value: Variant, indent: String = "") -> String:
	if value == null:
		return ""
	return JSON.stringify(value, indent)


## Parse a JSON string. Returns the parsed Variant or `default` on failure.
static func parse(text: String, default: Variant = null) -> Variant:
	if text == null or text.is_empty():
		return default
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return default
	return parsed


## Parse expecting a JSON object. Always returns a Dictionary (empty on failure).
static func parse_or_empty(text: String) -> Dictionary:
	var parsed: Variant = parse(text, null)
	if parsed is Dictionary:
		return parsed
	return {}


## Parse expecting a JSON array. Always returns an Array (empty on failure).
static func parse_array_or_empty(text: String) -> Array:
	var parsed: Variant = parse(text, null)
	if parsed is Array:
		return parsed
	return []


## Convert "camelCase" -> "snake_case". Acronyms ("APIKey") become "a_p_i_key"
## — matches the common .NET/JS DataMember naming heuristic; not Unicode aware.
static func camel_to_snake(name: String) -> String:
	if name.is_empty():
		return name
	var out := ""
	for i in name.length():
		var ch: String = name[i]
		var lower: String = ch.to_lower()
		if ch != lower and i > 0:
			out += "_"
		out += lower
	return out


## Convert "snake_case" -> "camelCase". Leaves leading underscores alone.
static func snake_to_camel(name: String) -> String:
	if name.is_empty():
		return name
	var parts: PackedStringArray = name.split("_", false)
	if parts.size() == 0:
		return name
	var out: String = parts[0]
	for i in range(1, parts.size()):
		var part: String = parts[i]
		if part.is_empty():
			continue
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


## Recursively rewrite all string keys in a Dictionary/Array tree using the
## given converter. Non-string keys are preserved as-is. Use to translate
## a payload before sending or after receiving.
static func convert_keys(value: Variant, converter: Callable) -> Variant:
	if value is Dictionary:
		var src: Dictionary = value
		var out: Dictionary = {}
		for k in src.keys():
			var new_key: Variant = k
			if k is String:
				new_key = converter.call(k)
			out[new_key] = convert_keys(src[k], converter)
		return out
	if value is Array:
		var arr: Array = value
		var out_arr: Array = []
		out_arr.resize(arr.size())
		for i in arr.size():
			out_arr[i] = convert_keys(arr[i], converter)
		return out_arr
	return value


## Convenience: deep-convert keys to snake_case.
static func keys_to_snake(value: Variant) -> Variant:
	return convert_keys(value, Callable(JsonHelper, "camel_to_snake"))


## Convenience: deep-convert keys to camelCase.
static func keys_to_camel(value: Variant) -> Variant:
	return convert_keys(value, Callable(JsonHelper, "snake_to_camel"))
