@tool
# Tree view showing scene tree nodes, dynamically updating
extends Control

const Util = preload("util.gd")

const METADATA_NODE_NAME = 0

signal item_selected
signal item_mouse_selected(pos: Vector2, mouse_button_index: int)
signal nothing_selected

const _update_interval = 1.0

var _tree_view: Tree

var _time_before_next_update := 0.0
var _deferred_update_pending := false

# The default "icon not found" texture. Captured so it can be compared against when trying to
# find a specific icon.
# @see _update_node_view
var _no_texture := get_theme_icon("", "EditorIcons")


func _init() -> void:
	_tree_view = Tree.new()
	_tree_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree_view.allow_reselect = true
	_tree_view.allow_rmb_select = true
	_tree_view.item_selected.connect(_on_tree_item_selected)
	_tree_view.item_mouse_selected.connect(_on_tree_item_mouse_selected)
	_tree_view.item_collapsed.connect(_on_tree_item_collapsed)
	_tree_view.nothing_selected.connect(_on_tree_nothing_selected)
	add_child(_tree_view)


func _on_tree_item_selected() -> void:
	item_selected.emit()


func _on_tree_item_mouse_selected(pos: Vector2, mouse_button_index: int) -> void:
	item_mouse_selected.emit(pos, mouse_button_index)


func _on_tree_item_collapsed(item: TreeItem) -> void:
	_deferred_update_pending = true


func _on_tree_nothing_selected() -> void:
	nothing_selected.emit()


func get_selected_node() -> Node:
	var nv := _tree_view.get_selected()
	return get_node_from_view(nv)


func _process(delta: float) -> void:
	if Util.is_in_edited_scene(self):
		set_process(false)
		return
		
	if _deferred_update_pending:
		_deferred_update_pending = false
		_update_tree()
	else:
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


func _update_branch(root: Node, root_view: TreeItem, force_one_level := false) -> void:
	var child_count := root.get_child_count(true)
	
	if root_view.collapsed and not force_one_level:
		# Don't care about collapsed nodes.
		# The editor is a big tree, don't waste cycles on things you can't see.
		# Only update whether to show a collapsing arrow or not.
		if child_count > 0 and root_view.get_first_child() == null:
			# Fake child to show the collapsing button.
			# If it ever gets shown, put some placeholder text.
			var view := _tree_view.create_item(root_view)
			view.set_metadata(METADATA_NODE_NAME, "")
			view.set_text(0, "Loading...")
			view.collapsed = true
		
		elif child_count == 0 and root_view.get_first_child() != null:
			# Clear child views
			var children_views := root_view.get_children()
			for child in children_views:
				child.free()
		
		# Note: we don't try to clear excess children recursively. It usually allows remembering
		# their collapsed state when the user toggles branches in and out, assuming they don't change.
		
	else:
		# Children are visible, or we want to create their TreeItem anyways
		
		var children_views := root_view.get_children()
	
		for i in root.get_child_count(true):
			var child := root.get_child(i, true)
			var child_view: TreeItem
			if i >= len(children_views):
				child_view = _create_node_view(child, root_view)
				children_views.append(child_view)
			else:
				child_view = children_views[i]
				var child_view_name : String = child_view.get_metadata(METADATA_NODE_NAME)
				if child.name != child_view_name:
					_update_node_view(child, child_view)
			_update_branch(child, child_view)
	
		# Remove excess tree items
		if child_count < len(children_views):
			for i in range(child_count, len(children_views)):
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


func get_node_from_view(node_view: TreeItem) -> Node:
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


func focus_in_tree(node: Node) -> void:
	_update_tree()
	
	var parent: Node = get_tree().root
	var path := node.get_path()
	var parent_view := _tree_view.get_root()
	
	var node_view: TreeItem = null
	
	for i in range(1, path.get_name_count()):
		var part := path.get_name(i)
		
		_update_branch(parent, parent_view, true)
		var child_view := parent_view.get_first_child()
		
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
