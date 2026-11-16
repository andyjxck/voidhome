import SwiftUI
import SwiftData

/// Looking after things you own: repeating plans, and a log of work done.
/// Plans have a next date only. Nothing here is ever called overdue.
struct MaintenanceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenancePlan.nextDueDate) private var plans: [MaintenancePlan]
    @Query(sort: \Maintenance.date, order: .reverse) private var records: [Maintenance]

    enum Tab: String, CaseIterable { case plans = "Plans", log = "Log", health = "By item" }
    @State private var tab: Tab = .plans
    @State private var showingAddPlan = false
    @State private var showingAddLog = false
    @State private var searchText = ""

    var body: some View {
        VoidPage(subtitle: "Maintenance", addAction: { if tab == .log { showingAddLog = true } else { showingAddPlan = true } }) {
            ChipBar(options: Tab.allCases, selection: $tab) { $0.rawValue }

            switch tab {
            case .plans: plansPage
            case .log: logPage
            case .health: healthPage
            }
        }
        .sheet(isPresented: $showingAddPlan) { EditPlanSheet(plan: nil) }
        .sheet(isPresented: $showingAddLog) { EditMaintenanceLogSheet(record: nil) }
    }

    private var plansPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plans.isEmpty {
                EmptyStateView(icon: "repeat", text: "Add jobs that come round regularly, like a boiler service every year. They appear on your To-Do list on their date.", buttonTitle: "Add a plan") { showingAddPlan = true }
            } else {
                Text("Each plan shows on your To-Do list on its next date. Tick it off there or here and it's logged.")
                    .font(.system(size: 12)).foregroundColor(VoidPalette.faint)
            }
            ForEach(plans) { plan in
                PlanRow(plan: plan)
                    .contextMenu {
                        Button { plan.markDone(in: modelContext); NotificationService.shared.syncPlanReminder(for: plan) } label: { Label("Done today", systemImage: "checkmark.circle") }
                        Button(role: .destructive) {
                            NotificationService.shared.cancelPlanReminder(for: plan)
                            modelContext.delete(plan)
                        } label: { Label("Delete plan", systemImage: "trash") }
                    }
            }
        }
        .padding(.horizontal, 24)
    }

    private var logPage: some View {
        let filtered = searchText.isEmpty ? records : records.filter {
            $0.task.localizedCaseInsensitiveContains(searchText) || ($0.targetName ?? "").localizedCaseInsensitiveContains(searchText) || $0.notes.localizedCaseInsensitiveContains(searchText)
        }
        let spentThisYear = records.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .year) && $0.date <= Date() }.reduce(0) { $0 + $1.cost }
        return VStack(spacing: 14) {
            if !records.isEmpty {
                HStack(spacing: 12) {
                    StatTile(icon: "checkmark.seal.fill", tint: VoidPalette.maintenance, value: "\(records.filter { $0.date <= Date() }.count)", label: "Jobs logged")
                    StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: Money.format(spentThisYear, decimals: 0), label: "Spent this year")
                }
                .padding(.horizontal, 24)
                VoidSearchField(prompt: "Search the log", text: $searchText)
            }
            VStack(spacing: 10) {
                if filtered.isEmpty {
                    EmptyStateView(icon: "wrench.and.screwdriver", text: records.isEmpty ? "Work you've had done shows here, with the cost and who did it." : "Nothing matches.", buttonTitle: records.isEmpty ? "Log a job" : nil) { showingAddLog = true }
                }
                ForEach(filtered) { record in
                    NavigationLink(destination: MaintenanceDetailView(maintenance: record)) { MaintenanceRow(maintenance: record) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                NotificationService.shared.cancelMaintenanceReminder(for: record)
                                modelContext.delete(record)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// Every asset or room with maintenance, and a calm status: looked after recently, plan coming up, or no plan.
    private var healthPage: some View {
        var targets: [(key: String, name: String, icon: String, lastDone: Date?, next: Date?, asset: Asset?, room: Room?)] = []
        var seen = Set<String>()
        for plan in plans {
            let key = plan.asset.map { "a\($0.persistentModelID.hashValue)" } ?? plan.room.map { "r\($0.persistentModelID.hashValue)" }
            guard let key, !seen.contains(key) else { continue }
            seen.insert(key)
            let relatedPlans = plans.filter { ($0.asset != nil && $0.asset === plan.asset) || ($0.asset == nil && $0.room != nil && $0.room === plan.room) }
            let relatedLogs = records.filter { ($0.asset != nil && $0.asset === plan.asset) || ($0.asset == nil && $0.room != nil && $0.room === plan.room) }
            targets.append((key, plan.targetName ?? "", plan.asset == nil ? "square.grid.2x2.fill" : "cube.fill", relatedLogs.map(\.date).filter { $0 <= Date() }.max(), relatedPlans.filter { !$0.isPaused }.map(\.nextDueDate).min(), plan.asset, plan.asset == nil ? plan.room : nil))
        }
        for record in records {
            let key = record.asset.map { "a\($0.persistentModelID.hashValue)" } ?? record.room.map { "r\($0.persistentModelID.hashValue)" }
            guard let key, !seen.contains(key) else { continue }
            seen.insert(key)
            let related = records.filter { ($0.asset != nil && $0.asset === record.asset) || ($0.asset == nil && $0.room != nil && $0.room === record.room) }
            targets.append((key, record.targetName ?? "", record.asset == nil ? "square.grid.2x2.fill" : "cube.fill", related.map(\.date).filter { $0 <= Date() }.max(), nil, record.asset, record.asset == nil ? record.room : nil))
        }
        return VStack(alignment: .leading, spacing: 10) {
            if targets.isEmpty {
                EmptyStateView(icon: "heart.text.square", text: "Link plans or logged work to an asset or room to see how each one is looked after.")
            }
            ForEach(targets, id: \.key) { target in
                let status: (String, Color) = target.next != nil ? ("Next \(DayText.relative(max(target.next!, Calendar.current.startOfDay(for: Date()))))", VoidPalette.calm) : (target.lastDone != nil ? ("Looked after", VoidPalette.done) : ("No plan", VoidPalette.muted))
                Group {
                    if let asset = target.asset {
                        LinkRow(icon: target.icon, tint: VoidPalette.maintenance, title: target.name, subtitle: target.lastDone.map { "Last done \(DayText.short($0))" } ?? "Not logged yet", trailing: status.0, trailingColor: status.1) { AssetDetailView(asset: asset) }
                    } else if let room = target.room {
                        LinkRow(icon: target.icon, tint: VoidPalette.maintenance, title: target.name, subtitle: target.lastDone.map { "Last done \(DayText.short($0))" } ?? "Not logged yet", trailing: status.0, trailingColor: status.1) { RoomDetailView(room: room) }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct PlanRow: View {
    let plan: MaintenancePlan
    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let shownDate = max(Calendar.current.startOfDay(for: plan.nextDueDate), today)
        LinkRow(icon: "repeat", tint: VoidPalette.maintenance, title: plan.title,
                subtitle: [plan.targetName, plan.intervalSummary].compactMap { $0 }.joined(separator: " · "),
                trailing: plan.isPaused ? "Paused" : DayText.relative(shownDate), trailingColor: VoidPalette.calm) {
            MaintenancePlanDetailView(plan: plan)
        }
    }
}

struct MaintenanceRow: View {
    let maintenance: Maintenance
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: maintenance.plan == nil ? "wrench.and.screwdriver.fill" : "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VoidPalette.maintenance)
                .frame(width: 42, height: 42)
                .background(Circle().fill(VoidPalette.maintenance.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(maintenance.task).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineLimit(1)
                Text([maintenance.targetName, maintenance.person?.name].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(DayText.short(maintenance.date)).font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                if maintenance.cost > 0 {
                    Text(Money.format(maintenance.cost)).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

// MARK: - Log entry detail

struct MaintenanceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var maintenance: Maintenance
    @Query(sort: \Document.title) private var allDocuments: [Document]
    @State private var showingEdit = false
    @State private var linkingDocs = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Maintenance") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(maintenance.task).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Text(DayText.short(maintenance.date)).font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }
                VStack(spacing: 10) {
                    if maintenance.cost > 0 { GlassDetailCard(label: "COST", value: Money.format(maintenance.cost), icon: Money.symbolName(filled: true), tint: VoidPalette.bills) }
                    if !maintenance.notes.isEmpty { GlassDetailCard(label: "NOTES", value: maintenance.notes, icon: "note.text", tint: VoidPalette.muted) }
                }
                LinkedSection(title: "Linked", count: (maintenance.asset == nil ? 0 : 1) + (maintenance.room == nil ? 0 : 1) + (maintenance.person == nil ? 0 : 1) + (maintenance.plan == nil ? 0 : 1)) {
                    if let asset = maintenance.asset {
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: "Asset") { AssetDetailView(asset: asset) }
                    }
                    if let room = maintenance.room {
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: "Room") { RoomDetailView(room: room) }
                    }
                    if let person = maintenance.person {
                        LinkRow(icon: "person.fill", tint: VoidPalette.people, title: person.name, subtitle: "Done by") { PersonDetailView(person: person) }
                    }
                    if let plan = maintenance.plan {
                        LinkRow(icon: "repeat", tint: VoidPalette.maintenance, title: plan.title, subtitle: plan.intervalSummary) { MaintenancePlanDetailView(plan: plan) }
                    }
                }
                LinkedSection(title: "Documents", count: maintenance.documents.count, addTitle: "Link", addAction: { linkingDocs = true }) {
                    ForEach(maintenance.documents) { doc in
                        LinkRow(icon: "doc.fill", tint: VoidPalette.documents, title: doc.title, subtitle: doc.type.rawValue) { DocumentDetailView(document: doc) }
                    }
                }
                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete record", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditMaintenanceLogSheet(record: maintenance) }
        .sheet(isPresented: $linkingDocs) {
            MultiLinkSheet(title: "Documents", options: allDocuments, label: { $0.title },
                           isLinked: { $0.maintenance === maintenance },
                           toggle: { doc in doc.maintenance = (doc.maintenance === maintenance) ? nil : maintenance })
        }
        .confirmationDialog("Delete this record?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelMaintenanceReminder(for: maintenance)
                modelContext.delete(maintenance)
                dismiss()
            }
        }
    }
}

/// Add or edit a log entry.
struct EditMaintenanceLogSheet: View {
    let record: Maintenance?
    var presetAsset: Asset? = nil
    var presetRoom: Room? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Person.name) private var people: [Person]
    @State private var task = ""
    @State private var date = Date()
    @State private var cost = ""
    @State private var notes = ""
    @State private var asset: Asset?
    @State private var room: Room?
    @State private var person: Person?
    @State private var reminder = false
    @State private var loaded = false

    var body: some View {
        FormSheet(title: record == nil ? "Log a job" : "Edit record", canSave: !task.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "What was done", text: $task, icon: "wrench.and.screwdriver.fill", tint: VoidPalette.maintenance)
            DateField(title: "Date", date: $date)
            GlassTextField(title: "Cost", text: $cost, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            MenuPickerField(title: "Asset", selection: $asset, options: assets) { $0.name }
            MenuPickerField(title: "Room", selection: $room, options: rooms) { $0.name }
            MenuPickerField(title: "Done by", selection: $person, options: people) { $0.name }
            if date > Date() {
                Toggle("Remind me the day before", isOn: $reminder).tint(VoidPalette.maintenance).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
            }
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let record {
                task = record.task; date = record.date; cost = record.cost > 0 ? Money.editString(record.cost) : ""
                notes = record.notes; asset = record.asset; room = record.room; person = record.person; reminder = record.remindersEnabled
            } else {
                asset = presetAsset; room = presetRoom ?? presetAsset?.room
            }
        }
        .onChange(of: asset) { _, newAsset in if room == nil, let r = newAsset?.room { room = r } }
    }

    private func save() {
        let target = record ?? Maintenance(task: task, date: date, cost: 0, notes: "")
        if record == nil { modelContext.insert(target) }
        target.task = task.trimmingCharacters(in: .whitespaces)
        target.date = date
        target.cost = Money.parse(cost) ?? 0
        target.notes = notes
        target.asset = asset
        target.room = room
        target.person = person
        target.remindersEnabled = date > Date() && reminder
        try? modelContext.save()
        NotificationService.shared.syncMaintenanceReminder(for: target, daysBefore: 1)
    }
}

// MARK: - Plans

struct MaintenancePlanDetailView: View {
    @Bindable var plan: MaintenancePlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingDone = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Maintenance plan") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Text(plan.intervalSummary).font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }
                HStack(spacing: 12) {
                    StatTile(icon: "calendar", tint: VoidPalette.calm, value: plan.isPaused ? "Paused" : DayText.relative(max(plan.nextDueDate, Calendar.current.startOfDay(for: Date()))), label: "Next on your list")
                    StatTile(icon: "checkmark.seal.fill", tint: VoidPalette.done, value: plan.lastDoneDate.map { DayText.short($0) } ?? "Not yet", label: "Last done")
                }
                Button(action: { showingDone = true }) {
                    Label("Mark done", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VoidPalette.maintenance.opacity(0.6)))
                }
                Toggle("Pause this plan", isOn: Binding(get: { plan.isPaused }, set: { plan.isPaused = $0; NotificationService.shared.syncPlanReminder(for: plan) }))
                    .tint(VoidPalette.maintenance).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
                if !plan.notes.isEmpty { GlassDetailCard(label: "NOTES", value: plan.notes, icon: "note.text", tint: VoidPalette.muted) }

                LinkedSection(title: "Linked", count: (plan.asset == nil ? 0 : 1) + (plan.room == nil ? 0 : 1) + (plan.person == nil ? 0 : 1)) {
                    if let asset = plan.asset {
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: "Asset") { AssetDetailView(asset: asset) }
                    }
                    if let room = plan.room {
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: "Room") { RoomDetailView(room: room) }
                    }
                    if let person = plan.person {
                        LinkRow(icon: "person.fill", tint: VoidPalette.people, title: person.name, subtitle: "Usually done by") { PersonDetailView(person: person) }
                    }
                }
                LinkedSection(title: "Done before", count: plan.logs.count) {
                    ForEach(plan.sortedLogs) { log in
                        NavigationLink(destination: MaintenanceDetailView(maintenance: log)) { MaintenanceRow(maintenance: log) }.buttonStyle(.plain)
                    }
                }
                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete plan", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
                Text("Deleting a plan keeps its logged work.").font(.system(size: 11)).foregroundColor(VoidPalette.faint)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditPlanSheet(plan: plan) }
        .sheet(isPresented: $showingDone) { PlanDoneSheet(plan: plan) }
        .confirmationDialog("Delete this plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelPlanReminder(for: plan)
                modelContext.delete(plan)
                dismiss()
            }
        }
    }
}

struct PlanDoneSheet: View {
    let plan: MaintenancePlan
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var date = Date()
    @State private var cost = ""
    @State private var notes = ""
    @State private var person: Person?

    var body: some View {
        FormSheet(title: "Mark done", saveTitle: "Done", onSave: {
            plan.markDone(on: date, cost: Money.parse(cost) ?? 0, notes: notes, person: person, in: modelContext)
            NotificationService.shared.syncPlanReminder(for: plan)
            try? modelContext.save()
        }) {
            Text(plan.title).font(.system(size: 18, weight: .medium)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            DateField(title: "Done on", date: $date)
            GlassTextField(title: "Cost", text: $cost, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            MenuPickerField(title: "Done by", selection: $person, options: people) { $0.name }
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
            Text("Next one goes on your list \(plan.intervalSummary.lowercased()) from this date.")
                .font(.system(size: 12)).foregroundColor(VoidPalette.faint)
        }
        .onAppear { person = plan.person }
    }
}

struct EditPlanSheet: View {
    let plan: MaintenancePlan?
    var presetAsset: Asset? = nil
    var presetRoom: Room? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Person.name) private var people: [Person]
    @State private var title = ""
    @State private var intervalValue = 1
    @State private var unit: IntervalUnit = .years
    @State private var nextDate = Date()
    @State private var timeOfDay: TaskTimeOfDay = .anytime
    @State private var asset: Asset?
    @State private var room: Room?
    @State private var person: Person?
    @State private var notes = ""
    @State private var reminders = true
    @State private var loaded = false

    var body: some View {
        FormSheet(title: plan == nil ? "New plan" : "Edit plan", canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "Job (e.g. boiler service)", text: $title, icon: "repeat", tint: VoidPalette.maintenance)
            HStack {
                Text("EVERY").font(.system(size: 11, weight: .semibold)).foregroundColor(VoidPalette.muted).tracking(1.5)
                Spacer()
                Stepper("\(intervalValue)", value: $intervalValue, in: 1...60).foregroundColor(.white).fixedSize()
                Picker("", selection: $unit) { ForEach(IntervalUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).tint(.white)
            }
            .padding(12).voidCard(cornerRadius: 16)
            DateField(title: plan == nil ? "First time" : "Next time", date: $nextDate)
            ChoicePickerField(title: "Time of day", selection: $timeOfDay, options: TaskTimeOfDay.allCases) { $0.rawValue }
            MenuPickerField(title: "Asset", selection: $asset, options: assets) { $0.name }
            MenuPickerField(title: "Room", selection: $room, options: rooms) { $0.name }
            MenuPickerField(title: "Usually done by", selection: $person, options: people) { $0.name }
            Toggle("A gentle note on the day", isOn: $reminders).tint(VoidPalette.maintenance).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let plan {
                title = plan.title; intervalValue = plan.intervalValue; unit = plan.intervalUnit; nextDate = plan.nextDueDate
                timeOfDay = plan.timeOfDay; asset = plan.asset; room = plan.room; person = plan.person; notes = plan.notes; reminders = plan.remindersEnabled
            } else {
                asset = presetAsset; room = presetRoom ?? presetAsset?.room
            }
        }
    }

    private func save() {
        let target = plan ?? MaintenancePlan(title: title)
        if plan == nil { modelContext.insert(target) }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.intervalValue = intervalValue
        target.intervalUnit = unit
        target.nextDueDate = Calendar.current.startOfDay(for: nextDate)
        target.timeOfDay = timeOfDay
        target.asset = asset
        target.room = room
        target.person = person
        target.notes = notes
        target.remindersEnabled = reminders
        try? modelContext.save()
        NotificationService.shared.syncPlanReminder(for: target)
    }
}
