import SwiftUI
import Combine

/// Bridges SwiftUI widget views to AppKit-level actions owned by the AppDelegate.
@MainActor
final class AppController: ObservableObject {
    /// Ask the panel to take key status so a text field can receive typing.
    var requestKey: () -> Void = {}
    /// Release key status after text entry ends.
    var resignKey: () -> Void = {}
    var openHistory: () -> Void = {}

    /// Cap for the widget's content height; content scrolls beyond it.
    @Published var maxContentHeight: CGFloat = 500
}
