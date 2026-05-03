@tool


static func get_node_in_parents(node: Node, klass: Variant) -> Node:
	while node != null:
		node = node.get_parent()
		if node != null and is_instance_of(node, klass):
			return node
	return null


static func is_in_edited_scene(node: Node) -> bool:
	#                               .___.
	#           /)               ,-^     ^-. 
	#          //               /           \
	# .-------| |--------------/  __     __  \-------------------.__
	# |WMWMWMW| |>>>>>>>>>>>>> | />>\   />>\ |>>>>>>>>>>>>>>>>>>>>>>:>
	# `-------| |--------------| \__/   \__/ |-------------------'^^
	#          \\               \    /|\    /
	#           \)               \   \_/   /
	#                             |       |
	#                             |+H+H+H+|
	#                             \       /
	#                              ^-----^
	# TODO https://github.com/godotengine/godot/issues/17592
	# This may break some day, don't fly planes with this bullshit.
	# Obviously it won't work for nested viewports since that's basically what this function checks.
	if not node.is_inside_tree():
		return false
	var vp := get_node_in_parents(node, Viewport)
	if vp == null:
		return false
	return vp.get_parent() != null


# Saves a node and its children to a scene file.
static func save_node_branch(node: Node, path: String) -> void:
	# Make the selected node own all it's children.
	var owners := {}
	_override_ownership(node, owners, true)
	# Pack the selected node and it's children into a scene then save it.
	var packed_scene := PackedScene.new()
	packed_scene.pack(node)
	ResourceSaver.save(packed_scene, path)
	# Revert ownership of all children.
	_restore_ownership(node, owners, true)


# @param root
# @param {Dictionary[Node, Node]} owners
static func _override_ownership(root: Node, owners: Dictionary, include_internal: bool) -> void:
	assert(root is Node)
	_override_ownership_recursive(root, root, owners, include_internal)


# @param root
# @param node
# @param {Dictionary[Node, Node]} owners
static func _override_ownership_recursive(
	root: Node, 
	node: Node, 
	owners: Dictionary, 
	include_internal: bool
) -> void:
	# Make root own all children of node.
	for child in node.get_children(include_internal):
		if child.owner != null:
			owners[child] = child.owner
		child.set_owner(root)
		_override_ownership_recursive(root, child, owners, include_internal)


# @param root
# @param {Dictionary[Node, Node]} owners
static func _restore_ownership(root: Node, owners: Dictionary, include_internal: bool) -> void:
	assert(root is Node)
	# Remove all of root's children's owners.
	# Also restore node ownership to nodes which had their owner overridden.
	for child in root.get_children(include_internal):
		if owners.has(child):
			child.owner = owners[child]
			owners.erase(child)
		else:
			child.set_owner(null)
		_restore_ownership(child, owners, include_internal)
