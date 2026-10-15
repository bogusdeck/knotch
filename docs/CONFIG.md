# Configuration Reference

All NotchDeck settings live in `~/.config/notchdeck/config.toml`.  
The file is created automatically on first launch with commented defaults.

Hot-reload is supported: save the file and changes apply immediately (Phase 2+).

---

## `[general]`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `screen` | string | `"builtin"` | Which display to use. `"builtin"` selects the built-in MacBook display; use `0`, `1`, … for external screens. |
| `hover_to_peek` | bool | `true` | Show a quick-glance peek when the cursor enters the notch area. |
| `peek_delay_ms` | int | `150` | Milliseconds to wait before transitioning from collapsed → peek. |
| `launch_at_login` | bool | `false` | Register NotchDeck as a login item via `SMAppService`. |
| `copy_on_drop` | bool | `false` | When `true`, files dropped onto the shelf or notch are copied into `~/.config/notchdeck/shelf/files/` instead of referenced. |

---

## `[shortcuts]`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `toggle` | string | `"cmd+shift+space"` | Global shortcut to show/hide the expanded notch. |
| `quick_note` | string | `"cmd+shift+n"` | Global shortcut to open straight into the Quick Note input. |

Modifier tokens: `cmd`, `shift`, `opt`, `ctrl`. Key tokens: any single letter or F-key (`f1`…`f12`).

---

## `[appearance]`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `theme` | string | `"dark"` | `"dark"` or `"light"`. |
| `accent` | string | `"#7C5CFF"` | Hex colour used for highlights and active states. |
| `expanded_width` | int | `640` | Width of the expanded notch in points. |
| `expanded_height` | int | `260` | Height of the expanded notch in points. |
| `corner_radius` | int | `22` | Bottom-corner radius of the expanded shape. |

---

## `[layout]`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `tabs` | array of strings | `["home","notes","shelf","terminal","vpn"]` | Ordered list of tabs shown in the expanded notch. |
| `home` | array of strings | `["media","clock","calendar","vpn-status"]` | Widget IDs shown on the Home tab. |

---

## `[[widgets]]`

Each `[[widgets]]` entry defines a widget. The `type` field determines which keys are valid.

### Common fields

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `id` | string | ✅ | Unique identifier; referenced in `layout.tabs` and `layout.home`. |
| `type` | string | ✅ | Widget type: `action`, `shell`, `terminal`, `web`. |
| `title` | string | ✅ | Label shown in the tab bar. |
| `icon` | string | | SF Symbol name for the tab icon. |
| `shortcut` | string | | Per-widget shortcut to focus this tab. |

### type = `action`

Runs shell commands or AppleScript; polls a status command on an interval.

| Key | Type | Description |
|-----|------|-------------|
| `status_command` | string | Shell command whose stdout is matched against `status_regex`. |
| `status_interval_s` | int | Polling interval in seconds. |
| `status_regex` | string | Regex pattern; if matched, the status indicator shows as "active". |
| `[[widgets.buttons]]` | array | Each button has `label` (string) and one of: `command`, `applescript`, or `open_url`. |

```toml
[[widgets]]
id = "vpn-status"
type = "action"
title = "Windscribe"
icon = "lock.shield"
status_command = "windscribe-cli status"
status_interval_s = 10
status_regex = "Connected"

[[widgets.buttons]]
label = "Connect"
command = "windscribe-cli connect"

[[widgets.buttons]]
label = "Disconnect"
command = "windscribe-cli disconnect"
```

### type = `shell`

Displays the stdout of a command refreshed on an interval.

| Key | Type | Description |
|-----|------|-------------|
| `command` | string | Shell command to run. |
| `interval_s` | int | Refresh interval. |
| `format` | string | Optional: `"text"` (default) or `"json"`. |

### type = `terminal`

An embedded terminal session using SwiftTerm.

| Key | Type | Description |
|-----|------|-------------|
| `command` | string | Command to run in the terminal (e.g. `"npm run dev"`). |
| `cwd` | string | Working directory (supports `~`). |
| `autostart` | bool | Start the command when NotchDeck launches. |

### type = `web`

Loads a user-supplied HTML/JS widget in a transparent `WKWebView`.

| Key | Type | Description |
|-----|------|-------------|
| `path` | string | Path inside `~/.config/notchdeck/` containing `index.html`. |
| `allow_shell` | bool | **Security risk** — allows the widget to call `window.notch.run(command)`. Disabled by default. |

JS Bridge (`window.notch`):

```js
// Run a shell command (requires allow_shell = true)
const out = await window.notch.run("echo hello");

// Read the widget's TOML config table
const cfg = window.notch.config;

// Persistent key-value storage
window.notch.storage.set("key", "value");
const val = window.notch.storage.get("key");

// Show a macOS notification
window.notch.notify("Hello from widget!");
```

---

## File layout created on first launch

```
~/.config/notchdeck/
  config.toml        ← main config (this file)
  notes/             ← quick notes as timestamped .md files
  shelf/             ← pinned file/folder metadata
  widgets/           ← user web widgets (one subdirectory each)
  themes/            ← optional theme files
```
