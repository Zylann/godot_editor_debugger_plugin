Changelog
============

This is a high-level changelog for each released versions of the plugin.
For a more detailed list of past and incoming changes, see the commit history.


0.4 (dev)
------------

This version requires Godot 4.2 or later.

- Added a menu to copy node access codes using `get_child(index)` instead of names (thanks to ryevdokimov)
- Fixed optional GDScript warnings that could show up when addon warnings are enabled (thanks to pineapplemachine); breaks compatibility with versions of Godot older than 4.2


0.3
----

This version requires Godot 4.0 or later.

- Added icons to nodes in the tree view (thanks to Xananax)
- Replaced "Save Branch As Scene" button with a contextual menu (thanks to Xananax)
- Added a menu to copy node paths, optionally including node types (thanks to Xananax)


0.2 (godot3 branch)
----------------------

- Selecting nodes also opens them in the regular inspector (errors expected, this is a hack)
- Pressing F12 attempts to select the control node below the mouse


0.1
----

- Plugin available on the assetlib
- Browse editor scene tree
- Highlight control nodes when selected in the tree

