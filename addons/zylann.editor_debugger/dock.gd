@tool
extends Control

const Util = preload("util.gd")
const LiveTree = preload("./live_tree.gd")

@onready var _popup_menu : PopupMenu = get_node("PopupMenu")
@onready var _inspection_checkbox : CheckBox = get_node("VBoxContainer/ShowInInspectorCheckbox")
@onready var _label : Label = get_node("VBoxContainer/Label")
@onready var _tree_view : LiveTree = get_node("VBoxContainer/LiveTree")
@onready var _save_branch_file_dialog : FileDialog = get_node("SaveBranchFileDialog")

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


func _enter_tree() -> void:
	if Util.is_in_edited_scene(self):
		return
	_control_highlighter = ColorRect.new()
	_control_highlighter.color = Color(1, 1, 0, 0.2)
	_control_highlighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_control_highlighter.hide()
	get_viewport().call_deferred("add_child", _control_highlighter)


func _exit_tree() -> void:
	if _control_highlighter != null:
		_control_highlighter.queue_free()


func _process(delta: float) -> void:
	if Util.is_in_edited_scene(self):
		set_process(false)
		return
	
	var viewport := get_viewport()
	_label.text = str(viewport.get_mouse_position())


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
	return Util.get_node_in_parents(node, EditorInspector) != null


func _on_tree_item_selected() -> void:
	_select_node()


func _on_tree_item_mouse_selected(_unused_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_select_node()
		_popup_menu.popup()
		_popup_menu.set_position(get_viewport().get_mouse_position())


func _highlight_node(node: Node) -> void:
	if node is Control:
		var target_control := (node as Control)
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
	_control_highlighter.hide()


func _input(event: InputEvent) -> void:
	var event_key := event as InputEventKey
	if event_key != null and event_key.pressed:
		if event_key.keycode == KEY_F12:
			pick(get_viewport().get_mouse_position())
	
	var event_mouse_button := event as InputEventMouseButton
	if event_mouse_button != null and event_mouse_button.pressed:
		if event_mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_control_highlighter.hide()


func pick(mpos: Vector2) -> void:
	var root := get_tree().root
	var node := _pick(root, mpos)
	if node != null:
		_tree_view.focus_in_tree(node)
	else:
		_highlight_node(null)


func _pick(root: Node, mpos: Vector2, level := 0) -> Node:
#	var s := ""
#	for i in level:
#		s = str(s, "  ")
#
#	print(s, "Looking at ", root, ": ", root.name)
	
	var node: Node = null
	
	for i in root.get_child_count(true):
		var child := root.get_child(i, true)
		
		var child_canvas_item := child as CanvasItem
		if (child_canvas_item != null and not child_canvas_item.visible):
			#print(s, child, " is invisible or viewport")
			continue
		if child is Viewport:
			continue
		if child == _control_highlighter:
			continue
		
		var child_control := child as Control
		if child_control != null and child_control.get_global_rect().has_point(mpos):
			var c := _pick(child, mpos, level + 1)
			if c != null:
				return c
			else:
				node = child
		else:
			var c := _pick(child, mpos, level + 1)
			if c != null:
				return c
	
	return node

# @param root
# @param {Dictionary[Node, Node]} owners
static func override_ownership(root: Node, owners: Dictionary, include_internal: bool) -> void:
	assert(root is Node)
	_override_ownership_recursive(root, root, owners, include_internal)


# @param root
# @param node
# @param {Dictionary[Node, Node]} owners
static func _override_ownership_recursive(root: Node, node: Node, owners: Dictionary, 
	include_internal: bool) -> void:
	# Make root own all children of node.
	for child in node.get_children(include_internal):
		if child.owner != null:
			owners[child] = child.owner
		child.set_owner(root)
		_override_ownership_recursive(root, child, owners, include_internal)


# @param root
# @param {Dictionary[Node, Node]} owners
static func restore_ownership(root: Node, owners: Dictionary, include_internal: bool) -> void:
	assert(root is Node)
	# Remove all of root's children's owners.
	# Also restore node ownership to nodes which had their owner overridden.
	for child in root.get_children(include_internal):
		if owners.has(child):
			child.owner = owners[child]
			owners.erase(child)
		else:
			child.set_owner(null)
		restore_ownership(child, owners, include_internal)


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
	# Make the selected node own all it's children.
	var owners := {}
	override_ownership(node, owners, true)
	# Pack the selected node and it's children into a scene then save it.
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	ResourceSaver.save(packed_scene, path)
	# Revert ownership of all children.
	restore_ownership(node, owners, true)


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
