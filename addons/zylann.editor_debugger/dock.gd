@tool
extends Control

const Util = preload("util.gd")

signal node_selected(node)

@onready var _popup_menu : PopupMenu = get_node("PopupMenu")
@onready var _inspection_checkbox : CheckBox = get_node("VBoxContainer/ShowInInspectorCheckbox")
@onready var _label : Label = get_node("VBoxContainer/Label")
@onready var _tree_view : Tree = get_node("VBoxContainer/Tree")
@onready var _save_branch_file_dialog : FileDialog = get_node("SaveBranchFileDialog")

const METADATA_NODE_NAME = 0

enum POPUP_ACTIONS {
	SAVE_BRANCH_AS_SCENE,
	COPY_PATH_TO_CLIPBOARD,
	COPY_NODE_TYPES_TO_CLIPBOARD,
}

const _popup_action_names = {
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
}

const _update_interval = 1.0

var _time_before_next_update := 0.0
var _control_highlighter: ColorRect = null

# The default "icon not found" texture. Captured so it can be compared against when trying to
# find a specific icon.
# @see _update_node_view
var _no_texture := get_theme_icon("", "EditorIcons")


func get_tree_view() -> Tree:
	return _tree_view


func _ready() -> void:
	_popup_menu.clear()
	for id in _popup_action_names:
		_popup_menu.add_item(_popup_action_names[id].title, id)
		var index := _popup_menu.get_item_index(id)
		_popup_menu.set_item_tooltip(index, _popup_action_names[id].tooltip)

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
	
	_time_before_next_update -= delta
	if _time_before_next_update <= 0:
		_time_before_next_update = _update_interval
		_update_tree()


func _update_tree() -> void:
	var root := get_tree().root
	if root == null:
		_tree_view.clear()
		return

	#print("Updating tree")
	
	var root_view := _tree_view.get_root()
	if root_view == null:
		root_view = _create_node_view(root, null)
	
	_update_branch(root, root_view)


func _update_branch(root: Node, root_view: TreeItem) -> void:
	if root_view.collapsed and root_view.get_first_child() != null:
		# Don't care about collapsed nodes.
		# The editor is a big tree, don't waste cycles on things you can't see
		#print(root, " is collapsed and first child is ", root_view.get_first_child())
		return
	
	var children_views := root_view.get_children()
	
	for i in root.get_child_count(true):
		var child := root.get_child(i, true)
		var child_view: TreeItem
		if i >= len(children_views):
			child_view = _create_node_view(child, root_view)
			children_views.append(child_view)
		else:
			child_view = children_views[i]
			var child_view_name: String = child_view.get_metadata(METADATA_NODE_NAME)
			if child.name != child_view_name:
				_update_node_view(child, child_view)
		_update_branch(child, child_view)
	
	# Remove excess tree items
	if root.get_child_count(true) < len(children_views):
		for i in range(root.get_child_count(true), len(children_views)):
			children_views[i].free()


func _create_node_view(node: Node, parent_view: TreeItem) -> TreeItem:
	#print("Create view for ", node)
	assert(node is Node)
	assert(parent_view == null or parent_view is TreeItem)
	var view := _tree_view.create_item(parent_view)
	view.collapsed = true
	_update_node_view(node, view)
	return view


func _update_node_view(node: Node, view: TreeItem) -> void:
	assert(node is Node)
	assert(view is TreeItem)
	
	var icon_texture := get_theme_icon(node.get_class(), "EditorIcons")
	if (icon_texture == null or icon_texture == _no_texture):
		icon_texture = get_theme_icon("Node", "EditorIcons")
	
	view.set_icon(0, icon_texture)
	view.set_text(0, str(node.get_class(), ": ", node.name))
	
	view.set_metadata(METADATA_NODE_NAME, node.name)


func _select_node() -> void:
	var node_view := _tree_view.get_selected()
	var node := _get_node_from_view(node_view)
	
	print("Selected ", node)
	
	_highlight_node(node)
	
	emit_signal("node_selected", node)


func _on_Tree_item_selected() -> void:
	_select_node()


func _on_Tree_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
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


func _get_node_from_view(node_view: TreeItem) -> Node:
	if node_view.get_parent() == null:
		return get_tree().root
	
	# Reconstruct path
	var path: String = node_view.get_metadata(METADATA_NODE_NAME)
	var parent_view := node_view
	while parent_view.get_parent() != null:
		parent_view = parent_view.get_parent()
		# Exclude root
		if parent_view.get_parent() == null:
			break
		path = str(parent_view.get_metadata(METADATA_NODE_NAME), "/", path)
	
	var node := get_tree().root.get_node(path)
	return node


func _focus_in_tree(node: Node) -> void:
	_update_tree()
	
	var parent: Node = get_tree().root
	var path := node.get_path()
	var parent_view := _tree_view.get_root()
	
	var node_view: TreeItem = null
	
	for i in range(1, path.get_name_count()):
		var part := path.get_name(i)
		print(part)
		
		var child_view := parent_view.get_first_child()
		if child_view == null:
			_update_branch(parent, parent_view)
		
		child_view = parent_view.get_first_child()
		
		while child_view != null and child_view.get_metadata(METADATA_NODE_NAME) != part:
			child_view = child_view.get_next()
		
		if child_view == null:
			node_view = parent_view
			break
		
		node_view = child_view
		parent = parent.get_node(NodePath(part))
		parent_view = child_view
	
	if node_view != null:
		_uncollapse_to_root(node_view)
		node_view.select(0)
		_tree_view.ensure_cursor_is_visible()


static func _uncollapse_to_root(node_view: TreeItem) -> void:
	var parent_view := node_view.get_parent()
	while parent_view != null:
		parent_view.collapsed = false
		parent_view = parent_view.get_parent()


static func _get_index_path(node: Node) -> Array[int]:
	var ipath: Array[int] = []
	while node.get_parent() != null:
		ipath.append(node.get_index())
		node = node.get_parent()
	ipath.reverse()
	return ipath


func _on_Tree_nothing_selected() -> void:
	_control_highlighter.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_F12:
				pick(get_viewport().get_mouse_position())


func pick(mpos: Vector2) -> void:
	var root := get_tree().root
	var node := _pick(root, mpos)
	if node != null:
		print("Picked ", node, " at ", node.get_path())
		_focus_in_tree(node)
	else:
		_highlight_node(null)


func is_inspection_enabled() -> bool:
	return _inspection_checkbox.button_pressed


func _pick(root: Node, mpos: Vector2, level := 0) -> Node:
#	var s := ""
#	for i in level:
#		s = str(s, "  ")
#
#	print(s, "Looking at ", root, ": ", root.name)
	
	var node: Node = null
	
	for i in root.get_child_count(true):
		var child := root.get_child(i, true)
		
		if (child is CanvasItem and not child.visible):
			#print(s, child, " is invisible or viewport")
			continue
		if child is Viewport:
			continue
		if child == _control_highlighter:
			continue
		
		if child is Control and child.get_global_rect().has_point(mpos):
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


func _on_ShowInInspectorCheckbox_toggled(_button_pressed: bool) -> void:
	pass


func _on_popup_menu_id_pressed(id: int) -> void:
	_popup_menu.hide()
	match id:
		POPUP_ACTIONS.SAVE_BRANCH_AS_SCENE:
			_save_branch_file_dialog.popup_centered_ratio()
		
		POPUP_ACTIONS.COPY_PATH_TO_CLIPBOARD:
			var node_view := _tree_view.get_selected()
			var node := _get_node_from_view(node_view)
			DisplayServer.clipboard_set(node.get_path())
			print("Copied to clipboard: %s"%[node.get_path()])
		
		POPUP_ACTIONS.COPY_NODE_TYPES_TO_CLIPBOARD:
			var node_view := _tree_view.get_selected()
			var node := _get_node_from_view(node_view)
			var node_types := []
			while node.get_parent():
				var tuple := PackedStringArray([node.get_class(), node.name])
				node_types.append(tuple)
				node = node.get_parent()
			node_types.reverse()
			var node_types_str := "%s"%[node_types]
			DisplayServer.clipboard_set(node_types_str)
			print("Copied to clipboard: %s"%[node_types_str])


func _on_SaveBranchFileDialog_file_selected(path: String) -> void:
	var node_view := _tree_view.get_selected()
	var node := _get_node_from_view(node_view)
	# Make the selected node own all it's children.
	var owners := {}
	override_ownership(node, owners, true)
	# Pack the selected node and it's children into a scene then save it.
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	ResourceSaver.save(packed_scene, path)
	# Revert ownership of all children.
	restore_ownership(node, owners, true)


