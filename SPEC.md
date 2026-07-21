# Spec: Onus — floating daily task & goals widget for macOS

Build a native macOS app called **Onus** in Swift + SwiftUI (AppKit where needed for window management). The app is a small always-on-top widget on the desktop — I want it bottom-right — that displays my daily tasks and goals at all times. The name reflects the product's personality: obligations stay visible and follow you until they're done.

## How to read this spec

- **Requirements** describe behavior that must work as stated: what data exists, how it changes over time, and the core window behavior. Don't deviate from these without asking.
- Anything describing **visual appearance, sizing, wording, icon choices, or exact interaction gestures is a suggestion**, even when phrased concretely. You have design freedom there — use good judgment, keep everything minimal, and propose alternatives when you see a better way. Prefer showing me a running version and iterating over debating in the abstract.

## Product summary (requirements)

A minimal, always-visible floating panel with three kinds of content:

1. **Every day** — recurring tasks I do every day. A plain list — these are reminders, not checkable items. No completion state.
2. **Dated tasks** — one-off tasks assigned to a specific date, with completion checkboxes. The widget groups them into one section per date, in chronological order, and shows **all** upcoming dates that have tasks. The current day's section is labeled "Today" (friendly labels like "Tomorrow" for other dates are a nice touch — your call on format). Checking a task strikes it through but keeps it visible until the next rollover — the day's progress stays on screen. Only today and future dates can exist (see rollover).
3. **Goals** — ongoing items with no date. A plain list. A goal stays until I explicitly complete it, at which point it moves to history.

The widget's resting state shows only these lists. Everything else — adding, editing, deleting, history, settings — is hidden behind clicks. Simplicity is the top priority: no visible chrome beyond one or two small, subtle controls (an "add" affordance and a "history" affordance).

## Window behavior (requirements)

- The widget must float above all normal windows, appear on every Space, and remain visible over fullscreen apps. In AppKit terms: an `NSPanel` with an elevated window level (e.g. `.statusBar`) and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`.
- Interacting with the widget must not steal focus from the app I'm working in. Use a non-activating panel (`.nonactivatingPanel`); note you'll need to override `canBecomeKey` to return `true` on the panel so the add/edit text field can receive typing when needed — but the panel should only take key status during text entry.
- Anchors to the bottom-right corner of the screen by default (margin size: your call). Handle display/resolution changes gracefully. Draggable is fine but not required.
- No title bar or standard window chrome. Rounded, compact, adapts to light and dark mode.
- Runs as an accessory app (`LSUIElement = true`): no Dock icon. **Include a menu bar status item** — with no Dock icon it's the only sane place for Quit, the launch-at-login toggle, and any other rare actions. Keep its menu tiny.

## Visual style (suggestion — decide during development)

Don't lock in a look now. Start with a clean adaptive placeholder (e.g. `NSVisualEffectView` with a system material for a frosted translucent feel) and keep the styling isolated in one place so we can iterate on the final design against the running app. Must build and run on all supported macOS versions — no version-gated visual APIs without an `if #available` fallback.

## Layout (structure is a requirement; specifics are suggestions)

Top to bottom: the "Every day" list, then one section per date (chronological), then "Goals", with small muted section labels and subtle dividers between groups. Completed dated tasks render struck-through/muted. Empty groups disappear entirely rather than showing an empty header. Somewhere unobtrusive: the add control and the history control (make the two visually distinct from each other). Width in the ~250px range feels right, height grows with content — but tune all of this by eye.

All upcoming dates with tasks are shown — no truncation of future sections. Instead, cap the widget's height (a sensible fraction of the screen height — tune by eye) and scroll the content inside when it exceeds the cap, keeping the panel anchored in its corner. The scroll should be quiet: no visible scrollbar chrome unless scrolling.

## Add flow (behavior is a requirement; presentation is a suggestion)

- Never show input fields in the resting state. Activating the add control reveals an input view — in place within the panel is preferred over a separate window.
- The input needs: text, a choice between the three kinds (Every day / Dated / Goal; default Dated), and for dated tasks a date choice defaulting to today. Keep the date control compact; quick picks for today/tomorrow plus a way to pick any future date works well.
- **Past dates must not be selectable** — a task can only target today or later.
- Keyboard-friendly: Return commits, Escape cancels. Afterward, return to the resting state.

## Edit / delete / complete (requirements)

- Each row needs a low-visibility way to Edit and Delete (right-click context menu is the obvious fit, but your call). Nothing visible until invoked.
- Editing a dated task must allow changing its date (moving it to another day).
- Goals need an explicit Complete action (e.g. in the same context menu). Completing a goal removes it from the widget and records it in history with the completion date. This is the only way a goal ends, other than deleting it.
- Deleting an "Every day" item removes the recurring task entirely.
- Deletions do NOT go to history — history records accomplishments, not removals.

## History (requirements)

- Completed items are never silently discarded; they accumulate in a history the user can browse.
- A history control on the widget opens the history in a separate, ordinary window (normal `NSWindow`, can take focus — only the floating widget is a non-activating panel).
- The window lists completed tasks and goals, newest first, grouped by completion date, with tasks and goals distinguishable. Read-only, except: delete individual entries and clear all (tucked away, not prominent).
- The history window never affects the widget's state.

## Data & persistence (requirements; the schema shown is illustrative)

- All data lives locally — no accounts, no network, no sync. A single JSON file in `~/Library/Application Support/Onus/` is the suggested shape; any equivalent local persistence is fine as long as data survives quit/relaunch and a corrupt/missing file starts fresh without crashing.
- Persist promptly on every mutation (debounced writes are fine).

Illustrative schema:

```json
{
  "everyDay": [ { "id": "uuid", "title": "Morning workout" } ],
  "tasks":    [ { "id": "uuid", "title": "Call the bank", "date": "2026-07-20", "done": false, "completedOn": null } ],
  "goals":    [ { "id": "uuid", "title": "Run a 10K" } ],
  "history":  [ { "id": "uuid", "title": "Finish Swift course", "kind": "goal", "completedOn": "2026-07-15" } ]
}
```

- Record the actual completion date when a task is checked (clear it if unchecked). Archive uses this real date, not the task's scheduled date.

## Daily rollover (requirements)

At local midnight — and on launch/wake when the date has changed, since the Mac may be asleep or off at midnight — reconcile dates:

- Dated tasks that are **done** and whose date has passed move to `history` (kind "task", with their recorded completion date).
- Dated tasks that are **not done** and whose date has passed **roll over: their date becomes the current day**, unchecked. A skipped task lands in "Today" and keeps following me until completed — intentional; the app enforces, it doesn't forgive. Rolling to the current day (not date + 1) means a task missed while the Mac was off for a week still appears in Today, and the invariant "no past dates exist" always holds.
- Future-dated tasks, "Every day" items, and goals are untouched.
- Implementation: a timer scheduled for the next midnight plus `NSWorkspace` wake/launch checks.

## Snooze (behavior is a requirement; bindings and durations are suggestions)

- A global hotkey hides the widget **completely** for a snooze period, then it returns automatically. While snoozed the panel must be ordered out entirely — not transparent, not click-interceptable; it does not exist on screen.
- Use the `KeyboardShortcuts` Swift package (sindresorhus) — it's actively maintained, sandbox-safe, and needs no special permissions. Per the package's own guidance, don't hard-code a shortcut: expose a small recorder so I set my own. A sensible pre-filled default is fine. The recorder lives in a small Settings window opened from the status-item menu ("Snooze Shortcut…"), not inline in the menu itself — an open menu's event tracking swallows modifier keys, so combos like ⌘H can't be recorded from within the menu.
- Default snooze duration ~10 minutes. The hotkey acts as a toggle: pressing it while snoozed brings the widget back immediately (rather than extending the snooze).
- An optional small snooze control on the widget itself is nice but not required.

## Launch at login (requirement)

- The app registers itself to launch at login (`SMAppService.mainApp.register()`, macOS 13+). On by default from first launch, with a toggle in the status-item menu.

## Non-goals

- No notifications, sounds, or badges. No cloud sync or accounts. No due times, priorities, tags, or subtasks. No settings window — the status-item menu covers the few preferences that exist.

## Tech notes

- Target macOS 13+ (Ventura or later). Avoid version-gated APIs; where a nicer API exists only on newer versions, use `if #available` with a graceful fallback.
- SwiftUI for views, hosted in the NSPanel via `NSHostingView`; AppKit for the panel/window plumbing.
- Only external dependency: `KeyboardShortcuts`.
- Suggested structure (not binding): `App` (lifecycle, panel setup, hotkey, rollover timer), `Store` (observable data + persistence), `WidgetView`, `AddItemView`, `HistoryView`, small row subviews.

## Acceptance checklist

- [ ] Widget visible bottom-right over normal windows, other Spaces, and fullscreen apps
- [ ] Checking a task does not deactivate the app I'm working in; typing works in the add view
- [ ] Add flow: hidden until invoked; three kinds; dated tasks target today or any future date, never the past
- [ ] Per-date sections render chronologically; current day labeled "Today"; all future dates with tasks are visible
- [ ] Checked tasks stay visible struck-through until the next rollover, then land in history
- [ ] Widget height caps at a reasonable maximum and scrolls internally when content overflows
- [ ] After a date change (midnight, wake, or launch): completed past tasks are in history, unfinished ones sit in "Today" unchecked; no past-date sections exist
- [ ] Goals persist until explicitly completed; completing moves them to history with the date
- [ ] History window opens separately, grouped by completion date, and never disturbs the widget
- [ ] Snooze hotkey removes the widget entirely and it returns on its own; hotkey is user-recordable
- [ ] Launches at login by default; toggle works; Quit is reachable from the status item
- [ ] Data survives quit/relaunch; corrupt/missing data file doesn't crash
- [ ] Builds and runs on macOS 13+; light and dark mode both look right
