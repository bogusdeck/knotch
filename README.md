# Knotch (NotchDeck)

> A modern, customizable productivity hub and desktop extension living right inside your MacBook notch — built with Swift 6 and SwiftUI.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B%20(Sonoma%20%7C%20Sequoia)-blue.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Xcode 16](https://img.shields.io/badge/Xcode-16%2B-blueviolet.svg?style=flat-square&logo=xcode)](https://developer.apple.com/xcode/)
[![Tests](https://img.shields.io/badge/Tests-50%20passing-brightgreen.svg?style=flat-square)](NotchDeck/Tests/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

---

## 🌟 Overview

**Knotch** transforms the unused hardware notch on your MacBook into an interactive command center. Hover or hit a global hotkey to reveal media playback, scratchpad notes, persistent shell sessions, a desktop application & file holder with built-in PDF reading, and customizable status widgets (such as VPN toggles and shell monitors).

Everything is driven by a single, clean `~/.config/notchdeck/config.toml` that hot-reloads instantly upon saving.

---

## ✨ Features

### 🏠 Home Dashboard
- **Now Playing**: Live media playback controls and track information (Apple Music, Spotify, browsers).
- **Calendar & Clock**: Upcoming events, dates, and clean status indicators.
- **Customizable Grid**: Choose which widgets appear on the home canvas.

### 📝 Quick Notes
- Instant scratchpad for thoughts, meeting notes, code snippets, or links.
- Global shortcut (`⌘ ⇧ N`) brings up the notch and auto-focuses note input immediately.
- Fast search, list management, and persistent local storage.

### 🖥️ Persistent Multi-Shell Terminal
- Built-in `zsh` terminal sessions powered by [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).
- Create multiple independent tabs (`Shell 1`, `Shell 2`, etc.) with full environment loading (`$PATH`, colors, fonts).
- **Shell state preserved**: Closing or collapsing the notch preserves running processes without disconnecting.
- **Direct Notch Expansion**: Click the zoom button to smoothly expand the notch canvas to a large workspace (`1040 × 620`), and click again to shrink back.

### 📂 Holder (Desktop Environment & App Launcher)
- **Application Launcher**: Drag and drop applications (e.g. `Slack.app`, `Spotify.app`) directly into the notch for one-click launching.
- **Active Running Dot**: Shows real-time running status for pinned applications.
- **Embedded In-Notch PDF Reader**: Drop PDFs to view, scroll, and read them directly inside the notch using native PDFKit.
- **File Scratchpad**: Pin documents, folders, and reference files; drag them out into other applications, or copy their paths with one click.

### 🛡️ VPN & Action Widgets
- Fully configurable CLI and script-driven status widgets.
- Works out-of-the-box with **any** VPN (Tailscale, WireGuard, Windscribe, Mullvad, Cloudflare WARP, or native macOS VPNs).
- Live connection shield, real-time public IP and firewall badges, and one-click Connect / Disconnect / Toggle buttons.

### ⚙️ Hot-Reloaded TOML Configuration
- Configure tabs, shortcuts, appearance, accent colors, and custom widgets in `~/.config/notchdeck/config.toml`.
- Changes reload live using FSEvents without needing an app restart.

---

## ⌨️ Default Keyboard Shortcuts

| Shortcut | Action |
|:---------|:-------|
| `⌘ ⇧ Space` | Toggle Notch open / collapsed |
| `⌘ ⇧ N` | Open Notch & focus Quick Note |
| `⌘ ,` | In-notch Settings |
| `Esc` | Collapse notch / return from preview |

*(All shortcuts can be customized in `config.toml`)*

---

## 🚀 Installation & Setup

### Prerequisites
- macOS 14 (Sonoma) or macOS 15 (Sequoia)
- Xcode 16+ or Command Line Tools

### Building from Source

```bash
# 1. Clone the repository
git clone git@github.com:bogusdeck/knotch.git
cd knotch

# 2. Build Debug or Release using xcodebuild
xcodebuild -project NotchDeck/NotchDeck.xcodeproj \
  -scheme NotchDeck \
  -configuration Debug \
  -skipPackagePluginValidation build

# 3. Copy to /Applications
cp -R ~/Library/Developer/Xcode/DerivedData/NotchDeck-*/Build/Products/Debug/NotchDeck.app /Applications/

# 4. Launch NotchDeck
open /Applications/NotchDeck.app
```

---

## 🛠️ Configuration (`~/.config/notchdeck/config.toml`)

On first launch, NotchDeck generates a configuration file at:
```
~/.config/notchdeck/config.toml
```

### Complete Example Configuration

```toml
# NotchDeck Configuration
# Sourced from ~/.config/notchdeck/config.toml

[general]
screen = "builtin"          # "builtin" or display identifier
hover_to_peek = false       # Peek when hovering near the notch
hover_to_expand = false     # Fully expand on hover
peek_delay_ms = 150         # Delay before peek activates
launch_at_login = false     # Start automatically at login

[shortcuts]
toggle = "cmd+shift+space"  # Global toggle shortcut
quick_note = "cmd+shift+n"  # Quick note shortcut

[appearance]
theme = "dark"              # "dark", "light", or "system"
accent = "#7C5CFF"          # Accent color hex
expanded_width = 640        # Standard expanded notch width
expanded_height = 260       # Standard expanded notch height
cornerRadius = 8            # Notch corner curvature

[layout]
# Order of tabs in the notch header:
tabs = ["home", "notes", "terminal", "holder", "vpn"]
home = ["media", "clock", "calendar"]

# Example: VPN Action Widget (Tailscale / Windscribe / WireGuard)
[[widgets]]
id = "vpn-status"
type = "action"
title = "VPN"
icon = "lock.shield"
status_command = "if pgrep -x Windscribe > /dev/null; then /usr/local/bin/windscribe-cli status 2>/dev/null | grep -E 'Connect state|Public IP|Firewall'; else echo 'Connect state: Disconnected'; fi"
status_interval_s = 5
status_regex = "Connect state: Connected"

[[widgets.buttons]]
label = "Toggle"
command = "if /usr/local/bin/windscribe-cli status 2>/dev/null | grep -q 'Connected'; then /usr/local/bin/windscribe-cli disconnect; else /usr/local/bin/windscribe-cli connect; fi"

[[widgets.buttons]]
label = "Connect"
command = "/usr/local/bin/windscribe-cli connect"

[[widgets.buttons]]
label = "Disconnect"
command = "/usr/local/bin/windscribe-cli disconnect"
```

---

## 🧪 Testing

Run the full automated test suite (50 unit tests across config, widgets, terminal, and state):

```bash
xcodebuild -project NotchDeck/NotchDeck.xcodeproj \
  -scheme NotchDeck \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation test
```

---

## 📂 Project Structure

```
NotchDeck/
├── App/                  # App entry point, AppDelegate, global shortcuts
├── Config/               # TOML parser, serializer, FSEvents watcher, AppConfig
├── Settings/             # In-notch Settings view & categories
├── Tests/                # 50 unit tests covering core subsystems
├── Widgets/
│   ├── Action/           # Status polling and button action runner (VPN, scripts)
│   ├── Core/             # NotchWidget protocol & WidgetRegistry
│   ├── Holder/           # Desktop environment: app launcher & embedded PDF reader
│   ├── Media/            # Media player info & playback controls
│   ├── Notes/            # Scratchpad notes manager and UI
│   ├── Shelf/            # Drag & drop file shelf
│   ├── Shell/            # Scheduled shell script runner widgets
│   ├── Terminal/         # Multi-session zsh terminal via SwiftTerm
│   └── Web/              # Embedded web widgets via WKWebView & JS bridge
└── Window/               # NotchPanel, NotchShape, NotchViewModel, ExpandedView
```

---

## 📄 License

Licensed under the [MIT License](LICENSE).
