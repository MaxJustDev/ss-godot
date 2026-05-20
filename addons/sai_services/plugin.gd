@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SaiServer"
const AUTOLOAD_PATH := "res://addons/sai_services/core/sai_server.gd"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
