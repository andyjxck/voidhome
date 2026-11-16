import SwiftUI
import SwiftData

/// The household To-Do list. Jobs are grouped by time of day; nothing but a bill is ever called overdue,
/// missed repeating jobs simply drop off, and there is no score to keep up.
struct TodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HomeTask.createdAt) private var tasks: [HomeTask]
    @Query private var bills: [Bill]
    @Query private var plans: [MaintenancePlan]
    @Query private var warranties: [Warranty]
    @Query private var documents: [Document]

    enum Tab: String, CaseIterable { case today = "Day", jobs = "All jobs", history = "History" }

    @State private var tab: Tab = .today
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showingAdd = false
    @State private var completing: TodoItem?

    private var items: [TodoItem] {
        TodoFeed.items(on: selectedDay, tasks: tasks, bills: bills, plans: plans, warranties: warranties, documents: documents)
    }

    var body: some View {
        VoidPage(subtitle: "To-Do", addAction: { showingAdd = true }) {
            ChipBar(options: Tab.allCases, selection: $tab) { $0 == .today ? (Calendar.current.isDateInToday(selectedDay) ? "Today" : DayText.relative(selectedDay)) : $0.rawValue }

            switch tab {
            case .today: dayPage
            case .jobs: jobsPage
            case .history: historyPage
            }
        }
        .sheet(isPresented: $showingAdd) { EditTaskSheet(task: nil, defaultDay: selectedDay) }
        .sheet(item: $completing) { item in CompleteTodoSheet(item: item, day: selectedDay) }
    }

    // MARK: Day

    private var dayPage: some View {
        let all = items
        let actionable = all.filter { !$0.isInfo }
        let doneCount = actionable.filter(\.isDone).count
        return VStack(spacing: 18) {
            WeekStrip(selectedDay: $selectedDay)

            HStack(spacing: 12) {
                Image(systemName: doneCount > 0 ? "sparkles" : "leaf")
                    .font(.system(size: 18))
                    .foregroundColor(doneCount > 0 ? VoidPalette.done : VoidPalette.calm)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doneCount == 0 ? "\(actionable.count) on the list" : "\(doneCount) done")
                        .font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                    Text(doneCount == 0 ? "Take it at your own pace." : "\(actionable.count - doneCount) still on the list, no rush.")
                        .font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                }
                Spacer()
                Button(action: { showingAdd = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(VoidPalette.accent.opacity(0.5)))
                }
            }
            .padding(16)
            .voidCard()
            .padding(.horizontal, 24)

            if all.isEmpty {
                EmptyStateView(icon: "checklist", text: "Nothing on the list for this day.", buttonTitle: "Add a job") { showingAdd = true }
            }

            ForEach(TaskTimeOfDay.allCases) { slot in
                let slotItems = all.filter { $0.timeOfDay == slot }
                if !slotItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: slot.icon).font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                            GlassSectionHeader(title: slot.rawValue)
                        }
                        ForEach(slotItems) { item in
                            TodoRow(item: item, day: selectedDay,
                                    onToggle: { toggle(item) },
                                    onCompleteWithDetails: { completing = item })
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private func toggle(_ item: TodoItem) {
        guard !item.isInfo else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if item.isDone {
                TodoFeed.uncomplete(item, on: selectedDay, in: modelContext)
            } else {
                TodoFeed.complete(item, on: selectedDay, in: modelContext)
            }
        }
    }

    // MARK: All jobs

    private var jobsPage: some View {
        let active = tasks.filter { !($0.repeatRule == .none && $0.isDone) }
        let finished = tasks.filter { $0.repeatRule == .none && $0.isDone }
        return VStack(alignment: .leading, spacing: 12) {
            if tasks.isEmpty {
                EmptyStateView(icon: "square.and.pencil", text: "Jobs you add show here.", buttonTitle: "Add a job") { showingAdd = true }
            }
            if !active.isEmpty {
                GlassSectionHeader(title: "On the list")
                ForEach(active) { task in
                    LinkRow(icon: task.repeatRule == .none ? "circle" : "repeat", tint: VoidPalette.todo, title: task.title,
                            subtitle: [task.scheduleSummary, task.timeOfDay.rawValue, task.assignee?.name].compactMap { $0 }.joined(separator: " · ")) {
                        TaskDetailView(task: task)
                    }
                }
            }
            if !finished.isEmpty {
                GlassSectionHeader(title: "Done").padding(.top, 8)
                ForEach(finished) { task in
                    LinkRow(icon: "checkmark.circle.fill", tint: VoidPalette.done, title: task.title,
                            subtitle: task.completions.map(\.completedAt).max().map { "Done \(DayText.relative($0))" }) {
                        TaskDetailView(task: task)
                    }
                }
            }
            if !plans.isEmpty || !bills.isEmpty {
                Text("Bills and maintenance plans add themselves to the list on their dates. Manage them on their own pages.")
                    .font(.system(size: 12)).foregroundColor(VoidPalette.faint).padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: History

    private var historyPage: some View {
        let entries = TodoFeed.history(tasks: tasks, bills: bills, plans: plans)
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return VStack(alignment: .leading, spacing: 16) {
            if entries.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath", text: "Everything you tick off is recorded here.")
            }
            ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                VStack(alignment: .leading, spacing: 8) {
                    GlassSectionHeader(title: DayText.relative(day))
                    ForEach(grouped[day] ?? []) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(VoidPalette.done).font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(entry.title).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                                    if let origin = entry.origin { TagLabel(text: origin) }
                                }
                                Text([entry.date.formatted(date: .omitted, time: .shortened), entry.person?.name, entry.detail].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                                if !entry.note.isEmpty {
                                    Text(entry.note).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                                }
                                if entry.photoFileName != nil {
                                    StoredPhotoView(fileName: entry.photoFileName, cornerRadius: 10).frame(width: 120, height: 90)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .voidCard(cornerRadius: 14)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Binding var selectedDay: Date

    private var weekDays: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: { shift(-7) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(selectedDay.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                if !Calendar.current.isDateInToday(selectedDay) {
                    Button("Today") { withAnimation { selectedDay = Calendar.current.startOfDay(for: Date()) } }
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(VoidPalette.accent)
                }
                Spacer()
                Button(action: { shift(7) }) { Image(systemName: "chevron.right") }
            }
            .foregroundColor(VoidPalette.muted)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { day in
                    let selected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                    let isToday = Calendar.current.isDateInToday(day)
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedDay = day } }) {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selected ? .white : VoidPalette.muted)
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: selected ? .semibold : .regular))
                                .foregroundColor(.white)
                            Circle().fill(isToday ? VoidPalette.accent : Color.clear).frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? VoidPalette.accent.opacity(0.4) : Color.white.opacity(0.03)))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if value.translation.width < -40 { shift(7) } else if value.translation.width > 40 { shift(-7) }
        })
    }

    private func shift(_ days: Int) {
        withAnimation { selectedDay = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) ?? selectedDay }
    }
}

// MARK: - Row

struct TodoRow: View {
    let item: TodoItem
    let day: Date
    let onToggle: () -> Void
    let onCompleteWithDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if item.isInfo {
                Image(systemName: "info.circle").font(.system(size: 22)).foregroundColor(VoidPalette.calm)
            } else {
                Button(action: onToggle) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(item.isDone ? VoidPalette.done : (item.isOverdue ? VoidPalette.billOverdue : VoidPalette.muted))
                }
                .buttonStyle(.plain)
            }

            NavigationLink(destination: destination) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(item.isDone ? VoidPalette.muted : .white)
                            .strikethrough(item.isDone, color: VoidPalette.muted)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            if item.isOverdue { TagLabel(text: "Overdue", color: VoidPalette.billOverdue) }
                            if let origin = item.origin { TagLabel(text: origin) }
                            if let subtitle = item.subtitle {
                                Text(subtitle).font(.system(size: 12)).foregroundColor(VoidPalette.muted).lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    if let person = item.assignee {
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(VoidPalette.people.opacity(0.6)))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .voidCard(cornerRadius: 14, tint: item.isOverdue ? VoidPalette.billOverdue : nil)
        .contextMenu {
            if !item.isInfo && !item.isDone {
                Button(action: onCompleteWithDetails) { Label("Done, with a note or photo", systemImage: "square.and.pencil") }
            }
        }
    }

    @ViewBuilder private var destination: some View {
        switch item.source {
        case .task(let task): TaskDetailView(task: task, day: day)
        case .bill(let bill): BillDetailView(bill: bill)
        case .plan(let plan): MaintenancePlanDetailView(plan: plan)
        case .warranty(let warranty): WarrantyDetailView(warranty: warranty)
        case .document(let document): DocumentDetailView(document: document)
        }
    }
}

// MARK: - Complete with details

struct CompleteTodoSheet: View {
    let item: TodoItem
    let day: Date
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var note = ""
    @State private var photo: String?
    @State private var person: Person?
    @State private var saved = false

    var body: some View {
        FormSheet(title: "Done", saveTitle: "Done", onSave: save) {
            Text(item.title).font(.system(size: 18, weight: .medium)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            GlassTextField(title: "Note", text: $note, icon: "note.text", tint: VoidPalette.todo, isMultiline: true)
            MenuPickerField(title: "Done by", selection: $person, options: people.sorted { ($0.kind == .household ? 0 : 1, $0.name) < ($1.kind == .household ? 0 : 1, $1.name) }) { $0.name }
            if case .task = item.source {
                HStack {
                    if photo != nil { StoredPhotoView(fileName: photo, cornerRadius: 10).frame(width: 80, height: 60) }
                    PhotoPickButton(onSaved: { name in PhotoStore.delete(photo); photo = name }) {
                        Label(photo == nil ? "Add a photo" : "Change photo", systemImage: "camera")
                            .font(.system(size: 14, weight: .medium)).foregroundColor(VoidPalette.accent)
                    }
                    Spacer()
                }
                .padding(12).voidCard(cornerRadius: 16)
            }
        }
        .onAppear {
            if person == nil, case .task(let task) = item.source { person = task.assignee }
            // In a shared house, default "Done by" to whoever is ticking it off.
            if person == nil, let me = HouseContext.uid { person = people.first { $0.memberUid == me } }
        }
        .onDisappear { if !saved { PhotoStore.delete(photo) } }
    }

    private func save() {
        saved = true
        TodoFeed.complete(item, on: day, note: note, photoFileName: photo, person: person, in: modelContext)
    }
}

// MARK: - Task detail

struct TaskDetailView: View {
    @Bindable var task: HomeTask
    var day: Date = Calendar.current.startOfDay(for: Date())
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Job") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Text([task.scheduleSummary, task.timeOfDay.rawValue].joined(separator: " · "))
                            .font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                if !task.notes.isEmpty {
                    Text(task.notes).font(.system(size: 15)).foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).voidCard()
                }

                if !task.checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassSectionHeader(title: "Checklist · \(DayText.relative(day))")
                        ForEach(task.sortedChecklist) { entry in
                            Button(action: { entry.checkedOn = entry.isChecked(on: day) ? nil : day }) {
                                HStack(spacing: 10) {
                                    Image(systemName: entry.isChecked(on: day) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(entry.isChecked(on: day) ? VoidPalette.done : VoidPalette.muted)
                                    Text(entry.title).foregroundColor(.white).strikethrough(entry.isChecked(on: day), color: VoidPalette.muted)
                                    Spacer()
                                }
                                .padding(12).voidCard(cornerRadius: 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LinkedSection(title: "Linked", count: (task.assignee == nil ? 0 : 1) + (task.project == nil ? 0 : 1) + (task.room == nil ? 0 : 1) + (task.asset == nil ? 0 : 1)) {
                    if let person = task.assignee {
                        LinkRow(icon: "person.fill", tint: VoidPalette.people, title: person.name, subtitle: "Assigned") { PersonDetailView(person: person) }
                    }
                    if let project = task.project {
                        LinkRow(icon: "hammer.fill", tint: VoidPalette.projects, title: project.title, subtitle: "Project") { ProjectDetailView(project: project) }
                    }
                    if let room = task.room {
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: "Room") { RoomDetailView(room: room) }
                    }
                    if let asset = task.asset {
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: "Asset") { AssetDetailView(asset: asset) }
                    }
                }

                let done = task.completions.sorted { $0.completedAt > $1.completedAt }
                LinkedSection(title: "History", count: done.count) {
                    ForEach(done) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text([c.completedAt.formatted(date: .abbreviated, time: .shortened), c.person?.name ?? (c.completedByUid.isEmpty ? nil : HouseContext.name(for: c.completedByUid))].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            if !c.note.isEmpty { Text(c.note).font(.system(size: 13)).foregroundColor(VoidPalette.muted) }
                            if c.photoFileName != nil { StoredPhotoView(fileName: c.photoFileName, cornerRadius: 10).frame(width: 140, height: 100) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).voidCard(cornerRadius: 14)
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete job", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditTaskSheet(task: task, defaultDay: day) }
        .confirmationDialog("Delete this job and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                task.completions.forEach { PhotoStore.delete($0.photoFileName) }
                modelContext.delete(task)
                dismiss()
            }
        }
    }
}

// MARK: - Add / edit job

struct EditTaskSheet: View {
    let task: HomeTask?
    var defaultDay: Date = Date()
    var presetProject: Project? = nil
    var presetRoom: Room? = nil
    var presetAsset: Asset? = nil
    var presetPerson: Person? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Asset.name) private var assets: [Asset]

    @State private var title = ""
    @State private var notes = ""
    @State private var timeOfDay: TaskTimeOfDay = .anytime
    @State private var day: Date?
    @State private var repeatRule: TaskRepeat = .none
    @State private var weekdays: Set<Int> = []
    @State private var checklist: [String] = []
    @State private var newChecklistItem = ""
    @State private var assignee: Person?
    @State private var project: Project?
    @State private var room: Room?
    @State private var asset: Asset?
    @State private var visibility = Visibility.house.rawValue
    @State private var loaded = false

    var body: some View {
        FormSheet(title: task == nil ? "New job" : "Edit job", canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "What needs doing", text: $title, icon: "checklist", tint: VoidPalette.todo)

            ChoicePickerField(title: "Time of day", selection: $timeOfDay, options: TaskTimeOfDay.allCases) { $0.rawValue }
            ChoicePickerField(title: "Repeat", selection: $repeatRule, options: TaskRepeat.allCases) { $0.rawValue }

            if repeatRule == .none {
                OptionalDateField(title: "On a particular day", date: $day)
            } else {
                DateField(title: "Starting", date: Binding(get: { day ?? defaultDay }, set: { day = $0 }))
            }

            if repeatRule == .weekly {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { weekday in
                        let on = weekdays.contains(weekday)
                        Button(action: { if on { weekdays.remove(weekday) } else { weekdays.insert(weekday) } }) {
                            Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(on ? .white : VoidPalette.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(on ? VoidPalette.accent.opacity(0.5) : Color.white.opacity(0.04)))
                        }
                    }
                }
                Text(weekdays.isEmpty ? "No days picked: it repeats on the start day's weekday." : "Repeats on the days picked.")
                    .font(.system(size: 11)).foregroundColor(VoidPalette.faint).frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CHECKLIST").font(.system(size: 11, weight: .semibold)).foregroundColor(VoidPalette.muted).tracking(1.5)
                ForEach(Array(checklist.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Image(systemName: "square").foregroundColor(VoidPalette.faint)
                        Text(entry).foregroundColor(.white)
                        Spacer()
                        Button(action: { checklist.remove(at: index) }) { Image(systemName: "minus.circle").foregroundColor(VoidPalette.muted) }
                    }
                }
                HStack {
                    TextField("Add a step", text: $newChecklistItem).foregroundColor(.white).onSubmit(addChecklistItem)
                    Button(action: addChecklistItem) { Image(systemName: "plus.circle.fill").foregroundColor(VoidPalette.accent) }
                        .disabled(newChecklistItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(12).voidCard(cornerRadius: 16)

            MenuPickerField(title: "Assign to", selection: $assignee, options: people.sorted { ($0.kind == .household ? 0 : 1, $0.name) < ($1.kind == .household ? 0 : 1, $1.name) }) { $0.name + ($0.kind == .household ? "" : " · \($0.kind.rawValue)") }
            MenuPickerField(title: "Project", selection: $project, options: projects) { $0.title }
            MenuPickerField(title: "Room", selection: $room, options: rooms) { $0.name }
            MenuPickerField(title: "Asset", selection: $asset, options: assets) { $0.name }
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.todo, isMultiline: true)
            VisibilityField(raw: $visibility, createdBy: task?.createdBy ?? "", tint: VoidPalette.todo,
                            note: visibility == Visibility.me.rawValue ? "A personal job. Only you can see it." : "A house job. Everyone can see it, even when it's assigned to someone.")
        }
        .onAppear(perform: load)
    }

    private func addChecklistItem() {
        let text = newChecklistItem.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        checklist.append(text)
        newChecklistItem = ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let task {
            title = task.title
            notes = task.notes
            timeOfDay = task.timeOfDay
            day = task.startDate
            repeatRule = task.repeatRule
            weekdays = task.weekdays
            checklist = task.sortedChecklist.map(\.title)
            assignee = task.assignee
            project = task.project
            room = task.room
            asset = task.asset
            visibility = task.visibilityRaw
        } else {
            day = Calendar.current.isDateInToday(defaultDay) ? nil : defaultDay
            project = presetProject
            room = presetRoom
            asset = presetAsset
            assignee = presetPerson
        }
    }

    private func save() {
        addChecklistItem()
        let target = task ?? HomeTask(title: title)
        if task == nil { modelContext.insert(target) }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.timeOfDay = timeOfDay
        target.repeatRule = repeatRule
        target.startDate = repeatRule == .none ? day.map { Calendar.current.startOfDay(for: $0) } : Calendar.current.startOfDay(for: day ?? defaultDay)
        target.weekdays = repeatRule == .weekly ? weekdays : []
        target.assignee = assignee
        target.project = project
        target.room = room
        target.asset = asset
        target.visibilityRaw = visibility

        // Keep existing checklist rows (and their ticks) when the text is unchanged.
        var existing = target.checklist
        for (index, text) in checklist.enumerated() {
            if let match = existing.firstIndex(where: { $0.title == text }) {
                existing[match].order = index
                existing.remove(at: match)
            } else {
                let entry = TaskChecklistItem(title: text, order: index)
                modelContext.insert(entry)
                entry.task = target
            }
        }
        existing.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}
