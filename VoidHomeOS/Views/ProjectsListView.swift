import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showingAddProject = false
    @State private var searchText = ""
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { project in
            project.title.localizedCaseInsensitiveContains(searchText) ||
            project.projectDescription.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for ProjectsListView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.95, green: 0.85, blue: 1.0), Color(red: 1.0, green: 0.9, blue: 0.8)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.bottom, 4)

                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("PROJECTS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddProject = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                    
                    // Search bar with glassmorphic styling
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .font(.system(size: 16))
                        
                        TextField("Search projects", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 24)
                    
                    // Projects list with glassmorphic rows
                    VStack(spacing: 12) {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(project)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if filteredProjects.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "hammer")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                
                                Text("No projects yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                
                                Button(action: { showingAddProject = true }) {
                                    Text("Add Project")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(red: 0.4, green: 0.4, blue: 0.7))
                                        )
                                }
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView()
            }
        }
        .navigationBarHidden(true)
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon circle with glassmorphic effect
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                
                Image(systemName: "hammer.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.7))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(project.status.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor(for: project.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(statusColor(for: project.status).opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(statusColor(for: project.status).opacity(0.3), lineWidth: 0.5)
                            )
                    )
                
                if project.budget > 0 {
                    Text(Money.format(project.budget, decimals: 0))
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .planned:
            return Color(red: 0.3, green: 0.5, blue: 0.7)
        case .inProgress:
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .completed:
            return Color(red: 0.3, green: 0.6, blue: 0.4)
        case .onHold:
            return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @State private var showingEditProject = false
    @State private var showingAddContractor = false
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
       
    var body: some View {
        ZStack {
            // Unique starry background for ProjectDetailView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.95, blue: 0.85), Color(red: 0.95, green: 0.85, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.bottom, 4)

                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("PROJECT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditProject = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                    
                    // Project details with glassmorphic cards
                    VStack(spacing: 16) {
                        GlassDetailCard(label: "Title", value: project.title, icon: "textformat", tint: Color(red: 0.4, green: 0.4, blue: 0.7))
                        GlassDetailCard(label: "Status", value: project.status.rawValue, icon: "flag.fill", tint: statusColor(for: project.status))
                        if let startDate = project.startDate {
                            GlassDetailCard(
                                label: "Start Date",
                                value: formatDate(startDate),
                                icon: "calendar",
                                tint: Color(red: 0.3, green: 0.5, blue: 0.55)
                            )
                        }
                        if let endDate = project.endDate {
                            GlassDetailCard(
                                label: "End Date",
                                value: formatDate(endDate),
                                icon: "calendar.badge.exclamationmark",
                                tint: Color(red: 0.65, green: 0.4, blue: 0.35)
                            )
                        }

                        
                        if project.budget > 0 {
                            GlassDetailCard(label: "Budget", value: Money.format(project.budget), icon: Money.symbolName(filled: false), tint: Color(red: 0.3, green: 0.6, blue: 0.4))
                        }
                        
                        if project.actualCost > 0 {
                            GlassDetailCard(label: "Actual Cost", value: Money.format(project.actualCost), icon: "chart.bar.fill", tint: Color(red: 0.8, green: 0.5, blue: 0.2))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if !project.projectDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DESCRIPTION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .tracking(2)
                                .padding(.horizontal, 24)
                            
                            Text(project.projectDescription)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.02))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                        )
                                )
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 20)
                    }
                    
                    // Contractors section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CONTRACTORS (\(project.contractors.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .tracking(2)
                            .padding(.horizontal, 24)
                        
                        if project.contractors.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                
                                Text("No contractors assigned")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            }
                            .padding(.vertical, 30)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(project.contractors) { contractor in
                                    NavigationLink(destination: PersonDetailView(person: contractor)) {
                                        PersonRow(person: contractor)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)
                    
                    if !project.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NOTES")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .tracking(2)
                                .padding(.horizontal, 24)
                            
                            Text(project.notes)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.02))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                        )
                                )
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .sheet(isPresented: $showingEditProject) {
                EditProjectView(project: project)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .planned:
            return Color(red: 0.3, green: 0.5, blue: 0.7)
        case .inProgress:
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .completed:
            return Color(red: 0.3, green: 0.6, blue: 0.4)
        case .onHold:
            return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
}

// MARK: - Add Project View
struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var budget = ""
    @State private var actualCost = ""
    @State private var status: ProjectStatus = .planned
    @State private var notes = ""
    
    var body: some View {
        ZStack {
            // Unique starry background for AddProjectView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.9, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.9, blue: 0.85)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 4)

                        Text("VOID")
                            .font(.system(size: 44, weight: .ultraLight, design: .default))
                            .foregroundColor(.white)
                            .tracking(6)
                            .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                        
                        Text("PROJECTS")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                            .tracking(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Title", text: $title, icon: "textformat", tint: Color(red: 0.4, green: 0.4, blue: 0.7))
                            GlassTextField(title: "Description", text: $description, icon: "doc.text", tint: Color(red: 0.25, green: 0.45, blue: 0.75), isMultiline: true)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("START DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: Binding(
                                    get: { startDate ?? Date() },
                                    set: { startDate = $0 }
                                ), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("END DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: Binding(
                                    get: { endDate ?? Date() },
                                    set: { endDate = $0 }
                                ), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            GlassTextField(title: "Budget", text: $budget, icon: Money.symbolName(filled: false), tint: Color(red: 0.3, green: 0.6, blue: 0.4), keyboardType: .decimalPad)
                            GlassTextField(title: "Actual Cost", text: $actualCost, icon: "chart.bar.fill", tint: Color(red: 0.8, green: 0.5, blue: 0.2), keyboardType: .decimalPad)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("STATUS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                Picker("", selection: $status) {
                                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                                        Text(status.rawValue).tag(status)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveProject()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(title.isEmpty)
                        .foregroundColor(title.isEmpty ? .white.opacity(0.3) : Color(red: 0.4, green: 0.4, blue: 0.7))
                    }
                }
            }
        }
    }
    
    private func saveProject() {
        let budgetValue = Money.parse(budget) ?? 0.0
        let actualCostValue = Money.parse(actualCost) ?? 0.0
        let project = Project(
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            budget: budgetValue,
            actualCost: actualCostValue,
            status: status,
            notes: notes
        )
        
        if let home = homes.first {
            home.projects.append(project)
        }
        
        modelContext.insert(project)
    }
}

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @State private var budgetString: String
    @State private var actualCostString: String
    
    init(project: Project) {
        self.project = project
        _budgetString = State(initialValue: Money.editString(project.budget))
        _actualCostString = State(initialValue: Money.editString(project.actualCost))
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for EditProjectView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.95, blue: 0.85), Color(red: 0.95, green: 0.85, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("EDIT PROJECT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Title", text: $project.title, icon: "textformat", tint: Color(red: 0.4, green: 0.4, blue: 0.7))
                            GlassTextField(title: "Description", text: $project.projectDescription, icon: "doc.text", tint: Color(red: 0.25, green: 0.45, blue: 0.75), isMultiline: true)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("START DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: Binding(
                                    get: { project.startDate ?? Date() },
                                    set: { project.startDate = $0 }
                                ), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("END DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: Binding(
                                    get: { project.endDate ?? Date() },
                                    set: { project.endDate = $0 }
                                ), displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            GlassTextField(title: "Budget", text: $budgetString, icon: Money.symbolName(filled: false), tint: Color(red: 0.3, green: 0.6, blue: 0.4), keyboardType: .decimalPad)
                                .onChange(of: budgetString) { _, newValue in
                                    project.budget = Money.parse(newValue) ?? 0.0
                                }
                            
                            GlassTextField(title: "Actual Cost", text: $actualCostString, icon: "chart.bar.fill", tint: Color(red: 0.8, green: 0.5, blue: 0.2), keyboardType: .decimalPad)
                                .onChange(of: actualCostString) { _, newValue in
                                    project.actualCost = Money.parse(newValue) ?? 0.0
                                }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("STATUS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                Picker("", selection: $project.status) {
                                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                                        Text(status.rawValue).tag(status)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                    )
                            )
                            
                            GlassTextField(title: "Notes", text: $project.notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.7))
                    }
                }
            }
        }
    }
}

struct AddContractorToProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @Query(sort: \Person.name) private var people: [Person]
    
    @State private var selectedPerson: Person?
    
    var body: some View {
        ZStack {
            // Unique starry background for AddContractorToProjectView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.9, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.9, blue: 0.85)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("ADD CONTRACTOR")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // People list with glassmorphic rows
                        VStack(spacing: 12) {
                            ForEach(people) { person in
                                Button(action: {
                                    selectedPerson = person
                                    addContractor()
                                    dismiss()
                                }) {
                                    PersonRow(person: person)
                                }
                            }
                            
                            if people.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 48))
                                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                    
                                    Text("No people available")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                }
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
    
    private func addContractor() {
        guard let person = selectedPerson else { return }
        if !project.contractors.contains(where: { $0.id == person.id }) {
            project.contractors.append(person)
        }
    }
}
