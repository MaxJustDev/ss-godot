## LuaScriptManager - thin RPC wrapper around server-hosted Lua scripts.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:9`
## (upstream v0.2.40d).
##
## Translation notes:
##   - The SDK does NOT execute Lua locally. Every method is a REST RPC.
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals (CLAUDE.md B.4, B.5).
##   - Upstream wires the 5 endpoints through `ScriptFileRecord` (local-file
##     bookkeeping for the Inspector tools in `Editor/LuaScriptManagerEditor.cs`).
##     The Godot port drops the local-file plumbing — callers pass body fields
##     directly. Editor-side workflow (load files from disk, push/pull versions)
##     belongs in a future M7+ Godot editor plugin, not in the runtime SDK.
##   - Endpoint contract (docs/endpoints.md `## LuaScript`):
##       GET    /api/v1/games/{game_id}/scripts                — list
##       POST   /api/v1/games/{game_id}/scripts                — create
##       PATCH  /api/v1/games/{game_id}/scripts/{script_id}    — TWO body shapes:
##                                                                full update,
##                                                                flags-only
##       DELETE /api/v1/games/{game_id}/scripts/{script_id}    — delete
##     The two PATCH shapes share ONE path constant (`PATH_SCRIPT_BY_ID`)
##     exposed via TWO methods (`update_script` / `set_flags`), matching the
##     upstream coroutines `UpdateScriptCoroutine` (LuaScriptManager.cs:378)
##     and `UpdateScriptFlagsCoroutine` (LuaScriptManager.cs:401).
##   - `list()` tolerates ALL THREE upstream wrapper shapes (`scripts` / `data`
##     / `items`) plus a bare top-level JSON array, matching
##     `ParseBackendScriptList` (LuaScriptManager.cs:329) and
##     `GetBackendScripts` (LuaScriptManager.cs:340). SaiServer's generic JSON
##     parser already unwraps the array case before we see it.
##   - `run(script_name, params)` is an extra convenience tied to
##     `POST /api/v1/games/{game_id}/scripts/{script_name}/run` —
##     same endpoint as the M6c `BattleScript.run_script(...)`. Upstream's
##     `LuaScriptManager.cs` does NOT expose this method (only `BattleScript`
##     does), but `docs/examples/lua_script.md` documents `lua_script.run(...)`
##     as the primary SDK surface for invoking server-side Lua. Body and
##     response are dynamic — we surface the response under `data.raw` and
##     forward whatever the server returned. See the M6c discovery note for
##     the wire shape.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.lua_script` from app code.
##
## upstream: 9_LuaScript/LuaScriptManager.cs:9
class_name LuaScriptManager
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: 9_LuaScript/LuaScriptManager.cs:274 (LoadBackendScriptsCoroutine)
## upstream: 9_LuaScript/LuaScriptManager.cs:370 (CreateScriptCoroutine)
const PATH_SCRIPTS := "/api/v1/games/{game_id}/scripts"

## Shared path constant for the TWO PATCH body shapes (full update + flags-only)
## and the DELETE. The dual-body PATCH parity is implemented by `update_script`
## and `set_flags` below.
## upstream: 9_LuaScript/LuaScriptManager.cs:389 (UpdateScriptCoroutine)
## upstream: 9_LuaScript/LuaScriptManager.cs:409 (UpdateScriptFlagsCoroutine)
## upstream: 9_LuaScript/LuaScriptManager.cs:419 (DeleteScriptCoroutine)
const PATH_SCRIPT_BY_ID := "/api/v1/games/{game_id}/scripts/{script_id}"

## Extra `run` endpoint — server-side script execution.
## Shared with M6c BattleScript (same wire path, different SDK class).
## upstream: 8_Battle/BattleScript.cs:69 (RunScriptCoroutine)
const PATH_RUN_SCRIPT := "/api/v1/games/{game_id}/scripts/{script_name}/run"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `list()`. `scripts` is `Array[Dictionary]` (one entry
## per backend record) and mirrors upstream `BackendScriptRecord` fields:
## `{id, name, description, script_body, version, is_active, is_library,
##   created_by, created_at, updated_at}`.
## upstream: 9_LuaScript/LuaScriptManager.cs:281 (onSuccess of LoadBackendScripts)
signal list_loaded(scripts: Array)
## upstream: 9_LuaScript/LuaScriptManager.cs:285 (onError of LoadBackendScripts)
signal list_failed(error: String)

## Emitted on successful `create_script()`. `id` is the new server id; `raw`
## is the full response Dictionary (only `id` is parsed by upstream — see
## `HandleScriptResponse` LuaScriptManager.cs:468 — but we forward the whole
## body so callers can read e.g. `created_at` without a second GET).
## upstream: 9_LuaScript/LuaScriptManager.cs:374 (CreateScriptCoroutine success)
signal create_success(id: String, raw: Variant)
## upstream: 9_LuaScript/LuaScriptManager.cs:375 (CreateScriptCoroutine failure)
signal create_failed(error: String)

## Emitted on successful `update_script()` (full-body PATCH).
## upstream: 9_LuaScript/LuaScriptManager.cs:392 (UpdateScriptCoroutine success)
signal update_success(id: String, raw: Variant)
## upstream: 9_LuaScript/LuaScriptManager.cs:398 (UpdateScriptCoroutine failure)
signal update_failed(error: String)

## Emitted on successful `set_flags()` (flags-only PATCH).
## upstream: 9_LuaScript/LuaScriptManager.cs:412 (UpdateScriptFlagsCoroutine success)
signal flags_success(id: String, raw: Variant)
## upstream: 9_LuaScript/LuaScriptManager.cs:414 (UpdateScriptFlagsCoroutine failure)
signal flags_failed(error: String)

## Emitted on successful `delete_script()`.
## upstream: 9_LuaScript/LuaScriptManager.cs:424 (DeleteScriptCoroutine success)
signal delete_success(id: String)
## upstream: 9_LuaScript/LuaScriptManager.cs:426 (DeleteScriptCoroutine failure)
signal delete_failed(error: String)

## Emitted on successful `run()`. `script_name` echoes the input; `raw_data`
## is the parsed JSON response forwarded raw — shape is opaque to the SDK.
## upstream: 8_Battle/BattleScript.cs:10 (OnRunScriptSuccess)
signal run_success(script_name: String, raw_data: Variant)
## upstream: 8_Battle/BattleScript.cs:11 (OnRunScriptFailure)
signal run_failed(script_name: String, error: String)

# -------------------------------------------------------------------------
# Cached state (mirrors upstream's `scriptFiles` list)
# -------------------------------------------------------------------------

## Last script list returned by `list()`. Empty until first successful call.
## Each entry is a Dictionary (raw `BackendScriptRecord` shape).
## upstream: 9_LuaScript/LuaScriptManager.cs:17 (scriptFiles)
var cached_scripts: Array = []

# =========================================================================
# Public API
# =========================================================================


## GET /api/v1/games/{game_id}/scripts
##
## Server may return any of:
##   - bare JSON array `[...]`
##   - `{ "scripts": [...] }`
##   - `{ "data":    [...] }`
##   - `{ "items":   [...] }`
## All four are accepted, matching upstream's `ParseBackendScriptList` +
## `GetBackendScripts` fallback chain.
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `scripts`: Array[Dictionary] (raw backend records)
##   - `raw`: original parsed JSON (Variant — Array or Dictionary).
##
## upstream: 9_LuaScript/LuaScriptManager.cs:25 (LoadScripts),
##           9_LuaScript/LuaScriptManager.cs:272 (LoadBackendScriptsCoroutine)
func list() -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		list_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:35-39 — refuse before sending.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated. Local scripts were loaded only."
		list_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		# upstream: LuaScriptManager.cs:41-45
		var err := "Game Id is required. Local scripts were loaded only."
		list_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SCRIPTS.replace("{game_id}", game_id)
	var result: Dictionary = await server.get_request(path, {}, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "list scripts failed"))
		list_failed.emit(error_msg)
		return result

	# Tolerate all four upstream shapes — bare array OR one of three wrappers.
	# upstream: LuaScriptManager.cs:340 (GetBackendScripts) walks the same chain.
	var raw: Variant = result.get("data", null)
	var scripts: Array = _extract_scripts_array(raw)
	cached_scripts = scripts
	list_loaded.emit(scripts)

	var out := result.duplicate(true)
	out["data"] = {
		"scripts": scripts,
		"raw": raw,
	}
	return out


## POST /api/v1/games/{game_id}/scripts
##
## `body` is forwarded as-is to the server. The upstream `CreateRequest`
## shape (LuaScriptManager.cs:587) is:
##   `{ name, description, script_body }`
## Callers that want strict parity should pass exactly these three keys.
## Additional keys are ignored by the server, not rejected.
##
## On success, `data` is `{id: String, raw: Variant}` — `id` extracted via the
## same logic as upstream `HandleScriptResponse` (LuaScriptManager.cs:468).
##
## upstream: 9_LuaScript/LuaScriptManager.cs:168 (CreateScript),
##           9_LuaScript/LuaScriptManager.cs:360 (CreateScriptCoroutine)
func create_script(body: Dictionary) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		create_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:437-441 — refuse before sending.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated. Please login first."
		create_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		# upstream: LuaScriptManager.cs:443-446
		var err := "Game Id is required."
		create_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:449-453 — refuse blank script name.
	var name_value: String = String(body.get("name", ""))
	if name_value.strip_edges().is_empty():
		var err := "Script name is required."
		create_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SCRIPTS.replace("{game_id}", game_id)
	var result: Dictionary = await server.post_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "create script failed"))
		create_failed.emit(error_msg)
		return result

	var raw: Variant = result.get("data", null)
	var id_value: String = _extract_script_id(raw)
	create_success.emit(id_value, raw)

	var out := result.duplicate(true)
	out["data"] = {"id": id_value, "raw": raw}
	return out


## PATCH /api/v1/games/{game_id}/scripts/{script_id}
##
## FULL-BODY shape. Upstream `UpdateRequest` (LuaScriptManager.cs:594):
##   `{ description, script_body, is_active, is_library }`
## The companion `set_flags()` method shares the same path constant but sends
## only `{ is_active, is_library }`.
##
## upstream: 9_LuaScript/LuaScriptManager.cs:178 (UpdateScript),
##           9_LuaScript/LuaScriptManager.cs:378 (UpdateScriptCoroutine)
func update_script(script_id: String, body: Dictionary) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		update_failed.emit(err)
		return _envelope_fail(err)

	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated. Please login first."
		update_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "Game Id is required."
		update_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:185-189 — script id is mandatory for update.
	if script_id == null or String(script_id).strip_edges().is_empty():
		var err := "Script Id is required for update."
		update_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SCRIPT_BY_ID.replace("{game_id}", game_id).replace(
		"{script_id}", script_id
	)
	var result: Dictionary = await server.patch_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "update script failed"))
		update_failed.emit(error_msg)
		return result

	var raw: Variant = result.get("data", null)
	var id_value: String = _extract_script_id(raw)
	if id_value.is_empty():
		id_value = script_id
	update_success.emit(id_value, raw)

	var out := result.duplicate(true)
	out["data"] = {"id": id_value, "raw": raw}
	return out


## PATCH /api/v1/games/{game_id}/scripts/{script_id}
##
## FLAGS-ONLY shape. Upstream `FlagsRequest` (LuaScriptManager.cs:603):
##   `{ is_active, is_library }`
## Shares the same path constant as `update_script()`; the two methods differ
## ONLY in body shape (see the M9 discovery note in CLAUDE.md / endpoints.md).
##
## Convenience: callers commonly pass a `{enabled: bool}` dict (matches
## docs/examples/lua_script.md). This is normalised to `is_active` for the
## wire shape. Pass `is_active` / `is_library` directly to bypass the alias.
##
## upstream: 9_LuaScript/LuaScriptManager.cs:102 (UpdateScriptFlagsAtIndex),
##           9_LuaScript/LuaScriptManager.cs:401 (UpdateScriptFlagsCoroutine)
func set_flags(script_id: String, flags: Dictionary) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		flags_failed.emit(err)
		return _envelope_fail(err)

	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated. Please login first."
		flags_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "Game Id is required."
		flags_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:115-119 — script id is mandatory.
	if script_id == null or String(script_id).strip_edges().is_empty():
		var err := "Script Id is required for update."
		flags_failed.emit(err)
		return _envelope_fail(err)

	# Build the wire body. `enabled` alias → `is_active` per docs/examples.
	var body: Dictionary = {}
	if flags.has("is_active"):
		body["is_active"] = bool(flags["is_active"])
	elif flags.has("enabled"):
		body["is_active"] = bool(flags["enabled"])
	if flags.has("is_library"):
		body["is_library"] = bool(flags["is_library"])

	var path: String = PATH_SCRIPT_BY_ID.replace("{game_id}", game_id).replace(
		"{script_id}", script_id
	)
	var result: Dictionary = await server.patch_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "set flags failed"))
		flags_failed.emit(error_msg)
		return result

	var raw: Variant = result.get("data", null)
	var id_value: String = _extract_script_id(raw)
	if id_value.is_empty():
		id_value = script_id
	flags_success.emit(id_value, raw)

	var out := result.duplicate(true)
	out["data"] = {"id": id_value, "raw": raw}
	return out


## DELETE /api/v1/games/{game_id}/scripts/{script_id}
##
## Response is forwarded raw — upstream's `DeleteScriptCoroutine` only echoes
## the `onSuccess(response)` payload (LuaScriptManager.cs:424).
##
## upstream: 9_LuaScript/LuaScriptManager.cs:194 (DeleteScript),
##           9_LuaScript/LuaScriptManager.cs:417 (DeleteScriptCoroutine)
func delete_script(script_id: String) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		delete_failed.emit(err)
		return _envelope_fail(err)

	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated. Please login first."
		delete_failed.emit(err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "Game Id is required."
		delete_failed.emit(err)
		return _envelope_fail(err)

	# upstream: LuaScriptManager.cs:201-205 — script id is mandatory.
	if script_id == null or String(script_id).strip_edges().is_empty():
		var err := "Script Id is required for delete."
		delete_failed.emit(err)
		return _envelope_fail(err)

	var path: String = PATH_SCRIPT_BY_ID.replace("{game_id}", game_id).replace(
		"{script_id}", script_id
	)
	var result: Dictionary = await server.delete_request(path, null, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "delete script failed"))
		delete_failed.emit(error_msg)
		return result

	delete_success.emit(script_id)

	var out := result.duplicate(true)
	out["data"] = {"id": script_id, "raw": result.get("data", null)}
	return out


## POST /api/v1/games/{game_id}/scripts/{script_name}/run
##
## Invokes a server-hosted Lua script. `params` is sent verbatim — upstream's
## `BattleScript` (BattleScript.cs:17) wraps caller input under a `payload`
## key by default, so we follow the same convention to keep parity with the
## M6c port. Callers that already include a top-level `payload` key (or want
## a different wrapper) can pass a fully-formed body directly via the second
## form of this method — see `run_raw_body()` below.
##
## Body and response are DYNAMIC — both are per-script contracts. The
## response is forwarded raw under `data.raw` and not deserialised by the SDK.
##
## upstream: 8_Battle/BattleScript.cs:30 (RunScript),
##           8_Battle/BattleScript.cs:62 (RunScriptCoroutine)
func run(script_name: String, params: Dictionary = {}) -> Dictionary:
	return await run_raw_body(script_name, {"payload": params if params != null else {}})


## Variant of `run()` that sends `body` exactly as given (no `payload` wrap).
## Use this if your server-side script expects a flat body shape.
func run_raw_body(script_name: String, body: Variant) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		run_failed.emit(script_name, err)
		return _envelope_fail(err)

	# upstream: BattleScript.cs:45-49 — refuse before sending.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		run_failed.emit(script_name, err)
		return _envelope_fail(err)

	# upstream: BattleScript.cs:53-57 — refuse empty script name.
	if script_name == null or script_name.is_empty():
		var err := "Script name is empty!"
		run_failed.emit(script_name, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		run_failed.emit(script_name, err)
		return _envelope_fail(err)

	var path: String = PATH_RUN_SCRIPT.replace("{game_id}", game_id).replace(
		"{script_name}", script_name
	)
	var result: Dictionary = await server.post_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "run script failed"))
		run_failed.emit(script_name, error_msg)
		return result

	var raw: Variant = result.get("data", null)
	run_success.emit(script_name, raw)

	var out := result.duplicate(true)
	out["data"] = {"name": script_name, "raw": raw}
	return out


# =========================================================================
# Convenience helpers (operate on `cached_scripts`)
# =========================================================================


## upstream: 9_LuaScript/LuaScriptManager.cs:210 (FindScriptFileByName)
func get_script_by_name(script_name: String) -> Variant:
	for s in cached_scripts:
		if s is Dictionary and String(s.get("name", "")) == script_name:
			return s
	return null


## True iff `cached_scripts` is non-empty.
func has_scripts() -> bool:
	return cached_scripts.size() > 0


## Drop the cached list. No-op on the wire.
func clear_scripts() -> void:
	cached_scripts = []


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirrors SaiAuth._server (auth/sai_auth.gd:258-276): prefer parent, fall
	# back to autoload, then to the scene tree — keeps the class testable
	# under a fake-parent harness.
	var parent: Node = get_parent()
	if parent != null and parent.has_method("get_request"):
		return parent
	if Engine.has_singleton("SaiServer"):
		return Engine.get_singleton("SaiServer")
	if is_inside_tree():
		var node: Node = get_tree().root.get_node_or_null("SaiServer")
		if node != null:
			return node
	return null


func _game_id(server: Node) -> String:
	if server.has_method("normalized_game_id"):
		return String(server.normalized_game_id())
	if "game_id" in server:
		return String(server.game_id).strip_edges()
	return ""


## Walk `raw` to find the records array. Tolerates four shapes:
##   - bare Array (SaiServer parses `[...]` directly)
##   - `{ scripts: [...] }`
##   - `{ data:    [...] }`
##   - `{ items:   [...] }`
## Order matches upstream's `GetBackendScripts` (LuaScriptManager.cs:340) so
## the first wrapper present wins.
func _extract_scripts_array(raw: Variant) -> Array:
	if raw is Array:
		return raw
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key in ["scripts", "data", "items"]:
			var val: Variant = dict.get(key, null)
			if val is Array:
				return val
	return []


## Extract `id` from a create/update response. Upstream's `ApiResponse`
## (LuaScriptManager.cs:610) reads only `{id}` so we mirror that fallback
## chain but also accept the field under a `data` wrapper for back-compat
## with proxies that re-wrap creation responses.
func _extract_script_id(raw: Variant) -> String:
	if raw is Dictionary:
		var dict: Dictionary = raw
		var id_top: String = String(dict.get("id", ""))
		if not id_top.is_empty():
			return id_top
		var nested: Variant = dict.get("data", null)
		if nested is Dictionary:
			return String((nested as Dictionary).get("id", ""))
	return ""


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
