import SwiftUI

enum EditorState: Identifiable {
    case add
    case everyDay(EveryDayItem)
    case task(DatedTask)
    case goal(Goal)

    var id: String {
        switch self {
        case .add: return "add"
        case .everyDay(let i): return "e-\(i.id)"
        case .task(let t): return "t-\(t.id)"
        case .goal(let g): return "g-\(g.id)"
        }
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct WidgetView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var app: AppController

    @State private var editor: EditorState?
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let today = CalendarDay.today()
        VStack(alignment: .leading, spacing: 0) {
            header
            GoldRule().padding(.top, 12)

            ScrollView {
                lists(today: today)
                    .padding(.top, 15)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: HeightKey.self, value: g.size.height)
                    })
            }
            .frame(height: min(max(contentHeight, 1), app.maxContentHeight))
            .scrollIndicators(.automatic)
            .onPreferenceChange(HeightKey.self) { contentHeight = $0 }

            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.top, 13)

            Group {
                if let editor {
                    EditorView(editor: editor) { self.editor = nil }
                        .id(editor.id)
                } else {
                    footer
                }
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, Theme.pad)
        .padding(.top, Theme.padTop)
        .padding(.bottom, Theme.padBottom)
        .frame(width: Theme.width)
        .background(InkSurface())
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(DayFormat.weekday(Date()))
                .font(Theme.dayName)
                .foregroundStyle(Theme.paper)
            Text(DayFormat.longMonthDay(Date()))
                .font(Theme.dateSub)
                .foregroundStyle(Theme.paperDim)
        }
    }

    // MARK: Lists

    @ViewBuilder
    private func lists(today: CalendarDay) -> some View {
        let isEmpty = store.everyDay.isEmpty && store.tasks.isEmpty && store.goals.isEmpty
        VStack(alignment: .leading, spacing: Theme.groupGap) {
            if isEmpty {
                emptyState
            } else {
                if !store.everyDay.isEmpty {
                    group(label: "Every day") {
                        ForEach(store.everyDay) { item in
                            EveryDayRow(item: item) { editor = .everyDay(item) }
                        }
                    }
                }

                ForEach(store.taskSections(today: today), id: \.day) { g in
                    let isToday = g.day == today
                    group(label: DayFormat.label(for: g.day, today: today),
                          emphasized: isToday,
                          accessory: { if isToday { tally(for: g.tasks) } }) {
                        ForEach(g.tasks) { task in
                            TaskRow(task: task) { editor = .task(task) }
                        }
                    }
                }

                if !store.goals.isEmpty {
                    group(label: "Goals") {
                        ForEach(store.goals) { goal in
                            GoalRow(goal: goal) { editor = .goal(goal) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tally(for tasks: [DatedTask]) -> some View {
        let done = tasks.filter { $0.done }.count
        let total = tasks.count
        if done == total {
            Text("done")
                .font(Theme.tally)
                .foregroundStyle(Theme.gold)
        } else {
            Text("\(done) / \(total)")
                .font(Theme.tally)
                .monospacedDigit()
                .foregroundStyle(Theme.gold)
        }
    }

    private func group<Content: View, Accessory: View>(
        label: String,
        emphasized: Bool = false,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Theme.sectionLabel)
                    .tracking(0.4)
                    .foregroundStyle(emphasized ? Theme.paper : Theme.paperDim)
                Spacer(minLength: 8)
                accessory()
            }
            VStack(alignment: .leading, spacing: Theme.rowGap, content: content)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Nothing owed")
                .font(Theme.title)
                .foregroundStyle(Theme.paper)
            Text("A clean slate, rare and yours.")
                .font(Theme.dateSub)
                .foregroundStyle(Theme.paperDim)
        }
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack {
            Button { app.openHistory() } label: {
                Text("History")
                    .font(Theme.sectionLabel)
                    .tracking(0.4)
                    .foregroundStyle(Theme.paperDim)
            }
            .buttonStyle(.plain)
            .help("Show finished items")

            Spacer()

            Button { editor = .add } label: {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.gold)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.onGold)
                    )
            }
            .buttonStyle(.plain)
            .help("Add a task, reminder, or goal")
        }
    }
}

// MARK: - Rows

private struct EveryDayRow: View {
    @EnvironmentObject var store: Store
    let item: EveryDayItem
    let onEdit: () -> Void

    var body: some View {
        RowLayout(marker: {
            Circle().fill(Theme.paperFaint).frame(width: 3, height: 3)
        }, title: {
            Text(item.title).font(Theme.body).foregroundStyle(Theme.paper)
        })
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive) { store.delete(everyDay: item) }
        }
    }
}

private struct TaskRow: View {
    @EnvironmentObject var store: Store
    let task: DatedTask
    let onEdit: () -> Void

    var body: some View {
        RowLayout(marker: {
            Button { store.toggle(task: task) } label: {
                ZStack {
                    if task.done {
                        Circle().fill(Theme.gold).frame(width: 15, height: 15)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.onGold)
                    } else {
                        Circle().stroke(Theme.paperDim.opacity(0.6), lineWidth: 1)
                            .frame(width: 15, height: 15)
                    }
                }
            }
            .buttonStyle(.plain)
        }, title: {
            Text(task.title)
                .font(Theme.body)
                .strikethrough(task.done, color: Theme.goldSoft)
                .foregroundStyle(task.done ? Theme.paperFaint : Theme.paper)
        })
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive) { store.delete(task: task) }
        }
    }
}

private struct GoalRow: View {
    @EnvironmentObject var store: Store
    let goal: Goal
    let onEdit: () -> Void

    var body: some View {
        RowLayout(marker: {
            Image(systemName: "diamond")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Theme.paperFaint)
        }, title: {
            Text(goal.title).font(Theme.body).foregroundStyle(Theme.paper)
        })
        .contextMenu {
            Button("Complete") { store.complete(goal: goal) }
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive) { store.delete(goal: goal) }
        }
    }
}

private struct RowLayout<Marker: View, Title: View>: View {
    @ViewBuilder let marker: () -> Marker
    @ViewBuilder let title: () -> Title

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            marker().frame(width: Theme.markerWidth, height: 18, alignment: .center)
            title()
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
