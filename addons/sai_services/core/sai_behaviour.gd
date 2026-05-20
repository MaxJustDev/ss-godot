## SaiBehaviour - base class for SaiGame sub-services in the Godot port.
##
## Godot translation note:
##   The upstream `SaiBehaviour` (Unity MonoBehaviour) auto-wires its
##   `[SerializeField]` children inside `LoadComponents()`, called from
##   `Awake()` and `Reset()`. Unity also calls `Reset()` from the editor's
##   "Reset" inspector button. Godot has no direct equivalent of the editor
##   reset button or of MonoBehaviour.Awake(), so this class:
##
##     - calls `_load_components()` from `_ready()` (Godot's runtime entry)
##     - exposes `manual_reset()` as a public method that subclasses (or an
##       editor tool) can invoke to trigger `_load_components()` and
##       `_reset_values()` together.
##
## Subclasses should override `_load_components()` to grab child nodes and
## `_reset_values()` to set inspector defaults.
##
## upstream: ss-unity/Assets/SaiGame/Scripts/Common/SaiBehaviour.cs:5
class_name SaiBehaviour
extends Node


func _ready() -> void:
	_load_components()


## Override to fetch child nodes / cache references. Called once on `_ready`
## and any time `manual_reset()` is invoked.
##
## upstream: SaiBehaviour.cs:24
func _load_components() -> void:
	pass


## Override to reset inspector-visible state back to defaults.
##
## upstream: SaiBehaviour.cs:29
func _reset_values() -> void:
	pass


## Editor / debug helper. Equivalent of Unity's "Reset" inspector button —
## reloads components then resets values.
##
## upstream: SaiBehaviour.cs:18
func manual_reset() -> void:
	_load_components()
	_reset_values()


## Shorthand for hiding/showing this node. Matches the upstream helper that
## toggled GameObject.SetActive.
##
## upstream: SaiBehaviour.cs:34
func set_active(active: bool) -> void:
	if active:
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		process_mode = Node.PROCESS_MODE_DISABLED
	# Visibility only matters for CanvasItem/Node3D subclasses, but we
	# attempt it generically so editor sub-nodes hide themselves too.
	if has_method("set_visible"):
		call("set_visible", active)
