## SaiServer - autoload singleton for SaiGame backend REST client.
## Port of ss-unity/Assets/SaiGame/Scripts/SaiServer.cs (v0.2.40d).
##
## NOTE: This is an M0 skeleton stub. Real implementation lands in M1.
extends Node

const VERSION := "0.1.0"
const UPSTREAM_VERSION := "0.2.40d"

const BASE_URL_PRODUCTION := "https://api.saigame.studio"
const BASE_URL_LOCAL := "http://local-api.saigame.studio:82"

@export var use_local_endpoint: bool = false
@export var game_id: String = ""
@export var request_timeout_sec: float = 30.0

var _access_token: String = ""
var _refresh_token: String = ""

signal token_refreshed(access_token: String)
signal auth_required()


func _ready() -> void:
	print("[SaiServer] v%s (upstream ss-unity v%s) — M0 skeleton" % [VERSION, UPSTREAM_VERSION])


func base_url() -> String:
	return BASE_URL_LOCAL if use_local_endpoint else BASE_URL_PRODUCTION


func is_authenticated() -> bool:
	return _access_token != ""


func set_tokens(access: String, refresh: String) -> void:
	_access_token = access
	_refresh_token = refresh
	token_refreshed.emit(access)


func clear_tokens() -> void:
	_access_token = ""
	_refresh_token = ""
