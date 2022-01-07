@tool
extends EditorPlugin

var _dock = null


func _enter_tree():
	_dock = load("res://addons/zylann.editor_debugger/dock.tscn")
	_dock = _dock.instantiate()
	_dock.node_selected.connect(_on_EditorDebugger_node_selected)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	
	#var editor_settings = get_editor_interface().get_editor_settings()


func _exit_tree():
	remove_control_from_docks(_dock)
	_dock.free()
	_dock = null


func _on_EditorDebugger_node_selected(node):
	if _dock.is_inspection_enabled():
		# Oops.
		get_editor_interface().inspect_object(node)
