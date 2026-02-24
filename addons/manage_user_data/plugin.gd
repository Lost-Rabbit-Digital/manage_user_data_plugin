@tool
extends EditorPlugin

var button: Button
var confirmation_dialog: ConfirmationDialog
var help_dialog: AcceptDialog
var tree: Tree
var search_text: LineEdit
var filter_menu_button: MenuButton
var clear_filter_btn: Button
var warning_label: Label
var select_all_checkbox: CheckBox
var active_type_filters: Array[int] = []


func _enter_tree() -> void:
	button = Button.new()
	button.icon = EditorInterface.get_base_control().get_theme_icon("Filesystem", "EditorIcons")
	button.tooltip_text = "Selectively delete user:// directory contents"
	button.pressed.connect(_on_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)


func _exit_tree() -> void:
	if button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, button)
		button.queue_free()

	if help_dialog:
		help_dialog.queue_free()

	if confirmation_dialog:
		confirmation_dialog.queue_free()


func _on_button_pressed() -> void:
	show_confirmation_dialog()


## Opens the main user data management dialog.
func show_confirmation_dialog() -> void:
	active_type_filters.clear()
	var base := EditorInterface.get_base_control()

	var cfg := ConfigFile.new()
	var plugin_version := ""
	if cfg.load("res://addons/manage_user_data/plugin.cfg") == OK:
		plugin_version = cfg.get_value("plugin", "version", "")

	confirmation_dialog = ConfirmationDialog.new()
	confirmation_dialog.title = "Manage User Directory Contents" + (" v" + plugin_version if plugin_version else "")
	confirmation_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	confirmation_dialog.size = Vector2i(780, 580)
	confirmation_dialog.min_size = Vector2i(540, 420)
	confirmation_dialog.wrap_controls = true
	confirmation_dialog.get_cancel_button().text = "Close"
	confirmation_dialog.get_ok_button().text = "Delete Selected"
	confirmation_dialog.get_ok_button().icon = base.get_theme_icon("Remove", "EditorIcons")
	var _delete_icon_color := base.get_theme_color("error_color", "Editor")
	confirmation_dialog.get_ok_button().add_theme_color_override("icon_normal_color", _delete_icon_color)
	confirmation_dialog.get_ok_button().add_theme_color_override("icon_hover_color", _delete_icon_color)
	confirmation_dialog.get_ok_button().add_theme_color_override("icon_pressed_color", _delete_icon_color)
	confirmation_dialog.get_ok_button().add_theme_color_override("icon_focus_color", _delete_icon_color)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	# === SEARCH ROW ===
	var search_hbox := HBoxContainer.new()
	search_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_hbox.add_theme_constant_override("separation", 4)

	# Styled panel: dark background + accent-colored border, search icon on right
	var search_panel := PanelContainer.new()
	search_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search_panel_style := StyleBoxFlat.new()
	var accent_color := base.get_theme_color("accent_color", "Editor")
	search_panel_style.bg_color = Color(0.08, 0.08, 0.08, 1.0)
	search_panel_style.border_color = accent_color
	search_panel_style.set_border_width_all(2)
	search_panel_style.set_corner_radius_all(4)
	search_panel_style.content_margin_left = 8
	search_panel_style.content_margin_right = 6
	search_panel_style.content_margin_top = 2
	search_panel_style.content_margin_bottom = 2
	search_panel.add_theme_stylebox_override("panel", search_panel_style)

	var search_inner_hbox := HBoxContainer.new()
	search_inner_hbox.add_theme_constant_override("separation", 4)
	search_panel.add_child(search_inner_hbox)

	search_text = LineEdit.new()
	search_text.placeholder_text = "Filter Settings"
	search_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_text.clear_button_enabled = false
	search_text.text_changed.connect(_on_search_changed)
	var le_transparent_style := StyleBoxEmpty.new()
	search_text.add_theme_stylebox_override("normal", le_transparent_style)
	search_text.add_theme_stylebox_override("focus", le_transparent_style)
	search_text.add_theme_stylebox_override("read_only", le_transparent_style)
	search_inner_hbox.add_child(search_text)

	var search_icon := TextureRect.new()
	search_icon.texture = base.get_theme_icon("Search", "EditorIcons")
	search_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	search_icon.custom_minimum_size = Vector2(20, 20)
	search_icon.modulate = Color.WHITE
	search_inner_hbox.add_child(search_icon)

	search_hbox.add_child(search_panel)

	filter_menu_button = MenuButton.new()
	filter_menu_button.text = "All Types"
	filter_menu_button.flat = false
	filter_menu_button.tooltip_text = "Filter by file type"
	var popup := filter_menu_button.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.add_check_item("Files Only", 1)
	popup.add_check_item("Folders Only", 2)
	popup.add_check_item(".json", 3)
	popup.add_check_item(".cache", 4)
	popup.set_item_icon(0, base.get_theme_icon("File", "EditorIcons"))
	popup.set_item_icon(1, base.get_theme_icon("Folder", "EditorIcons"))
	popup.set_item_icon(2, base.get_theme_icon("File", "EditorIcons"))
	popup.set_item_icon(3, base.get_theme_icon("File", "EditorIcons"))
	popup.set_item_icon_modulate(1, Color(1, 0.71, 0.26, 1))
	popup.id_pressed.connect(_on_filter_type_toggled)
	search_hbox.add_child(filter_menu_button)
	_apply_outline_to_button(filter_menu_button, base)

	clear_filter_btn = Button.new()
	clear_filter_btn.icon = base.get_theme_icon("Close", "EditorIcons")
	clear_filter_btn.tooltip_text = "Clear filters"
	clear_filter_btn.pressed.connect(_on_clear_filters)
	clear_filter_btn.visible = false
	search_hbox.add_child(clear_filter_btn)
	_apply_outline_to_button(clear_filter_btn, base)

	var refresh_btn := Button.new()
	refresh_btn.icon = base.get_theme_icon("Reload", "EditorIcons")
	refresh_btn.tooltip_text = "Refresh"
	refresh_btn.flat = false
	refresh_btn.pressed.connect(_on_refresh_tree)
	search_hbox.add_child(refresh_btn)

	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "Help"
	help_btn.flat = false
	help_btn.pressed.connect(_on_help_pressed)
	search_hbox.add_child(help_btn)

	var search_margin := MarginContainer.new()
	search_margin.add_theme_constant_override("margin_left", 4)
	search_margin.add_theme_constant_override("margin_right", 4)
	search_margin.add_theme_constant_override("margin_top", 6)
	search_margin.add_theme_constant_override("margin_bottom", 6)
	search_margin.add_child(search_hbox)
	vbox.add_child(search_margin)

	vbox.add_child(HSeparator.new())

	# === TOOLBAR ROW (Gmail-style action bar: select-all + actions) ===
	var toolbar_hbox := HBoxContainer.new()
	toolbar_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_hbox.add_theme_constant_override("separation", 6)

	var open_dir_btn := Button.new()
	open_dir_btn.text = "Open Folder"
	open_dir_btn.icon = base.get_theme_icon("Folder", "EditorIcons")
	open_dir_btn.add_theme_color_override("icon_normal_color", Color.hex(0xE0A55CFF))
	open_dir_btn.add_theme_color_override("icon_hover_color", Color.hex(0xE0A55CFF))
	open_dir_btn.add_theme_color_override("icon_pressed_color", Color.hex(0xE0A55CFF))
	open_dir_btn.add_theme_color_override("icon_focus_color", Color.hex(0xE0A55CFF))
	open_dir_btn.tooltip_text = "Open user:// directory in file explorer"
	open_dir_btn.flat = false
	open_dir_btn.pressed.connect(func() -> void:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://"))
	)
	toolbar_hbox.add_child(open_dir_btn)

	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_hbox.add_child(toolbar_spacer)

	var toolbar_sep_v := VSeparator.new()
	toolbar_hbox.add_child(toolbar_sep_v)

	select_all_checkbox = CheckBox.new()
	select_all_checkbox.text = "Select All"
	select_all_checkbox.tooltip_text = "Select or deselect all visible items"
	select_all_checkbox.button_pressed = true
	select_all_checkbox.toggled.connect(_on_select_all_checkbox_toggled)
	toolbar_hbox.add_child(select_all_checkbox)
	_apply_outline_to_button(select_all_checkbox, base)

	var toolbar_margin := MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 4)
	toolbar_margin.add_theme_constant_override("margin_right", 4)
	toolbar_margin.add_theme_constant_override("margin_top", 4)
	toolbar_margin.add_theme_constant_override("margin_bottom", 4)
	toolbar_margin.add_child(toolbar_hbox)
	vbox.add_child(toolbar_margin)

	vbox.add_child(HSeparator.new())

	# === FILE TREE ===
	tree = Tree.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0, 280)
	tree.hide_root = false
	tree.hide_folding = false
	tree.set_columns(3)
	tree.set_column_title(0, "Name")
	tree.set_column_title(1, "Type / Size")
	tree.set_column_title(2, "Select")
	tree.set_column_titles_visible(true)
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, true)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(0, 200)
	tree.set_column_custom_minimum_width(1, 110)
	tree.set_column_custom_minimum_width(2, 60)
	tree.set_column_expand_ratio(0, 5)
	tree.set_column_expand_ratio(1, 1)

	var root := tree.create_item()
	root.set_text(0, "user://")
	root.set_icon(0, base.get_theme_icon("Folder", "EditorIcons"))
	root.set_icon_modulate(0, Color(1, 0.71, 0.26, 1))
	root.set_text(1, "Directory")
	root.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
	root.set_checked(2, true)
	root.set_editable(2, true)
	var root_tooltip := "user://\nType: Directory\nPath: %s" % ProjectSettings.globalize_path("user://")
	root.set_tooltip_text(0, root_tooltip)
	root.set_tooltip_text(1, root_tooltip)

	populate_tree(root, "user://")

	tree.item_edited.connect(_on_tree_item_edited)
	tree.item_mouse_selected.connect(_on_tree_item_mouse_selected)
	vbox.add_child(tree)

	vbox.add_child(HSeparator.new())

	# === STATUS / WARNING BAR ===
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	warning_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 6)
	status_margin.add_theme_constant_override("margin_right", 6)
	status_margin.add_theme_constant_override("margin_top", 4)
	status_margin.add_theme_constant_override("margin_bottom", 4)
	status_margin.add_child(warning_label)
	vbox.add_child(status_margin)

	update_warning_label()

	confirmation_dialog.add_child(vbox)
	confirmation_dialog.confirmed.connect(_on_confirmed_delete)
	confirmation_dialog.canceled.connect(_on_dialog_closed)
	confirmation_dialog.close_requested.connect(_on_dialog_closed)

	EditorInterface.get_base_control().add_child(confirmation_dialog)
	confirmation_dialog.popup_centered()


## Recursively populates the tree with the contents of [param path].
func populate_tree(parent_item: TreeItem, path: String) -> void:
	var base := EditorInterface.get_base_control()
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)
		var item := tree.create_item(parent_item)
		item.set_metadata(1, full_path)

		item.set_text(0, file_name)
		item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
		item.set_checked(2, true)
		item.set_editable(2, true)

		if dir.current_is_dir():
			item.set_text(1, "Folder")
			item.set_icon(0, base.get_theme_icon("Folder", "EditorIcons"))
			item.set_icon_modulate(0, Color(1, 0.71, 0.26, 1))
			item.set_collapsed(false)
			var folder_tooltip := "%s\nType: Folder\nPath: %s" % [file_name, full_path]
			item.set_tooltip_text(0, folder_tooltip)
			item.set_tooltip_text(1, folder_tooltip)
			populate_tree(item, full_path)
		else:
			item.set_icon(0, get_file_icon(file_name))
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var file_size := file.get_length()
				file.close()
				item.set_text(1, "File (%s)" % format_file_size(file_size))
				var file_tooltip := "%s\nType: %s\nSize: %s\nPath: %s" % [file_name, get_file_type_label(file_name), format_file_size(file_size), full_path]
				item.set_tooltip_text(0, file_tooltip)
				item.set_tooltip_text(1, file_tooltip)
			else:
				item.set_text(1, "File")
				var file_tooltip := "%s\nType: %s\nPath: %s" % [file_name, get_file_type_label(file_name), full_path]
				item.set_tooltip_text(0, file_tooltip)
				item.set_tooltip_text(1, file_tooltip)

		file_name = dir.get_next()

	dir.list_dir_end()


## Handles checkbox edits and propagates the new state to all child items.
func _on_tree_item_edited() -> void:
	var edited_item := tree.get_edited()
	if edited_item == null:
		return
	propagate_check_state(edited_item, edited_item.is_checked(2))
	update_warning_label()


## Toggles expand/collapse when a folder item is clicked in the name or type column.
func _on_tree_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var item := tree.get_item_at_position(mouse_position)
	if item == null:
		return
	var item_type_text := item.get_text(1)
	var is_folder: bool = item_type_text.begins_with("Folder") or item_type_text == "Directory"
	if not is_folder:
		return
	if item.get_first_child() == null:
		return
	var col := tree.get_column_at_position(mouse_position)
	if col == 2:
		return
	item.set_collapsed(not item.is_collapsed())


## Recursively applies [param checked] to all children of [param item].
func propagate_check_state(item: TreeItem, checked: bool) -> void:
	var child := item.get_first_child()
	while child != null:
		child.set_checked(2, checked)
		propagate_check_state(child, checked)
		child = child.get_next()


func _on_select_all_checkbox_toggled(checked: bool) -> void:
	var root := tree.get_root()
	if root:
		root.set_checked(2, checked)
		propagate_check_state(root, checked)
		update_warning_label()


## Syncs the select-all checkbox visual state to reflect current tree selection.
func _update_select_all_checkbox() -> void:
	if select_all_checkbox == null or tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var counts := [0, 0]  # [total, checked]
	_count_tree_items(root, counts)
	select_all_checkbox.set_block_signals(true)
	if counts[1] == 0:
		select_all_checkbox.button_pressed = false
		if "indeterminate" in select_all_checkbox:
			select_all_checkbox.set("indeterminate", false)
	elif counts[1] == counts[0]:
		select_all_checkbox.button_pressed = true
		if "indeterminate" in select_all_checkbox:
			select_all_checkbox.set("indeterminate", false)
	else:
		select_all_checkbox.button_pressed = false
		if "indeterminate" in select_all_checkbox:
			select_all_checkbox.set("indeterminate", true)
	select_all_checkbox.set_block_signals(false)


## Counts total and checked tree items recursively into [param counts] ([total, checked]).
func _count_tree_items(item: TreeItem, counts: Array) -> void:
	counts[0] += 1
	if item.is_checked(2):
		counts[1] += 1
	var child := item.get_first_child()
	while child != null:
		_count_tree_items(child, counts)
		child = child.get_next()


## Clears and repopulates the tree to reflect the current state of user://.
func _on_refresh_tree() -> void:
	if tree == null:
		return

	var tween_out := create_tween()
	tween_out.tween_property(tree, "modulate:a", 0.0, 0.15)
	await tween_out.finished

	tree.clear()

	var base := EditorInterface.get_base_control()
	var root := tree.create_item()
	root.set_text(0, "user://")
	root.set_icon(0, base.get_theme_icon("Folder", "EditorIcons"))
	root.set_icon_modulate(0, Color(1, 0.71, 0.26, 1))
	root.set_text(1, "Directory")
	root.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
	root.set_checked(2, true)
	root.set_editable(2, true)
	var root_tooltip := "user://\nType: Directory\nPath: %s" % ProjectSettings.globalize_path("user://")
	root.set_tooltip_text(0, root_tooltip)
	root.set_tooltip_text(1, root_tooltip)

	populate_tree(root, "user://")
	update_warning_label()

	var tween_in := create_tween()
	tween_in.tween_property(tree, "modulate:a", 1.0, 0.2)


## Updates the warning label to reflect the current selection.
func update_warning_label() -> void:
	if warning_label == null:
		return

	var items_to_delete: Array = []
	var total_size_ref := [0]
	var file_count_ref := [0]
	var folder_count_ref := [0]

	collect_checked_items_with_stats(
		tree.get_root(), items_to_delete, total_size_ref, file_count_ref, folder_count_ref
	)

	var base := EditorInterface.get_base_control()

	if items_to_delete.is_empty():
		warning_label.text = "No items selected."
		warning_label.add_theme_color_override(
			"font_color", base.get_theme_color("font_disabled_color", "Editor")
		)
	else:
		var items_text: String
		if file_count_ref[0] > 0 and folder_count_ref[0] > 0:
			items_text = "%d files, %d folders" % [file_count_ref[0], folder_count_ref[0]]
		elif file_count_ref[0] > 0:
			items_text = "%d file(s)" % file_count_ref[0]
		else:
			items_text = "%d folder(s)" % folder_count_ref[0]

		warning_label.text = (
			"%s selected (%s) \u2014 deletion cannot be undone"
			% [items_text, format_file_size(total_size_ref[0])]
		)
		warning_label.add_theme_color_override(
			"font_color", base.get_theme_color("error_color", "Editor")
		)

	_update_select_all_checkbox()


## Collects checked items and accumulates size/count statistics.
func collect_checked_items_with_stats(
	item: TreeItem,
	result: Array,
	total_size_ref: Array,
	file_count_ref: Array,
	folder_count_ref: Array
) -> void:
	if item == null:
		return

	if item.is_checked(2):
		var path = item.get_metadata(1)
		if path:
			result.append(path)
			var is_folder: bool = item.get_text(1).begins_with("Folder")
			if is_folder:
				folder_count_ref[0] += 1
				total_size_ref[0] += calculate_folder_size(path)
				return
			else:
				file_count_ref[0] += 1
				var file := FileAccess.open(path, FileAccess.READ)
				if file:
					total_size_ref[0] += file.get_length()
					file.close()

	var child := item.get_first_child()
	while child != null:
		collect_checked_items_with_stats(child, result, total_size_ref, file_count_ref, folder_count_ref)
		child = child.get_next()


## Returns the total byte size of all files under [param path], recursively.
func calculate_folder_size(path: String) -> int:
	var total_size := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				total_size += calculate_folder_size(full_path)
			else:
				var file := FileAccess.open(full_path, FileAccess.READ)
				if file:
					total_size += file.get_length()
					file.close()
		file_name = dir.get_next()
	dir.list_dir_end()
	return total_size


func _on_search_changed(_new_text: String) -> void:
	_update_clear_button_visibility()
	apply_filters()


func _on_filter_type_toggled(id: int) -> void:
	var popup := filter_menu_button.get_popup()
	var idx := popup.get_item_index(id)
	var currently_checked := popup.is_item_checked(idx)
	popup.set_item_checked(idx, not currently_checked)

	if not currently_checked:
		if not active_type_filters.has(id):
			active_type_filters.append(id)
	else:
		active_type_filters.erase(id)

	_update_filter_button_label()
	_update_clear_button_visibility()
	apply_filters()


func _update_filter_button_label() -> void:
	if filter_menu_button == null:
		return
	if active_type_filters.is_empty():
		filter_menu_button.text = "All Types"
	elif active_type_filters.size() == 1:
		var popup := filter_menu_button.get_popup()
		var idx := popup.get_item_index(active_type_filters[0])
		filter_menu_button.text = popup.get_item_text(idx)
	else:
		filter_menu_button.text = "%d Types" % active_type_filters.size()


## Shows the Clear button only when a type filter other than "All" is active
## (i.e. at least one specific type is selected), satisfying the requirement
## of "more than 1 filter or a filter beside All".
func _update_clear_button_visibility() -> void:
	if clear_filter_btn == null:
		return
	clear_filter_btn.visible = not active_type_filters.is_empty()


func _on_clear_filters() -> void:
	search_text.text = ""
	active_type_filters.clear()
	var popup := filter_menu_button.get_popup()
	for i in popup.item_count:
		popup.set_item_checked(i, false)
	_update_filter_button_label()
	_update_clear_button_visibility()
	apply_filters()


## Applies the active search text and type filters to the entire tree.
func apply_filters() -> void:
	var search_term := search_text.text.to_lower()
	filter_tree_item(tree.get_root(), search_term, active_type_filters)
	if not active_type_filters.is_empty() or not search_term.is_empty():
		expand_matching_parents(tree.get_root())


## Recursively filters tree items. Returns [code]true[/code] if the item or
## any descendant matches the active filters.
func filter_tree_item(item: TreeItem, search_term: String, filter_types: Array[int]) -> bool:
	if item == null:
		return false

	var item_name := item.get_text(0).to_lower()
	var item_type_text := item.get_text(1)
	var is_folder: bool = item_type_text.begins_with("Folder") or item_type_text == "Directory"

	var matches_search: bool = search_term.is_empty() or item_name.contains(search_term)

	var matches_type := false
	if filter_types.is_empty():
		matches_type = true
	else:
		for ft in filter_types:
			match ft:
				1: if not is_folder: matches_type = true
				2: if is_folder: matches_type = true
				3: if not is_folder and item_name.ends_with(".json"): matches_type = true
				4: if not is_folder and item_name.ends_with(".cache"): matches_type = true
			if matches_type:
				break

	var any_child_visible := false
	var child := item.get_first_child()
	while child != null:
		if filter_tree_item(child, search_term, filter_types):
			any_child_visible = true
		child = child.get_next()

	# If only non-folder filters are active and this is a folder, use folder as a container
	var has_folder_type_filter := filter_types.is_empty() or filter_types.has(2)
	var should_be_visible: bool
	if is_folder and not has_folder_type_filter:
		should_be_visible = any_child_visible
	else:
		should_be_visible = (matches_search and matches_type) or any_child_visible

	item.visible = should_be_visible
	return should_be_visible


## Expands folders that contain at least one visible child after filtering.
func expand_matching_parents(item: TreeItem) -> void:
	if item == null:
		return

	var item_type_text := item.get_text(1)
	var is_folder: bool = item_type_text.begins_with("Folder") or item_type_text == "Directory"

	if is_folder and item.visible:
		var child := item.get_first_child()
		while child != null:
			if child.visible:
				item.set_collapsed(false)
				break
			child = child.get_next()

	var child := item.get_first_child()
	while child != null:
		expand_matching_parents(child)
		child = child.get_next()


## Returns an editor icon for a file based on its extension.
func get_file_icon(file_name: String) -> Texture2D:
	var base := EditorInterface.get_base_control()
	var ext := file_name.get_extension().to_lower()
	match ext:
		"json":
			return base.get_theme_icon("File", "EditorIcons")
		"cfg", "ini", "toml":
			return base.get_theme_icon("FileTree", "EditorIcons")
		"png", "jpg", "jpeg", "webp", "bmp", "svg":
			return base.get_theme_icon("ImageTexture", "EditorIcons")
		"wav":
			return base.get_theme_icon("AudioStreamWAV", "EditorIcons")
		"ogg":
			return base.get_theme_icon("AudioStreamOggVorbis", "EditorIcons")
		"mp3":
			return base.get_theme_icon("AudioStreamMP3", "EditorIcons")
		"tscn":
			return base.get_theme_icon("PackedScene", "EditorIcons")
		"tres":
			return base.get_theme_icon("Resource", "EditorIcons")
		"gd":
			return base.get_theme_icon("GDScript", "EditorIcons")
		"cache":
			return base.get_theme_icon("File", "EditorIcons")
		"save", "dat":
			return base.get_theme_icon("Save", "EditorIcons")
		_:
			return base.get_theme_icon("File", "EditorIcons")


## Returns a human-readable type label for a file based on its extension.
func get_file_type_label(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	match ext:
		"json":
			return "JSON Data"
		"cfg":
			return "Config File"
		"ini":
			return "INI Config"
		"toml":
			return "TOML Config"
		"png":
			return "PNG Image"
		"jpg", "jpeg":
			return "JPEG Image"
		"webp":
			return "WebP Image"
		"bmp":
			return "BMP Image"
		"svg":
			return "SVG Image"
		"wav":
			return "WAV Audio"
		"ogg":
			return "OGG Audio"
		"mp3":
			return "MP3 Audio"
		"tscn":
			return "Packed Scene"
		"tres":
			return "Resource"
		"gd":
			return "GDScript"
		"cache":
			return "Cache File"
		"save":
			return "Save File"
		"dat":
			return "Data File"
		_:
			return ext.to_upper() + " File" if not ext.is_empty() else "File"


## Returns a human-readable string for the given byte count.
func format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.2f KB" % (bytes / 1024.0)
	else:
		return "%.2f MB" % (bytes / (1024.0 * 1024.0))


## Shows the help dialog with plugin info and credits.
func _on_help_pressed() -> void:
	if help_dialog:
		help_dialog.grab_focus()
		return

	var base := EditorInterface.get_base_control()

	var cfg := ConfigFile.new()
	var plugin_version := "2.4.6"
	if cfg.load("res://addons/manage_user_data/plugin.cfg") == OK:
		plugin_version = cfg.get_value("plugin", "version", plugin_version)

	help_dialog = AcceptDialog.new()
	help_dialog.ok_button_text = "Close"
	help_dialog.title = "Help — Manage User Data"
	help_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	help_dialog.size = Vector2i(780, 580)
	help_dialog.min_size = Vector2i(540, 420)
	help_dialog.wrap_controls = true
	help_dialog.exclusive = false

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 0)

	# === HEADER ===
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 10)

	var plugin_icon := TextureRect.new()
	plugin_icon.texture = base.get_theme_icon("Filesystem", "EditorIcons")
	plugin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plugin_icon.custom_minimum_size = Vector2(36, 36)
	header_hbox.add_child(plugin_icon)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_theme_constant_override("separation", 2)

	var title_label := Label.new()
	title_label.text = "Manage User Data"
	title_label.add_theme_font_size_override("font_size", title_label.get_theme_font_size("font_size") + 6)
	header_vbox.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "v%s  ·  by Lost Rabbit Digital" % plugin_version
	subtitle_label.add_theme_color_override("font_color", base.get_theme_color("font_disabled_color", "Editor"))
	header_vbox.add_child(subtitle_label)

	header_hbox.add_child(header_vbox)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 10)
	header_margin.add_theme_constant_override("margin_right", 10)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	header_margin.add_child(header_hbox)
	outer_vbox.add_child(header_margin)
	outer_vbox.add_child(HSeparator.new())

	# === SCROLLABLE CONTENT ===
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	content_margin.add_child(content_vbox)
	scroll.add_child(content_margin)

	# --- Shared helpers ---
	var _add_heading := func(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", lbl.get_theme_font_size("font_size") + 1)
		lbl.add_theme_color_override("font_color", base.get_theme_color("accent_color", "Editor"))
		content_vbox.add_child(lbl)
		content_vbox.add_child(HSeparator.new())

	var _add_body := func(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(lbl)

	# --- Overview ---
	_add_heading.call("Overview")
	_add_body.call(
		"Manage User Data lets you browse and selectively delete files from your project's " +
		"user:// directory — without leaving the editor."
	)

	# --- How to Use ---
	_add_heading.call("How to Use")

	var steps: Array = [
		["1.  Open the plugin", "Click \"User Data\" in the editor toolbar to open the main window."],
		["2.  Browse files", "The tree lists every file and folder inside user://. Folders are shown expanded by default."],
		["3.  Select items", "To delete everything: leave all items checked. To delete specific files: uncheck \"Select All\", then tick only what you want."],
		["4.  Search & filter", "Type in the search bar to find items by name. Use the \"All Types\" dropdown to show only files, folders, .json, or .cache entries."],
		["5.  Review", "The status bar shows a live count and total size of your selection before you commit."],
		["6.  Delete", "Click \"Delete Selected\" and confirm. Deletion is permanent and cannot be undone."],
	]

	var steps_grid := VBoxContainer.new()
	steps_grid.add_theme_constant_override("separation", 6)
	for step: Array in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var step_name := Label.new()
		step_name.text = step[0]
		step_name.custom_minimum_size = Vector2(150, 0)
		step_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(step_name)

		var step_desc := Label.new()
		step_desc.text = step[1]
		step_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(step_desc)

		steps_grid.add_child(row)
	content_vbox.add_child(steps_grid)

	# --- Features ---
	_add_heading.call("Features")

	var features: Array = [
		["File Tree", "Full visual tree of user:// with per-item checkboxes for fine-grained selection."],
		["Real-time Search", "Instantly filters the tree as you type — matching parent folders expand automatically."],
		["Type Filters", "Narrow the view to Files Only, Folders Only, .json, or .cache entries via the dropdown."],
		["Bulk Selection", "\"Select All\" selects or deselects every visible item in one click."],
		["File Sizes", "Inline file sizes on every entry; the status bar totals the size of your current selection."],
		["Open in OS", "\"Open Folder\" launches user:// in your operating system's native file manager."],
		["Refresh", "Rescans user:// at any time without reopening the plugin window."],
	]

	var features_grid := VBoxContainer.new()
	features_grid.add_theme_constant_override("separation", 6)
	for feat: Array in features:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var bullet := TextureRect.new()
		bullet.texture = base.get_theme_icon("ArrowRight", "EditorIcons")
		bullet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bullet.custom_minimum_size = Vector2(16, 16)
		row.add_child(bullet)

		var feat_name := Label.new()
		feat_name.text = feat[0]
		feat_name.custom_minimum_size = Vector2(130, 0)
		feat_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(feat_name)

		var feat_desc := Label.new()
		feat_desc.text = feat[1]
		feat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feat_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(feat_desc)

		features_grid.add_child(row)
	content_vbox.add_child(features_grid)

	# --- What's in user:// ---
	_add_heading.call("What's in user://")
	_add_body.call(
		"Godot writes to user:// when your game uses paths like \"user://save.json\". " +
		"Common files to clean during development:"
	)

	var user_types: Array = [
		[".cfg / .json", "Save data"],
		[".log", "Log files"],
		[".cache", "Engine/game caches"],
	]

	var user_types_grid := VBoxContainer.new()
	user_types_grid.add_theme_constant_override("separation", 6)
	for entry: Array in user_types:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var ext_lbl := Label.new()
		ext_lbl.text = entry[0]
		ext_lbl.custom_minimum_size = Vector2(130, 0)
		ext_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(ext_lbl)

		var src_lbl := Label.new()
		src_lbl.text = entry[1]
		src_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(src_lbl)

		user_types_grid.add_child(row)
	content_vbox.add_child(user_types_grid)

	# --- Tips ---
	_add_heading.call("Tips & Notes")
	_add_body.call(
		"\u2022  Deletion is permanent — double-check your selection before confirming.\n" +
		"\u2022  Checking a folder selects all of its contents recursively.\n" +
		"\u2022  The user:// path on disk:\n" +
		"       Windows:  %%APPDATA%%\\Godot\\app_userdata\\<project>\n" +
		"       macOS:    ~/Library/Application Support/Godot/app_userdata/<project>\n" +
		"       Linux:    ~/.local/share/godot/app_userdata/<project>"
	)

	outer_vbox.add_child(scroll)
	outer_vbox.add_child(HSeparator.new())

	# === LINKS FOOTER ===
	var links_hbox := HBoxContainer.new()
	links_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	links_hbox.add_theme_constant_override("separation", 8)

	var _make_outline_style := func(bg_alpha: float) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		var accent := base.get_theme_color("accent_color", "Editor")
		s.bg_color = Color(accent.r, accent.g, accent.b, bg_alpha)
		s.border_color = accent
		s.set_border_width_all(1)
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		return s

	var credit_btn := Button.new()
	credit_btn.text = "Lost Rabbit Digital"
	credit_btn.icon = base.get_theme_icon("ExternalLink", "EditorIcons")
	credit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credit_btn.tooltip_text = "https://lostrabbit.digital/"
	credit_btn.add_theme_stylebox_override("normal", _make_outline_style.call(0.0))
	credit_btn.add_theme_stylebox_override("hover", _make_outline_style.call(0.12))
	credit_btn.add_theme_stylebox_override("pressed", _make_outline_style.call(0.22))
	credit_btn.add_theme_stylebox_override("focus", _make_outline_style.call(0.0))
	credit_btn.pressed.connect(func() -> void:
		OS.shell_open("https://lostrabbit.digital/")
	)
	links_hbox.add_child(credit_btn)

	links_hbox.add_child(VSeparator.new())

	var discord_btn := Button.new()
	discord_btn.text = "Discord Community"
	discord_btn.icon = base.get_theme_icon("ExternalLink", "EditorIcons")
	discord_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	discord_btn.tooltip_text = "https://discord.gg/Y7caBf7gBj"
	discord_btn.add_theme_stylebox_override("normal", _make_outline_style.call(0.0))
	discord_btn.add_theme_stylebox_override("hover", _make_outline_style.call(0.12))
	discord_btn.add_theme_stylebox_override("pressed", _make_outline_style.call(0.22))
	discord_btn.add_theme_stylebox_override("focus", _make_outline_style.call(0.0))
	discord_btn.pressed.connect(func() -> void:
		OS.shell_open("https://discord.gg/Y7caBf7gBj")
	)
	links_hbox.add_child(discord_btn)

	links_hbox.add_child(VSeparator.new())

	var github_btn := Button.new()
	github_btn.text = "GitHub Repo"
	github_btn.icon = base.get_theme_icon("ExternalLink", "EditorIcons")
	github_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	github_btn.tooltip_text = "https://github.com/Lost-Rabbit-Digital/manage_user_data_plugin"
	github_btn.add_theme_stylebox_override("normal", _make_outline_style.call(0.0))
	github_btn.add_theme_stylebox_override("hover", _make_outline_style.call(0.12))
	github_btn.add_theme_stylebox_override("pressed", _make_outline_style.call(0.22))
	github_btn.add_theme_stylebox_override("focus", _make_outline_style.call(0.0))
	github_btn.pressed.connect(func() -> void:
		OS.shell_open("https://github.com/Lost-Rabbit-Digital/manage_user_data_plugin")
	)
	links_hbox.add_child(github_btn)

	var links_margin := MarginContainer.new()
	links_margin.add_theme_constant_override("margin_left", 8)
	links_margin.add_theme_constant_override("margin_right", 8)
	links_margin.add_theme_constant_override("margin_top", 4)
	links_margin.add_theme_constant_override("margin_bottom", 4)
	links_margin.add_child(links_hbox)
	outer_vbox.add_child(links_margin)

	help_dialog.add_child(outer_vbox)
	EditorInterface.get_base_control().add_child(help_dialog)
	help_dialog.popup_centered()

	var _close_help := func() -> void:
		if help_dialog:
			help_dialog.queue_free()
			help_dialog = null
	help_dialog.confirmed.connect(_close_help)
	help_dialog.canceled.connect(_close_help)
	help_dialog.close_requested.connect(_close_help)


func _on_confirmed_delete() -> void:
	delete_selected_items()
	_on_refresh_tree()
	confirmation_dialog.call_deferred("popup_centered")


func _on_dialog_closed() -> void:
	if help_dialog:
		help_dialog.queue_free()
		help_dialog = null
	if confirmation_dialog:
		confirmation_dialog.queue_free()
		confirmation_dialog = null
		select_all_checkbox = null
		filter_menu_button = null
		clear_filter_btn = null
		active_type_filters.clear()


## Deletes all checked items, deepest paths first to avoid parent-before-child issues.
func delete_selected_items() -> void:
	var items_to_delete: Array = []
	collect_checked_items(tree.get_root(), items_to_delete)

	items_to_delete.sort_custom(func(a: String, b: String) -> bool:
		return a.count("/") > b.count("/")
	)

	for path: String in items_to_delete:
		if path == "user://":
			continue

		var error: int
		if DirAccess.dir_exists_absolute(path):
			delete_directory_contents(path)
			error = DirAccess.remove_absolute(path)
		else:
			error = DirAccess.remove_absolute(path)

		if error != OK:
			push_error("Failed to delete: %s (Error Code: %d)" % [path, error])


## Recursively collects all checked items into [param result].
func collect_checked_items(item: TreeItem, result: Array) -> void:
	if item == null:
		return

	if item.is_checked(2):
		var path = item.get_metadata(1)
		if path:
			result.append(path)

	var child := item.get_first_child()
	while child != null:
		collect_checked_items(child, result)
		child = child.get_next()


## Applies a visible border/outline to [param btn] using the editor accent color.
## Duplicates the existing button StyleBoxFlat if available; otherwise creates one.
func _apply_outline_to_button(btn: Button, base: Control) -> void:
	var existing_style := base.get_theme_stylebox("normal", "Button")
	var style: StyleBoxFlat
	if existing_style is StyleBoxFlat:
		style = (existing_style as StyleBoxFlat).duplicate()
		style.set_border_width_all(1)
		style.border_color = base.get_theme_color("accent_color", "Editor")
	else:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.18, 1.0)
		style.set_border_width_all(1)
		style.border_color = base.get_theme_color("accent_color", "Editor")
		style.set_corner_radius_all(3)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)


## Recursively deletes all contents inside [param path] without removing the
## directory itself.
func delete_directory_contents(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				delete_directory_contents(full_path)
				DirAccess.remove_absolute(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
