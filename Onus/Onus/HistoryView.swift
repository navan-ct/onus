import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if store.history.isEmpty {
                Spacer()
                Text("No completed items yet.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(groupedHistory(), id: \.day) { group in
                        Section(DayFormat.full(group.day)) {
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            store.deleteHistory(entry)
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Spacer()
                Button("Clear All…") { showClearConfirm = true }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
                    .disabled(store.history.isEmpty)
            }
            .padding(8)
        }
        .frame(minWidth: 320, minHeight: 380)
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirm) {
            Button("Clear All", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every completed item.")
        }
    }

    private func groupedHistory() -> [(day: CalendarDay, entries: [HistoryEntry])] {
        let grouped = Dictionary(grouping: store.history, by: { $0.completedOn })
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.kind == .goal ? "target" : "checkmark.circle.fill")
                .foregroundStyle(entry.kind == .goal ? Color.secondary : Color.accentColor)
            Text(entry.title)
            Spacer(minLength: 8)
            Text(entry.kind == .goal ? "Goal" : "Task")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
