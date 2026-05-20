## SaiServer - autoload singleton for the SaiGame backend REST client.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/SaiServer.cs` (upstream v0.2.40d).
## Registered as the project autoload `SaiServer` (see plugin.gd / project.godot).
##
## Translation notes:
##   - Unity coroutines `IEnumerator GetRequest(...) yield return SendWebRequest()`
##     become `async` GDScript funcs that `await` `HTTPRequest.request_completed`.
##   - Each HTTP call spins up its own short-lived `HTTPRequest` child so that
##     concurrent calls don't clobber a shared node. Per project guidance this
##     is fine for v0.1; pooling can come later if profiling needs it.
##   - `PlayerPrefs` token/endpoint persistence is replaced with a `ConfigFile`
##     stored at `user://sai_server.cfg`.
##   - Bearer-token injection happens only when `auth == true` AND an access
##     token is present, matching the upstream `CreateAuthenticatedRequest`
##     behaviour but explicit per call.
##   - `AllowAllCertificateHandler` (Unity) is replaced by `TLSOptions.client_unsafe()`
##     and ONLY when `allow_insecure_tls` is set true in the inspector. This
##     should be off in production builds.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/SaiServer.cs:11
extends Node

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

const VERSION := "0.1.0"
const UPSTREAM_VERSION := "0.2.40d"
const PACKAGE_NAME := "Sai Server"

const BASE_URL_PRODUCTION := "https://api.saigame.studio"
const BASE_URL_LOCAL := "http://local-api.saigame.studio:82"

const HEALTH_PATH := "/health"

const CONFIG_PATH := "user://sai_server.cfg"
const CONFIG_SECTION_AUTH := "auth"
const CONFIG_SECTION_SERVER := "server"
const CONFIG_KEY_ACCESS := "access_token"
const CONFIG_KEY_REFRESH := "refresh_token"
const CONFIG_KEY_EXPIRES := "expires_in"
const CONFIG_KEY_ENDPOINT := "endpoint"  # 0 = LOCAL_HTTP, 1 = PRODUCTION_HTTPS

const HEALTH_REQUEST_TIMEOUT_SEC := 5.0

# -------------------------------------------------------------------------
# Inspector fields
# -------------------------------------------------------------------------

@export_group("Server")
## Force the local HTTP endpoint instead of production HTTPS.
## upstream: SaiServer.cs:41 (ServerEndpointOption)
@export var use_local_endpoint: bool = false

## Allow self-signed / invalid TLS certs. DEV ONLY — leave false in shipped builds.
## upstream: SaiServer.cs:203 — AllowAllCertificateHandler
@export var allow_insecure_tls: bool = false

@export_group("Game")
## SaiGame game id sent with most authenticated requests.
## upstream: SaiServer.cs:47
@export var game_id: String = ""

@export_group("API")
## Per-request timeout in seconds.
## upstream: SaiServer.cs:51
@export var request_timeout_sec: float = 30.0

@export_group("Debug Logging")
## upstream: SaiServer.cs:53 — showButtonsLog
@export var show_buttons_log: bool = true
## upstream: SaiServer.cs:54 — showCallbackLog
@export var show_callback_log: bool = true
## upstream: SaiServer.cs:55 — showDebugLog
@export var show_debug_log: bool = true
## upstream: SaiServer.cs:56 — showUrlRequest
@export var show_url_request: bool = true
## upstream: SaiServer.cs:57 — showJsonRequest
@export var show_json_request: bool = true
## upstream: SaiServer.cs:58 — showJsonResponse
@export var show_json_response: bool = true
## Extra debug toggle — log token refresh / persistence events.
@export var show_token_log: bool = false

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Fires when the access token changes (login, refresh, manual set).
## upstream: SaiServer.cs:60 — event Action<string> OnTokenRefreshed
signal token_refreshed(access_token: String)

## Fires when an authenticated request fails because there is no token, or
## (in M2+) when a 401 forces logout. Sub-services should subscribe and
## prompt the user to re-auth.
signal auth_required

## Emitted right before a request leaves. `method` is "GET"/"POST"/etc.
signal request_started(method: String, path: String)

## Emitted after every request completes (regardless of status).
signal request_completed(method: String, path: String, status: int)

# -------------------------------------------------------------------------
# Internal state
# -------------------------------------------------------------------------

var _access_token: String = ""
var _refresh_token: String = ""
var _expires_in: int = 0

# -------------------------------------------------------------------------
# Sub-services
# -------------------------------------------------------------------------
#
# Typed accessors. These are populated in `_ready()` after the matching
# child node has been spawned. Use `SaiServer.auth.login(...)` etc.
var auth: SaiAuth = null
var google_login: GoogleBackendLogin = null
var progress: GamerProgress = null
var mailbox: Mailbox = null
var shop: Shop = null
var player_event: PlayerEvent = null
## Alias for `player_event` — matches the upstream `6_Journey` namespace
## so callers can write `SaiServer.journey.emit_event(...)`.
var journey: PlayerEvent = null
# M5b — Quest sub-services. `quest` is the primary alias used by
# `docs/examples/quest.md` (SaiServer.quest.*) and points at the same
# ChainQuest instance as `chain_quest`.
var chain_quest: ChainQuest = null
var quest_progressor: QuestProgressor = null
var quest_history: QuestHistory = null
var daily_quest: DailyQuest = null
var quest: ChainQuest = null  # alias of `chain_quest`
var leaderboard: Leaderboard = null

# M4 — ItemContainer family.
var player_container: PlayerContainer = null
## Alias for `player_container`, matching the primary entry point in
## `docs/examples/inventory.md` (`SaiServer.inventory.*`). Points at the same
## PlayerContainer instance.
var inventory: PlayerContainer = null
var gacha: GachaPack = null
var item: PlayerItem = null
## Alias for `item`. Mirrors the upstream `PlayerItem` class name for callers
## who prefer the explicit reference (`SaiServer.player_item.get_items()`).
var player_item: PlayerItem = null
var item_add_deduct: ItemAddDeduct = null
var item_tag: ItemTag = null
var equipment_slot: EquipmentSlot = null
var item_preset: ItemPreset = null
var item_crafting: ItemCrafting = null
var item_generator: ItemGenerator = null

# M6c — Battle sub-services. `battle` is the primary alias used by
# `docs/examples/battle_session.md` (SaiServer.battle.*) and points at the
# same BattleSessions instance as `battle_sessions`.
var battle_sessions: BattleSessions = null
var battle_script: BattleScript = null
var battle: BattleSessions = null  # alias of `battle_sessions`

# M6d — LuaScript. `lua_script` is the primary alias used by
# `docs/examples/lua_script.md` (SaiServer.lua_script.*); `lua_script_manager`
# is the explicit upstream class name, pointing at the same instance.
var lua_script: LuaScriptManager = null
var lua_script_manager: LuaScriptManager = null  # alias of `lua_script`

# Sub-services registered here in M2+:
#   - SaiAuth                ("SaiAuth")              [M2 — done]
#   - GoogleBackendLogin     ("GoogleBackendLogin")   [M2 — done]
#   - GamerProgress          ("GamerProgress")        [M3a — done]
#   - Mailbox                ("Mailbox")              [M3b — done]
#   - PlayerContainer        ("PlayerContainer")      [M4 — done]
#   - GachaPack              ("GachaPack")            [M4 — done]
#   - PlayerItem             ("PlayerItem")           [M4 — done]
#   - ItemAddDeduct          ("ItemAddDeduct")        [M4 — done]
#   - ItemTag                ("ItemTag")              [M4 — done]
#   - EquipmentSlot          ("EquipmentSlot")        [M4 — done]
#   - ItemPreset             ("ItemPreset")           [M4 — done]
#   - ItemCrafting           ("ItemCrafting")         [M4 — done]
#   - ItemGenerator          ("ItemGenerator")        [M4 — done]
#   - PlayerEvent            ("PlayerEvent")          [M6a — done]
#   - Shop                   ("Shop")                 [M5a — done]
#   - ChainQuest             ("ChainQuest")           [M5b — done]
#   - QuestProgressor        ("QuestProgressor")      [M5b — done]
#   - QuestHistory           ("QuestHistory")         [M5b — done]
#   - DailyQuest             ("DailyQuest")           [M5b — done]
#   - ItemMove                — folded into PlayerItem (M4)
#   - ItemSwap                — folded into PlayerItem (M4)
#   - Leaderboard            ("Leaderboard")          [M6b — done]
#   - BattleSessions         ("BattleSessions")       [M6c — done]
#   - BattleScript           ("BattleScript")         [M6c — done]
#   - LuaScriptManager       ("LuaScriptManager")     [M6d — done]
#
# Each sub-service is added as a direct child Node of this autoload in
# its module's M-task. Reach them via `SaiServer.get_node("SaiAuth")` etc.
# Typed accessors will be added as @onready properties when their classes exist.

# =========================================================================
# Lifecycle
# =========================================================================


func _ready() -> void:
	_load_persisted_state()
	_register_sub_services()
	if show_debug_log:
		print(
			(
				"[SaiServer] v%s (upstream ss-unity v%s) ready — base=%s"
				% [
					VERSION,
					UPSTREAM_VERSION,
					base_url(),
				]
			)
		)


## Instantiate all M2+ sub-service nodes as children of this autoload.
## Reserved names are documented in the comment block above; reach a service
## via the typed property (`SaiServer.auth`) or `get_node("SaiAuth")`.
func _register_sub_services() -> void:
	# M2: Auth.
	auth = SaiAuth.new()
	auth.name = "SaiAuth"
	add_child(auth)

	google_login = GoogleBackendLogin.new()
	google_login.name = "GoogleBackendLogin"
	add_child(google_login)

	# M3a: GamerProgress.
	progress = GamerProgress.new()
	progress.name = "GamerProgress"
	add_child(progress)

	# M3b: Mailbox.
	mailbox = Mailbox.new()
	mailbox.name = "Mailbox"
	add_child(mailbox)

	# M5a: Shop.
	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)

	# M6a: Journey / PlayerEvent.
	# Single child node — both `journey` and `player_event` point at the
	# same instance so the upstream class name and the namespace name both
	# work from app code (see endpoints.md `## Journey`).
	player_event = PlayerEvent.new()
	player_event.name = "PlayerEvent"
	add_child(player_event)
	journey = player_event

	# M5b: Quest (chain / progressor / history / daily).
	# `quest` is the primary alias documented in `docs/examples/quest.md`
	# and points at the same node as `chain_quest`.
	chain_quest = ChainQuest.new()
	chain_quest.name = "ChainQuest"
	add_child(chain_quest)
	quest = chain_quest

	quest_progressor = QuestProgressor.new()
	quest_progressor.name = "QuestProgressor"
	add_child(quest_progressor)

	quest_history = QuestHistory.new()
	quest_history.name = "QuestHistory"
	add_child(quest_history)

	daily_quest = DailyQuest.new()
	daily_quest.name = "DailyQuest"
	add_child(daily_quest)

	# M6b: Leaderboard.
	leaderboard = Leaderboard.new()
	leaderboard.name = "Leaderboard"
	add_child(leaderboard)

	# M4: ItemContainer family.
	# `inventory` is the public alias documented in docs/examples/inventory.md
	# and points at the same node as `player_container`.
	player_container = PlayerContainer.new()
	player_container.name = "PlayerContainer"
	add_child(player_container)
	inventory = player_container

	gacha = GachaPack.new()
	gacha.name = "GachaPack"
	add_child(gacha)

	# `player_item` is an alias of `item` so callers can use either name.
	item = PlayerItem.new()
	item.name = "PlayerItem"
	add_child(item)
	player_item = item

	item_add_deduct = ItemAddDeduct.new()
	item_add_deduct.name = "ItemAddDeduct"
	add_child(item_add_deduct)

	item_tag = ItemTag.new()
	item_tag.name = "ItemTag"
	add_child(item_tag)

	equipment_slot = EquipmentSlot.new()
	equipment_slot.name = "EquipmentSlot"
	add_child(equipment_slot)

	item_preset = ItemPreset.new()
	item_preset.name = "ItemPreset"
	add_child(item_preset)

	item_crafting = ItemCrafting.new()
	item_crafting.name = "ItemCrafting"
	add_child(item_crafting)

	item_generator = ItemGenerator.new()
	item_generator.name = "ItemGenerator"
	add_child(item_generator)

	# M6c: Battle (sessions + script).
	# `battle` is the primary alias documented in
	# `docs/examples/battle_session.md` and points at the same node as
	# `battle_sessions`.
	battle_sessions = BattleSessions.new()
	battle_sessions.name = "BattleSessions"
	add_child(battle_sessions)
	battle = battle_sessions

	battle_script = BattleScript.new()
	battle_script.name = "BattleScript"
	add_child(battle_script)

	# M6d: LuaScript. Single child node; both `lua_script` and
	# `lua_script_manager` point at the same instance — `lua_script` is the
	# primary alias used by `docs/examples/lua_script.md`.
	lua_script = LuaScriptManager.new()
	lua_script.name = "LuaScriptManager"
	add_child(lua_script)
	lua_script_manager = lua_script

	# TODO M7+: future sub-services (if any) register here.


# =========================================================================
# Endpoint / auth state
# =========================================================================


## Current base URL — production HTTPS unless `use_local_endpoint` is true.
## upstream: SaiServer.cs:74 (BaseUrl property)
func base_url() -> String:
	return BASE_URL_LOCAL if use_local_endpoint else BASE_URL_PRODUCTION


## Returns true if an access token is set. M2 SaiAuth may extend this with
## an expiry check.
## upstream: SaiServer.cs:89
func is_authenticated() -> bool:
	return _access_token != ""


## upstream: SaiServer.cs:91
func access_token() -> String:
	return _access_token


## upstream: SaiServer.cs:93
func refresh_token() -> String:
	return _refresh_token


## upstream: SaiServer.cs:95
func expires_in() -> int:
	return _expires_in


## Set both tokens + expiry in one call. Mirrors `SaiServer.SetLoginData`.
## upstream: SaiServer.cs:187
func set_login_data(access: String, refresh: String, expires: int) -> void:
	_access_token = access
	_refresh_token = refresh
	_expires_in = expires
	_persist_tokens()
	if show_token_log:
		print("[SaiServer] set_login_data — token persisted")
	token_refreshed.emit(access)


## Update access token only (e.g. after a silent refresh).
## upstream: SaiServer.cs:178
func set_access_token(token: String) -> void:
	_access_token = token
	_persist_tokens()
	token_refreshed.emit(token)


## Wipe stored credentials.
func clear_tokens() -> void:
	_access_token = ""
	_refresh_token = ""
	_expires_in = 0
	_persist_tokens()


## Trim the configured game id, matching upstream NormalizeInput.
## upstream: SaiServer.cs:147
func normalized_game_id() -> String:
	return game_id.strip_edges() if game_id != null else ""


## Set the game id at runtime.
## upstream: SaiServer.cs:615
func set_game_id(new_id: String) -> void:
	game_id = new_id.strip_edges() if new_id != null else ""


# =========================================================================
# HTTP — async (await) API
# =========================================================================


## GET request. `query` is appended as URL params. Returns
## `{success, status, error, data}` where `data` is the parsed JSON
## (Dictionary/Array) if any, else the raw response string.
##
## upstream: SaiServer.cs:213
func get_request(path: String, query: Dictionary = {}, auth: bool = true) -> Dictionary:
	return await _send("GET", path, query, null, auth)


## POST request. `body` is JSON-serialised. Pass `null` for empty body.
##
## upstream: SaiServer.cs:237
func post_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	return await _send("POST", path, {}, body, auth)


## PUT request. `body` is JSON-serialised.
##
## upstream: SaiServer.cs:267
func put_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	return await _send("PUT", path, {}, body, auth)


## PATCH request. `body` is JSON-serialised.
##
## upstream: SaiServer.cs:297
func patch_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	return await _send("PATCH", path, {}, body, auth)


## DELETE request. Some APIs accept a body; upstream's `DeleteRequest`
## does not send one but we allow it here for parity with REST conventions.
##
## upstream: SaiServer.cs:327
func delete_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	return await _send("DELETE", path, {}, body, auth)


## Health check. Hits `<base_url>/health` with a short timeout and returns
## true on HTTP 2xx.
##
## upstream: SaiServer.cs:722 (TestConnection / TestConnectionCoroutine)
func ping() -> bool:
	var req := _make_request_node(HEALTH_REQUEST_TIMEOUT_SEC)
	add_child(req)
	var url: String = HttpHelper.build_url(base_url(), HEALTH_PATH)
	var err: int = req.request(url, HttpHelper.build_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		req.queue_free()
		return false
	var result: Array = await req.request_completed
	req.queue_free()
	var status: int = result[1] if result.size() > 1 else 0
	return status >= 200 and status < 300


# =========================================================================
# HTTP — internal
# =========================================================================


func _send(
	method: String, path: String, query: Dictionary, body: Variant, auth: bool
) -> Dictionary:
	var url: String = HttpHelper.build_url(base_url(), path, query)
	var token: String = _access_token if (auth and is_authenticated()) else ""

	# Refuse to send if the caller asked for auth but we have no token.
	# Upstream Unity silently sent with no Authorization header; here we
	# fail fast and emit `auth_required()` so the app can show login UI.
	if auth and token.is_empty():
		auth_required.emit()
		return {
			"success": false,
			"status": 0,
			"error": "Authentication required: no access token set",
			"data": null,
		}

	var headers: PackedStringArray = HttpHelper.build_headers(token)
	var body_str: String = ""
	if body != null:
		body_str = JsonHelper.stringify(body)

	if show_url_request:
		print("[SaiServer] %s %s" % [method, url])
	if show_json_request and not body_str.is_empty():
		print("[SaiServer] %s Request Body\n%s" % [method, body_str])

	request_started.emit(method, path)

	var http_method: int = _to_http_method(method)
	var req := _make_request_node(request_timeout_sec)
	add_child(req)

	var err: int = req.request(url, headers, http_method, body_str)
	if err != OK:
		req.queue_free()
		var msg := "HTTPRequest.request returned %d" % err
		request_completed.emit(method, path, 0)
		return {"success": false, "status": 0, "error": msg, "data": null}

	var result: Array = await req.request_completed
	req.queue_free()

	# `request_completed(result, response_code, headers, body)`
	var godot_result: int = result[0] if result.size() > 0 else HTTPRequest.RESULT_NO_RESPONSE
	var status: int = result[1] if result.size() > 1 else 0
	var body_bytes: PackedByteArray = result[3] if result.size() > 3 else PackedByteArray()
	var body_text: String = body_bytes.get_string_from_utf8()

	request_completed.emit(method, path, status)

	if show_json_response and not body_text.is_empty():
		print("[SaiServer] %s Response (status %d)\n%s" % [method, status, body_text])

	# 401 -> trip the auth_required signal so app can re-auth.
	if status == 401 and auth:
		auth_required.emit()

	var ok: bool = godot_result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var parsed: Variant = null
	if not body_text.is_empty():
		var p: Variant = JSON.parse_string(body_text)
		parsed = p if p != null else body_text
	if ok:
		return {"success": true, "status": status, "error": "", "data": parsed}

	var error_msg: String = (
		"%s %s failed (godot_result=%d, status=%d)"
		% [
			method,
			path,
			godot_result,
			status,
		]
	)
	return {"success": false, "status": status, "error": error_msg, "data": parsed}


func _make_request_node(timeout: float) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = timeout
	if allow_insecure_tls:
		# upstream: SaiServer.cs:203 — AllowAllCertificateHandler
		req.set_tls_options(TLSOptions.client_unsafe())
	return req


func _to_http_method(method: String) -> int:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			push_error("SaiServer: unknown HTTP method '%s'" % method)
			return HTTPClient.METHOD_GET


# =========================================================================
# Persistence (ConfigFile @ user://sai_server.cfg)
# =========================================================================


func _load_persisted_state() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(CONFIG_PATH)
	if err != OK:
		# First run / no file yet — that's fine.
		return
	_access_token = String(cfg.get_value(CONFIG_SECTION_AUTH, CONFIG_KEY_ACCESS, ""))
	_refresh_token = String(cfg.get_value(CONFIG_SECTION_AUTH, CONFIG_KEY_REFRESH, ""))
	_expires_in = int(cfg.get_value(CONFIG_SECTION_AUTH, CONFIG_KEY_EXPIRES, 0))

	# Server endpoint persistence — upstream uses PREF_SERVER_ENDPOINT.
	# upstream: SaiServer.cs:589 (LoadServerEndpointFromPlayerPrefs)
	if cfg.has_section_key(CONFIG_SECTION_SERVER, CONFIG_KEY_ENDPOINT):
		var stored: int = int(cfg.get_value(CONFIG_SECTION_SERVER, CONFIG_KEY_ENDPOINT, 0))
		use_local_endpoint = stored == ServerEndpointOption.Value.LOCAL_HTTP

	if show_token_log and not _access_token.is_empty():
		print("[SaiServer] loaded persisted access token (len=%d)" % _access_token.length())


func _persist_tokens() -> void:
	var cfg := ConfigFile.new()
	# Best-effort load so we don't wipe unrelated sections (e.g. server endpoint).
	cfg.load(CONFIG_PATH)
	cfg.set_value(CONFIG_SECTION_AUTH, CONFIG_KEY_ACCESS, _access_token)
	cfg.set_value(CONFIG_SECTION_AUTH, CONFIG_KEY_REFRESH, _refresh_token)
	cfg.set_value(CONFIG_SECTION_AUTH, CONFIG_KEY_EXPIRES, _expires_in)
	var err: int = cfg.save(CONFIG_PATH)
	if err != OK and show_token_log:
		push_warning("[SaiServer] failed to persist tokens (err=%d)" % err)


## Save current endpoint selection to disk. Equivalent of upstream
## `ManualSaveServerEndpoint`.
## upstream: SaiServer.cs:608
func save_server_endpoint() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	var endpoint_value: int = (
		ServerEndpointOption.Value.LOCAL_HTTP
		if use_local_endpoint
		else ServerEndpointOption.Value.PRODUCTION_HTTPS
	)
	cfg.set_value(CONFIG_SECTION_SERVER, CONFIG_KEY_ENDPOINT, endpoint_value)
	var err: int = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("[SaiServer] failed to persist server endpoint (err=%d)" % err)
	elif show_debug_log:
		print(
			"[SaiServer] saved endpoint = %s" % ServerEndpointOption.to_string_value(endpoint_value)
		)
