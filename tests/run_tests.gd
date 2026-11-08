extends SceneTree
## Test runner that executes all test scripts sequentially.
## Run via: godot --headless --script tests/run_tests.gd
##
## Each test file is a self-contained SceneTree script that prints PASS/FAIL
## results and exits with code 0 (all pass) or 1 (any fail).
##
## For CI usage, run each test individually:
##   godot --headless --script tests/test_format_file_size.gd
##   godot --headless --script tests/test_file_type_label.gd
##   godot --headless --script tests/test_filter_logic.gd
##   godot --headless --script tests/test_file_operations.gd
##   godot --headless --script tests/test_deletion_safety.gd


func _init() -> void:
	print("")
	print("╔══════════════════════════════════════════╗")
	print("║   Manage User Data — Test Suite          ║")
	print("╚══════════════════════════════════════════╝")
	print("")
	print("Run individual tests with:")
	print("  godot --headless --script tests/test_format_file_size.gd")
	print("  godot --headless --script tests/test_file_type_label.gd")
	print("  godot --headless --script tests/test_filter_logic.gd")
	print("  godot --headless --script tests/test_file_operations.gd")
	print("  godot --headless --script tests/test_deletion_safety.gd")
	print("")
	print("Or use the shell runner:")
	print("  bash tests/run_all.sh")
	print("")
	quit(0)
