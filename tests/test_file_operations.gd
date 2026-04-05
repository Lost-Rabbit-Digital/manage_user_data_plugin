extends Node
## Integration tests for file save/load/delete/migrate operations.
## Tests actual file I/O against a temporary directory under user://test_manage_user_data/.
## Run via: godot --headless --script tests/test_file_operations.gd

const TEST_DIR := "user://test_manage_user_data"

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	print("=== test_file_operations ===")
	_setup()

	# Save flow tests
	test_save_json_file()
	test_save_cfg_file()
	test_save_binary_dat_file()
	test_save_nested_directories()

	# Load flow tests
	test_load_json_file()
	test_load_cfg_file()
	test_load_binary_dat_file()

	# Edge cases: corrupted / malformed files
	test_load_corrupted_json()
	test_load_empty_file()
	test_load_nonexistent_file()
	test_load_binary_as_text()

	# Delete flow tests
	test_delete_single_file()
	test_delete_directory_recursive()
	test_delete_nonexistent_path()
	test_delete_already_deleted()

	# Migration / version mismatch tests
	test_migrate_v1_to_v2_json()
	test_version_mismatch_detection()
	test_cfg_version_migration()

	# Size calculation tests
	test_calculate_folder_size()
	test_calculate_folder_size_empty()
	test_calculate_folder_size_nested()

	_teardown()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


# ── Setup / Teardown ──────────────────────────────────────────────────────────

func _setup() -> void:
	_teardown()  # Clean slate
	DirAccess.make_dir_recursive_absolute(TEST_DIR)


func _teardown() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		_remove_recursive(TEST_DIR)


func _remove_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := path.path_join(name)
			if dir.current_is_dir():
				_remove_recursive(full)
				DirAccess.remove_absolute(full)
			else:
				DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# ── Save Flow Tests ───────────────────────────────────────────────────────────

func test_save_json_file() -> void:
	var path := TEST_DIR.path_join("save_data.json")
	var data := {"player_name": "Hero", "level": 5, "hp": 100}
	var json_str := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "save json: open for write")
	if file:
		file.store_string(json_str)
		file.close()
	_assert_true(FileAccess.file_exists(path), "save json: file exists after write")


func test_save_cfg_file() -> void:
	var path := TEST_DIR.path_join("settings.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", 0.8)
	cfg.set_value("video", "fullscreen", true)
	cfg.set_value("meta", "version", 2)
	var err := cfg.save(path)
	_assert_eq_int(err, OK, "save cfg: ConfigFile.save returns OK")
	_assert_true(FileAccess.file_exists(path), "save cfg: file exists after save")


func test_save_binary_dat_file() -> void:
	var path := TEST_DIR.path_join("world.dat")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "save dat: open for write")
	if file:
		file.store_32(0xDEADBEEF)
		file.store_float(3.14)
		file.store_pascal_string("test_data")
		file.close()
	_assert_true(FileAccess.file_exists(path), "save dat: file exists after write")


func test_save_nested_directories() -> void:
	var nested := TEST_DIR.path_join("saves/slot1/backup")
	DirAccess.make_dir_recursive_absolute(nested)
	var path := nested.path_join("autosave.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert_true(file != null, "save nested: open for write")
	if file:
		file.store_string('{"slot": 1}')
		file.close()
	_assert_true(FileAccess.file_exists(path), "save nested: file exists in deep path")


# ── Load Flow Tests ───────────────────────────────────────────────────────────

func test_load_json_file() -> void:
	var path := TEST_DIR.path_join("save_data.json")
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "load json: open for read")
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(content)
		_assert_eq_int(err, OK, "load json: parse succeeds")
		var data: Dictionary = json.data
		_assert_eq_str(str(data.get("player_name", "")), "Hero", "load json: player_name")
		_assert_eq_int(int(data.get("level", 0)), 5, "load json: level")


func test_load_cfg_file() -> void:
	var path := TEST_DIR.path_join("settings.cfg")
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	_assert_eq_int(err, OK, "load cfg: ConfigFile.load returns OK")
	_assert_eq_str(str(cfg.get_value("audio", "volume", 0.0)), "0.8", "load cfg: volume")
	_assert_true(cfg.get_value("video", "fullscreen", false), "load cfg: fullscreen")
	_assert_eq_int(int(cfg.get_value("meta", "version", 0)), 2, "load cfg: version")


func test_load_binary_dat_file() -> void:
	var path := TEST_DIR.path_join("world.dat")
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "load dat: open for read")
	if file:
		var magic := file.get_32()
		_assert_eq_int(magic, 0xDEADBEEF, "load dat: magic number")
		var pi := file.get_float()
		_assert_true(absf(pi - 3.14) < 0.01, "load dat: float value ~3.14")
		var s := file.get_pascal_string()
		_assert_eq_str(s, "test_data", "load dat: pascal string")
		file.close()


# ── Edge Cases: Corrupted / Malformed Files ───────────────────────────────────

func test_load_corrupted_json() -> void:
	var path := TEST_DIR.path_join("corrupted.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string('{"broken": true, missing_quote: }')
		file.close()

	var read_file := FileAccess.open(path, FileAccess.READ)
	_assert_true(read_file != null, "corrupted json: file opens")
	if read_file:
		var content := read_file.get_as_text()
		read_file.close()
		var json := JSON.new()
		var err := json.parse(content)
		_assert_true(err != OK, "corrupted json: parse fails as expected")
		_assert_true(json.get_error_message() != "", "corrupted json: error message present")
		print("    (error message: %s)" % json.get_error_message())


func test_load_empty_file() -> void:
	var path := TEST_DIR.path_join("empty.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("")
		file.close()

	var read_file := FileAccess.open(path, FileAccess.READ)
	_assert_true(read_file != null, "empty file: opens successfully")
	if read_file:
		var content := read_file.get_as_text()
		read_file.close()
		_assert_eq_str(content, "", "empty file: content is empty")
		var json := JSON.new()
		var err := json.parse(content)
		_assert_true(err != OK, "empty file: JSON parse fails on empty string")


func test_load_nonexistent_file() -> void:
	var path := TEST_DIR.path_join("does_not_exist.json")
	_assert_true(not FileAccess.file_exists(path), "nonexistent: file does not exist")
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file == null, "nonexistent: FileAccess.open returns null")
	_assert_true(FileAccess.get_open_error() != OK, "nonexistent: get_open_error != OK")


func test_load_binary_as_text() -> void:
	var path := TEST_DIR.path_join("world.dat")
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "binary as text: file opens")
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(content)
		_assert_true(err != OK, "binary as text: JSON parse fails on binary data")


# ── Delete Flow Tests ─────────────────────────────────────────────────────────

func test_delete_single_file() -> void:
	var path := TEST_DIR.path_join("to_delete.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("delete me")
		file.close()
	_assert_true(FileAccess.file_exists(path), "delete single: file exists before")
	var err := DirAccess.remove_absolute(path)
	_assert_eq_int(err, OK, "delete single: remove returns OK")
	_assert_true(not FileAccess.file_exists(path), "delete single: file gone after delete")


func test_delete_directory_recursive() -> void:
	var sub_dir := TEST_DIR.path_join("delete_me_dir")
	DirAccess.make_dir_recursive_absolute(sub_dir.path_join("nested"))
	var f1 := FileAccess.open(sub_dir.path_join("a.txt"), FileAccess.WRITE)
	if f1:
		f1.store_string("a")
		f1.close()
	var f2 := FileAccess.open(sub_dir.path_join("nested/b.txt"), FileAccess.WRITE)
	if f2:
		f2.store_string("b")
		f2.close()

	_assert_true(DirAccess.dir_exists_absolute(sub_dir), "delete dir: exists before")

	# Simulate the plugin's recursive delete
	_remove_recursive(sub_dir)

	_assert_true(not DirAccess.dir_exists_absolute(sub_dir), "delete dir: gone after recursive delete")
	_assert_true(not FileAccess.file_exists(sub_dir.path_join("a.txt")), "delete dir: child file gone")


func test_delete_nonexistent_path() -> void:
	var path := TEST_DIR.path_join("ghost_file.txt")
	_assert_true(not FileAccess.file_exists(path), "delete nonexistent: does not exist")
	var err := DirAccess.remove_absolute(path)
	_assert_true(err != OK, "delete nonexistent: remove returns error")


func test_delete_already_deleted() -> void:
	var path := TEST_DIR.path_join("ephemeral.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("temp")
		file.close()
	DirAccess.remove_absolute(path)
	_assert_true(not FileAccess.file_exists(path), "double delete: gone after first delete")
	var err := DirAccess.remove_absolute(path)
	_assert_true(err != OK, "double delete: second remove returns error")


# ── Migration / Version Mismatch Tests ────────────────────────────────────────

func test_migrate_v1_to_v2_json() -> void:
	# Simulate v1 save format → v2 migration
	var path := TEST_DIR.path_join("save_v1.json")
	var v1_data := {"name": "Player1", "score": 100}  # No "version" key
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(v1_data))
		file.close()

	# Load and migrate
	var read_file := FileAccess.open(path, FileAccess.READ)
	_assert_true(read_file != null, "migrate v1→v2: open")
	if read_file:
		var json := JSON.new()
		json.parse(read_file.get_as_text())
		read_file.close()
		var data: Dictionary = json.data

		# Migration logic: add version and rename fields
		if not data.has("version"):
			data["version"] = 2
			if data.has("name"):
				data["player_name"] = data["name"]
				data.erase("name")

		_assert_eq_int(int(data.get("version", 0)), 2, "migrate v1→v2: version set to 2")
		_assert_eq_str(str(data.get("player_name", "")), "Player1", "migrate v1→v2: name → player_name")
		_assert_true(not data.has("name"), "migrate v1→v2: old 'name' key removed")

		# Save migrated data
		var write_file := FileAccess.open(path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(JSON.stringify(data, "\t"))
			write_file.close()
		_assert_true(FileAccess.file_exists(path), "migrate v1→v2: migrated file saved")


func test_version_mismatch_detection() -> void:
	var path := TEST_DIR.path_join("save_future.json")
	var future_data := {"version": 99, "data": "from the future"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(future_data))
		file.close()

	var read_file := FileAccess.open(path, FileAccess.READ)
	if read_file:
		var json := JSON.new()
		json.parse(read_file.get_as_text())
		read_file.close()
		var data: Dictionary = json.data
		var save_version := int(data.get("version", 0))
		var current_version := 2

		_assert_true(save_version > current_version, "version mismatch: future version detected")
		_assert_true(save_version != current_version, "version mismatch: not equal to current")
		print("    (detected save version %d, current is %d)" % [save_version, current_version])


func test_cfg_version_migration() -> void:
	# Simulate migrating a .cfg save from v1 (no version) to v2
	var path := TEST_DIR.path_join("old_settings.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", "OldPlayer")
	cfg.set_value("player", "score", 50)
	# No "meta/version" section — this is v1
	cfg.save(path)

	# Load and migrate
	var loaded := ConfigFile.new()
	var err := loaded.load(path)
	_assert_eq_int(err, OK, "cfg migrate: load succeeds")

	if not loaded.has_section_key("meta", "version"):
		# Perform migration
		loaded.set_value("meta", "version", 2)
		loaded.set_value("player", "display_name", loaded.get_value("player", "name", "Unknown"))
		loaded.erase_section_key("player", "name")
		loaded.save(path)

	var migrated := ConfigFile.new()
	migrated.load(path)
	_assert_eq_int(int(migrated.get_value("meta", "version", 0)), 2, "cfg migrate: version set")
	_assert_eq_str(str(migrated.get_value("player", "display_name", "")), "OldPlayer", "cfg migrate: renamed field")
	_assert_true(not migrated.has_section_key("player", "name"), "cfg migrate: old key removed")


# ── Size Calculation Tests ────────────────────────────────────────────────────

func test_calculate_folder_size() -> void:
	var sub := TEST_DIR.path_join("size_test")
	DirAccess.make_dir_recursive_absolute(sub)
	var f := FileAccess.open(sub.path_join("a.txt"), FileAccess.WRITE)
	if f:
		f.store_string("hello")  # 5 bytes
		f.close()
	var f2 := FileAccess.open(sub.path_join("b.txt"), FileAccess.WRITE)
	if f2:
		f2.store_string("world!")  # 6 bytes
		f2.close()

	var total := _calculate_folder_size(sub)
	_assert_eq_int(total, 11, "folder size: 5+6=11 bytes")


func test_calculate_folder_size_empty() -> void:
	var sub := TEST_DIR.path_join("empty_dir")
	DirAccess.make_dir_recursive_absolute(sub)
	var total := _calculate_folder_size(sub)
	_assert_eq_int(total, 0, "folder size empty: 0 bytes")


func test_calculate_folder_size_nested() -> void:
	var sub := TEST_DIR.path_join("nested_size")
	DirAccess.make_dir_recursive_absolute(sub.path_join("child"))
	var f := FileAccess.open(sub.path_join("root.txt"), FileAccess.WRITE)
	if f:
		f.store_string("abc")  # 3 bytes
		f.close()
	var f2 := FileAccess.open(sub.path_join("child/deep.txt"), FileAccess.WRITE)
	if f2:
		f2.store_string("defgh")  # 5 bytes
		f2.close()

	var total := _calculate_folder_size(sub)
	_assert_eq_int(total, 8, "folder size nested: 3+5=8 bytes")


# Mirror of plugin's calculate_folder_size for testing outside the editor
func _calculate_folder_size(path: String) -> int:
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
				total_size += _calculate_folder_size(full_path)
			else:
				var file := FileAccess.open(full_path, FileAccess.READ)
				if file:
					total_size += file.get_length()
					file.close()
		file_name = dir.get_next()
	dir.list_dir_end()
	return total_size


# ── Assertions ────────────────────────────────────────────────────────────────

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


func _assert_eq_int(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected %d, got %d" % [label, expected, actual])


func _assert_eq_str(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected '%s', got '%s'" % [label, expected, actual])


func _print_summary() -> void:
	print("--- %d passed, %d failed ---" % [_pass_count, _fail_count])
