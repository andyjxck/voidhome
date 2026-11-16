import Foundation
import SwiftData

/// Where a To-Do row comes from. Only manual/project jobs are stored as HomeTask;
/// everything else is read live from its own record, so nothing is ever copied or out of step.
enum TodoSource {
    case task(HomeTask)
    case bill(Bill)
    case plan(MaintenancePlan)
    case warranty(Warranty)
    case document(Document)
}

struct TodoItem: Identifiable {
    let id: String
    let source: TodoSource
    let title: String
    let subtitle: String?
    let timeOfDay: TaskTimeOfDay
    /// Small label naming where it came from (Bill, Maintenance, Project, Warranty, Document). nil for your own jobs.
    let origin: String?
    let isDone: Bool
    /// True only for unpaid bills past their due date.
    let isOverdue: Bool
    /// Heads-up rows (expiry dates) have nothing to tick.
    let isInfo: Bool
    let assignee: Person?
}

/// One line of history: a job done, a bill paid or maintenance logged.
struct TodoHistoryEntry: Identifiable {
    let id: String
    let date: Date
    let title: String
    let detail: String?
    let origin: String?
    let person: Person?
    let note: String
    let photoFileName: String?
}

enum TodoFeed {
    static func items(on day: Date, tasks: [HomeTask], bills: [Bill], plans: [MaintenancePlan], warranties: [Warranty], documents: [Document]) -> [TodoItem] {
        let cal = Calendar.current
        let day = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        var items: [TodoItem] = []

        for task in tasks where task.appears(on: day) {
            let done = task.repeatRule == .none ? task.isDone : task.completion(on: day) != nil
            var subtitle: [String] = []
            if let project = task.project { subtitle.append(project.title) }
            if let room = task.room { subtitle.append(room.name) }
            if let asset = task.asset { subtitle.append(asset.name) }
            if task.repeatRule != .none { subtitle.append(task.scheduleSummary) }
            if !task.checklist.isEmpty {
                let ticked = task.checklist.filter { $0.isChecked(on: day) }.count
                subtitle.append("\(ticked)/\(task.checklist.count)")
            }
            items.append(TodoItem(id: "task-\(task.persistentModelID.hashValue)", source: .task(task), title: task.title,
                                  subtitle: subtitle.isEmpty ? nil : subtitle.joined(separator: " · "),
                                  timeOfDay: task.timeOfDay, origin: task.project == nil ? nil : "Project",
                                  isDone: done, isOverdue: false, isInfo: false, assignee: task.assignee))
        }

        for bill in bills {
            let amount = bill.amount > 0 ? (bill.isEstimate ? "about " : "") + Money.format(bill.amount) : nil
            let detail = [amount, bill.paymentMethod.isEmpty ? nil : bill.paymentMethod].compactMap { $0 }.joined(separator: " · ")
            if let paid = bill.payments.first(where: { cal.isDate($0.paidDate, inSameDayAs: day) }) {
                items.append(TodoItem(id: "bill-paid-\(paid.persistentModelID.hashValue)", source: .bill(bill), title: "Pay \(bill.name)",
                                      subtitle: "Paid \(Money.format(paid.amount))", timeOfDay: .anytime, origin: "Bill",
                                      isDone: true, isOverdue: false, isInfo: false, assignee: nil))
                continue
            }
            guard !bill.isSettled else { continue }
            let due = cal.startOfDay(for: bill.nextDueDate)
            let showsToday = due < today && day == today
            guard due == day || showsToday else { continue }
            items.append(TodoItem(id: "bill-\(bill.persistentModelID.hashValue)", source: .bill(bill), title: "Pay \(bill.name)",
                                  subtitle: detail.isEmpty ? nil : detail, timeOfDay: .anytime, origin: "Bill",
                                  isDone: false, isOverdue: bill.isOverdue, isInfo: false, assignee: nil))
        }

        for plan in plans {
            if let log = plan.logs.first(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                items.append(TodoItem(id: "plan-done-\(log.persistentModelID.hashValue)", source: .plan(plan), title: plan.title,
                                      subtitle: plan.targetName, timeOfDay: plan.timeOfDay, origin: "Maintenance",
                                      isDone: true, isOverdue: false, isInfo: false, assignee: log.person))
                continue
            }
            guard plan.appears(on: day) else { continue }
            items.append(TodoItem(id: "plan-\(plan.persistentModelID.hashValue)", source: .plan(plan), title: plan.title,
                                  subtitle: [plan.targetName, plan.intervalSummary].compactMap { $0 }.joined(separator: " · "),
                                  timeOfDay: plan.timeOfDay, origin: "Maintenance", isDone: false, isOverdue: false, isInfo: false, assignee: plan.person))
        }

        for warranty in warranties {
            let expiry = cal.startOfDay(for: warranty.expiryDate)
            let early = cal.date(byAdding: .day, value: -30, to: expiry) ?? expiry
            guard day == expiry || day == early else { continue }
            let name = warranty.asset?.name ?? warranty.provider
            items.append(TodoItem(id: "warranty-\(warranty.persistentModelID.hashValue)", source: .warranty(warranty),
                                  title: day == expiry ? "\(name) warranty ends today" : "\(name) warranty ends in 30 days",
                                  subtitle: warranty.claimContact.isEmpty ? warranty.provider : "Claims: \(warranty.claimContact)",
                                  timeOfDay: .anytime, origin: "Warranty", isDone: false, isOverdue: false, isInfo: true, assignee: nil))
        }

        for document in documents {
            guard let expiryDate = document.expiryDate else { continue }
            let expiry = cal.startOfDay(for: expiryDate)
            let early = cal.date(byAdding: .day, value: -30, to: expiry) ?? expiry
            guard day == expiry || day == early else { continue }
            items.append(TodoItem(id: "doc-\(document.persistentModelID.hashValue)", source: .document(document),
                                  title: day == expiry ? "\(document.title) expires today" : "\(document.title) expires in 30 days",
                                  subtitle: document.type.rawValue, timeOfDay: .anytime, origin: "Document",
                                  isDone: false, isOverdue: false, isInfo: true, assignee: nil))
        }

        return items.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            if a.isOverdue != b.isOverdue { return a.isOverdue }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    /// Ticks a row off and updates the record it came from.
    static func complete(_ item: TodoItem, on day: Date, note: String = "", photoFileName: String? = nil, person: Person? = nil, in context: ModelContext) {
        let cal = Calendar.current
        let doneDate = cal.isDateInToday(day) ? Date() : (cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        switch item.source {
        case .task(let task):
            let completion = TaskCompletion(occurrenceDate: day, note: note)
            context.insert(completion)
            completion.task = task
            completion.person = person ?? task.assignee
            completion.photoFileName = photoFileName
            if task.repeatRule == .none { task.isDone = true }
        case .bill(let bill):
            bill.markPaid(on: doneDate, note: note, in: context)
            NotificationService.shared.syncBillReminder(for: bill)
        case .plan(let plan):
            plan.markDone(on: doneDate, notes: note, person: person, in: context)
            NotificationService.shared.syncPlanReminder(for: plan)
        case .warranty, .document:
            break
        }
        try? context.save()
    }

    /// Unticks a row and puts the source record back as it was.
    static func uncomplete(_ item: TodoItem, on day: Date, in context: ModelContext) {
        let cal = Calendar.current
        switch item.source {
        case .task(let task):
            let matches = task.repeatRule == .none ? task.completions : task.completions.filter { cal.isDate($0.occurrenceDate, inSameDayAs: day) }
            for completion in matches {
                PhotoStore.delete(completion.photoFileName)
                context.delete(completion)
            }
            if task.repeatRule == .none { task.isDone = false }
        case .bill(let bill):
            if let payment = bill.payments.first(where: { cal.isDate($0.paidDate, inSameDayAs: day) }) {
                bill.undo(payment, in: context)
                NotificationService.shared.syncBillReminder(for: bill)
            }
        case .plan(let plan):
            if let log = plan.logs.first(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                plan.nextDueDate = cal.startOfDay(for: log.date)
                context.delete(log)
                plan.lastDoneDate = plan.logs.filter { $0 !== log }.map(\.date).max()
                NotificationService.shared.syncPlanReminder(for: plan)
            }
        case .warranty, .document:
            break
        }
        try? context.save()
    }

    static func history(tasks: [HomeTask], bills: [Bill], plans: [MaintenancePlan]) -> [TodoHistoryEntry] {
        var entries: [TodoHistoryEntry] = []
        for task in tasks {
            for c in task.completions {
                entries.append(TodoHistoryEntry(id: "c-\(c.persistentModelID.hashValue)", date: c.completedAt, title: task.title,
                                                detail: task.project?.title ?? task.room?.name, origin: task.project == nil ? nil : "Project",
                                                person: c.person, note: c.note, photoFileName: c.photoFileName))
            }
        }
        for bill in bills {
            for p in bill.payments {
                entries.append(TodoHistoryEntry(id: "p-\(p.persistentModelID.hashValue)", date: p.paidDate, title: "Paid \(bill.name)",
                                                detail: Money.format(p.amount), origin: "Bill", person: nil, note: p.note, photoFileName: nil))
            }
        }
        for plan in plans {
            for log in plan.logs {
                entries.append(TodoHistoryEntry(id: "m-\(log.persistentModelID.hashValue)", date: log.date, title: log.task,
                                                detail: log.targetName, origin: "Maintenance", person: log.person, note: log.notes, photoFileName: nil))
            }
        }
        return entries.sorted { $0.date > $1.date }
    }
}
