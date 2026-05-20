## AuthEventListener - example bridge that forwards SaiServer / SaiAuth
## events to subclasses or to game code.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/AuthEventListener.cs:8
##
## Translation notes:
##   - Unity used C# `event Action<T>` subscribed in `OnEnable`. Godot
##     `signal` + `connect()` is the direct analogue.
##   - The upstream version references `SaiAuth` directly (which doesn't
##     exist until M2). To avoid blocking M2, this listener wires up only
##     to signals that EXIST on `SaiServer` today (`token_refreshed`,
##     `auth_required`). In M2, additional `login_success` / `login_failed`
##     / `logout_success` / `logout_failed` connections should be added in
##     `_connect_auth_signals()` once `SaiAuth` exposes them.
##   - Override the `_handle_*` virtual methods in subclasses to react.
class_name AuthEventListener
extends SaiBehaviour

const SAI_SERVER_AUTOLOAD_PATH := "/root/SaiServer"

var _sai_server: Node


func _load_components() -> void:
	# Cache the autoload reference. We deliberately use get_node() so this
	# class works even before code-completion is aware of SaiServer's type.
	_sai_server = get_node_or_null(SAI_SERVER_AUTOLOAD_PATH)


func _enter_tree() -> void:
	# Re-cache and connect every time we enter the tree (handles scene
	# reload). Disconnect on exit to avoid leaks if the listener outlives
	# its parent.
	_sai_server = get_node_or_null(SAI_SERVER_AUTOLOAD_PATH)
	_connect_auth_signals(true)


func _exit_tree() -> void:
	_connect_auth_signals(false)


func _connect_auth_signals(connect: bool) -> void:
	if _sai_server == null:
		return
	_toggle(_sai_server, "token_refreshed", Callable(self, "_on_token_refreshed"), connect)
	_toggle(_sai_server, "auth_required", Callable(self, "_on_auth_required"), connect)
	# TODO(M2): When SaiAuth is added as a child of SaiServer, expose
	# `login_success(LoginResponse)`, `login_failed(String)`,
	# `logout_success()`, `logout_failed(String)` and connect them here:
	#   var auth := _sai_server.get_node_or_null("SaiAuth")
	#   _toggle(auth, "login_success", Callable(self, "_on_login_success"), connect)
	#   ...


func _toggle(source: Object, signal_name: String, target: Callable, connect: bool) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	var is_connected: bool = source.is_connected(signal_name, target)
	if connect and not is_connected:
		source.connect(signal_name, target)
	elif not connect and is_connected:
		source.disconnect(signal_name, target)


# -------------------------------------------------------------------------
# Virtual handlers — override in subclasses.
# -------------------------------------------------------------------------


## upstream: AuthEventListener.cs:42 (HandleLoginSuccess)
func _handle_login_success(_response: Dictionary) -> void:
	pass


## upstream: AuthEventListener.cs:48 (HandleLoginFailure)
func _handle_login_failure(_error: String) -> void:
	pass


## upstream: AuthEventListener.cs:54 (HandleLogoutSuccess)
func _handle_logout_success() -> void:
	pass


## upstream: AuthEventListener.cs:60 (HandleLogoutFailure)
func _handle_logout_failure(_error: String) -> void:
	pass


## Fires after a successful access-token refresh.
func _handle_token_refreshed(_access_token: String) -> void:
	pass


## Fires when SaiServer detects there is no token / a 401 was returned.
func _handle_auth_required() -> void:
	pass


# -------------------------------------------------------------------------
# Internal signal hops
# -------------------------------------------------------------------------


func _on_token_refreshed(access_token: String) -> void:
	_handle_token_refreshed(access_token)


func _on_auth_required() -> void:
	_handle_auth_required()
