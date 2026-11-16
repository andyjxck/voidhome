import SwiftUI
import SwiftData

/// The history of the home, built from records that already exist. It stores nothing of its own.
/// "Coming up" sits above a today line; everything that already happened runs down the screen by month.
/// Only a bill can ever show as overdue or red. Jobs and maintenance never carry a lateness label.
struct TimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @Query private var projects: [Project]
    @Query private var maintenance: [Maintenance]
    @Query private var plans: [MaintenancePlan]
    @Query private var warranties: [Warranty]
    @Query private var documents: [Document]
    @Query private var bills: [Bill]
    @Query private var payments: [BillPayment]
    @Query private var tasks: [HomeTask]
    @Query private var completions: [TaskCompletion]

    @State private var filter: TimelineFilter = .all

    /// How far ahead "Coming up" looks.
    private let lookAheadDays = 60

    var body: some View {
        let built = TimelineBuilder.build(assets: assets, projects: projects, maintenance: maintenance, plans: plans,
                                          warranties: warranties, documents: documents, bills: bills, payments: payments,
                                          tasks: tasks, completions: completions, lookAheadDays: lookAheadDays)
        let upcoming = built.upcoming.filter { filter.includes($0.kind) }
        let past = built.past.filter { filter.includes($0.kind) }
        let months = TimelineBuilder.groupByMonth(past)

        ZStack {
            StarryBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimelineFilter.allCases) { option in
                                Button { withAnimation(.easeInOut(duration: 0.2)) { filter = option } } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: option.icon).font(.system(size: 11, weight: .semibold))
                                        Text(option.title).font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(filter == option ? .white : VoidPalette.muted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(filter == option ? option.tint.opacity(0.35) : Color.white.opacity(0.05))
                                    )
                                    .overlay(Capsule().stroke(filter == option ? option.tint.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, -24)

                    if upcoming.isEmpty && past.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            // Coming up, soonest first
                            TimelineSectionTitle(title: "Coming up", detail: "Next \(lookAheadDays) days")
                            if upcoming.isEmpty {
                                TimelineQuietRow(text: "Nothing coming up.")
                            } else {
                                ForEach(upcoming) { event in
                                    NavigationLink(destination: destination(for: event.target)) {
                                        TimelineEventRow(event: event)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            TodayLine()

                            // History, newest first, by month
                            if months.isEmpty {
                                TimelineQuietRow(text: "Nothing has happened here yet.")
                            } else {
                                ForEach(months) { group in
                                    TimelineMonthHeader(month: group.month)
                                    ForEach(group.events) { event in
                                        NavigationLink(destination: destination(for: event.target)) {
                                            TimelineEventRow(event: event)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Back").font(.system(size: 16))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 4)

            Text("VOID")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(.white)
                .tracking(6)
                .shadow(color: Color.purple.opacity(0.3), radius: 20)

            Text("TIMELINE")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VoidPalette.muted)
                .tracking(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 50)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
            Text(filter == .all ? "Your timeline is empty" : "Nothing here for \(filter.title)")
                .font(.system(size: 16))
                .foregroundColor(VoidPalette.muted)
            Text("It fills itself from purchases, bills, jobs, maintenance, warranties, projects and documents.")
                .font(.system(size: 13))
                .foregroundColor(VoidPalette.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func destination(for target: TimelineTarget) -> some View {
        switch target {
        case .project(let project): ProjectDetailView(project: project)
        case .asset(let asset): AssetDetailView(asset: asset)
        case .maintenance(let record): MaintenanceDetailView(maintenance: record)
        case .plan(let plan): MaintenancePlanDetailView(plan: plan)
        case .warranty(let warranty): WarrantyDetailView(warranty: warranty)
        case .document(let document): DocumentDetailView(document: document)
        case .bill(let bill): BillDetailView(bill: bill)
        case .task(let task): TaskDetailView(task: task)
        }
    }
}

// MARK: - Model

enum TimelineKind {
    case bill, job, maintenance, warranty, project, asset, document

    var tint: Color {
        switch self {
        case .bill: return VoidPalette.bills
        case .job: return VoidPalette.todo
        case .maintenance: return VoidPalette.maintenance
        case .warranty: return VoidPalette.warranties
        case .project: return VoidPalette.projects
        case .asset: return VoidPalette.assets
        case .document: return VoidPalette.documents
        }
    }
}

enum TimelineFilter: String, CaseIterable, Identifiable {
    case all, bills, jobs, maintenance, warranties, projects, assets, documents
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .bills: return "Bills"
        case .jobs: return "To-Do"
        case .maintenance: return "Maintenance"
        case .warranties: return "Warranties"
        case .projects: return "Projects"
        case .assets: return "Assets"
        case .documents: return "Documents"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .bills: return "creditcard.fill"
        case .jobs: return "checklist"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .warranties: return "shield.checkered"
        case .projects: return "hammer.fill"
        case .assets: return "cube.fill"
        case .documents: return "doc.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return VoidPalette.accent
        case .bills: return VoidPalette.bills
        case .jobs: return VoidPalette.todo
        case .maintenance: return VoidPalette.maintenance
        case .warranties: return VoidPalette.warranties
        case .projects: return VoidPalette.projects
        case .assets: return VoidPalette.assets
        case .documents: return VoidPalette.documents
        }
    }

    func includes(_ kind: TimelineKind) -> Bool {
        switch self {
        case .all: return true
        case .bills: return kind == .bill
        case .jobs: return kind == .job
        case .maintenance: return kind == .maintenance
        case .warranties: return kind == .warranty
        case .projects: return kind == .project
        case .assets: return kind == .asset
        case .documents: return kind == .document
        }
    }
}

/// The exact record an event opens.
enum TimelineTarget {
    case project(Project)
    case asset(Asset)
    case maintenance(Maintenance)
    case plan(MaintenancePlan)
    case warranty(Warranty)
    case document(Document)
    case bill(Bill)
    case task(HomeTask)
}

struct TimelineEvent: Identifiable {
    /// Stable id built from the record and what happened to it.
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let kind: TimelineKind
    let icon: String
    /// Words shown on the right instead of the date, e.g. "Today" or "Whenever suits".
    var whenText: String? = nil
    /// Only ever true for an unpaid bill past its due date.
    var isOverdueBill: Bool = false
    let target: TimelineTarget
}

enum TimelineBuilder {
    struct Built {
        let upcoming: [TimelineEvent]
        let past: [TimelineEvent]
    }

    private static func key(_ prefix: String, _ model: some PersistentModel) -> String {
        "\(prefix)-\(String(describing: model.persistentModelID))"
    }

    static func build(assets: [Asset], projects: [Project], maintenance: [Maintenance], plans: [MaintenancePlan],
                      warranties: [Warranty], documents: [Document], bills: [Bill], payments: [BillPayment],
                      tasks: [HomeTask], completions: [TaskCompletion], lookAheadDays: Int,
                      now: Date = Date(), calendar: Calendar = .current) -> Built {
        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: lookAheadDays, to: today) ?? today
        var past: [TimelineEvent] = []
        var upcoming: [TimelineEvent] = []

        // Assets bought
        for asset in assets {
            guard let bought = asset.purchaseDate, bought <= now else { continue }
            var detail = [asset.category]
            if asset.purchasePrice > 0 { detail.append(Money.format(asset.purchasePrice)) }
            if let room = asset.room?.name { detail.append(room) }
            past.append(TimelineEvent(id: key("asset", asset), date: bought, title: "Bought \(asset.name)",
                                      subtitle: detail.filter { !$0.isEmpty }.joined(separator: " · "),
                                      kind: .asset, icon: "cube.fill", target: .asset(asset)))
        }

        // Projects: start, end, and the end date coming up
        for project in projects {
            if let start = project.startDate {
                let event = TimelineEvent(id: key("project-start", project), date: start, title: "\(project.title) starts",
                                          subtitle: "Project · \(project.status.rawValue)", kind: .project, icon: "hammer.fill",
                                          target: .project(project))
                if start <= now { past.append(event) } else if start <= horizon { upcoming.append(event) }
            }
            if let end = project.endDate {
                let finished = project.status == .completed
                let event = TimelineEvent(id: key("project-end", project), date: end,
                                          title: finished ? "\(project.title) finished" : "\(project.title) end date",
                                          subtitle: project.actualCost > 0 ? "Project · spent \(Money.format(project.actualCost, decimals: 0))" : "Project",
                                          kind: .project, icon: finished ? "checkmark.seal.fill" : "flag.checkered",
                                          target: .project(project))
                if end <= now { past.append(event) } else if end <= horizon { upcoming.append(event) }
            }
        }

        // Maintenance log
        for record in maintenance where record.date <= now {
            var detail: [String] = []
            if let target = record.targetName { detail.append(target) }
            if let person = record.person?.name { detail.append(person) }
            if record.cost > 0 { detail.append(Money.format(record.cost)) }
            past.append(TimelineEvent(id: key("maintenance", record), date: record.date, title: record.task,
                                      subtitle: detail.isEmpty ? "Maintenance" : detail.joined(separator: " · "),
                                      kind: .maintenance, icon: "wrench.and.screwdriver.fill", target: .maintenance(record)))
        }
        // A maintenance record dated in the future is a booked job.
        for record in maintenance where record.date > now && record.date <= horizon {
            upcoming.append(TimelineEvent(id: key("maintenance-booked", record), date: record.date, title: record.task,
                                          subtitle: [record.targetName, "Booked"].compactMap { $0 }.joined(separator: " · "),
                                          kind: .maintenance, icon: "wrench.and.screwdriver.fill", target: .maintenance(record)))
        }

        // Maintenance plans coming up. A plan whose date has passed sits on today with no lateness label.
        for plan in plans where !plan.isPaused {
            let due = calendar.startOfDay(for: plan.nextDueDate)
            guard due <= horizon else { continue }
            let shownDate = max(due, today)
            upcoming.append(TimelineEvent(id: key("plan", plan), date: shownDate, title: plan.title,
                                          subtitle: [plan.targetName, plan.intervalSummary].compactMap { $0 }.joined(separator: " · "),
                                          kind: .maintenance, icon: "repeat",
                                          whenText: due < today ? "Whenever suits" : nil,
                                          target: .plan(plan)))
        }

        // Warranties: start, end, and endings coming up
        for warranty in warranties {
            let name = warranty.asset?.name ?? warranty.provider
            if warranty.startDate <= now {
                past.append(TimelineEvent(id: key("warranty-start", warranty), date: warranty.startDate,
                                          title: "\(name) warranty started", subtitle: warranty.provider,
                                          kind: .warranty, icon: "shield.checkered", target: .warranty(warranty)))
            }
            if warranty.expiryDate <= now {
                past.append(TimelineEvent(id: key("warranty-end", warranty), date: warranty.expiryDate,
                                          title: "\(name) warranty ended", subtitle: warranty.provider,
                                          kind: .warranty, icon: "shield.slash", target: .warranty(warranty)))
            } else if warranty.expiryDate <= horizon {
                upcoming.append(TimelineEvent(id: key("warranty-end", warranty), date: warranty.expiryDate,
                                              title: "\(name) warranty ends", subtitle: warranty.provider,
                                              kind: .warranty, icon: "shield.lefthalf.filled", target: .warranty(warranty)))
            }
        }

        // Documents: added, and expiry dates
        for document in documents {
            var detail = [document.type.rawValue]
            if let owner = document.asset?.name ?? document.room?.name { detail.append(owner) }
            past.append(TimelineEvent(id: key("document", document), date: document.createdAt, title: "Added \(document.title)",
                                      subtitle: detail.joined(separator: " · "), kind: .document, icon: "doc.fill",
                                      target: .document(document)))
            if let expiry = document.expiryDate {
                if expiry <= now {
                    past.append(TimelineEvent(id: key("document-expiry", document), date: expiry, title: "\(document.title) expired",
                                              subtitle: detail.joined(separator: " · "), kind: .document, icon: "calendar.badge.clock",
                                              target: .document(document)))
                } else if expiry <= horizon {
                    upcoming.append(TimelineEvent(id: key("document-expiry", document), date: expiry, title: "\(document.title) expires",
                                                  subtitle: detail.joined(separator: " · "), kind: .document, icon: "calendar.badge.clock",
                                                  target: .document(document)))
                }
            }
        }

        // Bills paid
        for payment in payments {
            guard let bill = payment.bill, payment.paidDate <= now else { continue }
            past.append(TimelineEvent(id: key("payment", payment), date: payment.paidDate, title: "Paid \(bill.name)",
                                      subtitle: [Money.format(payment.amount), bill.provider?.name].compactMap { $0 }.joined(separator: " · "),
                                      kind: .bill, icon: "checkmark.circle.fill", target: .bill(bill)))
        }
        // Bills due. An unpaid bill past its date is the only thing on the timeline that shows as overdue.
        for bill in bills where !bill.isSettled {
            let due = calendar.startOfDay(for: bill.nextDueDate)
            guard due <= horizon else { continue }
            let amount = (bill.isEstimate ? "~" : "") + Money.format(bill.amount)
            if bill.isOverdue {
                upcoming.append(TimelineEvent(id: key("bill", bill), date: today, title: "\(bill.name) due",
                                              subtitle: "\(amount) · was due \(DayText.short(bill.nextDueDate))",
                                              kind: .bill, icon: bill.category.icon, whenText: "Overdue",
                                              isOverdueBill: true, target: .bill(bill)))
            } else {
                upcoming.append(TimelineEvent(id: key("bill", bill), date: due, title: "\(bill.name) due",
                                              subtitle: [amount, bill.paymentMethod].filter { !$0.isEmpty }.joined(separator: " · "),
                                              kind: .bill, icon: bill.category.icon, target: .bill(bill)))
            }
        }

        // Jobs done
        for completion in completions {
            guard let task = completion.task, completion.completedAt <= now else { continue }
            var detail: [String] = []
            if let person = completion.person?.name ?? (completion.completedByUid.isEmpty ? nil : HouseContext.name(for: completion.completedByUid)) { detail.append("by \(person)") }
            if let place = task.room?.name ?? task.asset?.name ?? task.project?.title { detail.append(place) }
            if !completion.note.isEmpty { detail.append(completion.note) }
            past.append(TimelineEvent(id: key("completion", completion), date: completion.completedAt, title: "Done: \(task.title)",
                                      subtitle: detail.isEmpty ? "To-Do" : detail.joined(separator: " · "),
                                      kind: .job, icon: "checkmark.circle", target: .task(task)))
        }
        // Jobs coming up: the next day each job is on the list and not yet done. No lateness, ever.
        for task in tasks {
            var day = today
            while day <= horizon {
                if task.appears(on: day, calendar: calendar) && task.completion(on: day, calendar: calendar) == nil {
                    var detail = [task.scheduleSummary]
                    if let place = task.room?.name ?? task.asset?.name ?? task.project?.title { detail.append(place) }
                    if let who = task.assignee?.name { detail.append(who) }
                    upcoming.append(TimelineEvent(id: key("task", task), date: day, title: task.title,
                                                  subtitle: detail.joined(separator: " · "), kind: .job, icon: "checklist",
                                                  target: .task(task)))
                    break
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        // Overdue bills first, then soonest first; history newest first.
        upcoming.sort { a, b in
            if a.isOverdueBill != b.isOverdueBill { return a.isOverdueBill }
            if a.date != b.date { return a.date < b.date }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        past.sort { $0.date > $1.date }
        return Built(upcoming: upcoming, past: past)
    }

    struct MonthGroup: Identifiable {
        let month: Date
        let events: [TimelineEvent]
        var id: Date { month }
    }

    static func groupByMonth(_ events: [TimelineEvent], calendar: Calendar = .current) -> [MonthGroup] {
        var order: [Date] = []
        var groups: [Date: [TimelineEvent]] = [:]
        for event in events {
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: event.date)) ?? event.date
            if groups[month] == nil { order.append(month) }
            groups[month, default: []].append(event)
        }
        return order.map { MonthGroup(month: $0, events: groups[$0] ?? []) }
    }
}

// MARK: - Rows

/// Width of the column that holds the line and the dots.
private let railWidth: CGFloat = 28

struct TimelineSectionTitle: View {
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(VoidPalette.faint)
        }
        .padding(.bottom, 8)
    }
}

struct TimelineMonthHeader: View {
    let month: Date
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2)
                Circle().fill(Color.white.opacity(0.35)).frame(width: 6, height: 6)
            }
            .frame(width: railWidth)
            Text(month.formatted(.dateTime.month(.wide).year()).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(VoidPalette.muted)
                .padding(.vertical, 12)
            Spacer()
        }
    }
}

struct TodayLine: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(VoidPalette.accent)
                .frame(width: 12, height: 12)
                .shadow(color: VoidPalette.accent.opacity(0.7), radius: 6)
                .frame(width: railWidth)
            Text("TODAY · \(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(VoidPalette.accent)
            Rectangle()
                .fill(LinearGradient(colors: [VoidPalette.accent.opacity(0.8), VoidPalette.accent.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
        }
        .padding(.vertical, 14)
    }
}

struct TimelineQuietRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2).frame(width: railWidth)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(VoidPalette.faint)
                .padding(.vertical, 12)
            Spacer()
        }
    }
}

struct TimelineEventRow: View {
    let event: TimelineEvent

    private var dotColor: Color { event.isOverdueBill ? VoidPalette.billOverdue : event.kind.tint }

    private var whenLabel: String {
        if let text = event.whenText { return text }
        let cal = Calendar.current
        if cal.isDateInToday(event.date) { return "Today" }
        if cal.isDateInTomorrow(event.date) { return "Tomorrow" }
        if cal.isDateInYesterday(event.date) { return "Yesterday" }
        return event.date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ZStack {
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2)
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 2))
            }
            .frame(width: railWidth)

            HStack(spacing: 12) {
                Image(systemName: event.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(dotColor)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(dotColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    if !event.subtitle.isEmpty {
                        Text(event.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(VoidPalette.muted)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 6)

                Text(whenLabel)
                    .font(.system(size: 11, weight: event.isOverdueBill ? .semibold : .regular))
                    .foregroundColor(event.isOverdueBill ? VoidPalette.billOverdue : VoidPalette.faint)
                    .multilineTextAlignment(.trailing)
            }
            .padding(10)
            .voidCard(cornerRadius: 14)
            .padding(.vertical, 4)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
