# Manage User Data

A Godot 4 editor plugin for browsing and selectively deleting your project's `user://` directory — without leaving the editor.

**Requires Godot 4.3+**

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

A **User Data** button appears in the editor toolbar. Click it to open the dialog.

| Action | How |
|---|---|
| Delete everything | Leave all items checked → **Delete Selected** |
| Delete specific files | **Select All** checkbox to deselect all → tick what you want → **Delete Selected** |
| Find a file | Type in the **Search** bar or use the **All Types** filter dropdown |
| Reset filters | Click the **×** button next to the filter dropdown |
| Refresh the list | Click the **⟳** (reload) icon |
| Open in file manager | Click **Open Folder** |

> Deletion is permanent and cannot be undone. The status bar shows a live count and total size of what will be deleted before you confirm.

---

## What's in user://

Godot writes to `user://` when your game uses paths like `"user://save.json"`. Common files to clean during development:

| Extension | Source |
|---|---|
| `.cfg` / `.json` | Save data |
| `.log` | Log files |
| `.cache` | Engine/game caches |

**On-disk location:**

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\<project>\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/<project>/` |
| Linux | `~/.local/share/godot/app_userdata/<project>/` |

---

## License

MIT — see [LICENSE](LICENSE) for details.
