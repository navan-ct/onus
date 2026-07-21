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
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                lists(today: today)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: HeightKey.self, value: g.size.height)
                    })
            }
            .frame(height: min(max(contentHeight, 1), app.maxContentHeight))
            .scrollIndicators(.automatic)
            .onPreferenceChange(HeightKey.self) { contentHeight = $0 }

            Divider().opacity(0.4)

            if let editor {
                EditorView(editor: editor) { self.editor = nil }
                    .id(editor.id)
            } else {
                footer
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func lists(today: CalendarDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.everyDay.isEmpty {
                section("Every day") {
                    ForEach(store.everyDay) { item in
                        EveryDayRow(item: item) { editor = .everyDay(item) }
                    }
                }
            }

            ForEach(store.taskSections(today: today), id: \.day) { group in
                section(DayFormat.label(for: group.day, today: today)) {
                    ForEach(group.tasks) { task in
                        TaskRow(task: task) { editor = .task(task) }
                    }
                }
            }

            if !store.goals.isEmpty {
                section("Goals") {
                    ForEach(store.goals) { goal in
                        GoalRow(goal: goal) { editor = .goal(goal) }
                    }
                }
            }

            if store.everyDay.isEmpty && store.tasks.isEmpty && store.goals.isEmpty {
                Text("Nothing yet. Tap + to add.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            content()
        }
    }

    private var footer: some View {
        HStack {
            Button {
                app.openHistory()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("History")

            Spacer()

            Button {
                editor = .add
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .help("Add")
        }
    }
}

// MARK: - Rows

private struct EveryDayRow: View {
    @EnvironmentObject var store: Store
    let item: EveryDayItem
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
            Text(item.title)
                .font(.callout)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
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
        HStack(spacing: 8) {
            Button {
                store.toggle(task: task)
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(task.done ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.callout)
                .strikethrough(task.done)
                .foregroundStyle(task.done ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
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
        HStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(goal.title)
                .font(.callout)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Complete") { store.complete(goal: goal) }
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive) { store.delete(goal: goal) }
        }
    }
}
