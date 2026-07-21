import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var app: AppController

    let editor: EditorState
    let onClose: () -> Void

    @State private var title: String
    @State private var kind: ItemKind
    @State private var day: CalendarDay
    @State private var showCalendar = false
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
        VStack(alignment: .leading, spacing: 13) {
            TextField(isEditing ? "Edit item" : "Write it down", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.paper)
                .focused($focused)
                .onSubmit(commit)
                .onExitCommand(perform: onClose)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(focused ? Theme.gold : Theme.hairline)
                        .frame(height: focused ? 1.5 : 1)
                }

            if !isEditing {
                kindSelector
            }

            if kind == .task {
                dateControls
            }

            HStack(spacing: 14) {
                Spacer()
                Button(action: onClose) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.paperDim)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: commit) {
                    Text(isEditing ? "Save" : "Add")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(trimmed.isEmpty ? Theme.paperFaint : Theme.onGold)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(trimmed.isEmpty ? Color.white.opacity(0.06) : Theme.gold)
                        )
                }
                .buttonStyle(.plain)
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

    private var kindSelector: some View {
        HStack(spacing: 18) {
            kindOption("Every day", .everyDay)
            kindOption("Dated", .task)
            kindOption("Goal", .goal)
            Spacer()
        }
    }

    private func kindOption(_ label: String, _ value: ItemKind) -> some View {
        let selected = kind == value
        return Button { kind = value } label: {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.paper : Theme.paperDim)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 4, height: 4)
                        .offset(y: 6)
                        .opacity(selected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var dateControls: some View {
        HStack(spacing: 6) {
            datePill("Today", selected: day == .today()) { day = .today() }
            datePill("Tomorrow", selected: day == tomorrow) { day = tomorrow }
            datePill(customLabel, selected: isCustomDay, icon: "calendar") {
                showCalendar = true
            }
            .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                DatePicker("", selection: dateBinding, in: startOfToday..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.gold)
                    .padding(12)
                    .frame(width: 236)
            }
            Spacer(minLength: 0)
        }
    }

    private func datePill(_ label: String, selected: Bool, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 9, weight: .medium)) }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.onGold : Theme.paperDim)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected ? Theme.gold : Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var customLabel: String {
        isCustomDay ? DayFormat.shortMonthDay(day.date()) : "Pick"
    }

    private var isCustomDay: Bool {
        day != .today() && day != tomorrow
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
