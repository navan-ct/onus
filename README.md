# Onus

A minimal, always-on-top floating widget for macOS that keeps your daily tasks and goals visible at all times. It anchors to the bottom-right of the screen, floats above every window, appears on all Spaces, and stays visible over fullscreen apps — obligations stay in view until they're done.

See [SPEC.md](SPEC.md) for the full product specification.

## Features

- **Every day** — recurring reminders shown as a plain list (no completion state).
- **Dated tasks** — one-off tasks grouped by date with checkboxes. Today's section is labeled "Today"; all future dates with tasks are shown.
- **Goals** — ongoing items with no date; stay until explicitly completed.
- **Daily rollover** — at midnight (and on wake/launch after a date change) completed past tasks move to history and unfinished ones roll into Today.
- **History** — completed tasks and goals accumulate in a separate window, grouped by completion date.
- **Snooze** — a user-recordable global hotkey hides the widget for ~10 minutes, then it returns automatically.
- **Menu bar item** — the app runs with no Dock icon; Quit, settings, and the launch-at-login toggle live in the status-item menu.
- **Local-only** — all data lives in a single JSON file under `~/Library/Application Support/Onus/`. No accounts, no network, no sync.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode with the macOS SDK and Command Line Tools (needed for `xcodebuild`)

The only external dependency is [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (Swift Package Manager), resolved automatically by the build.

## Project layout

```
Onus/
  Onus.xcodeproj/        Xcode project
  Onus/                  Swift sources
    OnusApp.swift        App entry point
    AppDelegate.swift    Lifecycle, panel setup, rollover timer, hotkey
    AppController.swift
    FloatingPanel.swift  Non-activating always-on-top NSPanel
    Store.swift          Observable data model + JSON persistence
    Models.swift
    WidgetView.swift     Main widget UI
    AddItemView.swift    In-place add/edit flow
    HistoryView.swift    History window
    SettingsView.swift   Snooze-shortcut recorder
    Theme.swift          Isolated styling
    Shortcuts.swift      KeyboardShortcuts definitions
    VisualEffectView.swift
    DayFormat.swift      Date labels ("Today", "Tomorrow", …)
SPEC.md
```

## Build and run from the command line

You do **not** need to open Xcode. All commands are run from the repository root.

### Build

```sh
xcodebuild \
  -project Onus/Onus.xcodeproj \
  -scheme Onus \
  -configuration Debug \
  -derivedDataPath Onus/build/dd \
  build
```

Use `-configuration Release` for an optimized build. The compiled app lands at:

```
Onus/build/dd/Build/Products/Debug/Onus.app
```

(`build/` is gitignored.)

### Run

```sh
open Onus/build/dd/Build/Products/Debug/Onus.app
```

Onus is an accessory app (`LSUIElement`), so it has **no Dock icon**. On launch, the widget appears bottom-right and a status item appears in the menu bar — use that menu for settings and Quit.

To relaunch a fresh build, quit any running instance first:

```sh
pkill -x Onus 2>/dev/null; open Onus/build/dd/Build/Products/Debug/Onus.app
```

### One-liner: build then run

```sh
xcodebuild -project Onus/Onus.xcodeproj -scheme Onus -configuration Debug \
  -derivedDataPath Onus/build/dd build \
&& pkill -x Onus 2>/dev/null; \
open Onus/build/dd/Build/Products/Debug/Onus.app
```

### Clean

```sh
xcodebuild -project Onus/Onus.xcodeproj -scheme Onus clean
rm -rf Onus/build
```

### List schemes / inspect settings

```sh
xcodebuild -list -project Onus/Onus.xcodeproj
xcodebuild -showBuildSettings -project Onus/Onus.xcodeproj -scheme Onus
```

## Notes

- **Bundle identifier:** `com.navaneethct.Onus` · **Version:** 1.0 · **Deployment target:** macOS 13.0
- **Code signing:** the project uses automatic signing with an ad-hoc identity (`CODE_SIGN_IDENTITY = -`), so a local `xcodebuild` build works without a developer account or team.
- **Launch at login** is on by default from first launch (`SMAppService`); toggle it from the status-item menu.
- **Data location:** `~/Library/Application Support/Onus/`. A missing or corrupt data file starts fresh without crashing.
