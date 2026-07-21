import Foundation

enum ItemKind: String, Codable, Hashable {
    case everyDay
    case task
    case goal
}

/// A calendar day (no time), stored as year/month/day to avoid timezone drift.
struct CalendarDay: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1970
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    static func today(_ calendar: Calendar = .current) -> CalendarDay {
        CalendarDay(date: Date(), calendar: calendar)
    }

    /// Start of this day in the given calendar.
    func date(_ calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

struct EveryDayItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
}

struct DatedTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: CalendarDay
    var done: Bool = false
    var completedOn: CalendarDay? = nil
}

struct Goal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: ItemKind
    var completedOn: CalendarDay
}

/// The full persisted document.
struct OnusData: Codable {
    var everyDay: [EveryDayItem] = []
    var tasks: [DatedTask] = []
    var goals: [Goal] = []
    var history: [HistoryEntry] = []
}
