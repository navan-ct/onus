import Foundation

enum DayFormat {
    static func label(for day: CalendarDay, today: CalendarDay = .today()) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: today.date(cal), to: day.date(cal)).day ?? 0
        switch diff {
        case ..<0, 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6:
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: day.date(cal))
        default:
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: day.date(cal))
        }
    }

    static func full(_ day: CalendarDay) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: day.date())
    }
}
