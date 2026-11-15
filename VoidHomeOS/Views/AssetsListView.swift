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
                        
                        if !asset.serialNumber.isEmpty {
                            GlassDetailCard(label: "Serial Number", value: asset.serialNumber, icon: "number", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                        }
                        
                        if let purchaseDate = asset.purchaseDate {
                            GlassDetailCard(label: "Purchase Date", value: formatDate(purchaseDate), icon: "calendar", tint: Color(red: 0.65, green: 0.4, blue: 0.35))
                        }

                        
                        if asset.purchasePrice > 0 {
                            GlassDetailCard(label: "Purchase Price", value: String(format: "$%.2f", asset.purchasePrice), icon: "dollarsign.circle", tint: Color(red: 0.3, green: 0.5, blue: 0.55))
                        }
                        
                        if !asset.location.isEmpty {
                            GlassDetailCard(label: "Location", value: asset.location, icon: "location.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
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
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingEditAsset) {
                EditAssetView(asset: asset)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Add Asset View
struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    
    @State private var name = ""
    @State private var category = ""
    @State private var serialNumber = ""
    @State private var purchaseDate: Date?
    @State private var purchasePrice: Double = 0.0
    @State private var location = ""
    @State private var notes = ""
    @State private var showingScanner = false
    @State private var scannedResult: String?
    private var safePurchaseDateBinding: Binding<Date> {
        Binding(
            get: { purchaseDate ?? Date() },
            set: { purchaseDate = $0 }
        )
    }

    var body: some View {
        ZStack {
            // Unique starry background for AddAssetView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 0.9, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.95, blue: 0.85)].randomElement()!
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
                            
                            Text("ADD ASSET")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $name, icon: "textformat", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Category", text: $category, icon: "cube.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            GlassTextField(title: "Serial Number", text: $serialNumber, icon: "number", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PURCHASE DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: safePurchaseDateBinding, displayedComponents: .date)
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

                            
                            GlassTextField(title: "Purchase Price", text: Binding(
                                get: { String(format: "%.2f", purchasePrice) },
                                set: { purchasePrice = Double($0) ?? 0.0 }
                            ), icon: "dollarsign.circle", tint: Color(red: 0.3, green: 0.5, blue: 0.55), keyboardType: .decimalPad)
                            
                            GlassTextField(title: "Location", text: $location, icon: "location.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
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
            serialNumber: serialNumber,
            purchaseDate: purchaseDate,
            purchasePrice: purchasePrice,
            location: location,
            notes: notes
        )
        if let home = homes.first {
            home.assets.append(asset)
        }
        modelContext.insert(asset)
    }
}

// MARK: - Edit Asset View
struct EditAssetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var asset: Asset
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
       
    var body: some View {
        ZStack {
            // Unique starry background for EditAssetView
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
                        // Header
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
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $asset.name, icon: "textformat", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Category", text: $asset.category, icon: "cube.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            GlassTextField(title: "Serial Number", text: $asset.serialNumber, icon: "number", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PURCHASE DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                
                                DatePicker("", selection: Binding(get: { asset.purchaseDate ?? Date() }, set: { asset.purchaseDate = $0 }), displayedComponents: .date)
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
                            
                            GlassTextField(title: "Purchase Price", text: Binding(
                                get: { String(format: "%.2f", asset.purchasePrice) },
                                set: { asset.purchasePrice = Double($0) ?? 0.0 }
                            ), icon: "dollarsign.circle", tint: Color(red: 0.3, green: 0.5, blue: 0.55), keyboardType: .decimalPad)
                            
                            GlassTextField(title: "Location", text: $asset.location, icon: "location.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
                            GlassTextField(title: "Notes", text: $asset.notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
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
                            .foregroundColor(Color(red: 0.55, green: 0.3, blue: 0.6))
                    }
                }
            }
        }
    }
}
