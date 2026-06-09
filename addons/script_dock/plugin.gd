@tool
extends EditorPlugin

enum DockSide {
	LEFT,
	RIGHT,
}

var script_editor: Control
var original_script_parent: Node

var dock_v_split_center: Control
var original_center_parent: Node
var main_screen: Control
var bottom_dock: Control

var outer_split: HSplitContainer
var right_split: VSplitContainer

var dock_side := DockSide.RIGHT
var follow_selected_node_script := false
var last_scene_screen := "3D"
var returning_to_scene_screen := false

var saved_outer_offset := 650
var saved_right_offset := 500

var switch_side_button: Button
var follow_button: Button
var button_parent: Control

var editor_selection: EditorSelection
var pending_script: Script


func _enter_tree() -> void:
	script_editor = EditorInterface.get_script_editor()

	if script_editor == null:
		return

	original_script_parent = script_editor.get_parent()
	editor_selection = EditorInterface.get_selection()

	if not main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.connect(_on_main_screen_changed)

	if editor_selection and not editor_selection.selection_changed.is_connected(_on_selection_changed):
		editor_selection.selection_changed.connect(_on_selection_changed)

	call_deferred("_add_script_toolbar_buttons")
	call_deferred("_apply_custom_layout")


func _exit_tree() -> void:
	if main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.disconnect(_on_main_screen_changed)

	if editor_selection and editor_selection.selection_changed.is_connected(_on_selection_changed):
		editor_selection.selection_changed.disconnect(_on_selection_changed)

	_remove_script_toolbar_buttons()
	_restore_everything()


func _on_main_screen_changed(screen_name: String) -> void:
	if screen_name == "2D" or screen_name == "3D":
		last_scene_screen = screen_name
		returning_to_scene_screen = false
		call_deferred("_apply_custom_layout")
		return

	if screen_name == "Script":
		if _script_tab_was_clicked():
			_restore_everything()
			return

		if returning_to_scene_screen:
			return

		returning_to_scene_screen = true
		call_deferred("_return_to_scene_screen")


func _script_tab_was_clicked() -> bool:
	var viewport := EditorInterface.get_base_control().get_viewport()

	var focused := viewport.gui_get_focus_owner()

	if _is_script_tab_or_child(focused):
		return true

	if viewport.has_method("gui_get_hovered_control"):
		var hovered = viewport.call("gui_get_hovered_control")

		if hovered is Control and _is_script_tab_or_child(hovered):
			return true

	return false


func _is_script_tab_or_child(node: Node) -> bool:
	var current := node

	while current:
		if current is Button:
			if (current as Button).text == "Script":
				return true

		if current is Control:
			var tooltip := (current as Control).tooltip_text.to_lower()

			if tooltip == "script" or tooltip.contains("script editor"):
				return true

		var name_text := str(current.name).to_lower()

		if name_text == "script" or name_text.contains("script"):
			if current is BaseButton or current is TabBar:
				return true

		current = current.get_parent()

	return false


func _return_to_scene_screen() -> void:
	EditorInterface.set_main_screen_editor(last_scene_screen)
	call_deferred("_apply_custom_layout")


func _on_selection_changed() -> void:
	if not follow_selected_node_script:
		return

	call_deferred("_open_selected_node_script")


func _open_selected_node_script() -> void:
	if editor_selection == null:
		return

	var selected_nodes := editor_selection.get_selected_nodes()

	if selected_nodes.is_empty():
		return

	_queue_node_script_open(selected_nodes[0])


func _queue_node_script_open(node: Node) -> void:
	if node == null:
		return

	var node_script := node.get_script()

	if node_script == null:
		return

	pending_script = node_script
	call_deferred("_open_pending_script")


func _open_pending_script() -> void:
	if pending_script == null:
		return

	EditorInterface.edit_script(pending_script)
	pending_script = null

	call_deferred("_return_to_scene_screen")


func _add_script_toolbar_buttons() -> void:
	if switch_side_button:
		return

	button_parent = _find_script_popout_button_parent(script_editor)

	switch_side_button = Button.new()
	switch_side_button.text = "⇄"
	switch_side_button.tooltip_text = "Switch script panel side"
	switch_side_button.focus_mode = Control.FOCUS_NONE
	switch_side_button.pressed.connect(_on_switch_side_pressed)

	follow_button = Button.new()
	follow_button.text = "Follow"
	follow_button.tooltip_text = "Auto-open selected node script"
	follow_button.toggle_mode = true
	follow_button.button_pressed = follow_selected_node_script
	follow_button.focus_mode = Control.FOCUS_NONE
	follow_button.toggled.connect(_on_follow_toggled)

	if button_parent:
		button_parent.add_child(switch_side_button)
		button_parent.add_child(follow_button)
	else:
		add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, switch_side_button)
		add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, follow_button)


func _remove_script_toolbar_buttons() -> void:
	for button in [switch_side_button, follow_button]:
		if button == null:
			continue

		if button.get_parent():
			button.get_parent().remove_child(button)

		button.queue_free()

	switch_side_button = null
	follow_button = null
	button_parent = null


func _on_switch_side_pressed() -> void:
	dock_side = DockSide.LEFT if dock_side == DockSide.RIGHT else DockSide.RIGHT

	_restore_everything()
	call_deferred("_apply_custom_layout")


func _on_follow_toggled(enabled: bool) -> void:
	follow_selected_node_script = enabled

	if follow_selected_node_script:
		call_deferred("_open_selected_node_script")


func _apply_custom_layout() -> void:
	if outer_split:
		return

	dock_v_split_center = _find_node_by_name(
		EditorInterface.get_base_control(),
		"DockVSplitCenter"
	) as Control

	if dock_v_split_center == null:
		push_warning("Could not find DockVSplitCenter.")
		return

	original_center_parent = dock_v_split_center.get_parent()

	var controls := _get_control_children(dock_v_split_center)

	if controls.size() < 2:
		push_warning("DockVSplitCenter did not have expected children.")
		return

	main_screen = controls[0]
	bottom_dock = controls[1]

	if script_editor.get_parent():
		script_editor.get_parent().remove_child(script_editor)

	dock_v_split_center.remove_child(main_screen)
	dock_v_split_center.remove_child(bottom_dock)

	original_center_parent.remove_child(dock_v_split_center)

	outer_split = HSplitContainer.new()
	outer_split.name = "ScriptDockOuterSplit"
	outer_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	right_split = VSplitContainer.new()
	right_split.name = "ScriptDockSideSplit"
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL

	original_center_parent.add_child(outer_split)

	if dock_side == DockSide.LEFT:
		outer_split.add_child(right_split)
		outer_split.add_child(main_screen)
	else:
		outer_split.add_child(main_screen)
		outer_split.add_child(right_split)

	right_split.add_child(script_editor)
	right_split.add_child(bottom_dock)

	script_editor.show()
	bottom_dock.show()
	main_screen.show()

	call_deferred("_apply_offsets")
	call_deferred("_collapse_bottom_dock")


func _restore_everything() -> void:
	if outer_split:
		saved_outer_offset = outer_split.split_offset

	if right_split:
		saved_right_offset = right_split.split_offset

	if script_editor and script_editor.get_parent():
		script_editor.get_parent().remove_child(script_editor)

	if bottom_dock and bottom_dock.get_parent():
		bottom_dock.get_parent().remove_child(bottom_dock)

	if main_screen and main_screen.get_parent():
		main_screen.get_parent().remove_child(main_screen)

	if outer_split and outer_split.get_parent():
		outer_split.get_parent().remove_child(outer_split)

	if dock_v_split_center and original_center_parent:
		if dock_v_split_center.get_parent() == null:
			original_center_parent.add_child(dock_v_split_center)

		if main_screen:
			dock_v_split_center.add_child(main_screen)

		if bottom_dock:
			dock_v_split_center.add_child(bottom_dock)

	if script_editor and original_script_parent:
		original_script_parent.add_child(script_editor)
		script_editor.show()

	if outer_split:
		outer_split.queue_free()

	if right_split:
		right_split.queue_free()

	outer_split = null
	right_split = null


func _apply_offsets() -> void:
	if outer_split:
		outer_split.split_offset = saved_outer_offset

	if right_split:
		right_split.split_offset = saved_right_offset


func _collapse_bottom_dock() -> void:
	if right_split:
		right_split.split_offset = right_split.size.y - 8


func _find_script_popout_button_parent(node: Node) -> Control:
	for child in node.get_children():
		if child is BaseButton:
			var tooltip := (child as Control).tooltip_text.to_lower()

			if tooltip.contains("window") or tooltip.contains("float") or tooltip.contains("separate"):
				return child.get_parent() as Control

		var found := _find_script_popout_button_parent(child)

		if found:
			return found

	return null


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node

	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)

		if found:
			return found

	return null


func _get_control_children(node: Node) -> Array[Control]:
	var results: Array[Control] = []

	for child in node.get_children():
		if child is Control:
			results.append(child)

	return results
