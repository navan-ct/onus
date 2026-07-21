import SwiftUI

/// Central design tokens — colors, fonts, and layout metrics shared across every view.
/// Gold is used sparingly, only to mark completion and today's tasks.
enum Theme {
    static let width: CGFloat = 268
    static let radius: CGFloat = 18
    static let pad: CGFloat = 18
    static let padTop: CGFloat = 17
    static let padBottom: CGFloat = 14
    static let groupGap: CGFloat = 18
    static let rowGap: CGFloat = 8
    static let markerWidth: CGFloat = 18

    static let scrim = Color(red: 0.078, green: 0.070, blue: 0.058)
    static let onGold = Color(red: 0.098, green: 0.086, blue: 0.063)

    static let paper = Color(red: 0.937, green: 0.918, blue: 0.882)
    static let paperDim = Color(red: 0.615, green: 0.592, blue: 0.545)
    static let paperFaint = Color(red: 0.435, green: 0.416, blue: 0.376)
    static let hairline = Color.white.opacity(0.075)

    static let gold = Color(red: 0.816, green: 0.663, blue: 0.365)
    static let goldSoft = Color(red: 0.816, green: 0.663, blue: 0.365).opacity(0.45)

    static let dayName = Font.system(size: 15, weight: .semibold)
    static let dateSub = Font.system(size: 11.5, weight: .regular)
    static let sectionLabel = Font.system(size: 10.5, weight: .medium)
    static let body = Font.system(size: 13, weight: .regular)
    static let tally = Font.system(size: 11, weight: .semibold)
    static let title = Font.system(size: 18, weight: .semibold)
    static let small = Font.system(size: 11, weight: .regular)
}

/// Frosted dark background shared by the widget and all windows.
struct InkSurface: View {
    var body: some View {
        VisualEffectView(material: .hudWindow)
            .overlay(Theme.scrim.opacity(0.44))
    }
}

/// A thin gold divider used to separate sections.
struct GoldRule: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.gold.opacity(0.08), Theme.gold.opacity(0.8), Theme.gold.opacity(0.08)],
            startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }
}
