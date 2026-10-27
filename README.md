# Knotch

<div align="center">

**The Intelligent Dynamic Island & Productivity Command Center for macOS**  
*Living seamlessly inside your MacBook notch.*

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B%20(Sonoma%20%7C%20Sequoia)-blue.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Xcode 16](https://img.shields.io/badge/Xcode-16%2B-blueviolet.svg?style=flat-square&logo=xcode)](https://developer.apple.com/xcode/)
[![Tests](https://img.shields.io/badge/Tests-52%20passing-brightgreen.svg?style=flat-square)](NotchDeck/Tests/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-black.svg?style=flat-square)]()

</div>

---

## 🌟 Overview

**Knotch** transforms the physical camera notch of your MacBook into an interactive, fluid command center. Inspired by tactile hardware integration, Knotch expands beyond ordinary menu bar utilities by morphing naturally around the display bezel.

Whether you need to monitor unread WhatsApp messages via a subtle glowing perimeter, switch between work and personal profiles, talk to multiple AI models in one place, run background terminal sessions without interrupting your flow, or drag and drop files and PDFs into an in-notch workspace, **Knotch** keeps everything right at your fingertips.

Everything is powered by a human-friendly `~/.config/knotch/config.toml` file with live FSEvents hot-reloading.

---

## ✨ Key Features

### 🟢 Ambient Notch Notification Ring & WhatsApp Sync
- **Hardware-Contoured Stroke**: Unread notifications from WhatsApp and connected services illuminate the exact perimeter of your MacBook's camera notch with an emerald glow.
- **Closed & Open States**: Subtle, distraction-free boundary indicator when collapsed; expanded badge details when engaged.
- **Background Persistence**: Native WebKit session isolation ensures you never miss a critical ping while consuming zero unnecessary resources.

### 💼 Work Mode vs. Personal Mode
- **Instant Profile Switcher**: Toggle between focused **Work** and relaxed **Personal** environments with a single click in the notch header.
- **Customized Tab Layouts**: Keep work tools (Slack, PRs, Terminal, Notes) separated from personal apps (Music, Social, AI Hub) while pinning universal essentials like WhatsApp across both.

### 🤖 Multi-AI Assistant Hub (AI Deck)
- **All-in-One LLM Workspace**: Instant tab switching between **ChatGPT**, **Claude**, **Gemini**, and **DeepSeek**.
- **State Preservation**: Keeps your ongoing prompts and context preserved across model switches without reloading pages.

### 🖥️ Persistent Multi-Session Zsh Terminal
- **SwiftTerm Native Integration**: High-performance, fully rendered terminal sessions directly inside the notch canvas.
- **Multi-Tab Multiplexing**: Open independent shells (`Shell 1`, `Shell 2`, etc.) with your customized zsh plugins, themes, and `$PATH`.
- **Canvas Zoom (`1040 × 620`)**: Expand the notch canvas into an expansive development workstation with a single click, and snap back when you're finished.
- **Zero Process Disruption**: Closing or collapsing the notch preserves running processes, servers, and build tasks indefinitely.

### 📝 Markdown Notes & Interactive Checklists
- **Markdown Scratchpad**: Quick note-taking with instant search and GitHub-flavored Markdown rendering.
- **Clickable Checklist Todos**: Interactive `[ ]` and `[x]` checkboxes with filter tabs (**All**, **Notes**, **Todos**).
- **Global Quick-Note Hotkey**: Hit `⌘ ⇧ N` to immediately wake the notch and focus your note cursor.
- **Local Flat-File Storage**: Stored cleanly in plain markdown files on your disk.

### 📂 Desktop Holder & Embedded PDF Reader
- **App Launcher**: Drag applications (e.g. `Slack.app`, `Ghostty.app`) directly into the notch for swift one-click launches.
- **Live Running Indicators**: Real-time status dots illuminate beneath active applications.
- **In-Notch PDFKit Reader**: Drop any PDF directly onto the notch to view, scroll, and preview documents natively.
- **Drag & Drop File Shelf**: Temporarily pin files and folders to the notch and drag them directly into external apps, emails, or chat windows.

### 🛡️ VPN & Status Action Widgets
- **Script-Driven Automation**: Execute any shell command, ping service, or polling script with customizable intervals.
- **Universal VPN Compatibility**: Works out of the box with Tailscale, WireGuard, Windscribe, Mullvad, Cloudflare WARP, and native macOS VPN connections.
- **One-Click Actions**: Trigger Connect, Disconnect, or dynamic Toggle routines with live state regex matching.

### ⚙️ Live Hot-Reloaded TOML Configuration
- Customizations live in `~/.config/knotch/config.toml` (with seamless legacy support for `~/.config/notchdeck/`).
- Powered by native macOS `FSEvents` for zero-latency live reloading without restarting the application.

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Description |
| :--- | :--- |
| `⌘ ⇧ Space` | Toggle Knotch expanded / collapsed |
| `⌘ ⇧ N` | Open Knotch and immediately focus Quick Notes |
| `⌘ ,` | Open Knotch Preferences & Settings |
| `Esc` | Collapse notch / exit expanded zoom preview |

*(All keyboard shortcuts can be customized in `config.toml`)*

---

## 💻 Command Line Interface (CLI)

Knotch comes with a command-line interface (`knotch`) to control, manage, and inspect the application directly from your terminal or shell scripts.

### Quick Start

```bash
# Start Knotch in the background
knotch start

# Check running status, PID, memory, uptime, and active mode
knotch status

# Toggle the notch canvas open / closed
knotch

# Switch to a specific tab
knotch tab terminal
knotch tab notes
knotch tab whatsapp

# Toggle or switch between Work and Personal mode
knotch mode work
knotch mode personal

# Manage configuration
knotch config edit
knotch config reload
knotch config test

# Stop / quit Knotch gracefully
knotch stop
```

### All CLI Commands

| Command | Description |
| :--- | :--- |
| `knotch` | Toggle notch canvas (or starts Knotch if stopped) |
| `knotch start` | Launch Knotch background application |
| `knotch stop` / `quit` | Gracefully quit and terminate Knotch |
| `knotch restart` | Restart Knotch application |
| `knotch status` | Display status (PID, memory, CPU, uptime, active mode, config) |
| `knotch toggle` | Toggle notch expanded / collapsed |
| `knotch expand` / `open` | Expand the notch canvas |
| `knotch collapse` / `close` | Collapse notch back into the MacBook bezel |
| `knotch tab <name>` | Switch active tab (`home`, `terminal`, `notes`, `holder`, `whatsapp`, `ai`, `vpn`) |
| `knotch notes` | Expand notch and immediately focus Quick Notes |
| `knotch mode [work\|personal\|toggle]` | Switch or toggle between Work and Personal modes |
| `knotch settings` | Open Knotch Preferences & Settings |
| `knotch config [edit\|reload\|path\|cat\|test]` | Manage and test `~/.config/knotch/config.toml` |
| `knotch logs` | Stream live application logs from unified logging |
| `knotch install` | Symlink `knotch` CLI into your `$PATH` (`/opt/homebrew/bin` or `~/.local/bin`) |
| `knotch version` | Print Knotch version |
| `knotch help` | Display full CLI help reference |

---

## 🚀 Installation

### Option 1: Homebrew (Recommended)

```bash
brew install --cask knotch
```

### Option 2: Pre-Built Binary (GitHub Releases)

Download the latest `.dmg` or `.zip` release directly from [GitHub Releases](https://github.com/bogusdeck/knotch/releases):

1. Download `Knotch.dmg`.
2. Open the disk image and drag `Knotch.app` to your `/Applications` folder.
3. Launch `Knotch.app`. Grant Accessibility permissions if prompted for global hotkeys.

### Option 3: Building from Source

**Requirements:**
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 16.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (optional, if modifying `project.yml`)

```bash
# 1. Clone the repository
git clone git@github.com:bogusdeck/knotch.git
cd knotch

# 2. Build Release binary using xcodebuild
xcodebuild -project NotchDeck/Knotch.xcodeproj \
  -scheme Knotch \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation build

# 3. Copy application to /Applications
cp -R build/Build/Products/Release/Knotch.app /Applications/

# 4. Launch Knotch
open /Applications/Knotch.app
```

---

## 🛠️ Configuration (`config.toml`)

Knotch loads its configuration from:
```bash
~/.config/knotch/config.toml
```

If migrating from an earlier version, `~/.config/notchdeck/config.toml` is automatically detected and respected.

### Complete Example Configuration

```toml
# ==============================================================================
# Knotch Configuration
# ~/.config/knotch/config.toml
# ==============================================================================

[general]
screen = "builtin"          # "builtin" or specific display identifier
hover_to_peek = false       # Peek when hovering near the camera notch
hover_to_expand = false     # Fully expand on hover
peek_delay_ms = 150         # Delay before peek activates
launch_at_login = true      # Launch Knotch automatically at login

[shortcuts]
toggle = "cmd+shift+space"  # Global notch toggle shortcut
quick_note = "cmd+shift+n"  # Quick note creation shortcut

[appearance]
theme = "dark"              # "dark", "light", or "system"
accent = "#2ECC71"          # Ambient accent color (Emerald Green)
expanded_width = 680        # Standard expanded width in points
expanded_height = 280       # Standard expanded height in points
cornerRadius = 10           # Smooth corner curvature

[layout]
mode = "work"               # Default active mode: "work" or "personal"

# Tabs active in Work Mode:
work_tabs = ["terminal", "notes", "holder", "whatsapp", "vpn"]

# Tabs active in Personal Mode:
personal_tabs = ["home", "notes", "ai_deck", "whatsapp", "holder"]

# Home canvas widget order:
home = ["media", "clock", "calendar"]

# ------------------------------------------------------------------------------
# Action Widgets (Example: VPN & Network Monitor)
# ------------------------------------------------------------------------------
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

## 🧪 Testing & Verification

Knotch maintains a robust automated test suite with **52 comprehensive unit tests** verifying config parsing, state transitions, widget dispatching, and terminal multiplexing.

To execute the test suite:

```bash
xcodebuild test \
  -project NotchDeck/Knotch.xcodeproj \
  -scheme Knotch \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation
```

---

## 📂 Architecture & Directory Layout

```
knotch/
├── .github/
│   └── workflows/        # Automated CI build and release pipelines
├── NotchDeck/
│   ├── App/              # App lifecycle, NSApplicationDelegate, global hotkeys
│   ├── Config/           # TOML parser, FSEvents watcher, configuration models
│   ├── Settings/         # In-notch preferences, themes, and configuration UI
│   ├── Tests/            # Unit & integration test suites (52 passing)
│   ├── Widgets/
│   │   ├── Action/       # Custom script runner with status polling & buttons
│   │   ├── Core/         # NotchWidget protocol & WidgetRegistry
│   │   ├── Holder/       # Desktop app launcher, file shelf & PDFKit viewer
│   │   ├── Media/        # Now Playing media controls & metadata
│   │   ├── Notes/        # Markdown notes & interactive todo checklists
│   │   ├── Shelf/        # Drag-and-drop file staging shelf
│   │   ├── Shell/        # Scheduled shell runner widgets
│   │   ├── Terminal/     # Multi-session zsh terminal via SwiftTerm
│   │   └── Web/          # WhatsApp, AI Deck & isolated WebKit integrations
│   ├── Window/           # NotchPanel, fluid NotchShape geometry & ViewModels
│   ├── Knotch.xcodeproj  # Generated Xcode project
│   └── project.yml       # XcodeGen project specification
├── README.md             # Project documentation
└── LICENSE               # MIT License
```

---

## 🤝 Contributing

Contributions, bug reports, and suggestions are warmly welcome!

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'feat: add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

Please ensure all unit tests pass before submitting your PR.

---

## 📄 License

Knotch is open-source software licensed under the [MIT License](LICENSE).
