# Clear User Data

A Godot 4 editor plugin for browsing and selectively deleting the contents of your project's `user://` directory — the same directory where save files, logs, caches, and other persistent data land at runtime.

---

## Requirements

- Godot **4.3** or later

---

## Installation

### From the Asset Library

1. Open your project in the Godot editor.
2. Go to **AssetLib** (top centre of the editor).
3. Search for **"Clear User Data"**.
4. Click **Download**, then **Install**.
5. Enable the plugin under **Project → Project Settings → Plugins**.

### Manual

1. Copy the `addons/clear_user_data/` folder into your project's `addons/` directory so the layout looks like:

   ```
   your_project/
   └── addons/
       └── clear_user_data/
           ├── plugin.cfg
           └── plugin.gd
   ```

2. Open **Project → Project Settings → Plugins** and set **Clear User Data** to **Enabled**.

---

## Usage

Once enabled, a **"User Data"** button appears in the main editor toolbar (top-right area, alongside other editor tools).

### Opening the dialog

Click the **User Data** toolbar button. The **Manage User Directory Contents** dialog opens and immediately scans your `user://` directory.

### Reading the tree

The tree mirrors the structure of `user://`:

| Column | Contents |
|---|---|
| Checkbox | Tick = will be deleted; untick = will be kept |
| Name | File or folder name (with editor icon) |
| Type / Size | `Folder`, or `File (12.50 KB)` |

All items are **checked by default**. Untick anything you want to keep before confirming.

Clicking a folder's checkbox propagates the state to all its children automatically.

### Filtering

Use the **Search** field and **Type** drop-down to narrow the list:

| Type filter | Shows |
|---|---|
| All | Everything |
| Files Only | Files only (folders act as containers) |
| Folders Only | Folders only |
| .json | `.json` files only |
| .cache | `.cache` files only |

Press **Clear** to reset both filters at once. Folders that contain matching items are expanded automatically.

### Bulk selection

- **Select All** — checks every item.
- **Deselect All** — unchecks every item (useful when you only want to delete one or two things).

### Refreshing

Click **Refresh** to re-scan `user://` without closing the dialog. Useful if an external process wrote files while the dialog was open.

### Opening the directory

**Open User Dir** launches your OS file manager at the `user://` location (the actual path on disk, e.g. `~/.local/share/godot/app_userdata/<project>/`).

### Deleting

The status bar at the bottom of the dialog shows a live summary:

- **No items selected** — nothing will happen.
- **About to delete N files (X MB total). This cannot be undone!** — shown in red when at least one item is checked.

Click **Delete Selected** to perform the deletion. The operation cannot be undone. The dialog closes automatically on completion.

> **Tip:** To delete everything, leave all items checked and click Delete Selected. To clean only specific files, click **Deselect All** first, then tick the items you want to remove.

---

## What lives in user://

Godot writes to `user://` whenever your game uses paths like:

```gdscript
FileAccess.open("user://save.json", FileAccess.WRITE)
```

Common contents you may want to clean up during development:

| Path | Typical source |
|---|---|
| `user://*.cfg` | `ConfigFile` saves |
| `user://*.json` | Custom JSON save data |
| `user://*.log` | `print()` output redirected to file |
| `user://*.cache` | Engine or game caches |
| `user://screenshots/` | `DisplayServer.screenshot()` |

The exact on-disk location for each platform:

| Platform | Path |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\<project>\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/<project>/` |
| Linux | `~/.local/share/godot/app_userdata/<project>/` |

---

## Common workflows

**Reset game state between test runs**

Open the dialog, leave everything checked, click **Delete Selected**. Hit Play — your game starts with a clean slate.

**Keep settings, wipe saves**

Open the dialog, click **Deselect All**, then tick only the save-related files or folders. Click **Delete Selected**.

**Check how much data the game has written**

Open the dialog and read the status bar — it totals the size of all checked items. No need to navigate to the folder yourself.

---

## License

MIT — see [LICENSE](LICENSE) for details.
