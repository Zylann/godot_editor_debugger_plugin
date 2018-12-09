tool
extends EditorPlugin

var _dock = null


func _enter_tree():
	_dock = load("res://addons/zylann.editor_debugger/dock.tscn")
	_dock = _dock.instance()
	_dock.connect("node_selected", self, "_on_EditorDebugger_node_selected")
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	
	var editor_settings = get_editor_interface().get_editor_settings()
	editor_settings.connect("settings_changed", self, "_on_EditorSettings_settings_changed")
	call_deferred("_on_EditorSettings_settings_changed")


func _exit_tree():
	remove_control_from_docks(_dock)
	_dock.free()
	_dock = null


func _on_EditorDebugger_node_selected(node):
	if _dock.is_inspection_enabled():
		# Oops.
		get_editor_interface().inspect_object(node)


func _on_EditorSettings_settings_changed():
	var editor_settings = get_editor_interface().get_editor_settings()
	
	var enable_rl = editor_settings.get_setting("docks/scene_tree/draw_relationship_lines")
	var rl_color = editor_settings.get_setting("docks/scene_tree/relationship_line_color")
	
	var tree = _dock.get_tree_view()
	
	if enable_rl:
		tree.add_constant_override("draw_relationship_lines", 1)
		tree.add_color_override("relationship_line_color", rl_color)
		tree.add_constant_override("draw_guides", 0)
	else:
		tree.add_constant_override("draw_relationship_lines", 0)
		tree.add_constant_override("draw_guides", 1)
