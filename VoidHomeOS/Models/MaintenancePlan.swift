import Foundation
import SwiftData

enum IntervalUnit: String, CaseIterable, Identifiable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .days: return .day
        case .weeks: return .weekOfYear
        case .months: return .month
        case .years: return .year
        }
    }
}

/// A repeating job for something you own, e.g. "Boiler service, every 1 year".
/// It has one next date only; missed dates never pile up and it is never labelled overdue.
@Model
final class MaintenancePlan {
    var title: String = ""
    var intervalValue: Int = 1
    var intervalUnitRaw: String = IntervalUnit.years.rawValue
    var nextDueDate: Date = Date()
    var lastDoneDate: Date?
    var timeOfDayRaw: String = TaskTimeOfDay.anytime.rawValue
    var notes: String = ""
    var remindersEnabled: Bool = true
    var isPaused: Bool = false
    var reminderID: String?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var asset: Asset?
    @Relationship(deleteRule: .nullify)
    var room: Room?
    @Relationship(deleteRule: .nullify)
    var person: Person?
    @Relationship(deleteRule: .nullify, inverse: \Maintenance.plan)
    var logs: [Maintenance] = []

    init(title: String, intervalValue: Int = 1, intervalUnit: IntervalUnit = .years, nextDueDate: Date = Date()) {
        self.title = title
        self.intervalValue = max(1, intervalValue)
        self.intervalUnitRaw = intervalUnit.rawValue
        self.nextDueDate = Calendar.current.startOfDay(for: nextDueDate)
        self.createdAt = Date()
    }

    var intervalUnit: IntervalUnit {
        get { IntervalUnit(rawValue: intervalUnitRaw) ?? .years }
        set { intervalUnitRaw = newValue.rawValue }
    }

    var timeOfDay: TaskTimeOfDay {
        get { TaskTimeOfDay(rawValue: timeOfDayRaw) ?? .anytime }
        set { timeOfDayRaw = newValue.rawValue }
    }

    var intervalSummary: String {
        let unit = intervalUnit.rawValue.lowercased()
        return intervalValue == 1 ? "Every \(String(unit.dropLast()))" : "Every \(intervalValue) \(unit)"
    }

    var targetName: String? { asset?.name ?? room?.name }

    var sortedLogs: [Maintenance] { logs.sorted { $0.date > $1.date } }

    /// Whether the plan's job is on the list for a day: on its next date, and if that has passed, quietly on today.
    func appears(on day: Date, calendar: Calendar = .current) -> Bool {
        guard !isPaused else { return false }
        let day = calendar.startOfDay(for: day)
        let due = calendar.startOfDay(for: nextDueDate)
        let today = calendar.startOfDay(for: Date())
        if due >= today { return day == due }
        return day == today
    }

    /// Ticks the job off: writes a log entry and sets the next date from today.
    @discardableResult
    func markDone(on date: Date = Date(), cost: Double = 0, notes: String = "", person: Person? = nil, in context: ModelContext) -> Maintenance {
        let record = Maintenance(task: title, date: date, cost: cost, notes: notes)
        record.remindersEnabled = false
        context.insert(record)
        record.plan = self
        record.asset = asset
        record.room = room
        record.person = person ?? self.person
        lastDoneDate = date
        let base = Calendar.current.startOfDay(for: date)
        nextDueDate = Calendar.current.date(byAdding: intervalUnit.component, value: max(1, intervalValue), to: base) ?? base
        return record
    }
}

/// Before and after pictures on a project.
@Model
final class ProjectPhoto {
    var fileName: String = ""
    var isAfter: Bool = false
    var caption: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify)
    var project: Project?

    init(fileName: String, isAfter: Bool, caption: String = "") {
        self.fileName = fileName
        self.isAfter = isAfter
        self.caption = caption
        self.createdAt = Date()
    }
}
