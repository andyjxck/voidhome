import SwiftUI
import SwiftData

struct AssetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Asset.name) private var assets: [Asset]
    @State private var showingAddAsset = false
    
    var body: some View {
        ZStack {
            // Unique starry background for AssetsListView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.8, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.95, blue: 0.85)].randomElement()!
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
                            
                            Text("ASSETS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddAsset = true }) {
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
                    
                    // Assets list with glassmorphic rows
                    VStack(spacing: 12) {
                        ForEach(assets) { asset in
                            NavigationLink(destination: AssetDetailView(asset: asset)) {
                                AssetRow(asset: asset)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        NotificationService.shared.cancelReminders(forAssetBeingDeleted: asset)
                                        modelContext.delete(asset)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if assets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cube")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                
                                Text("No assets yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                
                                Button(action: { showingAddAsset = true }) {
                                    Text("Add Asset")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(red: 0.55, green: 0.3, blue: 0.6))
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
            .sheet(isPresented: $showingAddAsset) {
                AddAssetView()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Asset Detail View
struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var asset: Asset
    @State private var showingEditAsset = false
    @State private var showingAddDocument = false
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
       
    var body: some View {
        ZStack {
            // Unique starry background for AssetDetailView
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
                            
                            Text("ASSET")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditAsset = true }) {
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
                    
                    // Asset details with glassmorphic cards
                    VStack(spacing: 16) {
                        GlassDetailCard(label: "Name", value: asset.name, icon: "textformat", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                        GlassDetailCard(label: "Category", value: asset.category, icon: "cube.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))

                        if !asset.manufacturer.isEmpty {
                            GlassDetailCard(label: "Manufacturer", value: asset.manufacturer, icon: "building.2.fill", tint: Color(red: 0.4, green: 0.4, blue: 0.7))
                        }

                        if !asset.model.isEmpty {
                            GlassDetailCard(label: "Model", value: asset.model, icon: "tag.fill", tint: Color(red: 0.45, green: 0.35, blue: 0.6))
                        }

                        if let room = asset.room {
                            NavigationLink(destination: RoomDetailView(room: room)) {
                                GlassDetailCard(label: "Room", value: "\(room.name) · \(room.floorDisplay)", icon: "square.split.bottomrightquarter", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if !asset.serialNumber.isEmpty {
                            GlassDetailCard(label: "Serial Number", value: asset.serialNumber, icon: "number", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                        }
                        
                        if let purchaseDate = asset.purchaseDate {
                            GlassDetailCard(label: "Purchase Date", value: formatDate(purchaseDate), icon: "calendar", tint: Color(red: 0.65, green: 0.4, blue: 0.35))
                        }

                        
                        if asset.purchasePrice > 0 {
                            GlassDetailCard(label: "Purchase Price", value: Money.format(asset.purchasePrice), icon: Money.symbolName(filled: false), tint: Color(red: 0.3, green: 0.5, blue: 0.55))
                        }
                        
                        if !asset.location.isEmpty {
                            GlassDetailCard(label: asset.room == nil ? "Location" : "Spot in Room", value: asset.location, icon: "location.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
                        }
                        
                        if !asset.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NOTES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(2)
                                
                                Text(asset.notes)
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
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Warranties section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WARRANTIES (\(asset.warranties.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .tracking(2)
                            .padding(.horizontal, 24)
                        
                        if asset.warranties.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                
                                Text("No warranties for this asset")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            }
                            .padding(.vertical, 30)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(asset.warranties) { warranty in
                                    NavigationLink(destination: WarrantyDetailView(warranty: warranty)) {
                                        WarrantyRow(warranty: warranty)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)

                    // Documents section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("DOCUMENTS (\(asset.documents.count))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .tracking(2)
                            Spacer()
                            Button(action: { showingAddDocument = true }) {
                                Label("Add", systemImage: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 24)

                        if asset.documents.isEmpty {
                            Text("No documents linked. Add a manual, receipt or invoice.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(asset.documents.sorted { $0.createdAt > $1.createdAt }) { document in
                                    NavigationLink(destination: DocumentDetailView(document: document)) {
                                        DocumentRow(document: document)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)

                    // Maintenance section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MAINTENANCE (\(asset.maintenanceRecords.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .tracking(2)
                            .padding(.horizontal, 24)

                        if asset.maintenanceRecords.isEmpty {
                            Text("No maintenance logged for this asset")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .padding(.horizontal, 24)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(asset.maintenanceRecords.sorted { $0.date > $1.date }) { record in
                                    NavigationLink(destination: MaintenanceDetailView(maintenance: record)) {
                                        MaintenanceRow(maintenance: record)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingEditAsset) {
                EditAssetView(asset: asset)
            }
            .sheet(isPresented: $showingAddDocument) {
                AddDocumentView(initialAsset: asset)
            }
        }
        .navigationBarHidden(true)
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

    var body: some View {
        VStack(spacing: 16) {
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

    init(initialRoom: Room? = nil) {
        _room = State(initialValue: initialRoom)
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
                                        room: $room, location: $location, notes: $notes)
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
                                        room: $asset.room, location: $asset.location, notes: $asset.notes)
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

