import SwiftUI
import SwiftData

/// Assets as a grid of photo cards with a warranty badge.
struct AssetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @State private var showingAddAsset = false
    @State private var searchText = ""
    @State private var category = "All"

    private var categories: [String] {
        ["All"] + Array(Set(assets.map { $0.category }.filter { !$0.isEmpty })).sorted()
    }

    private var filtered: [Asset] {
        assets.filter { asset in
            (category == "All" || asset.category == category) &&
            (searchText.isEmpty || asset.name.localizedCaseInsensitiveContains(searchText) || asset.manufacturer.localizedCaseInsensitiveContains(searchText) ||
             asset.model.localizedCaseInsensitiveContains(searchText) || asset.serialNumber.localizedCaseInsensitiveContains(searchText) || asset.locationDisplay.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VoidPage(subtitle: "Assets", addAction: { showingAddAsset = true }) {
            if !assets.isEmpty {
                HStack(spacing: 12) {
                    StatTile(icon: "cube.fill", tint: VoidPalette.assets, value: "\(assets.count)", label: "Things you own")
                    StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: Money.format(assets.reduce(0) { $0 + $1.purchasePrice }, decimals: 0), label: "Total paid")
                }
                .padding(.horizontal, 24)
                VoidSearchField(prompt: "Search assets", text: $searchText)
                if categories.count > 2 {
                    ChipBar(options: categories, selection: $category) { $0 }
                }
            }

            if filtered.isEmpty {
                EmptyStateView(icon: "cube", text: assets.isEmpty ? "Add the things you own: appliances, furniture, tech. Keep their receipts, warranties and upkeep together." : "Nothing matches.", buttonTitle: assets.isEmpty ? "Add an asset" : nil) { showingAddAsset = true }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(filtered) { asset in
                    NavigationLink(destination: AssetDetailView(asset: asset)) { AssetCard(asset: asset) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                for w in asset.warranties { NotificationService.shared.cancelWarrantyReminder(for: w) }
                                PhotoStore.delete(asset.photoFileName)
                                modelContext.delete(asset)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAddAsset) { AddAssetView() }
    }
}

struct AssetCard: View {
    let asset: Asset

    private var warrantyBadge: (String, Color)? {
        guard let latest = asset.warranties.max(by: { $0.expiryDate < $1.expiryDate }) else { return nil }
        switch latest.status {
        case .active: return ("Covered", VoidPalette.done)
        case .endingSoon: return ("Cover ending", VoidPalette.amber)
        case .expired: return ("Cover ended", VoidPalette.muted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                StoredPhotoView(fileName: asset.photoFileName, icon: "cube.fill", tint: VoidPalette.assets, cornerRadius: 0)
                    .frame(height: 120)
                if let badge = warrantyBadge {
                    HStack(spacing: 3) {
                        Image(systemName: "shield.fill").font(.system(size: 9))
                        Text(badge.0).font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Capsule().fill(badge.1.opacity(0.85)))
                    .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(asset.locationDisplay.isEmpty ? asset.category : asset.locationDisplay)
                    .font(.system(size: 11)).foregroundColor(VoidPalette.muted).lineLimit(1)
                if asset.purchasePrice > 0 {
                    Text(Money.format(asset.purchasePrice)).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .voidCard(cornerRadius: 16)
    }
}

struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var asset: Asset
    @Query(sort: \Project.title) private var allProjects: [Project]
    @State private var showingEditAsset = false
    @State private var showingAddDocument = false
    @State private var showingAddWarranty = false
    @State private var showingAddPlan = false
    @State private var showingAddLog = false
    @State private var showingAddTask = false
    @State private var linkingProjects = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Asset") {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomTrailing) {
                    StoredPhotoView(fileName: asset.photoFileName, icon: "cube.fill", tint: VoidPalette.assets, cornerRadius: 22)
                        .frame(height: 220)
                    PhotoPickButton(onSaved: { name in
                        PhotoStore.delete(asset.photoFileName)
                        asset.photoFileName = name
                    }) {
                        Image(systemName: "camera.fill").font(.system(size: 15)).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(12)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(asset.name).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        Text([asset.category, asset.manufacturer, asset.model].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEditAsset = true }
                }

                HStack(spacing: 12) {
                    StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: asset.purchasePrice > 0 ? Money.format(asset.purchasePrice) : "—", label: "Paid")
                    StatTile(icon: "calendar", tint: VoidPalette.calm, value: asset.purchaseDate.map { DayText.short($0) } ?? "—", label: "Bought")
                }

                VStack(spacing: 10) {
                    if !asset.serialNumber.isEmpty { GlassDetailCard(label: "SERIAL NUMBER", value: asset.serialNumber, icon: "number", tint: VoidPalette.documents) }
                    if !asset.notes.isEmpty { GlassDetailCard(label: "NOTES", value: asset.notes, icon: "note.text", tint: VoidPalette.muted) }
                }

                LinkedSection(title: "Where it is", count: asset.room == nil && asset.location.isEmpty ? 0 : 1) {
                    if let room = asset.room {
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: asset.location.isEmpty ? "Show on the floor plan" : asset.location) {
                            RoomDetailView(room: room)
                        }
                    } else if !asset.location.isEmpty {
                        GlassDetailCard(label: "LOCATION", value: asset.location, icon: "location.fill", tint: VoidPalette.rooms)
                    }
                }

                LinkedSection(title: "Warranty", count: asset.warranties.count, addTitle: "Add", addAction: { showingAddWarranty = true }) {
                    ForEach(asset.warranties.sorted { $0.expiryDate > $1.expiryDate }) { w in
                        NavigationLink(destination: WarrantyDetailView(warranty: w)) { WarrantyRow(warranty: w) }.buttonStyle(.plain)
                    }
                }

                LinkedSection(title: "Documents", count: asset.documents.count, addTitle: "Add", addAction: { showingAddDocument = true }) {
                    ForEach(asset.documents) { doc in
                        LinkRow(icon: "doc.fill", tint: VoidPalette.documents, title: doc.title, subtitle: doc.type.rawValue) { DocumentDetailView(document: doc) }
                    }
                }

                LinkedSection(title: "Maintenance plan", count: asset.maintenancePlans.count, addTitle: "Add", addAction: { showingAddPlan = true }) {
                    ForEach(asset.maintenancePlans) { plan in PlanRow(plan: plan) }
                }

                LinkedSection(title: "Maintenance history", count: asset.maintenanceRecords.count, addTitle: "Log", addAction: { showingAddLog = true }) {
                    ForEach(asset.maintenanceRecords.sorted { $0.date > $1.date }) { record in
                        NavigationLink(destination: MaintenanceDetailView(maintenance: record)) { MaintenanceRow(maintenance: record) }.buttonStyle(.plain)
                    }
                }

                let openTasks = asset.tasks.filter { !($0.repeatRule == .none && $0.isDone) }
                LinkedSection(title: "Jobs", count: openTasks.count, addTitle: "Add", addAction: { showingAddTask = true }) {
                    ForEach(openTasks) { task in
                        LinkRow(icon: task.repeatRule == .none ? "circle" : "repeat", tint: VoidPalette.todo, title: task.title, subtitle: task.scheduleSummary) { TaskDetailView(task: task) }
                    }
                }

                LinkedSection(title: "Projects", count: asset.projects.count, addTitle: "Link", addAction: { linkingProjects = true }) {
                    ForEach(asset.projects) { project in
                        LinkRow(icon: "hammer.fill", tint: VoidPalette.projects, title: project.title, subtitle: project.status.rawValue) { ProjectDetailView(project: project) }
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete asset", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEditAsset) { EditAssetView(asset: asset) }
        .sheet(isPresented: $showingAddDocument) { AddDocumentView(initialAsset: asset) }
        .sheet(isPresented: $showingAddWarranty) { EditWarrantySheet(warranty: nil, presetAsset: asset) }
        .sheet(isPresented: $showingAddPlan) { EditPlanSheet(plan: nil, presetAsset: asset) }
        .sheet(isPresented: $showingAddLog) { EditMaintenanceLogSheet(record: nil, presetAsset: asset) }
        .sheet(isPresented: $showingAddTask) { EditTaskSheet(task: nil, presetAsset: asset) }
        .sheet(isPresented: $linkingProjects) {
            MultiLinkSheet(title: "Projects", options: allProjects, label: { $0.title },
                           isLinked: { p in asset.projects.contains { $0 === p } },
                           toggle: { p in
                               if let i = asset.projects.firstIndex(where: { $0 === p }) { asset.projects.remove(at: i) } else { asset.projects.append(p) }
                           })
        }
        .confirmationDialog("Delete this asset? Its warranties and maintenance history go with it. Documents are kept.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for w in asset.warranties { NotificationService.shared.cancelWarrantyReminder(for: w) }
                PhotoStore.delete(asset.photoFileName)
                modelContext.delete(asset)
                dismiss()
            }
        }
    }
}

// MARK: - Asset form fields (shared by Add and Edit)
private struct AssetFormFields: View {
    @Binding var name: String
    @Binding var category: String
    @Binding var manufacturer: String
    @Binding var model: String
    @Binding var serialNumber: String
    @Binding var purchaseDate: Date?
    @Binding var priceText: String
    @Binding var room: Room?
    @Binding var location: String
    @Binding var notes: String
    @Binding var photoFileName: String?
    var visibility: Binding<String>? = nil
    var createdBy: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                StoredPhotoView(fileName: photoFileName, icon: "camera.fill", tint: VoidPalette.assets)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 8) {
                    PhotoPickButton(onSaved: { name in photoFileName = name }) {
                        Label(photoFileName == nil ? "Add photo" : "Change photo", systemImage: "photo.on.rectangle")
                            .font(.system(size: 14, weight: .medium)).foregroundColor(VoidPalette.accent)
                    }
                    if photoFileName != nil {
                        Button("Remove photo") { photoFileName = nil }
                            .font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                    }
                }
                Spacer()
            }
            GlassTextField(title: "Name", text: $name, icon: "textformat", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
            GlassTextField(title: "Category", text: $category, icon: "cube.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
            GlassTextField(title: "Manufacturer", text: $manufacturer, icon: "building.2.fill", tint: Color(red: 0.4, green: 0.4, blue: 0.7))
            GlassTextField(title: "Model", text: $model, icon: "tag.fill", tint: Color(red: 0.45, green: 0.35, blue: 0.6))
            GlassTextField(title: "Serial Number", text: $serialNumber, icon: "number", tint: Color(red: 0.2, green: 0.55, blue: 0.7))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PURCHASE DATE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                        .tracking(1.5)
                    Spacer()
                    if purchaseDate != nil {
                        Button("Clear") { purchaseDate = nil }
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                if purchaseDate == nil {
                    Button("Add purchase date") { purchaseDate = Date() }
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                } else {
                    DatePicker("", selection: Binding(get: { purchaseDate ?? Date() }, set: { purchaseDate = $0 }), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
            )

            GlassTextField(title: "Purchase Price", text: $priceText, icon: Money.symbolName(filled: false), tint: Color(red: 0.3, green: 0.5, blue: 0.55), keyboardType: .decimalPad)

            RoomPickerField(selection: $room)

            GlassTextField(title: room == nil ? "Location" : "Spot in room (optional)", text: $location, icon: "location.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
            if let visibility {
                VisibilityField(raw: visibility, createdBy: createdBy, tint: VoidPalette.assets,
                                note: visibility.wrappedValue == Visibility.me.rawValue ? "Only you can see this. Its warranties and maintenance are private too." : "Everyone in the house can see this, with its warranties and maintenance.")
            }
        }
    }
}

// MARK: - Add Asset View
struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]

    @State private var name = ""
    @State private var category = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serialNumber = ""
    @State private var purchaseDate: Date?
    @State private var priceText = ""
    @State private var room: Room?
    @State private var location = ""
    @State private var notes = ""
    @State private var photoFileName: String?
    @State private var visibility = Visibility.house.rawValue

    init(initialRoom: Room? = nil) {
        _room = State(initialValue: initialRoom)
        // Items added to someone's own room start as theirs.
        if let owner = initialRoom?.ownerUid, !owner.isEmpty, owner == HouseContext.uid {
            _visibility = State(initialValue: Visibility.me.rawValue)
        }
    }

    var body: some View {
        ZStack {
            StarryBackground()
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
                            Text("ADD ASSET")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        AssetFormFields(name: $name, category: $category, manufacturer: $manufacturer, model: $model,
                                        serialNumber: $serialNumber, purchaseDate: $purchaseDate, priceText: $priceText,
                                        room: $room, location: $location, notes: $notes, photoFileName: $photoFileName,
                                        visibility: $visibility)
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
                            saveAsset()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(name.isEmpty || category.isEmpty)
                        .foregroundColor(name.isEmpty || category.isEmpty ? .white.opacity(0.3) : Color(red: 0.55, green: 0.3, blue: 0.6))
                    }
                }
            }
        }
    }

    private func saveAsset() {
        let asset = Asset(
            name: name,
            category: category,
            manufacturer: manufacturer,
            model: model,
            serialNumber: serialNumber,
            purchaseDate: purchaseDate,
            purchasePrice: Money.parse(priceText) ?? 0,
            location: location,
            notes: notes
        )
        modelContext.insert(asset)
        asset.room = room
        asset.photoFileName = photoFileName
        asset.visibilityRaw = visibility
        if let home = homes.first {
            home.assets.append(asset)
        }
    }
}

// MARK: - Edit Asset View
struct EditAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var asset: Asset
    @State private var priceText: String

    init(asset: Asset) {
        self.asset = asset
        _priceText = State(initialValue: Money.editString(asset.purchasePrice))
    }

    var body: some View {
        ZStack {
            StarryBackground()
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
                            Text("EDIT ASSET")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        AssetFormFields(name: $asset.name, category: $asset.category, manufacturer: $asset.manufacturer, model: $asset.model,
                                        serialNumber: $asset.serialNumber, purchaseDate: $asset.purchaseDate, priceText: $priceText,
                                        room: $asset.room, location: $asset.location, notes: $asset.notes, photoFileName: $asset.photoFileName,
                                        visibility: $asset.visibilityRaw, createdBy: asset.createdBy)
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
                        Button("Done") { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.55, green: 0.3, blue: 0.6))
                    }
                }
            }
        }
        .onChange(of: priceText) { _, newValue in
            asset.purchasePrice = Money.parse(newValue) ?? 0
        }
    }
}

