extends Node
## Unit tests for get_file_type_label().
## Run via: godot --headless --script tests/test_file_type_label.gd

var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	print("=== test_file_type_label ===")
	test_known_extensions()
	test_case_insensitivity()
	test_unknown_extension()
	test_no_extension()
	_print_summary()
	get_tree().quit(0 if _fail_count == 0 else 1)


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


func test_known_extensions() -> void:
	_assert_eq(get_file_type_label("data.json"), "JSON Data", "json")
	_assert_eq(get_file_type_label("settings.cfg"), "Config File", "cfg")
	_assert_eq(get_file_type_label("config.ini"), "INI Config", "ini")
	_assert_eq(get_file_type_label("config.toml"), "TOML Config", "toml")
	_assert_eq(get_file_type_label("icon.png"), "PNG Image", "png")
	_assert_eq(get_file_type_label("photo.jpg"), "JPEG Image", "jpg")
	_assert_eq(get_file_type_label("photo.jpeg"), "JPEG Image", "jpeg")
	_assert_eq(get_file_type_label("image.webp"), "WebP Image", "webp")
	_assert_eq(get_file_type_label("image.bmp"), "BMP Image", "bmp")
	_assert_eq(get_file_type_label("icon.svg"), "SVG Image", "svg")
	_assert_eq(get_file_type_label("sound.wav"), "WAV Audio", "wav")
	_assert_eq(get_file_type_label("music.ogg"), "OGG Audio", "ogg")
	_assert_eq(get_file_type_label("track.mp3"), "MP3 Audio", "mp3")
	_assert_eq(get_file_type_label("level.tscn"), "Packed Scene", "tscn")
	_assert_eq(get_file_type_label("mat.tres"), "Resource", "tres")
	_assert_eq(get_file_type_label("player.gd"), "GDScript", "gd")
	_assert_eq(get_file_type_label("data.cache"), "Cache File", "cache")
	_assert_eq(get_file_type_label("game.save"), "Save File", "save")
	_assert_eq(get_file_type_label("world.dat"), "Data File", "dat")


func test_case_insensitivity() -> void:
	_assert_eq(get_file_type_label("DATA.JSON"), "JSON Data", "uppercase JSON")
	_assert_eq(get_file_type_label("Image.PNG"), "PNG Image", "uppercase PNG")
	_assert_eq(get_file_type_label("Track.Mp3"), "MP3 Audio", "mixed case mp3")


func test_unknown_extension() -> void:
	_assert_eq(get_file_type_label("archive.zip"), "ZIP File", "unknown .zip")
	_assert_eq(get_file_type_label("readme.txt"), "TXT File", "unknown .txt")
	_assert_eq(get_file_type_label("binary.bin"), "BIN File", "unknown .bin")


func test_no_extension() -> void:
	_assert_eq(get_file_type_label("Makefile"), "File", "no extension")
	_assert_eq(get_file_type_label("LICENSE"), "File", "no extension LICENSE")


func _assert_eq(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s — expected '%s', got '%s'" % [label, expected, actual])


func _print_summary() -> void:
	print("--- %d passed, %d failed ---" % [_pass_count, _fail_count])
