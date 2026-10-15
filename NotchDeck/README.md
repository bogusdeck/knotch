# NotchDeck

> An open-source, fully customizable macOS notch productivity hub — written in Swift 6 / SwiftUI.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/sonoma/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build](https://github.com/notchdeck/notchdeck/actions/workflows/build.yml/badge.svg)](https://github.com/notchdeck/notchdeck/actions)

NotchDeck turns the MacBook notch into a live productivity hub: quick notes, a file shelf, now-playing media info, embedded terminal sessions, shell-command widgets, and user-crafted web widgets — all driven by a single `~/.config/notchdeck/config.toml` file.

---

## Features (roadmap)

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Notch window · collapsed / peek / expanded · toggle shortcut | ✅ |
| 2 | TOML config · hot-reload · error banner · Settings window | ✅ |
| 3 | Quick notes · file shelf | ✅ |
| 4 | Media widget · action & shell widgets | 🔜 |
| 5 | Embedded terminal · web widget bridge · Sparkle auto-updates | 🔜 |

---

## Installation

> **Requires macOS 14 (Sonoma) or later.**

### From source

```bash
# 1. Clone
git clone https://github.com/notchdeck/notchdeck.git
cd notchdeck/NotchDeck

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode and run
open NotchDeck.xcodeproj
```

### Dependencies (managed by SPM)

| Package | Purpose |
|---------|---------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkeys |
| [TOMLKit](https://github.com/LebJe/TOMLKit) | Config file parsing |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Embedded terminal |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Auto-updates |

---

## Configuration

NotchDeck is configured entirely through `~/.config/notchdeck/config.toml`.  
The file is created with commented defaults on first launch.

See [docs/CONFIG.md](docs/CONFIG.md) for a full reference.

### Quick example

```toml
[general]
hover_to_peek = true
peek_delay_ms = 150

[appearance]
accent = "#7C5CFF"
expanded_width = 640
expanded_height = 260

[shortcuts]
toggle = "cmd+shift+space"
quick_note = "cmd+shift+n"
```

---

## Architecture

```
NotchDeck/
  App/            # @main entry, AppDelegate, keyboard shortcut names
  Window/         # NotchPanel · NotchPanelController · state machine · views
  Config/         # AppConfig models · ConfigManager · (Phase 2) FSEvents watcher
  Widgets/
    Core/         # NotchWidget protocol · WidgetRegistry
    Notes/        # (Phase 3)
    Shelf/        # (Phase 3)
    Media/        # (Phase 4)
    Terminal/     # (Phase 5)
    Action/       # (Phase 4)
    Shell/        # (Phase 4)
    Web/          # (Phase 5)
  Settings/       # SwiftUI settings window (Phase 5)
  Resources/      # default config.toml, assets
docs/             # CONFIG.md · WIDGETS.md
examples/         # example configs · example web widgets
Tests/            # unit tests
```

### Notch window

- `NotchPanel` — a borderless, non-activating `NSPanel` at `statusBar + 1` level.
- `NotchPanelController` — drives state transitions, positioning, hover tracking, and click-outside-to-collapse.
- `NotchShape` — an animatable SwiftUI `Shape` that morphs between the collapsed notch shape and the rounded-bottom expanded dashboard.
- Three states: **collapsed** (invisible, matches bezel) → **peek** (hover, quick-glance) → **expanded** (full dashboard).

---

## Keyboard shortcuts

| Action | Default |
|--------|---------|
| Toggle expanded notch | `⌘ ⇧ Space` |
| Quick Note | `⌘ ⇧ N` |

Shortcuts are configurable in `config.toml` (Phase 2).

---

## Contributing

PRs welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) (coming soon) and open an issue before starting large features.

---

## License

MIT — see [LICENSE](LICENSE).
