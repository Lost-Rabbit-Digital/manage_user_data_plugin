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
	button.text = "User Data"
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
	confirmation_dialog.size = Vector2i(700, 550)
	confirmation_dialog.min_size = Vector2i(500, 400)
	confirmation_dialog.wrap_controls = true
	confirmation_dialog.get_ok_button().text = "Delete Selected"
	confirmation_dialog.get_ok_button().icon = base.get_theme_icon("Remove", "EditorIcons")

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Search and filter row
	var search_hbox := HBoxContainer.new()
	search_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var search_label := Label.new()
	search_label.text = "Search:"
	search_hbox.add_child(search_label)

	search_text = LineEdit.new()
	search_text.placeholder_text = "Filter by name..."
	search_text.custom_minimum_size = Vector2(200, 0)
	search_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_text.clear_button_enabled = true
	search_text.text_changed.connect(_on_search_changed)
	search_hbox.add_child(search_text)

	var filter_label := Label.new()
	filter_label.text = "Type:"
	search_hbox.add_child(filter_label)

	filter_menu_button = MenuButton.new()
	filter_menu_button.text = "All"
	filter_menu_button.flat = false
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
	popup.id_pressed.connect(_on_filter_type_toggled)
	search_hbox.add_child(filter_menu_button)

	clear_filter_btn = Button.new()
	clear_filter_btn.text = "Clear"
	clear_filter_btn.icon = base.get_theme_icon("Clear", "EditorIcons")
	clear_filter_btn.pressed.connect(_on_clear_filters)
	clear_filter_btn.visible = false
	search_hbox.add_child(clear_filter_btn)

	vbox.add_child(search_hbox)

	# Action buttons row
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	select_all_checkbox = CheckBox.new()
	select_all_checkbox.text = "Select All"
	select_all_checkbox.button_pressed = true
	select_all_checkbox.toggled.connect(_on_select_all_checkbox_toggled)
	hbox.add_child(select_all_checkbox)

	var open_dir_btn := Button.new()
	open_dir_btn.text = "Open User Dir"
	open_dir_btn.icon = base.get_theme_icon("Folder", "EditorIcons")
	open_dir_btn.tooltip_text = "Open user:// directory in file explorer"
	open_dir_btn.pressed.connect(func() -> void:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path("user://"))
	)
	hbox.add_child(open_dir_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var refresh_btn := Button.new()
	refresh_btn.icon = base.get_theme_icon("Reload", "EditorIcons")
	refresh_btn.tooltip_text = "Refresh"
	refresh_btn.flat = false
	refresh_btn.pressed.connect(_on_refresh_tree)
	hbox.add_child(refresh_btn)

	var help_btn := Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "Help"
	help_btn.flat = false
	help_btn.pressed.connect(_on_help_pressed)
	hbox.add_child(help_btn)

	vbox.add_child(hbox)

	# Directory tree
	tree = Tree.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0, 300)
	tree.hide_root = false
	tree.set_columns(3)
	tree.set_column_title(0, "")
	tree.set_column_title(1, "Name")
	tree.set_column_title(2, "Type / Size")
	tree.set_column_titles_visible(true)
	tree.set_column_expand(0, false)
	tree.set_column_expand(1, true)
	tree.set_column_expand(2, true)
	tree.set_column_custom_minimum_width(0, 24)
	tree.set_column_custom_minimum_width(1, 200)
	tree.set_column_custom_minimum_width(2, 100)
	tree.set_column_expand_ratio(0, 0)
	tree.set_column_expand_ratio(1, 4)
	tree.set_column_expand_ratio(2, 1)

	var root := tree.create_item()
	root.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	root.set_checked(0, true)
	root.set_editable(0, true)
	root.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
	root.set_text(1, "user://")
	root.set_icon(1, base.get_theme_icon("Folder", "EditorIcons"))
	root.set_icon_modulate(1, Color.hex(0xE0A55CFF))
	root.set_text(2, "Directory")
	var root_tooltip := "user://\nType: Directory\nPath: %s" % ProjectSettings.globalize_path("user://")
	root.set_tooltip_text(1, root_tooltip)
	root.set_tooltip_text(2, root_tooltip)

	populate_tree(root, "user://")

	tree.item_edited.connect(_on_tree_item_edited)
	vbox.add_child(tree)

	# Warning / status label
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(warning_label)

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

		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, true)
		item.set_editable(0, true)
		item.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text(1, file_name)

		if dir.current_is_dir():
			item.set_text(2, "Folder")
			item.set_icon(1, base.get_theme_icon("Folder", "EditorIcons"))
			item.set_icon_modulate(1, Color.hex(0xE0A55CFF))
			item.set_collapsed(false)
			var folder_tooltip := "%s\nType: Folder\nPath: %s" % [file_name, full_path]
			item.set_tooltip_text(1, folder_tooltip)
			item.set_tooltip_text(2, folder_tooltip)
			populate_tree(item, full_path)
		else:
			item.set_icon(1, get_file_icon(file_name))
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var file_size := file.get_length()
				file.close()
				item.set_text(2, "File (%s)" % format_file_size(file_size))
				var file_tooltip := "%s\nType: %s\nSize: %s\nPath: %s" % [file_name, get_file_type_label(file_name), format_file_size(file_size), full_path]
				item.set_tooltip_text(1, file_tooltip)
				item.set_tooltip_text(2, file_tooltip)
			else:
				item.set_text(2, "File")
				var file_tooltip := "%s\nType: %s\nPath: %s" % [file_name, get_file_type_label(file_name), full_path]
				item.set_tooltip_text(1, file_tooltip)
				item.set_tooltip_text(2, file_tooltip)

		file_name = dir.get_next()

	dir.list_dir_end()


## Handles checkbox edits and propagates the new state to all child items.
func _on_tree_item_edited() -> void:
	var edited_item := tree.get_edited()
	if edited_item == null:
		return
	propagate_check_state(edited_item, edited_item.is_checked(0))
	update_warning_label()


## Recursively applies [param checked] to all children of [param item].
func propagate_check_state(item: TreeItem, checked: bool) -> void:
	var child := item.get_first_child()
	while child != null:
		child.set_checked(0, checked)
		propagate_check_state(child, checked)
		child = child.get_next()


func _on_select_all_checkbox_toggled(checked: bool) -> void:
	var root := tree.get_root()
	if root:
		root.set_checked(0, checked)
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
	if item.is_checked(0):
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
	root.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	root.set_checked(0, true)
	root.set_editable(0, true)
	root.set_text_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
	root.set_text(1, "user://")
	root.set_icon(1, base.get_theme_icon("Folder", "EditorIcons"))
	root.set_icon_modulate(1, Color.hex(0xE0A55CFF))
	root.set_text(2, "Directory")
	var root_tooltip := "user://\nType: Directory\nPath: %s" % ProjectSettings.globalize_path("user://")
	root.set_tooltip_text(1, root_tooltip)
	root.set_tooltip_text(2, root_tooltip)

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
		warning_label.text = "No items selected for deletion."
		warning_label.add_theme_color_override(
			"font_color", base.get_theme_color("font_disabled_color", "Editor")
		)
	else:
		var items_text: String
		if file_count_ref[0] > 0 and folder_count_ref[0] > 0:
			items_text = "%d files and %d folders" % [file_count_ref[0], folder_count_ref[0]]
		elif file_count_ref[0] > 0:
			items_text = "%d file(s)" % file_count_ref[0]
		else:
			items_text = "%d folder(s)" % folder_count_ref[0]

		warning_label.text = (
			"About to delete %s (%s total). This cannot be undone!"
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

	if item.is_checked(0):
		var path = item.get_metadata(1)
		if path:
			result.append(path)
			var is_folder: bool = item.get_text(2).begins_with("Folder")
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
		filter_menu_button.text = "All"
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

	var item_name := item.get_text(1).to_lower()
	var item_type_text := item.get_text(2)
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

	var item_type_text := item.get_text(2)
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
		"wav", "ogg", "mp3":
			return base.get_theme_icon("AudioStreamWAV", "EditorIcons")
		"tscn":
			return base.get_theme_icon("PackedScene", "EditorIcons")
		"tres":
			return base.get_theme_icon("Resource", "EditorIcons")
		"gd":
			return base.get_theme_icon("Script", "EditorIcons")
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
	help_dialog = AcceptDialog.new()
	help_dialog.title = "About Manage User Data"
	help_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	help_dialog.min_size = Vector2i(640, 480)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = "Manage User Data  v2.4.0"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font_size := title_label.get_theme_font_size("font_size")
	title_label.add_theme_font_size_override("font_size", title_font_size + 4)
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var desc_label := Label.new()
	desc_label.text = (
		"A Godot editor plugin for browsing and selectively deleting the\n"
		+ "contents of your project's user:// directory.\n\n"
		+ "Features:\n"
		+ "  \u2022 Visual file/folder tree with per-item checkboxes\n"
		+ "  \u2022 Search and type filters (.json, .cache, files, folders)\n"
		+ "  \u2022 Displays file sizes and deletion summary before confirming\n"
		+ "  \u2022 Quick access to open the user:// folder in your OS file manager"
	)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var base := EditorInterface.get_base_control()

	var credit_btn := Button.new()
	credit_btn.text = "Created by Lost Rabbit Digital"
	credit_btn.icon = base.get_theme_icon("ExternalLink", "EditorIcons")
	credit_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	credit_btn.tooltip_text = "https://lostrabbit.digital/"
	credit_btn.pressed.connect(func() -> void:
		OS.shell_open("https://lostrabbit.digital/")
	)
	vbox.add_child(credit_btn)

	var discord_btn := Button.new()
	discord_btn.text = "Join us on Discord"
	discord_btn.icon = base.get_theme_icon("ExternalLink", "EditorIcons")
	discord_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	discord_btn.tooltip_text = "https://discord.gg/Y7caBf7gBj"
	discord_btn.pressed.connect(func() -> void:
		OS.shell_open("https://discord.gg/Y7caBf7gBj")
	)
	vbox.add_child(discord_btn)

	help_dialog.add_child(vbox)
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
	_on_dialog_closed()


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

	if item.is_checked(0):
		var path = item.get_metadata(1)
		if path:
			result.append(path)

	var child := item.get_first_child()
	while child != null:
		collect_checked_items(child, result)
		child = child.get_next()


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
