import Foundation

enum DayFormat {
    static func label(for day: CalendarDay, today: CalendarDay = .today()) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: today.date(cal), to: day.date(cal)).day ?? 0
        switch diff {
        case ..<0, 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return weekday(day.date(cal))
        default: return shortMonthDay(day.date(cal))
        }
    }

    static func full(_ day: CalendarDay) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: day.date())
    }

    static func weekday(_ date: Date) -> String { string(date, "EEEE") }
    static func shortMonthDay(_ date: Date) -> String { string(date, "MMM d") }
    static func longMonthDay(_ date: Date) -> String { string(date, "MMMM d") }

    private static func string(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
}
