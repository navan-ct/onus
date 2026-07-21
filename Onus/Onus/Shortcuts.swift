import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSnooze = Self("toggleSnooze", default: .init(.o, modifiers: [.command, .control]))
}
