Editor debugger plugin for Godot Engine 3
=============================================

This plugin allows you to inspect the editor's scene tree itself, within the editor.
It's a bit the same concept as a web browser element inspector.

![screenshot1](https://user-images.githubusercontent.com/1311555/49691825-fb759300-fb42-11e8-8c50-c73d02fce6e4.png)

You can also select `Control` nodes visually by pressing `F12` with the mouse on top of them.

There is also a button called `Save selected branch as scene`, which will save the selected node in the tree and it's children as a scene called `saved_from_editor_scene.tscn`.


How to install
-----------------

This is a regular editor plugin.
Copy the contents of `addons/zylann.editor_debugger` into the same folder in your project, and activate it in your project settings.
