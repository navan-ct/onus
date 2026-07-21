import Foundation
import Combine

@MainActor
final class Store: ObservableObject {
    @Published private(set) var everyDay: [EveryDayItem] = []
    @Published private(set) var tasks: [DatedTask] = []
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var history: [HistoryEntry] = []

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Onus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        load()
    }

    // MARK: Derived views

    /// Dated tasks grouped by day, chronologically. Excludes any day before today.
    func taskSections(today: CalendarDay = .today()) -> [(day: CalendarDay, tasks: [DatedTask])] {
        let grouped = Dictionary(grouping: tasks.filter { $0.date >= today }, by: { $0.date })
        return grouped.keys.sorted().map { day in
            (day, grouped[day]!.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        }
    }

    // MARK: Mutations

    func addEveryDay(_ title: String) {
        everyDay.append(EveryDayItem(title: title))
        save()
    }

    func addTask(_ title: String, on day: CalendarDay) {
        tasks.append(DatedTask(title: title, date: day))
        save()
    }

    func addGoal(_ title: String) {
        goals.append(Goal(title: title))
        save()
    }

    func rename(everyDay item: EveryDayItem, to title: String) {
        guard let i = everyDay.firstIndex(where: { $0.id == item.id }) else { return }
        everyDay[i].title = title
        save()
    }

    func update(task: DatedTask, title: String, day: CalendarDay) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].title = title
        tasks[i].date = day
        save()
    }

    func rename(goal: Goal, to title: String) {
        guard let i = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[i].title = title
        save()
    }

    func toggle(task: DatedTask, today: CalendarDay = .today()) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].done.toggle()
        tasks[i].completedOn = tasks[i].done ? today : nil
        save()
    }

    func delete(everyDay item: EveryDayItem) {
        everyDay.removeAll { $0.id == item.id }
        save()
    }

    func delete(task: DatedTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func delete(goal: Goal) {
        goals.removeAll { $0.id == goal.id }
        save()
    }

    /// Completing a goal removes it from the widget and records it in history.
    func complete(goal: Goal, today: CalendarDay = .today()) {
        goals.removeAll { $0.id == goal.id }
        history.append(HistoryEntry(title: goal.title, kind: .goal, completedOn: today))
        save()
    }

    // MARK: History

    func deleteHistory(_ entry: HistoryEntry) {
        history.removeAll { $0.id == entry.id }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    // MARK: Rollover

    /// Reconcile dated tasks against the current day. Safe to call repeatedly.
    func rollover(today: CalendarDay = .today()) {
        var changed = false
        var survivors: [DatedTask] = []
        for var task in tasks {
            if task.date < today {
                if task.done {
                    history.append(HistoryEntry(title: task.title,
                                                kind: .task,
                                                completedOn: task.completedOn ?? today))
                } else {
                    task.date = today
                    task.done = false
                    task.completedOn = nil
                    survivors.append(task)
                }
                changed = true
            } else {
                survivors.append(task)
            }
        }
        if changed {
            tasks = survivors
            save()
        }
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode(OnusData.self, from: data) else { return }
        everyDay = decoded.everyDay
        tasks = decoded.tasks
        goals = decoded.goals
        history = decoded.history
    }

    private func save() {
        saveWorkItem?.cancel()
        let snapshot = OnusData(everyDay: everyDay, tasks: tasks, goals: goals, history: history)
        let url = fileURL
        let work = DispatchWorkItem { [weak self] in self?.write(snapshot, to: url) }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Writes any pending changes synchronously. Call before the app terminates.
    func flush() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        write(OnusData(everyDay: everyDay, tasks: tasks, goals: goals, history: history), to: fileURL)
    }

    private nonisolated func write(_ snapshot: OnusData, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
