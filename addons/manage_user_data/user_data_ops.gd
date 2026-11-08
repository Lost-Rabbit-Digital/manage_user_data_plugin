@tool
extends RefCounted
## Selection-to-deletion planning and the actual file removal for the
## Manage User Data dialog. Kept free of editor APIs so it can be tested
## headless against real files (see tests/test_deletion_safety.gd).
##
## Safety rules:
## - Only items that are both checked AND visible (not hidden by a filter)
##   are ever deleted.
## - A folder is removed wholesale only when it and every descendant are
##   checked and visible. Otherwise only its selected children are removed and
##   the folder itself (with any unselected or filtered-out files) is kept.
## - Nothing outside user:// is touched, user:// itself is never removed, and
##   symbolic links are removed as links, never followed.

const COL_PATH := 1
const COL_CHECK := 2
const ROOT_PATH := "user://"


## Returns the minimal list of paths to delete for the current tree state.
## No returned path is inside another returned path.
static func plan_deletion(root: TreeItem) -> Array[String]:
	var out: Array[String] = []
	_plan(root, out)
	return out


static func _plan(item: TreeItem, out: Array[String]) -> void:
	if item == null:
		return
	var path := _path_of(item)
	if path != "" and path != ROOT_PATH and is_fully_selected(item):
		out.append(path)
		return
	var child := item.get_first_child()
	while child != null:
		_plan(child, out)
		child = child.get_next()


## True when [param item] and all of its descendants are checked and visible.
static func is_fully_selected(item: TreeItem) -> bool:
	if not item.visible or not item.is_checked(COL_CHECK):
		return false
	var child := item.get_first_child()
	while child != null:
		if not is_fully_selected(child):
			return false
		child = child.get_next()
	return true


static func _path_of(item: TreeItem) -> String:
	var meta: Variant = item.get_metadata(COL_PATH)
	return meta if meta is String else ""


## Rejects anything that is not strictly inside user://.
static func is_safe_target(path: String) -> bool:
	if not path.begins_with(ROOT_PATH) or path == ROOT_PATH or path.trim_suffix("/") == "user:":
		return false
	for part: String in path.trim_prefix(ROOT_PATH).split("/"):
		if part == "..":
			return false
	return true


## {files, folders, bytes} for a plan, counting the files inside whole folders.
static func describe(paths: Array[String]) -> Dictionary:
	var files := 0
	var folders := 0
	var bytes := 0
	for path: String in paths:
		if _is_link(path):
			files += 1
		elif DirAccess.dir_exists_absolute(path):
			folders += 1
			bytes += calculate_folder_size(path)
		elif FileAccess.file_exists(path):
			files += 1
			bytes += _file_size(path)
	return {"files": files, "folders": folders, "bytes": bytes}


## Deletes [param paths] (as produced by plan_deletion). Returns
## {"deleted": int, "failed": Array[String]}.
static func delete_paths(paths: Array[String]) -> Dictionary:
	var ordered: Array[String] = paths.duplicate()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a.count("/") > b.count("/"))

	var deleted := 0
	var failed: Array[String] = []
	for path: String in ordered:
		if not is_safe_target(path):
			push_error("Manage User Data: Refusing to delete '%s' (outside user://)" % path)
			failed.append(path)
			continue
		var is_link := _is_link(path)
		var is_dir := not is_link and DirAccess.dir_exists_absolute(path)
		if not is_link and not is_dir and not FileAccess.file_exists(path):
			push_warning("Manage User Data: Path no longer exists, skipping: %s" % path)
			continue
		if is_dir and delete_directory_contents(path) > 0:
			failed.append(path)
			continue
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_error("Manage User Data: Failed to delete '%s' (error %d)" % [path, err])
			failed.append(path)
		else:
			deleted += 1
	return {"deleted": deleted, "failed": failed}


## Recursively deletes everything inside [param path] (not the folder itself),
## removing symlinks without following them. Returns the number of failures.
static func delete_directory_contents(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Manage User Data: Cannot open directory for deletion: '%s'" % path)
		return 1
	var failures := 0
	dir.include_hidden = true
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)
			if dir.current_is_dir() and not dir.is_link(file_name):
				failures += delete_directory_contents(full_path)
			var err := DirAccess.remove_absolute(full_path)
			if err != OK:
				failures += 1
				push_warning("Manage User Data: Could not remove '%s' (error %d)" % [full_path, err])
		file_name = dir.get_next()
	dir.list_dir_end()
	return failures


## Total byte size of all files under [param path], not following symlinks.
static func calculate_folder_size(path: String) -> int:
	var total := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	dir.include_hidden = true
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.is_link(file_name):
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				total += calculate_folder_size(full_path)
			else:
				total += _file_size(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return total


static func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size := file.get_length()
	file.close()
	return size


static func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())
