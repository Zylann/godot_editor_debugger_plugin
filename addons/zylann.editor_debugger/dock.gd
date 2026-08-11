@tool
extends Control

const Util = preload("util.gd")
const LiveTree = preload("./live_tree.gd")

@onready var _popup_menu : PopupMenu = $PopupMenu
@onready var _inspection_checkbox : CheckBox = $VBoxContainer/ShowInInspectorCheckbox
@onready var _label : Label = $VBoxContainer/Label
@onready var _tree_view : LiveTree = $VBoxContainer/LiveTree
@onready var _save_branch_file_dialog : FileDialog = $SaveBranchFileDialog

enum POPUP_ACTIONS {
	SAVE_BRANCH_AS_SCENE,
	COPY_PATH_TO_CLIPBOARD,
	COPY_NODE_TYPES_TO_CLIPBOARD,
	COPY_NODE_CHILD_PATH_INDICES
}

const _popup_action_names: Dictionary = {
	POPUP_ACTIONS.SAVE_BRANCH_AS_SCENE: {
		"title": "Save branch as scene",
		"tooltip": "Save the branch as a new scene in a directory of your choice"
	},
	POPUP_ACTIONS.COPY_PATH_TO_CLIPBOARD: {
		"title": "Copy path to clipboard",
		"tooltip": "Copy the path to the node in the format \"/path/to/node\""
	},
	POPUP_ACTIONS.COPY_NODE_TYPES_TO_CLIPBOARD:{
		"title": "Copy typed path to clipboard",
		"tooltip": "Copy the path to the node in the format [[\"type\", \"node\"], [\"type\", \"node\"], ...]"
	},
	POPUP_ACTIONS.COPY_NODE_CHILD_PATH_INDICES:{
		"title": "Copy child path indicies",
		"tooltip": "Copy the get_child() path indicies"
	}
}

var _control_highlighter: ColorRect = null


func _ready() -> void:
	if Util.is_in_edited_scene(self):
		return
	
	_popup_menu.clear()
	
	for id: int in _popup_action_names:
		# Doing all of this typed unpacking to fix extra GDScript unsafe cast warnings
		var popup_data: Dictionary = _popup_action_names[id]
		var popup_title: String = popup_data.title
		var popup_tooltip: String = popup_data.tooltip
		_popup_menu.add_item(popup_title, id)
		var index := _popup_menu.get_item_index(id)
		_popup_menu.set_item_tooltip(index, popup_tooltip)
	
	_tree_view.item_selected.connect(_on_tree_item_selected)
	_tree_view.item_mouse_selected.connect(_on_tree_item_mouse_selected)
	_tree_view.nothing_selected.connect(_on_tree_nothing_selected)
	
	var root := get_tree().root
	root.window_input.connect(_handle_input)
	if not root.gui_embed_subwindows:
		root.mouse_exited.connect(_connect_to_window)
		root.focus_exited.connect(_connect_to_window)


func _exit_tree() -> void:
	if _control_highlighter != null:
		_control_highlighter.queue_free()


func _process(delta: float) -> void:
	if Util.is_in_edited_scene(self):
		set_process(false)
		return
	
	var viewport := get_viewport()
	_label.text = str(viewport.get_mouse_position())


func _create_highlighter() -> void:
	if is_instance_valid(_control_highlighter):
		return
	_control_highlighter = ColorRect.new()
	_control_highlighter.name = "EditorDebuggerHighlighter"
	_control_highlighter.color = Color(1, 1, 0, 0.2)
	_control_highlighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_control_highlighter.top_level = true
	_control_highlighter.hide()
	get_viewport().add_child(_control_highlighter)


func _select_node() -> void:
	var node := _tree_view.get_selected_node()
	
	_highlight_node(node)
	
	if _inspection_checkbox.button_pressed:
		_inspect_object(node)


func _on_ShowInInspectorCheckbox_toggled(button_pressed: bool) -> void:
	if Util.is_in_edited_scene(self):
		return
	if not button_pressed:
		return
	var node := _tree_view.get_selected_node()
	_inspect_object(node)


func _inspect_object(node: Node) -> void:
	if _is_under_editor_inspector(node):
		# Prevent inspecting the inspector, because unfortunately it can crash.
		# Something inside Godot is not handling well the possibility that what is inspected
		# could be freed anytime.
		return
	EditorInterface.inspect_object(node, "", true)


func _is_under_editor_inspector(node: Node) -> bool:
	return EditorInterface.get_inspector().is_ancestor_of(node)


func _on_tree_item_selected() -> void:
	_select_node()


func _on_tree_item_mouse_selected(_unused_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_select_node()
		_popup_menu.popup()
		_popup_menu.set_position(get_viewport().get_mouse_position())


func _highlight_node(node: Node) -> void:
	# The control highlighter may have been attached to a viewport that was deleted, so recreate if needed. 
	if not is_instance_valid(_control_highlighter):
		_create_highlighter()

	if node is Control:
		var target_control := (node as Control)
		if _control_highlighter == target_control:
			return
		# Parent to viewport of target for multiwindow.
		# Don't parent directly to target to show for hidden items.
		_control_highlighter.reparent(target_control.get_viewport(), false)
		_control_highlighter.global_position = target_control.global_position
		_control_highlighter.size = target_control.size
		_control_highlighter.show()
	else:
		_control_highlighter.hide()


static func _get_index_path(node: Node) -> Array[int]:
	var ipath: Array[int] = []
	while node.get_parent() != null:
		ipath.append(node.get_index())
		node = node.get_parent()
	ipath.reverse()
	return ipath


func _on_tree_nothing_selected() -> void:
	if is_instance_valid(_control_highlighter):
		_control_highlighter.hide()


func _connect_to_window() -> void:
	var window_id := DisplayServer.window_get_active_popup()
	if window_id == DisplayServer.INVALID_WINDOW_ID:
		window_id = DisplayServer.get_window_at_screen_position(DisplayServer.mouse_get_position())
	if window_id == DisplayServer.INVALID_WINDOW_ID or window_id == DisplayServer.MAIN_WINDOW_ID:
		return

	var win_obj_id := DisplayServer.window_get_attached_instance_id(window_id)
	var window := instance_from_id(win_obj_id) as Window
	if window == null:
		printerr("Failed to connect to window ", window_id)
		return

	if not window.window_input.is_connected(_handle_input):
		window.window_input.connect(_handle_input)
		# Window focus exited isn't emitted for popups so also connect to mouse exit.
		window.mouse_exited.connect(_connect_to_window)
		window.focus_exited.connect(_connect_to_window)


func _handle_input(event: InputEvent) -> void:
	var event_key := event as InputEventKey
	if event_key != null and event_key.pressed:
		if event_key.keycode == KEY_F12:
			var window: Window
			if get_tree().root.gui_embed_subwindows:
				window = get_window()
				var focused_window := Util.get_focused_window()
				if focused_window != null:
					# First try the focused window for popups.
					if pick(focused_window.get_mouse_position(), focused_window):
						return
					if focused_window == window:
						return
			else:
				var screen_mouse_pos := DisplayServer.mouse_get_position()
				var window_id := DisplayServer.get_window_at_screen_position(screen_mouse_pos)
				if window_id == DisplayServer.INVALID_WINDOW_ID:
					return
				var win_obj_id := DisplayServer.window_get_attached_instance_id(window_id)
				window = instance_from_id(win_obj_id) as Window
				if window == null:
					printerr("Failed to get window under mouse ", window_id)
					return
			pick(window.get_mouse_position(), window)

	var event_mouse_button := event as InputEventMouseButton
	if event_mouse_button != null and event_mouse_button.pressed and is_instance_valid(_control_highlighter):
		if event_mouse_button.button_index in [
			MOUSE_BUTTON_LEFT, 
			MOUSE_BUTTON_MIDDLE, 
			MOUSE_BUTTON_RIGHT
		]:
			_control_highlighter.hide()


func pick(mpos: Vector2, root: Node = null) -> bool:
	if root == null:
		root = get_tree().root
	var node := _pick(root, mpos)
	if node != null:
		_tree_view.focus_in_tree(node)
	else:
		_highlight_node(null)
	return node != null


func _pick(root: Node, mpos: Vector2, level := 0) -> Node:
#	var s := ""
#	for i in level:
#		s = str(s, "  ")
#
#	print(s, "Looking at ", root, ": ", root.name)
	
	var node: Node = null
	# Loop backwards over the children because later children are typically above earlier ones.
	# This helps with picking dialogs on single-window mode.
	for i in range(root.get_child_count(true) - 1, -1, -1):
		var child := root.get_child(i, true)
		
		var child_canvas_item := child as CanvasItem
		if (child_canvas_item != null and not child_canvas_item.visible):
			#print(s, child, " is invisible or viewport")
			continue
		if child == _control_highlighter:
			continue

		var child_mpos := mpos
		var child_window := child as Window
		if child_window != null:
			if not child_window.visible:
				continue
			if child_window.is_embedded():
				child_mpos = mpos - Vector2(child_window.position)
		elif child is Viewport:
			continue

		var child_control := child as Control
		if child_control != null and child_control.get_global_rect().has_point(mpos):
			var c := _pick(child, mpos, level + 1)
			if c != null:
				return c
			else:
				node = child
		else:
			var c := _pick(child, child_mpos, level + 1)
			if c != null:
				return c
	
	return node


func _on_popup_menu_id_pressed(id: int) -> void:
	_popup_menu.hide()
	match id:
		POPUP_ACTIONS.SAVE_BRANCH_AS_SCENE:
			_save_branch_file_dialog.popup_centered_ratio()
		
		POPUP_ACTIONS.COPY_PATH_TO_CLIPBOARD:
			var node := _tree_view.get_selected_node()
			DisplayServer.clipboard_set(node.get_path())
			print("Copied to clipboard: %s"%[node.get_path()])
		
		POPUP_ACTIONS.COPY_NODE_TYPES_TO_CLIPBOARD:
			var node := _tree_view.get_selected_node()
			var node_types := []
			while node.get_parent():
				var tuple := PackedStringArray([node.get_class(), node.name])
				node_types.append(tuple)
				node = node.get_parent()
			node_types.reverse()
			var node_types_str := "%s"%[node_types]
			DisplayServer.clipboard_set(node_types_str)
			print("Copied to clipboard: %s"%[node_types_str])
		
		POPUP_ACTIONS.COPY_NODE_CHILD_PATH_INDICES:
			var node := _tree_view.get_selected_node()
			var index_path := get_node_index_path(node)
			var string_path := path_to_get_child_string(index_path)
			DisplayServer.clipboard_set(string_path)
			print("Copied to clipboard: %s"%[string_path])


func _on_SaveBranchFileDialog_file_selected(path: String) -> void:
	var node := _tree_view.get_selected_node()
	Util.save_node_branch(node, path)


static func get_node_index_path(node: Node) -> PackedInt32Array:
	var ipath := PackedInt32Array()

	while node.get_parent() != null:
		ipath.append(node.get_index(true))
		node = node.get_parent()

	ipath.reverse()
	return ipath


static func path_to_get_child_string(ipath: PackedInt32Array) -> String:
	var code: String = "get_tree().root"
	for i in ipath:
		code += str(".get_child(", i, ")")
	return code
