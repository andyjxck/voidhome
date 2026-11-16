import SwiftUI
import SwiftData

extension ProjectStatus {
    var tint: Color {
        switch self {
        case .planned: return VoidPalette.calm
        case .inProgress: return VoidPalette.accent
        case .completed: return VoidPalette.done
        case .onHold: return VoidPalette.muted
        }
    }
    var icon: String {
        switch self {
        case .planned: return "pencil.and.outline"
        case .inProgress: return "hammer.fill"
        case .completed: return "checkmark.seal.fill"
        case .onHold: return "pause.circle.fill"
        }
    }
}

/// Home projects with budget, spend, jobs, people, rooms, assets, documents and photos.
struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showingAddProject = false
    @State private var searchText = ""

    private var filtered: [Project] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.projectDescription.localizedCaseInsensitiveContains(searchText) || $0.notes.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VoidPage(subtitle: "Projects", addAction: { showingAddProject = true }) {
            if !projects.isEmpty {
                HStack(spacing: 12) {
                    StatTile(icon: "hammer.fill", tint: VoidPalette.projects, value: "\(projects.filter { $0.status == .inProgress }.count)", label: "In progress")
                    StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: Money.format(projects.reduce(0) { $0 + $1.actualCost }, decimals: 0), label: "Spent across projects")
                }
                .padding(.horizontal, 24)
                VoidSearchField(prompt: "Search projects", text: $searchText)
            }

            VStack(alignment: .leading, spacing: 10) {
                if filtered.isEmpty {
                    EmptyStateView(icon: "hammer", text: projects.isEmpty ? "Plan a job on the house: budget, jobs, who's doing it and before and after photos." : "Nothing matches.", buttonTitle: projects.isEmpty ? "Start a project" : nil) { showingAddProject = true }
                }
                ForEach([ProjectStatus.inProgress, .planned, .onHold, .completed], id: \.self) { status in
                    let group = filtered.filter { $0.status == status }
                    if !group.isEmpty {
                        GlassSectionHeader(title: status.rawValue).padding(.top, 4)
                        ForEach(group) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) { ProjectRow(project: project) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { deleteProject(project) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAddProject) { EditProjectSheet(project: nil) }
    }

    private func deleteProject(_ project: Project) {
        project.photos.forEach { PhotoStore.delete($0.fileName) }
        modelContext.delete(project)
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let cover = project.photos.sorted(by: { ($0.isAfter ? 0 : 1, $0.createdAt) < ($1.isAfter ? 0 : 1, $1.createdAt) }).first {
                    StoredPhotoView(fileName: cover.fileName, cornerRadius: 12).frame(width: 52, height: 52)
                } else {
                    Image(systemName: project.status.icon).font(.system(size: 18)).foregroundColor(project.status.tint)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(project.status.tint.opacity(0.15)))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title).font(.system(size: 16, weight: .medium)).foregroundColor(.white).lineLimit(1)
                    Text([project.rooms.map(\.name).joined(separator: ", "), project.contractors.first?.name ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundColor(VoidPalette.muted).lineLimit(1)
                }
                Spacer()
                TagLabel(text: project.status.rawValue, color: project.status.tint)
            }
            if project.budget > 0 {
                BudgetBar(budget: project.budget, spent: project.actualCost)
            }
            if let progress = project.taskProgress {
                HStack(spacing: 8) {
                    ProgressView(value: progress).tint(VoidPalette.projects)
                    Text("\(project.tasks.filter { $0.repeatRule == .none && $0.isDone }.count)/\(project.tasks.filter { $0.repeatRule == .none }.count) jobs")
                        .font(.system(size: 11)).foregroundColor(VoidPalette.muted)
                }
            }
        }
        .padding(14)
        .voidCard(cornerRadius: 18)
    }
}

struct BudgetBar: View {
    let budget: Double
    let spent: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(spent > budget ? VoidPalette.amber : VoidPalette.bills)
                        .frame(width: geo.size.width * min(1, budget > 0 ? spent / budget : 0))
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(Money.format(spent)) of \(Money.format(budget))").font(.system(size: 11)).foregroundColor(VoidPalette.muted)
                Spacer()
                Text(spent > budget ? "\(Money.format(spent - budget)) over budget" : "\(Money.format(budget - spent)) left")
                    .font(.system(size: 11, weight: .medium)).foregroundColor(spent > budget ? VoidPalette.amber : VoidPalette.muted)
            }
        }
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @Query(sort: \Person.name) private var allPeople: [Person]
    @Query(sort: \Room.name) private var allRooms: [Room]
    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Document.title) private var allDocuments: [Document]
    @State private var showingEdit = false
    @State private var showingAddTask = false
    @State private var linkingPeople = false
    @State private var linkingRooms = false
    @State private var linkingAssets = false
    @State private var linkingDocs = false
    @State private var showingAddDocument = false
    @State private var confirmDelete = false
    @State private var addingSpend = false

    var body: some View {
        VoidPage(subtitle: "Project") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.title).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Menu {
                            ForEach([ProjectStatus.planned, .inProgress, .onHold, .completed], id: \.self) { status in
                                Button(status.rawValue) { project.status = status }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                TagLabel(text: project.status.rawValue, color: project.status.tint)
                                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(VoidPalette.muted)
                            }
                        }
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription).font(.system(size: 15)).foregroundColor(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        StatTile(icon: "target", tint: VoidPalette.projects, value: project.budget > 0 ? Money.format(project.budget, decimals: 0) : "—", label: "Budget")
                        StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: Money.format(project.actualCost, decimals: 0), label: "Spent")
                    }
                    if project.budget > 0 { BudgetBar(budget: project.budget, spent: project.actualCost) }
                    Button(action: { addingSpend = true }) {
                        Label("Add spending", systemImage: "plus.circle").font(.system(size: 13, weight: .medium)).foregroundColor(VoidPalette.accent)
                    }
                }
                .padding(14).voidCard()

                if project.startDate != nil || project.endDate != nil {
                    GlassDetailCard(label: "DATES", value: [project.startDate.map { "From \(DayText.short($0))" }, project.endDate.map { "to \(DayText.short($0))" }].compactMap { $0 }.joined(separator: " "), icon: "calendar", tint: VoidPalette.calm)
                }

                let jobs = project.tasks.sorted { a, b in a.isDone == b.isDone ? a.createdAt < b.createdAt : !a.isDone }
                LinkedSection(title: "Jobs", count: jobs.count, addTitle: "Add", addAction: { showingAddTask = true }) {
                    if let progress = project.taskProgress {
                        ProgressView(value: progress).tint(VoidPalette.projects)
                    }
                    ForEach(jobs) { task in
                        HStack(spacing: 10) {
                            Button(action: { toggle(task) }) {
                                Image(systemName: isDone(task) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22)).foregroundColor(isDone(task) ? VoidPalette.done : VoidPalette.muted)
                            }
                            .buttonStyle(.plain)
                            LinkRow(icon: task.repeatRule == .none ? "checklist" : "repeat", tint: VoidPalette.todo, title: task.title,
                                    subtitle: [task.assignee?.name, task.startDate.map { DayText.relative($0) }].compactMap { $0 }.joined(separator: " · ")) {
                                TaskDetailView(task: task)
                            }
                        }
                    }
                    Text("Jobs with a day show on your To-Do list; the rest sit in Anytime today.").font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                }

                PhotoStrip(project: project)

                LinkedSection(title: "People", count: project.contractors.count, addTitle: "Link", addAction: { linkingPeople = true }) {
                    ForEach(project.contractors) { person in
                        LinkRow(icon: person.kind.icon, tint: VoidPalette.people, title: person.name, subtitle: [person.role, person.company].filter { !$0.isEmpty }.joined(separator: " · ")) { PersonDetailView(person: person) }
                    }
                }

                LinkedSection(title: "Rooms", count: project.rooms.count, addTitle: "Link", addAction: { linkingRooms = true }) {
                    ForEach(project.rooms) { room in
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: room.floor.isEmpty ? nil : room.floor) { RoomDetailView(room: room) }
                    }
                }

                LinkedSection(title: "Assets", count: project.assets.count, addTitle: "Link", addAction: { linkingAssets = true }) {
                    ForEach(project.assets) { asset in
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: asset.room?.name) { AssetDetailView(asset: asset) }
                    }
                }

                LinkedSection(title: "Documents", count: project.documents.count, addTitle: "Link", addAction: { linkingDocs = true }) {
                    ForEach(project.documents) { doc in
                        NavigationLink(destination: DocumentDetailView(document: doc)) { DocumentRow(document: doc) }.buttonStyle(.plain)
                    }
                }

                if !project.notes.isEmpty { GlassDetailCard(label: "NOTES", value: project.notes, icon: "note.text", tint: VoidPalette.muted) }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete project", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
                Text("Deleting a project removes its jobs and photos. People, rooms, assets and documents are kept.")
                    .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditProjectSheet(project: project) }
        .sheet(isPresented: $showingAddTask) { EditTaskSheet(task: nil, presetProject: project) }
        .sheet(isPresented: $addingSpend) { AddSpendSheet(project: project) }
        .sheet(isPresented: $linkingPeople) {
            MultiLinkSheet(title: "People", options: allPeople, label: { $0.name },
                           isLinked: { p in project.contractors.contains { $0 === p } },
                           toggle: { p in if let i = project.contractors.firstIndex(where: { $0 === p }) { project.contractors.remove(at: i) } else { project.contractors.append(p) } })
        }
        .sheet(isPresented: $linkingRooms) {
            MultiLinkSheet(title: "Rooms", options: allRooms, label: { $0.name },
                           isLinked: { r in project.rooms.contains { $0 === r } },
                           toggle: { r in if let i = project.rooms.firstIndex(where: { $0 === r }) { project.rooms.remove(at: i) } else { project.rooms.append(r) } })
        }
        .sheet(isPresented: $linkingAssets) {
            MultiLinkSheet(title: "Assets", options: allAssets, label: { $0.name },
                           isLinked: { a in project.assets.contains { $0 === a } },
                           toggle: { a in if let i = project.assets.firstIndex(where: { $0 === a }) { project.assets.remove(at: i) } else { project.assets.append(a) } })
        }
        .sheet(isPresented: $linkingDocs) {
            MultiLinkSheet(title: "Documents", options: allDocuments, label: { $0.title },
                           isLinked: { $0.project === project },
                           toggle: { doc in doc.project = (doc.project === project) ? nil : project })
        }
        .confirmationDialog("Delete this project?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                project.photos.forEach { PhotoStore.delete($0.fileName) }
                modelContext.delete(project)
                dismiss()
            }
        }
    }

    private func isDone(_ task: HomeTask) -> Bool {
        task.repeatRule == .none ? task.isDone : task.completion(on: Date()) != nil
    }

    private func toggle(_ task: HomeTask) {
        let item = TodoItem(id: "", source: .task(task), title: task.title, subtitle: nil, timeOfDay: task.timeOfDay, origin: nil,
                            isDone: isDone(task), isOverdue: false, isInfo: false, assignee: task.assignee)
        let day = Calendar.current.startOfDay(for: Date())
        if item.isDone { TodoFeed.uncomplete(item, on: day, in: modelContext) } else { TodoFeed.complete(item, on: day, in: modelContext) }
    }
}

struct PhotoStrip: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassSectionHeader(title: "Before & after")
            HStack(alignment: .top, spacing: 12) {
                column(isAfter: false)
                column(isAfter: true)
            }
        }
    }

    private func column(isAfter: Bool) -> some View {
        let photos = project.photos.filter { $0.isAfter == isAfter }.sorted { $0.createdAt < $1.createdAt }
        return VStack(alignment: .leading, spacing: 8) {
            Text(isAfter ? "AFTER" : "BEFORE").font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(VoidPalette.muted)
            ForEach(photos) { photo in
                StoredPhotoView(fileName: photo.fileName, cornerRadius: 12)
                    .frame(height: 110)
                    .contextMenu {
                        Button(role: .destructive) {
                            PhotoStore.delete(photo.fileName)
                            modelContext.delete(photo)
                        } label: { Label("Remove photo", systemImage: "trash") }
                    }
            }
            PhotoPickButton(onSaved: { name in
                let photo = ProjectPhoto(fileName: name, isAfter: isAfter)
                modelContext.insert(photo)
                photo.project = project
            }) {
                Label("Add", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium)).foregroundColor(VoidPalette.accent)
                    .frame(maxWidth: .infinity, minHeight: photos.isEmpty ? 110 : 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(VoidPalette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddSpendSheet: View {
    let project: Project
    @State private var amount = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "Add spending", saveTitle: "Add", canSave: (Money.parse(amount) ?? 0) > 0, onSave: {
            project.actualCost += Money.parse(amount) ?? 0
            if !note.trimmingCharacters(in: .whitespaces).isEmpty {
                let line = "\(DayText.short(Date())): \(Money.format(Money.parse(amount) ?? 0)) · \(note)"
                project.notes = project.notes.isEmpty ? line : project.notes + "\n" + line
            }
        }) {
            GlassTextField(title: "Amount", text: $amount, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            GlassTextField(title: "What for (optional, added to notes)", text: $note, icon: "note.text", tint: VoidPalette.muted)
        }
    }
}

struct EditProjectSheet: View {
    let project: Project?
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @State private var title = ""
    @State private var details = ""
    @State private var status: ProjectStatus = .planned
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var budget = ""
    @State private var spent = ""
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        FormSheet(title: project == nil ? "New project" : "Edit project", canSave: !title.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "Project name", text: $title, icon: "hammer.fill", tint: VoidPalette.projects)
            GlassTextField(title: "What it is", text: $details, icon: "text.alignleft", tint: VoidPalette.projects, isMultiline: true)
            ChoicePickerField(title: "Status", selection: $status, options: [ProjectStatus.planned, .inProgress, .onHold, .completed]) { $0.rawValue }
            OptionalDateField(title: "Start date", date: $startDate)
            OptionalDateField(title: "End date", date: $endDate)
            GlassTextField(title: "Budget", text: $budget, icon: "target", tint: VoidPalette.bills, keyboardType: .decimalPad)
            GlassTextField(title: "Spent so far", text: $spent, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            guard let project else { return }
            title = project.title; details = project.projectDescription; status = project.status
            startDate = project.startDate; endDate = project.endDate
            budget = project.budget > 0 ? Money.editString(project.budget) : ""
            spent = project.actualCost > 0 ? Money.editString(project.actualCost) : ""
            notes = project.notes
        }
    }

    private func save() {
        let target = project ?? Project(title: title)
        if project == nil {
            modelContext.insert(target)
            target.home = homes.first
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.projectDescription = details
        target.status = status
        target.startDate = startDate
        target.endDate = endDate
        target.budget = Money.parse(budget) ?? 0
        target.actualCost = Money.parse(spent) ?? 0
        target.notes = notes
        try? modelContext.save()
    }
}

/// Kept for older call sites.
struct AddProjectView: View {
    var body: some View { EditProjectSheet(project: nil) }
}
