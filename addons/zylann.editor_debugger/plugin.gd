@tool
extends EditorPlugin

const DockScene = preload("dock.tscn")

const Dock = preload("dock.gd")
const Util = preload("util.gd")

var _dock: Dock = null


func _enter_tree() -> void:
	_dock = DockScene.instantiate()
	_dock.node_selected.connect(_on_EditorDebugger_node_selected)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	
	#var editor_settings := get_editor_interface().get_editor_settings()


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()
	_dock = null


func _on_EditorDebugger_node_selected(node: Node) -> void:
	if _dock.is_inspection_enabled():
		if _is_under_editor_inspector(node):
			# Prevent inspecting the inspector, because unfortunately it can crash.
			# Something inside Godot is not handling well the possibility that what is inspected
			# could be freed anytime.
			return
		# Oops.
		EditorInterface.inspect_object(node)


func _is_under_editor_inspector(node: Node) -> bool:
	return Util.get_node_in_parents(node, EditorInspector) != null
