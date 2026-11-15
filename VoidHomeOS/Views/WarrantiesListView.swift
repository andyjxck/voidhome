import SwiftUI
import SwiftData

struct WarrantiesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Warranty.expiryDate) private var warranties: [Warranty]
    @State private var showingAddWarranty = false
    @State private var searchText = ""
    
    var filteredWarranties: [Warranty] {
        if searchText.isEmpty {
            return warranties
        }
        return warranties.filter { warranty in
            warranty.provider.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for WarrantiesListView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.85, blue: 0.9), Color(red: 0.95, green: 0.9, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    HStack(alignment: .top) {
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
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("WARRANTIES")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddWarranty = true }) {
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
                        TextField("Search warranties", text: $searchText)
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
                        if filteredWarranties.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.6))
                                Text("No warranties yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Button(action: { showingAddWarranty = true }) {
                                    Text("Add Warranty")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.35, green: 0.25, blue: 0.6)))
                                }
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredWarranties) { warranty in
                                NavigationLink(destination: WarrantyDetailView(warranty: warranty)) {
                                    WarrantyRow(warranty: warranty)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            NotificationService.shared.cancelWarrantyReminder(for: warranty)
                                            modelContext.delete(warranty)
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
            .sheet(isPresented: $showingAddWarranty) {
                AddWarrantyView()
            }
        }
        .navigationBarHidden(true)
    }
}

struct WarrantyRow: View {
    let warranty: Warranty

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
                Image(systemName: "shield.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(warranty.isExpired ? Color.red.opacity(0.8) : Color(red: 0.45, green: 0.3, blue: 0.6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(warranty.provider)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                if let asset = warranty.asset {
                    Text(asset.name)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(warranty.expiryDate, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(warranty.isExpired ? .red : Color(red: 0.6, green: 0.55, blue: 0.7))
                if warranty.isExpired {
                    Text("EXPIRED")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                        .tracking(0.5)
                } else if let days = warranty.daysUntilExpiry, days <= 30 {
                    Text("\(days)d left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
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

struct WarrantyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var warranty: Warranty
    @State private var showingEditWarranty = false
    
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
                            Text("WARRANTY")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditWarranty = true }) {
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
                        GlassDetailCard(label: "Provider", value: warranty.provider, icon: "shield.fill", tint: Color(red: 0.45, green: 0.3, blue: 0.6))
                        GlassDetailCard(label: "Start Date", value: warranty.startDate.formatted(.dateTime.day().month().year()), icon: "calendar", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                        GlassDetailCard(label: "Expiry Date", value: warranty.expiryDate.formatted(.dateTime.day().month().year()), icon: "calendar.badge.exclamationmark", tint: warranty.isExpired ? Color.red : Color(red: 0.2, green: 0.55, blue: 0.4))

                        if let asset = warranty.asset {
                            GlassDetailCard(label: "Linked Asset", value: asset.name, icon: "cube.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                        }

                        if let days = warranty.daysUntilExpiry {
                            HStack(spacing: 12) {
                                Image(systemName: warranty.isExpired ? "exclamationmark.triangle.fill" : (days <= 30 ? "clock.fill" : "checkmark.circle.fill"))
                                    .foregroundColor(warranty.isExpired ? .red : (days <= 30 ? .orange : .green))
                                Text(warranty.isExpired ? "This warranty has expired" : (days <= 30 ? "Expires in \(days) days" : "Valid for \(days) more days"))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(warranty.isExpired ? .red : (days <= 30 ? .orange : .green))
                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.02))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            )
                        }

                        if !warranty.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NOTES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(2)
                                Text(warranty.notes)
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
            .sheet(isPresented: $showingEditWarranty, onDismiss: {
                // Edits apply live, so reschedule (or cancel) the reminder from the warranty's current values.
                NotificationService.shared.syncWarrantyReminder(for: warranty)
            }) {
                EditWarrantyView(warranty: warranty)
            }
        }
        .navigationBarHidden(true)
    }
}

struct AddWarrantyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Asset.name) private var assets: [Asset]
    
    @State private var provider = ""
    @State private var startDate = Date()
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var selectedAsset: Asset?
    @State private var notes = ""
    @State private var enableReminder = true
    
    var body: some View {
        ZStack {
            // Unique starry background for AddWarrantyView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.85, blue: 0.9), Color(red: 0.95, green: 0.9, blue: 1.0)].randomElement()!
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
                            Text("ADD WARRANTY")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Provider", text: $provider, icon: "shield.fill", tint: Color(red: 0.45, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: Color(red: 0.55, green: 0.35, blue: 0.35), isMultiline: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("START DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("EXPIRY DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
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

                            Toggle(isOn: $enableReminder) {
                                Text("Set Expiry Reminder")
                                    .font(.system(size: 15))
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
                        Button("Save") { saveWarranty(); dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .disabled(provider.isEmpty)
                            .foregroundColor(provider.isEmpty ? .white.opacity(0.3) : Color(red: 0.45, green: 0.3, blue: 0.6))
                    }
                }
            }
        }
    }
    
    private func saveWarranty() {
        let warranty = Warranty(provider: provider, startDate: startDate, expiryDate: expiryDate, notes: notes)
        
        if let asset = selectedAsset {
            asset.warranties.append(warranty)
            warranty.asset = asset
        }
        
        warranty.remindersEnabled = enableReminder
        modelContext.insert(warranty)
        NotificationService.shared.syncWarrantyReminder(for: warranty)
    }
}

struct EditWarrantyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @Bindable var warranty: Warranty
    @State private var selectedAsset: Asset?
    
    init(warranty: Warranty) {
        self.warranty = warranty
        _selectedAsset = State(initialValue: warranty.asset)
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for EditWarrantyView
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
                            Text("EDIT WARRANTY")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Provider", text: $warranty.provider, icon: "shield.fill", tint: Color(red: 0.45, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Notes", text: $warranty.notes, icon: "note.text", tint: Color(red: 0.55, green: 0.35, blue: 0.35), isMultiline: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("START DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $warranty.startDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("EXPIRY DATE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                DatePicker("", selection: $warranty.expiryDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            Toggle(isOn: $warranty.remindersEnabled) {
                                Text("Expiry Reminder")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
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
                                    if let oldAsset = warranty.asset {
                                        oldAsset.warranties.removeAll { $0 == warranty }
                                    }
                                    warranty.asset = newAsset
                                    if let newAsset = newAsset {
                                        newAsset.warranties.append(warranty)
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
                            .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.6))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WarrantiesListView()
    }
}