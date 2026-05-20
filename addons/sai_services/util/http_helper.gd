## HttpHelper - URL/header utilities for SaiServer HTTP requests.
##
## Pure functions; safe to call from any thread.
class_name HttpHelper
extends RefCounted

const HEADER_AUTHORIZATION := "Authorization"
const HEADER_CONTENT_TYPE := "Content-Type"
const HEADER_ACCEPT := "Accept"
const CONTENT_TYPE_JSON := "application/json"
const BEARER_PREFIX := "Bearer "


## Concatenate base URL + path with exactly one slash between them, and
## append a query string built from `query` (if any).
##
## upstream: SaiServer.cs:198 — `string url = $"{BaseUrl}{endpoint}";`
static func build_url(base_url: String, path: String, query: Dictionary = {}) -> String:
	var trimmed_base: String = base_url
	while trimmed_base.ends_with("/"):
		trimmed_base = trimmed_base.substr(0, trimmed_base.length() - 1)
	var trimmed_path: String = path
	if not trimmed_path.is_empty() and not trimmed_path.begins_with("/"):
		trimmed_path = "/" + trimmed_path
	var url: String = trimmed_base + trimmed_path
	var qs: String = encode_query_string(query)
	if not qs.is_empty():
		if url.contains("?"):
			url += "&" + qs
		else:
			url += "?" + qs
	return url


## URL-encode a Dictionary of query parameters. Array values become repeated
## key=value pairs ("?tag=a&tag=b"). Null values are skipped.
static func encode_query_string(query: Dictionary) -> String:
	if query.is_empty():
		return ""
	var parts: PackedStringArray = []
	for raw_key in query.keys():
		var key: String = String(raw_key).uri_encode()
		var value: Variant = query[raw_key]
		if value == null:
			continue
		if value is Array:
			for item in value:
				parts.append(key + "=" + _encode_value(item))
		else:
			parts.append(key + "=" + _encode_value(value))
	return "&".join(parts)


## Build the HTTP headers array that Godot's HTTPRequest expects
## (PackedStringArray of "Header: value" strings).
##
## - `auth_token` empty -> Authorization header omitted.
## - `extra` overrides defaults if keys collide (case-insensitive compare).
static func build_headers(auth_token: String = "", extra: Dictionary = {}) -> PackedStringArray:
	var collected: Dictionary = {
		HEADER_ACCEPT: CONTENT_TYPE_JSON,
		HEADER_CONTENT_TYPE: CONTENT_TYPE_JSON,
	}
	if not auth_token.is_empty():
		collected[HEADER_AUTHORIZATION] = BEARER_PREFIX + auth_token
	for raw_key in extra.keys():
		var key: String = String(raw_key)
		var overwrite_key: String = key
		# Replace existing keys case-insensitively so callers can override.
		for existing in collected.keys():
			if (existing as String).to_lower() == key.to_lower():
				overwrite_key = existing
				break
		collected[overwrite_key] = String(extra[raw_key])

	var out: PackedStringArray = []
	for k in collected.keys():
		out.append("%s: %s" % [k, collected[k]])
	return out


static func _encode_value(value: Variant) -> String:
	if value is bool:
		return "true" if value else "false"
	return String(value).uri_encode()
