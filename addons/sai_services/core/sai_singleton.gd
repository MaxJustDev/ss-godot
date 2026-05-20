## SaiSingleton - convenience base for sub-services that want a single
## process-wide accessor.
##
## Godot translation note:
##   Unity's `SaiSingleton<T>` mixes "singleton accessor" + "duplicate
##   destruction" + `DontDestroyOnLoad`. In Godot, the **autoload** is the
##   singleton — `SaiServer` is registered as an autoload and reachable via
##   `get_node("/root/SaiServer")`. Sub-services live as children of
##   `SaiServer`, so they have a single owner and persist for the lifetime
##   of the application.
##
##   This class therefore reduces to a thin helper: it provides an
##   `instance()` static-ish accessor that returns the first node in the
##   scene tree with the same class. Most sub-services should NOT need
##   this — they should be accessed via `SaiServer.<service>` properties.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/SaiSingleton.cs:5
class_name SaiSingleton
extends SaiBehaviour


## Returns the first node of the given script that exists in the current
## scene tree, or `null` if none found. Subclasses can wrap this with a
## typed `instance()` helper:
##
##     class_name MyService extends SaiSingleton
##     static func instance() -> MyService:
##         return _find_first(load("res://addons/sai_services/.../my_service.gd"))
##
## NOTE: Per project rule B.7, only `SaiServer` is an autoload. Prefer
## reaching sub-services through `SaiServer` instead of via this helper.
static func _find_first(script_ref: Script) -> Node:
	var root := Engine.get_main_loop()
	if root == null:
		return null
	var tree := root as SceneTree
	if tree == null or tree.root == null:
		return null
	return _walk(tree.root, script_ref)


static func _walk(node: Node, script_ref: Script) -> Node:
	if node.get_script() == script_ref:
		return node
	for child in node.get_children():
		var found: Node = _walk(child, script_ref)
		if found != null:
			return found
	return null
