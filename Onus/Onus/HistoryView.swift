import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            GoldRule().padding(.horizontal, 22)

            if store.history.isEmpty {
                Spacer()
                VStack(alignment: .center, spacing: 5) {
                    Text("Nothing settled yet")
                        .font(Theme.title)
                        .foregroundStyle(Theme.paper)
                    Text("Finish something and it rests here.")
                        .font(Theme.dateSub)
                        .foregroundStyle(Theme.paperDim)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedHistory(), id: \.day) { group in
                            VStack(alignment: .leading, spacing: 9) {
                                Text(DayFormat.full(group.day))
                                    .font(Theme.sectionLabel)
                                    .tracking(0.4)
                                    .foregroundStyle(Theme.paperDim)
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
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                }
                .scrollContentBackground(.hidden)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack {
                Spacer()
                Button(action: { showClearConfirm = true }) {
                    Text("Clear all")
                        .font(Theme.sectionLabel)
                        .tracking(0.4)
                        .foregroundStyle(Theme.paperDim)
                }
                .buttonStyle(.plain)
                .disabled(store.history.isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 360, minHeight: 440)
        .background(InkSurface().ignoresSafeArea())
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirm) {
            Button("Clear all", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every finished item.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Settled")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.paper)
            Text("The weight you've set down.")
                .font(Theme.dateSub)
                .foregroundStyle(Theme.paperDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 13)
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
        HStack(alignment: .top, spacing: 11) {
            marker.frame(width: 16, height: 18, alignment: .center)
            Text(entry.title)
                .font(Theme.body)
                .foregroundStyle(Theme.paper)
            Spacer(minLength: 10)
            Text(entry.kind == .goal ? "Goal" : "Task")
                .font(Theme.small)
                .foregroundStyle(Theme.paperFaint)
        }
    }

    @ViewBuilder
    private var marker: some View {
        if entry.kind == .goal {
            Image(systemName: "diamond.fill")
                .font(.system(size: 8))
                .foregroundStyle(Theme.gold)
        } else {
            Circle().fill(Theme.gold).frame(width: 8, height: 8)
        }
    }
}
