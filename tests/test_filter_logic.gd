extends Node
## Unit tests for filter/search logic used in the plugin.
## Tests the matching rules without requiring the editor UI.
## Run via: godot --headless --script tests/test_filter_logic.gd

var _pass_count := 0
var _fail_count := 0

# Filter type IDs (mirror plugin constants)
const FILTER_FILES_ONLY := 1
const FILTER_FOLDERS_ONLY := 2
const FILTER_JSON := 3
const FILTER_CACHE := 4


func _ready() -> void:
	print("=== test_filter_logic ===")
	test_no_filters_matches_everything()
	test_search_term_matching()
	test_search_case_insensitive()
	test_filter_files_only()
	test_filter_folders_only()
	test_filter_json()
	test_filter_cache()
	test_combined_filters()
	test_empty_search_with_type_filter()
	test_search_with_no_type_filter()
	test_depth_sort_for_deletion()
	test_propagate_check_logic()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


# Replicate the plugin's matching logic for isolated testing
func item_matches(item_name: String, is_folder: bool, search_term: String, filter_types: Array[int]) -> bool:
	var lower_name := item_name.to_lower()

	var matches_search: bool = search_term.is_empty() or lower_name.contains(search_term.to_lower())

	var matches_type := false
	if filter_types.is_empty():
		matches_type = true
	else:
		for ft in filter_types:
			match ft:
				FILTER_FILES_ONLY:
					if not is_folder:
						matches_type = true
				FILTER_FOLDERS_ONLY:
					if is_folder:
						matches_type = true
				FILTER_JSON:
					if not is_folder and lower_name.ends_with(".json"):
						matches_type = true
				FILTER_CACHE:
					if not is_folder and lower_name.ends_with(".cache"):
						matches_type = true
			if matches_type:
				break

	return matches_search and matches_type


func test_no_filters_matches_everything() -> void:
	var empty_filters: Array[int] = []
	_assert_true(item_matches("save.json", false, "", empty_filters), "no filter: file matches")
	_assert_true(item_matches("saves", true, "", empty_filters), "no filter: folder matches")
	_assert_true(item_matches("data.cache", false, "", empty_filters), "no filter: cache matches")


func test_search_term_matching() -> void:
	var empty_filters: Array[int] = []
	_assert_true(item_matches("player_save.json", false, "player", empty_filters), "search: 'player' in name")
	_assert_true(not item_matches("enemy_data.json", false, "player", empty_filters), "search: 'player' not in name")
	_assert_true(item_matches("my_folder", true, "folder", empty_filters), "search: folder matches")


func test_search_case_insensitive() -> void:
	var empty_filters: Array[int] = []
	_assert_true(item_matches("PlayerSave.json", false, "playersave", empty_filters), "case insensitive: mixed case")
	_assert_true(item_matches("DATA.JSON", false, "data", empty_filters), "case insensitive: uppercase file")


func test_filter_files_only() -> void:
	var filters: Array[int] = [FILTER_FILES_ONLY]
	_assert_true(item_matches("save.json", false, "", filters), "files only: file passes")
	_assert_true(not item_matches("saves", true, "", filters), "files only: folder excluded")


func test_filter_folders_only() -> void:
	var filters: Array[int] = [FILTER_FOLDERS_ONLY]
	_assert_true(item_matches("saves", true, "", filters), "folders only: folder passes")
	_assert_true(not item_matches("save.json", false, "", filters), "folders only: file excluded")


func test_filter_json() -> void:
	var filters: Array[int] = [FILTER_JSON]
	_assert_true(item_matches("data.json", false, "", filters), "json filter: .json passes")
	_assert_true(not item_matches("data.cache", false, "", filters), "json filter: .cache excluded")
	_assert_true(not item_matches("data.json.bak", false, "", filters), "json filter: .json.bak excluded")
	_assert_true(not item_matches("saves", true, "", filters), "json filter: folder excluded")


func test_filter_cache() -> void:
	var filters: Array[int] = [FILTER_CACHE]
	_assert_true(item_matches("temp.cache", false, "", filters), "cache filter: .cache passes")
	_assert_true(not item_matches("temp.json", false, "", filters), "cache filter: .json excluded")


func test_combined_filters() -> void:
	# JSON + Cache (OR logic — item must match at least one)
	var filters: Array[int] = [FILTER_JSON, FILTER_CACHE]
	_assert_true(item_matches("data.json", false, "", filters), "combined: .json passes")
	_assert_true(item_matches("temp.cache", false, "", filters), "combined: .cache passes")
	_assert_true(not item_matches("image.png", false, "", filters), "combined: .png excluded")

	# Files + Folders (everything passes)
	var all_filters: Array[int] = [FILTER_FILES_ONLY, FILTER_FOLDERS_ONLY]
	_assert_true(item_matches("file.txt", false, "", all_filters), "combined: file passes both")
	_assert_true(item_matches("folder", true, "", all_filters), "combined: folder passes both")


func test_empty_search_with_type_filter() -> void:
	var filters: Array[int] = [FILTER_JSON]
	_assert_true(item_matches("save.json", false, "", filters), "empty search + json: matches")
	_assert_true(not item_matches("save.cfg", false, "", filters), "empty search + json: cfg excluded")


func test_search_with_no_type_filter() -> void:
	var empty_filters: Array[int] = []
	_assert_true(item_matches("save.json", false, "save", empty_filters), "search + no type: matches")
	_assert_true(not item_matches("config.cfg", false, "save", empty_filters), "search + no type: no match")


func test_depth_sort_for_deletion() -> void:
	# The plugin sorts paths deepest-first for safe deletion
	var paths: Array = [
		"user://saves",
		"user://saves/slot1",
		"user://saves/slot1/backup/auto.sav",
		"user://saves/slot1/manual.sav",
		"user://logs/godot.log",
	]

	paths.sort_custom(func(a: String, b: String) -> bool:
		return a.count("/") > b.count("/")
	)

	# Deepest first
	_assert_eq_str(paths[0], "user://saves/slot1/backup/auto.sav", "depth sort: deepest first")
	_assert_eq_str(paths[-1], "user://saves", "depth sort: shallowest last")

	# Verify monotonically non-increasing depth
	var valid := true
	for i in range(paths.size() - 1):
		if paths[i].count("/") < paths[i + 1].count("/"):
			valid = false
			break
	_assert_true(valid, "depth sort: monotonically decreasing depth")


func test_propagate_check_logic() -> void:
	# Test the propagation concept: parent checked → all children checked
	var states := {"root": true, "child1": false, "child2": false, "grandchild": false}

	# Simulate propagate_check_state(root, true)
	var parent_checked := true
	for key in states.keys():
		states[key] = parent_checked

	_assert_true(states["child1"], "propagate: child1 checked")
	_assert_true(states["grandchild"], "propagate: grandchild checked")

	# Simulate propagate_check_state(root, false)
	parent_checked = false
	for key in states.keys():
		states[key] = parent_checked

	_assert_true(not states["child1"], "propagate: child1 unchecked")
	_assert_true(not states["grandchild"], "propagate: grandchild unchecked")


# ── Assertions ────────────────────────────────────────────────────────────────

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


func _assert_eq_str(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected '%s', got '%s'" % [label, expected, actual])


func _print_summary() -> void:
	print("--- %d passed, %d failed ---" % [_pass_count, _fail_count])
