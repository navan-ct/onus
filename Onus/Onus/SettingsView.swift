import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                Text("A quiet app, kept out of your way.")
                    .font(Theme.dateSub)
                    .foregroundStyle(Theme.paperDim)
            }
            .padding(.bottom, 13)

            GoldRule()

            VStack(alignment: .leading, spacing: 8) {
                Text("Snooze shortcut")
                    .font(Theme.sectionLabel)
                    .tracking(0.4)
                    .foregroundStyle(Theme.paperDim)

                KeyboardShortcuts.Recorder("", name: .toggleSnooze)
                    .labelsHidden()

                Text("Hides Onus for ten minutes. Press the shortcut again to bring it back early.")
                    .font(Theme.small)
                    .foregroundStyle(Theme.paperFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 18)
        }
        .padding(26)
        .frame(width: 360, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(InkSurface().ignoresSafeArea())
    }
}
