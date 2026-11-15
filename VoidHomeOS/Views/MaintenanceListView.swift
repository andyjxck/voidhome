import SwiftUI
import SwiftData

struct MaintenanceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Maintenance.date, order: .reverse) private var maintenanceRecords: [Maintenance]
    @State private var showingAddMaintenance = false
    @State private var searchText = ""
    
    var filteredMaintenance: [Maintenance] {
        if searchText.isEmpty {
            return maintenanceRecords
        }
        return maintenanceRecords.filter { maintenance in
            maintenance.task.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for MaintenanceListView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.8, green: 1.0, blue: 0.9), Color(red: 0.9, green: 0.9, blue: 1.0)].randomElement()!
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
                            
                            Text("MAINTENANCE")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddMaintenance = true }) {
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
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                        TextField("Search maintenance", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    )
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        if filteredMaintenance.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.45))
                                Text("No maintenance records yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Button(action: { showingAddMaintenance = true }) {
                                    Text("Add Record")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.2, green: 0.45, blue: 0.35)))
                                }
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredMaintenance) { maintenance in
                                NavigationLink(destination: MaintenanceDetailView(maintenance: maintenance)) {
                                    MaintenanceRow(maintenance: maintenance)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            NotificationService.shared.cancelMaintenanceReminder(for: maintenance)
                                            modelContext.delete(maintenance)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingAddMaintenance) {
                AddMaintenanceView()
            }
        }
        .navigationBarHidden(true)
    }
}

struct MaintenanceRow: View {
    let maintenance: Maintenance

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.5
                        )
                    )
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.45))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(maintenance.task)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                if let asset = maintenance.asset {
                    Text(asset.name)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(maintenance.date, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                if maintenance.cost > 0 {
                    Text(Money.format(maintenance.cost))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
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
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
                )
        )
    }
}

struct MaintenanceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var maintenance: Maintenance
    @State private var showingEditMaintenance = false
    
    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
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
                            Text("MAINTENANCE")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditMaintenance = true }) {
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

                    VStack(spacing: 16) {
                        GlassDetailCard(label: "Task", value: maintenance.task, icon: "wrench.and.screwdriver.fill", tint: Color(red: 0.3, green: 0.55, blue: 0.45))
                        GlassDetailCard(label: "Date", value: maintenance.date.formatted(.dateTime.day().month().year()), icon: "calendar", tint: Color(red: 0.25, green: 0.45, blue: 0.75))

                        if maintenance.cost > 0 {
                            GlassDetailCard(label: "Cost", value: Money.format(maintenance.cost), icon: Money.symbolName(filled: true), tint: Color(red: 0.55, green: 0.4, blue: 0.25))
                        }

                        if let asset = maintenance.asset {
                            GlassDetailCard(label: "Linked Asset", value: asset.name, icon: "cube.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                        }

                        if !maintenance.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NOTES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(2)
                                Text(maintenance.notes)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.02))
                                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingEditMaintenance, onDismiss: {
                // Edits apply live, so reschedule (or cancel) the reminder from the current values.
                NotificationService.shared.syncMaintenanceReminder(for: maintenance)
            }) {
                EditMaintenanceView(maintenance: maintenance)
            }
        }
        .navigationBarHidden(true)
    }
}

struct AddMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Asset.name) private var assets: [Asset]
    
    @State private var task = ""
    @State private var date = Date()
    @State private var cost = ""
    @State private var selectedAsset: Asset?
    @State private var enableReminder = true
    @State private var notes = ""
    
    var body: some View {
        ZStack {
            // Unique starry background for AddMaintenanceView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.8, green: 1.0, blue: 0.9), Color(red: 0.9, green: 0.9, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("ADD MAINTENANCE")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Task", text: $task, icon: "wrench.and.screwdriver.fill", tint: Color(red: 0.3, green: 0.55, blue: 0.45))
                            GlassTextField(title: "Cost", text: $cost, icon: Money.symbolName(filled: true), tint: Color(red: 0.55, green: 0.4, blue: 0.25), keyboardType: .decimalPad)
                            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: Color(red: 0.55, green: 0.35, blue: 0.35), isMultiline: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            Toggle(isOn: $enableReminder) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reminder")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    Text("Up to a week before, at 9 AM")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("LINKED ASSET")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                Picker("", selection: $selectedAsset) {
                                    Text("None").tag(nil as Asset?)
                                    ForEach(assets) { asset in
                                        Text(asset.name).tag(asset as Asset?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
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
                        Button("Save") { saveMaintenance(); dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .disabled(task.isEmpty)
                            .foregroundColor(task.isEmpty ? .white.opacity(0.3) : Color(red: 0.3, green: 0.55, blue: 0.45))
                    }
                }
            }
        }
    }
    
    private func saveMaintenance() {
        let costValue = Money.parse(cost) ?? 0.0
        let maintenance = Maintenance(task: task, date: date, cost: costValue, notes: notes)
        
        if let asset = selectedAsset {
            asset.maintenanceRecords.append(maintenance)
            maintenance.asset = asset
        }
        
        maintenance.remindersEnabled = enableReminder
        modelContext.insert(maintenance)
        NotificationService.shared.syncMaintenanceReminder(for: maintenance)
    }
}

struct EditMaintenanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Bindable var maintenance: Maintenance
    @State private var costString: String
    @State private var selectedAsset: Asset?
    
    init(maintenance: Maintenance) {
        self.maintenance = maintenance
        _costString = State(initialValue: Money.editString(maintenance.cost))
        _selectedAsset = State(initialValue: maintenance.asset)
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for EditMaintenanceView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.95, blue: 0.85), Color(red: 0.9, green: 0.8, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("EDIT MAINTENANCE")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Task", text: $maintenance.task, icon: "wrench.and.screwdriver.fill", tint: Color(red: 0.3, green: 0.55, blue: 0.45))
                            GlassTextField(title: "Cost", text: $costString, icon: Money.symbolName(filled: true), tint: Color(red: 0.55, green: 0.4, blue: 0.25), keyboardType: .decimalPad)
                                .onChange(of: costString) { _, newValue in maintenance.cost = Money.parse(newValue) ?? 0.0 }
                            GlassTextField(title: "Notes", text: $maintenance.notes, icon: "note.text", tint: Color(red: 0.55, green: 0.35, blue: 0.35), isMultiline: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $maintenance.date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            Toggle(isOn: $maintenance.remindersEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reminder")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    Text("Up to a week before, at 9 AM")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("LINKED ASSET")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                Picker("", selection: $selectedAsset) {
                                    Text("None").tag(nil as Asset?)
                                    ForEach(assets) { asset in
                                        Text(asset.name).tag(asset as Asset?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                                .onChange(of: selectedAsset) { _, newAsset in
                                    if let oldAsset = maintenance.asset {
                                        oldAsset.maintenanceRecords.removeAll { $0 == maintenance }
                                    }
                                    maintenance.asset = newAsset
                                    if let newAsset = newAsset {
                                        newAsset.maintenanceRecords.append(maintenance)
                                    }
                                }
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
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
                            .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.45))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceListView()
    }
}