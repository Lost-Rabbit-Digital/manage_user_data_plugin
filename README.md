# Manage User Data

<img src="plugin_icon.png" width="64" height="64" alt="Manage User Data icon">

A Godot 4 editor plugin for browsing and selectively deleting your project's `user://` directory without leaving the editor.

**Requires Godot 4.3+** · **MIT License**

[![Godot Asset Library](https://img.shields.io/badge/Godot%20Asset%20Library-Manage%20User%20Data-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/asset-library/asset/4811)
[![Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/Y7caBf7gBj)

<img src="screenshot_1.png" width="512" alt="Plugin screenshot">

---

## Table of Contents

- [Install](#install)
- [Usage](#usage)
- [Features](#features)
- [API Reference](#api-reference)
- [Working with Save Files](#working-with-save-files)
- [Handling Edge Cases](#handling-edge-cases)
- [Running Tests](#running-tests)
- [What's in user://](#whats-in-user)
- [Contributing](#contributing)
- [Credits](#credits)

---

## Install

### Asset Library (recommended)

1. Open your project → **AssetLib** → search **"Manage User Data"**
2. **Download** → **Install**
3. **Project → Project Settings → Plugins** → enable **Manage User Data**

### Manual

1. Copy `addons/manage_user_data/` into your project:
   ```
   your_project/
   └── addons/
       └── manage_user_data/
           ├── plugin.cfg
           └── plugin.gd
   ```
2. **Project → Project Settings → Plugins** → enable **Manage User Data**

---

## Usage

Click the **User Data** button in the editor toolbar to open the dialog.

<img src="screenshot_4.png" width="512" alt="Toolbar button">

| Action | How |
|---|---|
| Delete everything | Leave all items checked → **Delete Selected** |
| Delete specific files | Uncheck **Select All** → tick what you want → **Delete Selected** |
| Find a file | Type in the **Search** bar |
| Filter by type | Use the **All Types** dropdown (Files, Folders, `.json`, `.cache`) |
| Clear filters | Click **×** next to the dropdown |
| Refresh the list | Click the **⟳** icon |
| Open in file manager | Click **Open Folder** |
| Copy engine logs | Click **Copy Logs** (de-duplicates automatically) |

<img src="screenshot_2.png" width="512" alt="File tree screenshot">

The status bar shows a live count and total size of selected items before you confirm. Deletion is permanent and cannot be undone.

<img src="screenshot_5.png" width="512" height="256" alt="Status bar">

---

## Features

- **File Tree** — Full recursive view of `user://` with per-item checkboxes
- **Real-time Search** — Instantly filters the tree as you type; parent folders auto-expand
- **Type Filters** — Narrow to Files Only, Folders Only, `.json`, or `.cache`
- **Bulk Selection** — Select All / Deselect All with indeterminate state support
- **File Sizes** — Inline sizes on every entry; status bar totals the selection
- **Open in OS** — Launch `user://` in your native file manager
- **Copy Logs** — One-click copy of de-duplicated `godot.log` to clipboard
- **Refresh** — Rescan `user://` without reopening the plugin
- **Version Check** — Warns on Godot versions below 4.3
- **Error Resilience** — Gracefully handles unreadable files, locked directories, and permission errors

---

## API Reference

The plugin extends `EditorPlugin` and provides utility methods for managing `user://` contents. While primarily a UI tool, the following public methods are available.

### Core Methods

#### `show_confirmation_dialog() → void`
Opens the main plugin dialog. Scans `user://` and builds the file tree.

```gdscript
# Typically called via toolbar button, but can be invoked programmatically:
var plugin = EditorInterface.get_editor_plugin("Manage User Data")
plugin.show_confirmation_dialog()
```

#### `populate_tree(parent_item: TreeItem, path: String) → void`
Recursively scans a directory and populates the `Tree` control with items. Each item stores its full path in metadata slot 1.

- Handles unreadable directories with `push_warning()`
- Displays file sizes inline (or "unreadable" for locked files)
- Assigns icons based on file extension

#### `delete_selected_items() → Dictionary`
Deletes all checked items in the tree. Sorts paths deepest-first to avoid parent-before-child conflicts.

**Returns:** `{"deleted": int, "failed": Array[String]}`

```gdscript
var result = delete_selected_items()
print("Deleted %d items" % result.deleted)
if not result.failed.is_empty():
    push_warning("Failed to delete: %s" % str(result.failed))
```

#### `delete_directory_contents(path: String) → void`
Recursively deletes all files and subdirectories inside `path` without removing the directory itself. Logs warnings for items that fail to delete.

#### `calculate_folder_size(path: String) → int`
Returns the total byte size of all files under `path`, recursively. Skips unreadable files.

### Filter & Search Methods

#### `apply_filters() → void`
Applies the current search text and type filters to the tree. Matching parents auto-expand.

#### `filter_tree_item(item: TreeItem, search_term: String, filter_types: Array[int]) → bool`
Recursively filters tree items. Returns `true` if the item or any descendant matches.

**Filter type IDs:**
| ID | Filter |
|----|--------|
| 1 | Files Only |
| 2 | Folders Only |
| 3 | `.json` files |
| 4 | `.cache` files |

### Utility Methods

#### `format_file_size(bytes: int) → String`
Formats byte counts for display.

```gdscript
format_file_size(0)        # "0 B"
format_file_size(1024)     # "1.00 KB"
format_file_size(1572864)  # "1.50 MB"
```

#### `get_file_type_label(file_name: String) → String`
Returns a human-readable type label based on file extension.

```gdscript
get_file_type_label("save.json")   # "JSON Data"
get_file_type_label("icon.png")    # "PNG Image"
get_file_type_label("player.gd")   # "GDScript"
get_file_type_label("Makefile")    # "File"
```

#### `get_file_icon(file_name: String) → Texture2D`
Returns an appropriate editor theme icon for the file type.

**Supported extensions:** `.json`, `.cfg`, `.ini`, `.toml`, `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`, `.svg`, `.wav`, `.ogg`, `.mp3`, `.tscn`, `.tres`, `.gd`, `.cache`, `.save`, `.dat`

### UI Helper Methods

#### `propagate_check_state(item: TreeItem, checked: bool) → void`
Recursively applies a checked/unchecked state to all children of the given tree item.

#### `collect_checked_items(item: TreeItem, result: Array) → void`
Collects full paths of all checked items into the `result` array.

#### `collect_checked_items_with_stats(item, result, total_size_ref, file_count_ref, folder_count_ref) → void`
Like `collect_checked_items`, but also accumulates total size, file count, and folder count via reference arrays.

#### `update_warning_label() → void`
Updates the status bar with the current selection count, size, and warning text.

---

## Working with Save Files

This plugin helps you manage any files your game writes to `user://`. Here are common patterns used by Godot games and how this plugin helps during development.

### JSON Save Files

```gdscript
# Saving
var save_data := {"version": 2, "player_name": "Hero", "level": 5}
var file := FileAccess.open("user://save.json", FileAccess.WRITE)
file.store_string(JSON.stringify(save_data, "\t"))
file.close()

# Loading with error handling
var file := FileAccess.open("user://save.json", FileAccess.READ)
if file == null:
    push_error("Save file not found")
    return

var json := JSON.new()
var err := json.parse(file.get_as_text())
file.close()

if err != OK:
    push_error("Corrupted save file: %s" % json.get_error_message())
    return

var data: Dictionary = json.data
```

### ConfigFile Save Data

```gdscript
# Saving
var cfg := ConfigFile.new()
cfg.set_value("meta", "version", 2)
cfg.set_value("player", "name", "Hero")
cfg.set_value("player", "score", 1500)
cfg.save("user://settings.cfg")

# Loading
var cfg := ConfigFile.new()
if cfg.load("user://settings.cfg") != OK:
    push_error("Failed to load settings")
    return

var version := cfg.get_value("meta", "version", 1)
var name := cfg.get_value("player", "name", "Unknown")
```

### Binary Save Files

```gdscript
# Saving
var file := FileAccess.open("user://world.dat", FileAccess.WRITE)
file.store_32(0x53415645)  # Magic number "SAVE"
file.store_32(2)            # Version
file.store_float(player.position.x)
file.store_float(player.position.y)
file.store_pascal_string(player.name)
file.close()

# Loading with validation
var file := FileAccess.open("user://world.dat", FileAccess.READ)
if file == null:
    return

var magic := file.get_32()
if magic != 0x53415645:
    push_error("Not a valid save file")
    file.close()
    return

var version := file.get_32()
if version > 2:
    push_error("Save file from newer game version (v%d)" % version)
    file.close()
    return
```

---

## Handling Edge Cases

### Corrupted Save Files

Always validate before trusting file contents:

```gdscript
func load_save_safe(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Cannot open: %s (error %d)" % [path, FileAccess.get_open_error()])
        return null

    var content := file.get_as_text()
    file.close()

    if content.strip_edges().is_empty():
        push_warning("Empty save file: %s" % path)
        return null

    var json := JSON.new()
    if json.parse(content) != OK:
        push_error("Corrupted save: %s — %s" % [path, json.get_error_message()])
        return null

    return json.data
```

### Version Mismatches

Version your save format and handle migrations:

```gdscript
const CURRENT_SAVE_VERSION := 3

func load_and_migrate(path: String) -> Dictionary:
    var data := load_save_safe(path)
    if data == null or not data is Dictionary:
        return {}

    var version := int(data.get("version", 1))

    if version > CURRENT_SAVE_VERSION:
        push_error("Save from future version %d (current: %d)" % [version, CURRENT_SAVE_VERSION])
        return {}

    # Apply migrations sequentially
    if version < 2:
        # v1 → v2: rename "name" to "player_name"
        if data.has("name"):
            data["player_name"] = data["name"]
            data.erase("name")
        data["version"] = 2

    if version < 3:
        # v2 → v3: add inventory array
        if not data.has("inventory"):
            data["inventory"] = []
        data["version"] = 3

    return data
```

### ConfigFile Version Migration

```gdscript
func migrate_cfg(path: String) -> ConfigFile:
    var cfg := ConfigFile.new()
    if cfg.load(path) != OK:
        return cfg

    var version := int(cfg.get_value("meta", "version", 1))

    if version < 2:
        # Rename section key
        var old_val = cfg.get_value("player", "name", "")
        cfg.set_value("player", "display_name", old_val)
        cfg.erase_section_key("player", "name")
        cfg.set_value("meta", "version", 2)
        cfg.save(path)

    return cfg
```

---

## Running Tests

The test suite validates the plugin's core logic — formatting, filtering, file operations, and migration patterns.

### Prerequisites

- Godot 4.3+ in your `PATH` (or set `GODOT_BIN` environment variable)

### Run All Tests

```bash
bash tests/run_all.sh
```

### Run Individual Tests

```bash
godot --headless --path . --script tests/test_format_file_size.gd
godot --headless --path . --script tests/test_file_type_label.gd
godot --headless --path . --script tests/test_filter_logic.gd
godot --headless --path . --script tests/test_file_operations.gd
```

### Test Coverage

| Test File | What It Covers |
|---|---|
| `test_format_file_size.gd` | Byte/KB/MB formatting, boundary values |
| `test_file_type_label.gd` | Extension → label mapping, case insensitivity, unknown extensions |
| `test_filter_logic.gd` | Search matching, type filters, combined filters, depth sorting, propagation |
| `test_file_operations.gd` | JSON/CFG/binary save+load, corrupted files, empty files, recursive delete, version migration, folder size calculation |

### CI Integration

Add to your GitHub Actions workflow:

```yaml
- name: Run plugin tests
  uses: chickensoft-games/setup-godot@v2
  with:
    version: 4.4.1
    use-dotnet: false

- run: godot --headless --path . --script tests/test_format_file_size.gd
- run: godot --headless --path . --script tests/test_file_type_label.gd
- run: godot --headless --path . --script tests/test_filter_logic.gd
- run: godot --headless --path . --script tests/test_file_operations.gd
```

---

## What's in user://

Godot writes to `user://` when your game uses paths like `"user://save.json"`. Common files to clean during development:

| Extension | Source |
|---|---|
| `.cfg` / `.json` | Save data, settings |
| `.log` | Engine/game log files |
| `.cache` | Engine/game caches |
| `.save` / `.dat` | Binary save files |

**On-disk location:**

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\<project>\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/<project>/` |
| Linux | `~/.local/share/godot/app_userdata/<project>/` |

---

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-change`
3. Run the tests: `bash tests/run_all.sh`
4. Submit a pull request

### Development Setup

```bash
git clone https://github.com/Lost-Rabbit-Digital/manage_user_data_plugin.git
cd manage_user_data_plugin
# Open in Godot 4.3+ and enable the plugin
```

### Reporting Issues

- [GitHub Issues](https://github.com/Lost-Rabbit-Digital/manage_user_data_plugin/issues)
- [Discord Community](https://discord.gg/Y7caBf7gBj)

---

## Credits

<img src="screenshot_3.png" width="512" alt="Credits">

Made by [Lost Rabbit Digital](https://lostrabbit.digital/) · [Discord](https://discord.gg/Y7caBf7gBj)

MIT — see [LICENSE](LICENSE)
