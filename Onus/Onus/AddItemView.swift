import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var app: AppController

    let editor: EditorState
    let onClose: () -> Void

    @State private var title: String
    @State private var kind: ItemKind
    @State private var day: CalendarDay
    @FocusState private var focused: Bool

    init(editor: EditorState, onClose: @escaping () -> Void) {
        self.editor = editor
        self.onClose = onClose
        switch editor {
        case .add:
            _title = State(initialValue: "")
            _kind = State(initialValue: .task)
            _day = State(initialValue: .today())
        case .everyDay(let item):
            _title = State(initialValue: item.title)
            _kind = State(initialValue: .everyDay)
            _day = State(initialValue: .today())
        case .task(let t):
            _title = State(initialValue: t.title)
            _kind = State(initialValue: .task)
            _day = State(initialValue: t.date)
        case .goal(let g):
            _title = State(initialValue: g.title)
            _kind = State(initialValue: .goal)
            _day = State(initialValue: .today())
        }
    }

    private var isEditing: Bool {
        if case .add = editor { return false }
        return true
    }

    private var trimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add an item…", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .onExitCommand(perform: onClose)

            if !isEditing {
                Picker("", selection: $kind) {
                    Text("Every day").tag(ItemKind.everyDay)
                    Text("Dated").tag(ItemKind.task)
                    Text("Goal").tag(ItemKind.goal)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if kind == .task {
                dateControls
            }

            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .onAppear {
            app.requestKey()
            DispatchQueue.main.async { focused = true }
        }
        .onDisappear { app.resignKey() }
    }

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                quickPick("Today", target: .today())
                quickPick("Tomorrow", target: tomorrow)
                Spacer()
                DatePicker("", selection: dateBinding, in: startOfToday..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }
            Text("On \(DayFormat.full(day))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func quickPick(_ label: String, target: CalendarDay) -> some View {
        Button(label) { day = target }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(day == target ? Color.accentColor : Color.secondary)
    }

    private var tomorrow: CalendarDay {
        let cal = Calendar.current
        return CalendarDay(date: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date(), calendar: cal)
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { day.date() },
            set: { day = CalendarDay(date: $0) }
        )
    }

    private func commit() {
        let text = trimmed
        guard !text.isEmpty else { return }
        switch editor {
        case .add:
            switch kind {
            case .everyDay: store.addEveryDay(text)
            case .task: store.addTask(text, on: day)
            case .goal: store.addGoal(text)
            }
        case .everyDay(let item):
            store.rename(everyDay: item, to: text)
        case .task(let t):
            store.update(task: t, title: text, day: day)
        case .goal(let g):
            store.rename(goal: g, to: text)
        }
        onClose()
    }
}
