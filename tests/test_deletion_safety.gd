extends SceneTree
## Exercises the plugin's real deletion code (addons/manage_user_data/user_data_ops.gd)
## against real files under user://, with a Tree built the way the dialog builds it.
## Run via: godot --headless --path . --script tests/test_deletion_safety.gd

const Ops := preload("res://addons/manage_user_data/user_data_ops.gd")
const TEST_DIR := "user://test_deletion_safety"

var _pass_count := 0
var _fail_count := 0
var _tree: Tree


func _initialize() -> void:
	print("=== test_deletion_safety ===")
	test_unchecked_file_inside_checked_folder_survives()
	test_filter_hidden_items_are_never_deleted()
	test_fully_selected_folder_is_removed_whole()
	test_nothing_checked_deletes_nothing()
	test_root_and_outside_paths_are_refused()
	test_hidden_files_in_a_whole_folder_are_removed()
	test_describe_matches_the_plan()
	_rm(TEST_DIR)
	if _tree:
		_tree.free()
	print("\n%d passed, %d failed" % [_pass_count, _fail_count])
	quit(0 if _fail_count == 0 else 1)


# -- Fixtures ------------------------------------------------------------------

## Builds: TEST_DIR/{settings.cfg, saves/{slot1.json, slot2.json, cache/{a.cache}}}
func _make_files() -> void:
	_rm(TEST_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_DIR + "/saves/cache")
	for rel: String in ["settings.cfg", "saves/slot1.json", "saves/slot2.json", "saves/cache/a.cache"]:
		var f := FileAccess.open(TEST_DIR.path_join(rel), FileAccess.WRITE)
		f.store_string("data:" + rel)
		f.close()


## Mirrors populate_tree(): every item checked, path in column 1 metadata.
func _build_tree() -> TreeItem:
	if _tree:
		_tree.free()
	_tree = Tree.new()
	_tree.set_columns(3)
	var root := _tree.create_item()
	root.set_text(0, "user://")
	root.set_text(1, "Directory")
	root.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
	root.set_checked(2, true)
	_populate(root, TEST_DIR)
	return root


func _populate(parent: TreeItem, path: String) -> void:
	var dir := DirAccess.open(path)
	dir.include_hidden = true
	for name: String in dir.get_directories():
		var item := _item(parent, path.path_join(name), name, "Folder")
		_populate(item, path.path_join(name))
	for name: String in dir.get_files():
		_item(parent, path.path_join(name), name, "File")


func _item(parent: TreeItem, full: String, name: String, type: String) -> TreeItem:
	var item := _tree.create_item(parent)
	item.set_text(0, name)
	item.set_text(1, type)
	item.set_metadata(1, full)
	item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
	item.set_checked(2, true)
	return item


func _find(item: TreeItem, name: String) -> TreeItem:
	if item.get_text(0) == name:
		return item
	var child := item.get_first_child()
	while child != null:
		var hit := _find(child, name)
		if hit:
			return hit
		child = child.get_next()
	return null


func _set_checked_recursive(item: TreeItem, checked: bool) -> void:
	item.set_checked(2, checked)
	var child := item.get_first_child()
	while child != null:
		_set_checked_recursive(child, checked)
		child = child.get_next()


func _exists(rel: String) -> bool:
	var p := TEST_DIR.path_join(rel)
	return FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p)


# -- Tests ---------------------------------------------------------------------

func test_unchecked_file_inside_checked_folder_survives() -> void:
	# Regression: the folder stayed checked, so the old code wiped its whole
	# contents, including the file the user had just unchecked.
	_make_files()
	var root := _build_tree()
	_find(root, "slot1.json").set_checked(2, false)
	var result := Ops.delete_paths(Ops.plan_deletion(root))
	_check(_exists("saves/slot1.json"), "unchecked slot1.json survives")
	_check(not _exists("saves/slot2.json"), "checked sibling slot2.json deleted")
	_check(not _exists("saves/cache"), "fully selected subfolder deleted")
	_check(_exists("saves"), "partially selected folder itself is kept")
	_check(result.failed.is_empty(), "no failures reported")


func test_filter_hidden_items_are_never_deleted() -> void:
	# Regression: filtering to *.cache hid the saves but left them checked,
	# so "Delete Selected" removed them too.
	_make_files()
	var root := _build_tree()
	for name: String in ["settings.cfg", "slot1.json", "slot2.json"]:
		_find(root, name).visible = false
	Ops.delete_paths(Ops.plan_deletion(root))
	_check(not _exists("saves/cache/a.cache"), "visible a.cache deleted")
	_check(_exists("saves/slot1.json") and _exists("saves/slot2.json"), "filtered-out saves survive")
	_check(_exists("settings.cfg"), "filtered-out settings survive")


func test_fully_selected_folder_is_removed_whole() -> void:
	_make_files()
	var root := _build_tree()
	_find(root, "settings.cfg").set_checked(2, false)
	var plan := Ops.plan_deletion(root)
	_check(plan.size() == 1 and plan[0] == TEST_DIR + "/saves", "plan is just the folder: %s" % [plan])
	var result := Ops.delete_paths(plan)
	_check(not _exists("saves"), "saves/ removed with its contents")
	_check(_exists("settings.cfg"), "unchecked settings.cfg survives")
	_check(result.deleted == 1, "one deletion reported")


func test_nothing_checked_deletes_nothing() -> void:
	_make_files()
	var root := _build_tree()
	_set_checked_recursive(root, false)
	_check(Ops.plan_deletion(root).is_empty(), "empty plan")


func test_root_and_outside_paths_are_refused() -> void:
	_check(not Ops.is_safe_target("user://"), "user:// refused")
	_check(not Ops.is_safe_target("user://../escape"), ".. refused")
	_check(not Ops.is_safe_target("res://project.godot"), "res:// refused")
	_check(not Ops.is_safe_target("C:/Windows"), "absolute path refused")
	_check(Ops.is_safe_target(TEST_DIR + "/x.json"), "path inside user:// accepted")
	var result := Ops.delete_paths(["res://project.godot"] as Array[String])
	_check(FileAccess.file_exists("res://project.godot"), "res:// file untouched")
	_check(result.failed.size() == 1, "refusal reported as failure")


func test_hidden_files_in_a_whole_folder_are_removed() -> void:
	_make_files()
	var f := FileAccess.open(TEST_DIR + "/saves/.hidden", FileAccess.WRITE)
	f.store_string("12345")
	f.close()
	var root := _build_tree()
	var result := Ops.delete_paths(Ops.plan_deletion(root))
	_check(not _exists("saves"), "folder with a dotfile is fully removed")
	_check(result.failed.is_empty(), "no failures")


func test_describe_matches_the_plan() -> void:
	_make_files()
	var root := _build_tree()
	_find(root, "slot1.json").set_checked(2, false)
	var stats := Ops.describe(Ops.plan_deletion(root))
	# Plan: settings.cfg, saves/slot2.json, saves/cache (folder).
	_check(stats.files == 2, "2 files described (got %d)" % stats.files)
	_check(stats.folders == 1, "1 folder described (got %d)" % stats.folders)
	var expected := (
		"data:settings.cfg".length() + "data:saves/slot2.json".length()
		+ "data:saves/cache/a.cache".length()
	)
	_check(stats.bytes == expected, "bytes exclude the kept file (%d vs %d)" % [stats.bytes, expected])


# -- Helpers -------------------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: " + label)
	else:
		_fail_count += 1
		print("  FAIL: " + label)


func _rm(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	dir.include_hidden = true
	for name: String in dir.get_directories():
		_rm(path.path_join(name))
	for name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
