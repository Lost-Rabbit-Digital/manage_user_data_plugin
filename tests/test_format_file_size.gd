extends Node
## Unit tests for format_file_size().
## Run via: godot --headless --script tests/test_format_file_size.gd

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	print("=== test_format_file_size ===")
	test_zero_bytes()
	test_bytes_range()
	test_kilobytes()
	test_megabytes()
	test_boundary_1024()
	test_boundary_1mb()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


func format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.2f KB" % (bytes / 1024.0)
	else:
		return "%.2f MB" % (bytes / (1024.0 * 1024.0))


func test_zero_bytes() -> void:
	_assert_eq(format_file_size(0), "0 B", "zero bytes")


func test_bytes_range() -> void:
	_assert_eq(format_file_size(1), "1 B", "1 byte")
	_assert_eq(format_file_size(512), "512 B", "512 bytes")
	_assert_eq(format_file_size(1023), "1023 B", "1023 bytes")


func test_kilobytes() -> void:
	_assert_eq(format_file_size(2048), "2.00 KB", "2 KB")
	_assert_eq(format_file_size(1536), "1.50 KB", "1.5 KB")
	_assert_eq(format_file_size(500000), "488.28 KB", "~488 KB")


func test_megabytes() -> void:
	_assert_eq(format_file_size(1048576), "1.00 MB", "1 MB")
	_assert_eq(format_file_size(5242880), "5.00 MB", "5 MB")
	_assert_eq(format_file_size(1572864), "1.50 MB", "1.5 MB")


func test_boundary_1024() -> void:
	_assert_eq(format_file_size(1024), "1.00 KB", "exactly 1 KB")


func test_boundary_1mb() -> void:
	_assert_eq(format_file_size(1024 * 1024), "1.00 MB", "exactly 1 MB")


func _assert_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected '%s', got '%s'" % [label, expected, actual])


func _print_summary() -> void:
	print("--- %d passed, %d failed ---" % [_pass_count, _fail_count])
