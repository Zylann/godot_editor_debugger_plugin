tool
extends Control

const Util = preload("util.gd")

onready var _label = get_node("VBoxContainer/Label")
onready var _tree_view = get_node("VBoxContainer/Tree")

var _update_interval = 1.0
var _time_before_next_update = 0.0
var _control_highlighter = null


func _enter_tree():
	if Util.is_in_edited_scene(self):
		return
	_control_highlighter = ColorRect.new()
	_control_highlighter.color = Color(1, 1, 0, 0.2)
	_control_highlighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_control_highlighter.hide()
	get_viewport().call_deferred("add_child", _control_highlighter)


func _exit_tree():
	if _control_highlighter != null:
		_control_highlighter.queue_free()


func _process(delta):
	if Util.is_in_edited_scene(self):
		set_process(false)
		return
		
	var viewport = get_viewport()
	_label.text = str(viewport.get_mouse_position())
	
	_time_before_next_update -= delta
	if _time_before_next_update <= 0:
		_time_before_next_update = _update_interval
		_update_tree()


func _update_tree():
	var root = get_tree().get_root()
	if root == null:
		_tree_view.clear()
		return

	#print("Updating tree")
	
	var root_view = _tree_view.get_root()
	if root_view == null:
		root_view = _create_node_view(root, null)
	
	_update_branch(root, root_view)


func _update_branch(root, root_view):
	if root_view.collapsed and root_view.get_children() != null:
		return
	
	var children_views = _get_tree_item_children(root_view)
	
	for i in root.get_child_count():
		var child = root.get_child(i)
		var child_view
		if i >= len(children_views):
			child_view = _create_node_view(child, root_view)
			children_views.append(child_view)
		else:
			child_view = children_views[i]
			var child_view_name = child_view.get_metadata(0)
			if child.name != child_view_name:
				_update_node_view(child, child_view)
		_update_branch(child, child_view)
	
	if root.get_child_count() < len(children_views):
		for i in range(root.get_child_count(), len(children_views)):
			children_views[i].free()


func _create_node_view(node, parent_view):
	#print("Create view for ", node)
	assert(node is Node)
	assert(parent_view == null or parent_view is TreeItem)
	var view = _tree_view.create_item(parent_view)
	view.collapsed = true
	_update_node_view(node, view)
	return view


func _update_node_view(node, view):
	assert(node is Node)
	assert(view is TreeItem)
	view.set_text(0, str(node.get_class(), ": ", node.name))
	view.set_metadata(0, node.name)

			
static func _get_tree_item_children(item):
	var children = []
	var child = item.get_children()
	if child == null:
		return children
	children.append(child)
	child = child.get_next()
	while child != null:
		children.append(child)
		child = child.get_next()
	return children


func _on_Tree_item_selected():
	var node_view = _tree_view.get_selected()
	var node = _get_node_from_view(node_view)
	
	print("Selected ", node)
	
	if node is Control:
		var r = node.get_global_rect()
		_control_highlighter.rect_position = r.position
		_control_highlighter.rect_size = r.size
		_control_highlighter.show()
	else:
		_control_highlighter.hide()


func _get_node_from_view(node_view):
	if node_view.get_parent() == null:
		return get_tree().get_root()
	
	# Reconstruct path
	var path = node_view.get_metadata(0)
	var parent_view = node_view
	while parent_view.get_parent() != null:
		parent_view = parent_view.get_parent()
		# Exclude root
		if parent_view.get_parent() == null:
			break
		path = str(parent_view.get_metadata(0), "/", path)
	
	var node = get_tree().get_root().get_node(path)
	return node


func _on_Tree_nothing_selected():
	_control_highlighter.hide()
