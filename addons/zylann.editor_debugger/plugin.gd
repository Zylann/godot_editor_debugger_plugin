@tool
extends EditorPlugin

const Dock := preload("res://addons/zylann.editor_debugger/dock.gd")
const DockScene: PackedScene = preload("res://addons/zylann.editor_debugger/dock.tscn")
var _dock: Dock = null


func _enter_tree() -> void:
	_dock = DockScene.instantiate()
	_dock.node_selected.connect(_on_EditorDebugger_node_selected)
	_dock.get_theme_icon = Callable(self, "get_theme_icon")
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	
	#var editor_settings := get_editor_interface().get_editor_settings()


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()
	_dock = null


func _on_EditorDebugger_node_selected(node: Node) -> void:
	if _dock.is_inspection_enabled():
		# Oops.
		get_editor_interface().inspect_object(node)


# The default "icon not found" texture. Captured so it can be compared against when trying to
# find a specific icon
# @see get_theme_icon
var _no_texture := get_editor_interface().get_base_control().get_theme_icon("", "EditorIcons")


# Returns a theme icon for the provided class name. You may provide an 
# alternative class name as the second argument to avoid getting a "not found" icon
# @param icon_name              For example, "Button", or "Node2D"
# @param if_not_found_pick_this Generally, "Node". Leave blank to get a broken "not found" icon
func get_theme_icon(icon_name: String, if_not_found_pick_this:="") -> Texture2D:
	var texture := get_editor_interface().get_base_control().get_theme_icon(icon_name, "EditorIcons")
	if (texture == null or texture == _no_texture) and if_not_found_pick_this != "":
		texture = get_editor_interface().get_base_control().get_theme_icon(if_not_found_pick_this, "EditorIcons")
	return texture
