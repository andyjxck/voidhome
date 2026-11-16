import SwiftUI
import SwiftData

/// Household members, tradespeople and providers, each with everything they're linked to.
struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson = false
    @State private var searchText = ""

    private var filtered: [Person] {
        guard !searchText.isEmpty else { return people }
        return people.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.company.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText) || $0.phoneNumber.localizedCaseInsensitiveContains(searchText) || $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VoidPage(subtitle: "People", addAction: { showingAddPerson = true }) {
            if !people.isEmpty { VoidSearchField(prompt: "Search people", text: $searchText) }

            VStack(alignment: .leading, spacing: 10) {
                if filtered.isEmpty {
                    EmptyStateView(icon: "person.2", text: people.isEmpty ? "Add the people in your home, the tradespeople you use and your providers." : "Nothing matches.", buttonTitle: people.isEmpty ? "Add a person" : nil) { showingAddPerson = true }
                }
                ForEach(PersonKind.allCases) { kind in
                    let group = filtered.filter { $0.kind == kind }
                    if !group.isEmpty {
                        GlassSectionHeader(title: kind == .household ? "Household" : (kind == .tradesperson ? "Tradespeople" : "Providers")).padding(.top, 4)
                        ForEach(group) { person in
                            LinkRow(icon: kind.icon, tint: VoidPalette.people, title: person.name,
                                    subtitle: [person.role, person.company].filter { !$0.isEmpty }.joined(separator: " · ")) {
                                PersonDetailView(person: person)
                            }
                            .contextMenu {
                                Button(role: .destructive) { modelContext.delete(person) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAddPerson) { EditPersonSheet(person: nil) }
    }
}

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person
    @Query(sort: \Project.title) private var allProjects: [Project]
    @State private var showingEdit = false
    @State private var showingAddTask = false
    @State private var linkingProjects = false
    @State private var confirmDelete = false

    var body: some View {
        let projects = person.projects(in: allProjects)
        let openTasks = person.assignedTasks.filter { !($0.repeatRule == .none && $0.isDone) }
        VoidPage(subtitle: person.kind.rawValue) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(LinearGradient(colors: [VoidPalette.people, VoidPalette.accent.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Text([person.role, person.company].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                HStack(spacing: 10) {
                    if !person.phoneNumber.isEmpty, let url = URL(string: "sms:\(person.phoneNumber.filter { !$0.isWhitespace })") {
                        contactButton("Text", icon: "message.fill", url: url)
                    }
                    if !person.email.isEmpty, let url = URL(string: "mailto:\(person.email)") {
                        contactButton("Email", icon: "envelope.fill", url: url)
                    }
                    if !person.phoneNumber.isEmpty, let url = URL(string: "tel:\(person.phoneNumber.filter { !$0.isWhitespace })") {
                        contactButton("Call", icon: "phone.fill", url: url)
                    }
                }

                VStack(spacing: 10) {
                    if !person.phoneNumber.isEmpty { GlassDetailCard(label: "PHONE", value: person.phoneNumber, icon: "phone", tint: VoidPalette.people) }
                    if !person.email.isEmpty { GlassDetailCard(label: "EMAIL", value: person.email, icon: "envelope", tint: VoidPalette.people) }
                    if !person.notes.isEmpty { GlassDetailCard(label: "NOTES", value: person.notes, icon: "note.text", tint: VoidPalette.muted) }
                }

                LinkedSection(title: "Jobs assigned", count: openTasks.count, addTitle: "Add", addAction: { showingAddTask = true }) {
                    ForEach(openTasks) { task in
                        LinkRow(icon: task.repeatRule == .none ? "circle" : "repeat", tint: VoidPalette.todo, title: task.title, subtitle: task.scheduleSummary) { TaskDetailView(task: task) }
                    }
                }

                LinkedSection(title: "Projects", count: projects.count, addTitle: "Link", addAction: { linkingProjects = true }) {
                    ForEach(projects) { project in
                        LinkRow(icon: "hammer.fill", tint: VoidPalette.projects, title: project.title, subtitle: project.status.rawValue) { ProjectDetailView(project: project) }
                    }
                }

                LinkedSection(title: "Bills", count: person.bills.count) {
                    ForEach(person.bills) { bill in
                        LinkRow(icon: bill.category.icon, tint: VoidPalette.bills, title: bill.name, subtitle: "\(Money.format(bill.amount)) · \(bill.frequency.rawValue)") { BillDetailView(bill: bill) }
                    }
                }

                LinkedSection(title: "Maintenance plans", count: person.maintenancePlans.count) {
                    ForEach(person.maintenancePlans) { plan in PlanRow(plan: plan) }
                }

                let work = person.maintenanceWork.sorted { $0.date > $1.date }
                LinkedSection(title: "Work done", count: work.count) {
                    let spent = work.reduce(0) { $0 + $1.cost }
                    if spent > 0 {
                        Text("\(work.count) jobs · \(Money.format(spent)) in total").font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                    }
                    ForEach(work) { record in
                        NavigationLink(destination: MaintenanceDetailView(maintenance: record)) { MaintenanceRow(maintenance: record) }.buttonStyle(.plain)
                    }
                }

                let done = person.taskCompletions.sorted { $0.completedAt > $1.completedAt }.prefix(10)
                LinkedSection(title: "Recently ticked off", count: done.count) {
                    ForEach(Array(done)) { c in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(VoidPalette.done)
                            Text(c.task?.title ?? "Job").foregroundColor(.white).font(.system(size: 14))
                            Spacer()
                            Text(DayText.relative(c.completedAt)).font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                        }
                        .padding(12).voidCard(cornerRadius: 14)
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete person", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
                Text("Deleting a person keeps their projects, bills, jobs and history; only the link to them is removed.")
                    .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditPersonSheet(person: person) }
        .sheet(isPresented: $showingAddTask) { EditTaskSheet(task: nil, presetPerson: person) }
        .sheet(isPresented: $linkingProjects) {
            MultiLinkSheet(title: "Projects", options: allProjects, label: { $0.title },
                           isLinked: { p in p.contractors.contains { $0 === person } },
                           toggle: { p in
                               if let i = p.contractors.firstIndex(where: { $0 === person }) { p.contractors.remove(at: i) } else { p.contractors.append(person) }
                           })
        }
        .confirmationDialog("Delete \(person.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(person)
                dismiss()
            }
        }
    }

    private func contactButton(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .voidCard(cornerRadius: 14, tint: VoidPalette.people)
        }
    }
}

struct EditPersonSheet: View {
    let person: Person?
    var presetKind: PersonKind = .household
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var kind: PersonKind = .household
    @State private var company = ""
    @State private var role = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        FormSheet(title: person == nil ? "New person" : "Edit person", canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "Name", text: $name, icon: "person.fill", tint: VoidPalette.people)
            ChoicePickerField(title: "Who they are", selection: $kind, options: PersonKind.allCases) { $0.rawValue }
            GlassTextField(title: kind == .household ? "Relationship (optional)" : "Trade or service", text: $role, icon: "briefcase.fill", tint: VoidPalette.people)
            if kind != .household {
                GlassTextField(title: "Company", text: $company, icon: "building.2.fill", tint: VoidPalette.people)
            }
            GlassTextField(title: "Phone", text: $phoneNumber, icon: "phone.fill", tint: VoidPalette.people, keyboardType: .phonePad)
            GlassTextField(title: "Email", text: $email, icon: "envelope.fill", tint: VoidPalette.people, keyboardType: .emailAddress)
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let person {
                name = person.name; kind = person.kind; company = person.company; role = person.role
                phoneNumber = person.phoneNumber; email = person.email; notes = person.notes
            } else {
                kind = presetKind
            }
        }
    }

    private func save() {
        let target = person ?? Person(name: name)
        if person == nil { modelContext.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.kind = kind
        target.company = company
        target.role = role
        target.phoneNumber = phoneNumber
        target.email = email
        target.notes = notes
        try? modelContext.save()
    }
}

/// Kept for older call sites.
struct AddPersonView: View {
    var body: some View { EditPersonSheet(person: nil, presetKind: .tradesperson) }
}
