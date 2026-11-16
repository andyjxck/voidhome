import Foundation
import SwiftData

/// When in the day a job belongs. Purely for grouping on the To-Do page.
enum TaskTimeOfDay: String, CaseIterable, Identifiable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case anytime = "Anytime"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .anytime: return "circle.dashed"
        }
    }
}

/// How a job repeats.
enum TaskRepeat: String, CaseIterable, Identifiable {
    case none = "Once"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    var id: String { rawValue }
}

/// A household job on the To-Do list: added by hand, or belonging to a project.
/// Bills, maintenance plans and expiry dates are NOT copied in here; the To-Do page
/// reads them straight from their own records (see TodoFeed).
@Model
final class HomeTask {
    var title: String = ""
    var notes: String = ""
    var timeOfDayRaw: String = TaskTimeOfDay.anytime.rawValue
    /// The day it first appears. nil = no particular day (stays in Anytime until done).
    var startDate: Date?
    var repeatRaw: String = TaskRepeat.none.rawValue
    /// For weekly repeats: weekday numbers (1 = Sunday ... 7 = Saturday), comma separated.
    /// Empty means the start date's weekday.
    var weekdaysRaw: String = ""
    /// One-off jobs only: set once ticked off.
    var isDone: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var assignee: Person?
    @Relationship(deleteRule: .nullify)
    var project: Project?
    @Relationship(deleteRule: .nullify)
    var room: Room?
    @Relationship(deleteRule: .nullify)
    var asset: Asset?

    @Relationship(deleteRule: .cascade, inverse: \TaskChecklistItem.task)
    var checklist: [TaskChecklistItem] = []
    @Relationship(deleteRule: .cascade, inverse: \TaskCompletion.task)
    var completions: [TaskCompletion] = []

    init(title: String, notes: String = "", timeOfDay: TaskTimeOfDay = .anytime, startDate: Date? = nil, repeatRule: TaskRepeat = .none) {
        self.title = title
        self.notes = notes
        self.timeOfDayRaw = timeOfDay.rawValue
        self.startDate = startDate.map { Calendar.current.startOfDay(for: $0) }
        self.repeatRaw = repeatRule.rawValue
        self.createdAt = Date()
    }

    var timeOfDay: TaskTimeOfDay {
        get { TaskTimeOfDay(rawValue: timeOfDayRaw) ?? .anytime }
        set { timeOfDayRaw = newValue.rawValue }
    }

    var repeatRule: TaskRepeat {
        get { TaskRepeat(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    var weekdays: Set<Int> {
        get { Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { weekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var sortedChecklist: [TaskChecklistItem] {
        checklist.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    /// Whether the job is on the list for a given day.
    /// Repeating jobs show only on their own days; a missed day is simply gone, never piled up.
    /// A one-off job stays on the list from its day until it is done, with no lateness label.
    func appears(on day: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: startDate ?? createdAt)
        switch repeatRule {
        case .none:
            if isDone {
                // Done one-offs still show on the day they were done, ticked.
                return completions.contains { calendar.isDate($0.occurrenceDate, inSameDayAs: day) }
            }
            let today = calendar.startOfDay(for: Date())
            guard startDate != nil else { return day == today }
            if start >= today { return day == start }
            // Not done and its day has passed: it stays quietly on today's list, with no lateness label.
            return day == today
        case .daily:
            return day >= start
        case .weekly:
            guard day >= start else { return false }
            let days = weekdays.isEmpty ? [calendar.component(.weekday, from: start)] : Array(weekdays)
            return days.contains(calendar.component(.weekday, from: day))
        case .monthly:
            guard day >= start else { return false }
            let startDay = calendar.component(.day, from: start)
            let dayNum = calendar.component(.day, from: day)
            let lastDay = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
            return dayNum == min(startDay, lastDay)
        case .yearly:
            guard day >= start else { return false }
            let a = calendar.dateComponents([.month, .day], from: start)
            let b = calendar.dateComponents([.month, .day], from: day)
            return a.month == b.month && a.day == b.day
        }
    }

    func completion(on day: Date, calendar: Calendar = .current) -> TaskCompletion? {
        completions.first { calendar.isDate($0.occurrenceDate, inSameDayAs: day) }
    }

    var scheduleSummary: String {
        switch repeatRule {
        case .none:
            if let startDate { return startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
            return "Whenever"
        case .daily: return "Every day"
        case .weekly:
            let symbols = Calendar.current.shortWeekdaySymbols
            let days = weekdays.isEmpty ? [Calendar.current.component(.weekday, from: startDate ?? createdAt)] : weekdays.sorted()
            return "Weekly · " + days.map { symbols[($0 - 1) % 7] }.joined(separator: ", ")
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

@Model
final class TaskChecklistItem {
    var title: String = ""
    var order: Int = 0
    var createdAt: Date = Date()
    /// The day the item was last ticked; it counts as ticked only on that day,
    /// so repeating jobs start each day with a fresh checklist.
    var checkedOn: Date?
    @Relationship(deleteRule: .nullify)
    var task: HomeTask?

    init(title: String, order: Int) {
        self.title = title
        self.order = order
        self.createdAt = Date()
    }

    func isChecked(on day: Date) -> Bool {
        guard let checkedOn else { return false }
        return Calendar.current.isDate(checkedOn, inSameDayAs: day)
    }
}

/// One time a job was done: when, by whom, with an optional note and photo.
@Model
final class TaskCompletion {
    /// The day of the occurrence that was done.
    var occurrenceDate: Date = Date()
    var completedAt: Date = Date()
    var note: String = ""
    var photoFileName: String?
    @Relationship(deleteRule: .nullify)
    var person: Person?
    @Relationship(deleteRule: .nullify)
    var task: HomeTask?

    init(occurrenceDate: Date, note: String = "") {
        self.occurrenceDate = Calendar.current.startOfDay(for: occurrenceDate)
        self.completedAt = Date()
        self.note = note
    }
}
