## BattleScript - thin RPC wrapper for server-side Lua battle scripts.
##
## Port of `ss-unity/Assets/SaiGame/Scripts/8_Battle/BattleScript.cs:8`
## (upstream v0.2.40d).
##
## Translation notes:
##   - Unity callback pairs (`onSuccess` / `onError`) are replaced by the
##     project-standard envelope `{success, status, error, data}` plus
##     parallel signals (CLAUDE.md B.4, B.5).
##   - Sole endpoint: `POST /api/v1/games/{game_id}/scripts/{script_name}/run`
##     (BattleScript.cs:69). We mirror it as `run_script(script_name, params)`.
##   - The response is FORWARDED RAW. Upstream's reference model
##     `BattleScriptResponse { raw }` (`Responses/BattleScriptResponse.cs:8`)
##     is never deserialised — `BattleScript.cs:74` just stores the raw JSON
##     string. Per the M6c discovery note, the server-side schema is fully
##     opaque, so we surface `data` as the Dictionary parsed by SaiServer's
##     generic JSON pass and do NOT decode into a typed Resource. Callers
##     who need a typed view should build their own DTO per script.
##   - Upstream's `BeautifyResponse` / `JsonBeautify` helpers
##     (BattleScript.cs:94-155) were UI conveniences for the Unity inspector
##     and are intentionally NOT ported — `JSON.stringify(value, "\t")` in
##     GDScript replaces them when callers want a pretty string.
##   - Upstream stores `scriptName` + `requestBody` as Inspector defaults
##     (BattleScript.cs:14-17). The Godot port takes them per-call so the
##     class stays stateless; a future M7+ inspector-driven harness could
##     re-introduce them as `@export` if there is demand.
##   - This node is added as a child of `SaiServer` during M1's _ready hook.
##     Use `SaiServer.battle_script` from app code.
##
## upstream: 8_Battle/BattleScript.cs:8
class_name BattleScript
extends Node

# -------------------------------------------------------------------------
# Endpoints (B.6 — no magic strings)
# -------------------------------------------------------------------------

## upstream: BattleScript.cs:69
const PATH_RUN_SCRIPT := "/api/v1/games/{game_id}/scripts/{script_name}/run"

# -------------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------------

## Emitted on successful `run_script()`. `name` echoes the script name passed
## by the caller; `raw_data` is the parsed JSON response forwarded raw — its
## shape is opaque to the SDK (per-script payload).
## upstream: BattleScript.cs:10 (OnRunScriptSuccess)
signal script_success(name: String, raw_data: Variant)

## Emitted on any failure path — pre-flight (no SaiServer / not authenticated
## / empty game_id / empty script name) or wire-level (network / non-2xx).
## upstream: BattleScript.cs:11 (OnRunScriptFailure)
signal script_failed(name: String, error: String)

# =========================================================================
# Public API
# =========================================================================


## POST /api/v1/games/{game_id}/scripts/{script_name}/run
##
## `script_name` is the server-side Lua script id (e.g. `"damage_calc"`).
## `params` is sent verbatim under the `payload` key — upstream's reference
## `BattleScriptRequest { payload }` shape (`Requests/BattleScriptRequest.cs:8`).
## Pass an empty Dictionary to send the upstream default body `{"payload": {}}`
## (BattleScript.cs:17).
##
## Returns the standard envelope. On success, `data` is a Dictionary with:
##   - `name`: String — echoes the input script name
##   - `raw`: Variant — the raw parsed JSON (Dictionary / Array / null), as
##     forwarded by SaiServer. Per the M6c discovery note this is opaque to
##     the SDK; callers must agree on shape with the server-side script.
##
## upstream: BattleScript.cs:30 (RunScript), BattleScript.cs:62 (RunScriptCoroutine)
func run_script(script_name: String, params: Dictionary = {}) -> Dictionary:
	var server: Node = _server()
	if server == null:
		var err := "SaiServer not found"
		script_failed.emit(script_name, err)
		return _envelope_fail(err)

	# upstream: BattleScript.cs:45-49 — refuse before sending.
	if server.has_method("is_authenticated") and not server.is_authenticated():
		var err := "Not authenticated! Please login first."
		script_failed.emit(script_name, err)
		return _envelope_fail(err)

	# upstream: BattleScript.cs:53-57 — refuse empty script name.
	if script_name == null or script_name.is_empty():
		var err := "Script name is empty!"
		script_failed.emit(script_name, err)
		return _envelope_fail(err)

	var game_id: String = _game_id(server)
	if game_id.is_empty():
		var err := "game_id is empty — set SaiServer.game_id first"
		script_failed.emit(script_name, err)
		return _envelope_fail(err)

	var path: String = PATH_RUN_SCRIPT.replace("{game_id}", game_id).replace(
		"{script_name}", script_name
	)
	# upstream: BattleScript.cs:17 — default body shape is `{ "payload": {} }`.
	var body: Dictionary = {"payload": params if params != null else {}}
	var result: Dictionary = await server.post_request(path, body, true)

	if not result.get("success", false):
		var error_msg: String = String(result.get("error", "run script failed"))
		script_failed.emit(script_name, error_msg)
		return result

	# Raw passthrough — schema is fully opaque to the SDK.
	var raw: Variant = result.get("data", null)
	script_success.emit(script_name, raw)

	var out := result.duplicate(true)
	out["data"] = {
		"name": script_name,
		"raw": raw,
	}
	return out


# =========================================================================
# Internals
# =========================================================================


func _server() -> Node:
	# Mirrors SaiAuth._server: prefer parent, fall back to autoload, then to
	# the scene tree — keeps the class testable under a fake-parent harness.
	var parent: Node = get_parent()
	if parent != null and parent.has_method("post_request"):
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


func _envelope_fail(error: String, status: int = 0, data: Variant = null) -> Dictionary:
	return {"success": false, "status": status, "error": error, "data": data}
