import AppKit
import SwiftUI
import ServiceManagement
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = Store()
    private let appController = AppController()

    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private var historyWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var rolloverTimer: Timer?
    private var snoozeTimer: Timer?
    private var isSnoozed = false

    /// Bottom-left corner the panel keeps fixed as its content grows/shrinks.
    private var anchorOrigin: NSPoint?

    private let panelMargin: CGFloat = 16
    private let snoozeDuration: TimeInterval = 10 * 60

    private let loginItemDefaultKey = "didSetDefaultLoginItem"
    private let panelOriginKey = "panelOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaultLoginItemOnce()
        setupPanel()
        setupStatusItem()
        setupShortcut()
        setupRollover()
        store.rollover()
        positionPanel()
        panel.orderFrontRegardless()
    }

    // MARK: Panel

    private func setupPanel() {
        appController.requestKey = { [weak self] in self?.panel.makeKeyAndOrderFront(nil) }
        appController.resignKey = { [weak self] in self?.panel.resignKey() }
        appController.openHistory = { [weak self] in self?.openHistoryWindow() }

        let root = WidgetView()
            .environmentObject(store)
            .environmentObject(appController)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = .preferredContentSize

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 200))
        panel.contentViewController = hosting

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidResize),
            name: NSWindow.didResizeNotification, object: panel)
        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification, object: panel)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        updateMaxContentHeight()
    }

    private func updateMaxContentHeight() {
        let screen = panel?.screen ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            appController.maxContentHeight = frame.height * 0.7
        }
    }

    /// Places the panel at its saved origin, or the bottom-right default the first time.
    private func positionPanel() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = panel.frame.size
        let origin: NSPoint
        if let saved = loadSavedOrigin() {
            origin = clamp(saved, size: size, in: area)
        } else {
            origin = NSPoint(x: area.maxX - size.width - panelMargin,
                             y: area.minY + panelMargin)
        }
        anchorOrigin = origin
        panel.setFrameOrigin(origin)
    }

    @objc private func panelDidResize() {
        guard let anchorOrigin else { return }
        panel.setFrameOrigin(anchorOrigin)
    }

    @objc private func panelDidMove() {
        let origin = panel.frame.origin
        guard anchorOrigin.map({ $0 != origin }) ?? true else { return }
        anchorOrigin = origin
        saveOrigin(origin)
    }

    @objc private func screenParametersChanged() {
        updateMaxContentHeight()
        positionPanel()
    }

    private func clamp(_ origin: NSPoint, size: NSSize, in area: NSRect) -> NSPoint {
        let x = min(max(origin.x, area.minX), max(area.minX, area.maxX - size.width))
        let y = min(max(origin.y, area.minY), max(area.minY, area.maxY - size.height))
        return NSPoint(x: x, y: y)
    }

    private func saveOrigin(_ p: NSPoint) {
        UserDefaults.standard.set(["x": Double(p.x), "y": Double(p.y)], forKey: panelOriginKey)
    }

    private func loadSavedOrigin() -> NSPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: panelOriginKey),
              let x = d["x"] as? Double, let y = d["y"] as? Double else { return nil }
        return NSPoint(x: x, y: y)
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Onus")

        let menu = NSMenu()
        menu.delegate = self

        let shortcutItem = NSMenuItem(
            title: "Snooze Shortcut…",
            action: #selector(openSettings),
            keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: "")
        loginItem.target = self
        loginItem.tag = 1
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Onus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Onus Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let loginItem = menu.item(withTag: 1) {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
    }

    // MARK: Launch at login

    private func registerDefaultLoginItemOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: loginItemDefaultKey) else { return }
        try? SMAppService.mainApp.register()
        defaults.set(true, forKey: loginItemDefaultKey)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    // MARK: Snooze

    private func setupShortcut() {
        KeyboardShortcuts.onKeyUp(for: .toggleSnooze) { [weak self] in
            self?.toggleSnooze()
        }
    }

    private func toggleSnooze() {
        if isSnoozed {
            endSnooze()
        } else {
            isSnoozed = true
            panel.orderOut(nil)
            snoozeTimer?.invalidate()
            let timer = Timer(timeInterval: snoozeDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.endSnooze() }
            }
            RunLoop.main.add(timer, forMode: .common)
            snoozeTimer = timer
        }
    }

    private func endSnooze() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        isSnoozed = false
        store.rollover()
        positionPanel()
        panel.orderFrontRegardless()
    }

    // MARK: Rollover

    private func setupRollover() {
        scheduleMidnightRollover()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func didWake() {
        store.rollover()
        scheduleMidnightRollover()
    }

    private func scheduleMidnightRollover() {
        rolloverTimer?.invalidate()
        let calendar = Calendar.current
        guard let next = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime) else { return }
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.store.rollover()
                self?.scheduleMidnightRollover()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        rolloverTimer = timer
    }

    // MARK: History window

    private func openHistoryWindow() {
        if historyWindow == nil {
            let hosting = NSHostingController(rootView: HistoryView().environmentObject(store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "History"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 360, height: 460))
            window.isReleasedWhenClosed = false
            window.center()
            historyWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        historyWindow?.makeKeyAndOrderFront(nil)
    }
}
