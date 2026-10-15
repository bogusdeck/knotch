# Widget Development Guide

NotchDeck supports four user-configurable widget types and a Swift protocol for native extensions.

---

## Built-in widget types

| Type | Description |
|------|-------------|
| `action` | Runs shell commands, polls a status command, shows buttons |
| `shell` | Displays command output on a refresh interval |
| `terminal` | Embedded terminal session (SwiftTerm) |
| `web` | Transparent WebView loading your own HTML/JS |

See [CONFIG.md](CONFIG.md) for full configuration reference.

---

## Web widgets

Web widgets live in `~/.config/notchdeck/widgets/<name>/` and must contain `index.html`.

### Minimal example

```
~/.config/notchdeck/widgets/crypto/
  index.html
  widget.js
  style.css
```

`config.toml`:
```toml
[[widgets]]
id = "crypto"
type = "web"
path = "widgets/crypto"
allow_shell = false
```

`index.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div id="price">Loading…</div>
  <script src="widget.js"></script>
</body>
</html>
```

`widget.js`:
```js
async function fetchPrice() {
  const res = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd");
  const data = await res.json();
  document.getElementById("price").textContent = `BTC $${data.bitcoin.usd}`;
}
fetchPrice();
setInterval(fetchPrice, 60_000);
```

### JS Bridge (`window.notch`)

Available in every web widget, regardless of `allow_shell`.

```typescript
interface NotchBridge {
  /** Widget's TOML config table (read-only) */
  config: Record<string, unknown>;

  /** Persistent storage scoped to this widget */
  storage: {
    get(key: string): string | null;
    set(key: string, value: string): void;
    remove(key: string): void;
  };

  /** Show a macOS user notification */
  notify(text: string): void;

  /**
   * Run a shell command.
   * REQUIRES allow_shell = true in config.toml.
   * Returns stdout as a string.
   */
  run(command: string): Promise<string>;
}
```

> [!CAUTION]
> `window.notch.run()` executes arbitrary shell commands as your user. Only enable `allow_shell = true` for widgets you wrote yourself or fully trust.

---

## Native Swift widgets

Implement the `NotchWidget` protocol (in `Widgets/Core/NotchWidget.swift`) and register via `WidgetRegistry`:

```swift
struct MyWidget: NotchWidget {
    let id = "my-widget"
    let title = "My Widget"

    func compactView() -> AnyView {
        AnyView(Text("Compact").font(.caption))
    }

    func expandedView() -> AnyView {
        AnyView(
            VStack {
                Text("My Widget")
                    .font(.headline)
                // … your content
            }
        )
    }
}

// In AppDelegate or a setup function:
registry.register(MyWidget())
```

Views are rendered inside the NotchDeck panel — they should use:
- Dark background assumed; use white/light text and system materials for contrast
- `.animation(.spring(…), value: …)` for smooth transitions
- Avoid blocking the main thread; use `async`/`await` for network or shell calls
