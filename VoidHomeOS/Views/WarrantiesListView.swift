import SwiftUI
import SwiftData

/// Warranties as shield cards with a countdown bar, grouped Active / Ending soon / Expired.
struct WarrantiesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Warranty.expiryDate) private var warranties: [Warranty]
    @State private var showingAdd = false
    @State private var searchText = ""

    private var filtered: [Warranty] {
        guard !searchText.isEmpty else { return warranties }
        return warranties.filter {
            $0.provider.localizedCaseInsensitiveContains(searchText) || ($0.asset?.name ?? "").localizedCaseInsensitiveContains(searchText) || $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VoidPage(subtitle: "Warranties", addAction: { showingAdd = true }) {
            if !warranties.isEmpty {
                HStack(spacing: 12) {
                    StatTile(icon: "checkmark.shield.fill", tint: VoidPalette.done, value: "\(warranties.filter { $0.status == .active }.count)", label: "Active")
                    StatTile(icon: "hourglass", tint: VoidPalette.amber, value: "\(warranties.filter { $0.status == .endingSoon }.count)", label: "Ending within 60 days")
                    StatTile(icon: "shield.slash", tint: VoidPalette.muted, value: "\(warranties.filter { $0.status == .expired }.count)", label: "Expired")
                }
                .padding(.horizontal, 24)
                VoidSearchField(prompt: "Search warranties", text: $searchText)
            }

            VStack(alignment: .leading, spacing: 12) {
                if filtered.isEmpty {
                    EmptyStateView(icon: "shield.lefthalf.filled", text: warranties.isEmpty ? "Keep warranties with their receipts, and get a reminder 30 days before they end." : "Nothing matches.", buttonTitle: warranties.isEmpty ? "Add a warranty" : nil) { showingAdd = true }
                }
                ForEach([Warranty.Status.endingSoon, .active, .expired], id: \.self) { status in
                    let group = filtered.filter { $0.status == status }
                    if !group.isEmpty {
                        GlassSectionHeader(title: status.rawValue).padding(.top, 4)
                        ForEach(group) { warranty in
                            NavigationLink(destination: WarrantyDetailView(warranty: warranty)) { WarrantyRow(warranty: warranty) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        NotificationService.shared.cancelWarrantyReminder(for: warranty)
                                        modelContext.delete(warranty)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAdd) { EditWarrantySheet(warranty: nil) }
    }
}

struct WarrantyRow: View {
    let warranty: Warranty

    private var tint: Color {
        switch warranty.status {
        case .active: return VoidPalette.done
        case .endingSoon: return VoidPalette.amber
        case .expired: return VoidPalette.muted
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "shield.fill").font(.system(size: 34)).foregroundColor(tint.opacity(0.25))
                Image(systemName: warranty.status == .expired ? "xmark" : "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(tint)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(warranty.asset?.name ?? warranty.provider).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text(countdownText).font(.system(size: 12, weight: .medium)).foregroundColor(tint)
                }
                Text(warranty.asset == nil ? "Ends \(DayText.short(warranty.expiryDate))" : "\(warranty.provider) · ends \(DayText.short(warranty.expiryDate))")
                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(tint.opacity(0.8)).frame(width: geo.size.width * warranty.remainingFraction)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(14)
        .voidCard(cornerRadius: 16)
    }

    private var countdownText: String {
        guard let days = warranty.daysUntilExpiry, days >= 0 else { return "Expired" }
        if days == 0 { return "Ends today" }
        if days < 60 { return "\(days) days left" }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: warranty.expiryDate).month ?? 0
        return months >= 24 ? "\(months / 12) years left" : "\(months) months left"
    }
}

struct WarrantyDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var warranty: Warranty
    @Query(sort: \Document.title) private var allDocuments: [Document]
    @State private var showingEdit = false
    @State private var linkingDocs = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Warranty") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(warranty.asset?.name ?? warranty.provider).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        HStack(spacing: 6) {
                            TagLabel(text: warranty.status.rawValue, color: warranty.status == .active ? VoidPalette.done : (warranty.status == .endingSoon ? VoidPalette.amber : VoidPalette.muted))
                            Text(warranty.provider).font(.system(size: 13)).foregroundColor(VoidPalette.muted)
                        }
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                WarrantyRow(warranty: warranty)

                VStack(spacing: 10) {
                    GlassDetailCard(label: "COVER", value: "\(DayText.short(warranty.startDate)) to \(DayText.short(warranty.expiryDate))", icon: "calendar", tint: VoidPalette.warranties)
                    if !warranty.claimContact.isEmpty {
                        GlassDetailCard(label: "TO CLAIM", value: warranty.claimContact, icon: "phone.bubble.fill", tint: VoidPalette.calm)
                    }
                    GlassDetailCard(label: "REMINDERS", value: warranty.remindersEnabled ? "30 days before and on the day" : "Off", icon: "bell.fill", tint: VoidPalette.muted)
                    if !warranty.notes.isEmpty { GlassDetailCard(label: "NOTES", value: warranty.notes, icon: "note.text", tint: VoidPalette.muted) }
                }

                LinkedSection(title: "Asset", count: warranty.asset == nil ? 0 : 1) {
                    if let asset = warranty.asset {
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: asset.room?.name ?? asset.category) { AssetDetailView(asset: asset) }
                    }
                }

                LinkedSection(title: "Receipt & documents", count: warranty.documents.count, addTitle: "Link", addAction: { linkingDocs = true }) {
                    ForEach(warranty.documents) { doc in
                        LinkRow(icon: "doc.fill", tint: VoidPalette.documents, title: doc.title, subtitle: doc.type.rawValue) { DocumentDetailView(document: doc) }
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete warranty", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditWarrantySheet(warranty: warranty) }
        .sheet(isPresented: $linkingDocs) {
            MultiLinkSheet(title: "Documents", options: allDocuments, label: { $0.title },
                           isLinked: { $0.warranty === warranty },
                           toggle: { doc in doc.warranty = (doc.warranty === warranty) ? nil : warranty })
        }
        .confirmationDialog("Delete this warranty?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelWarrantyReminder(for: warranty)
                modelContext.delete(warranty)
                dismiss()
            }
        }
    }
}

struct EditWarrantySheet: View {
    let warranty: Warranty?
    var presetAsset: Asset? = nil
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]
    @State private var provider = ""
    @State private var startDate = Date()
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var asset: Asset?
    @State private var claimContact = ""
    @State private var notes = ""
    @State private var reminders = true
    @State private var loaded = false

    var body: some View {
        FormSheet(title: warranty == nil ? "New warranty" : "Edit warranty", canSave: !provider.trimmingCharacters(in: .whitespaces).isEmpty && expiryDate >= startDate, onSave: save) {
            GlassTextField(title: "Provider", text: $provider, icon: "building.2.fill", tint: VoidPalette.warranties)
            MenuPickerField(title: "Asset", selection: $asset, options: assets) { $0.name }
            DateField(title: "Starts", date: $startDate)
            DateField(title: "Ends", date: $expiryDate)
            HStack(spacing: 8) {
                ForEach([1, 2, 3, 5], id: \.self) { years in
                    Button("\(years) yr") { expiryDate = Calendar.current.date(byAdding: .year, value: years, to: startDate) ?? expiryDate }
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                }
            }
            GlassTextField(title: "Claim contact (phone, email or website)", text: $claimContact, icon: "phone.bubble.fill", tint: VoidPalette.calm)
            Toggle("Remind me 30 days before and on the day", isOn: $reminders).tint(VoidPalette.warranties).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.muted, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let warranty {
                provider = warranty.provider; startDate = warranty.startDate; expiryDate = warranty.expiryDate
                asset = warranty.asset; claimContact = warranty.claimContact; notes = warranty.notes; reminders = warranty.remindersEnabled
            } else {
                asset = presetAsset
                if let date = presetAsset?.purchaseDate {
                    startDate = date
                    expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? expiryDate
                }
            }
        }
    }

    private func save() {
        let target = warranty ?? Warranty(provider: provider, startDate: startDate, expiryDate: expiryDate, notes: notes)
        if warranty == nil { modelContext.insert(target) }
        target.provider = provider.trimmingCharacters(in: .whitespaces)
        target.startDate = startDate
        target.expiryDate = expiryDate
        target.asset = asset
        target.claimContact = claimContact
        target.notes = notes
        target.remindersEnabled = reminders
        try? modelContext.save()
        NotificationService.shared.syncWarrantyReminder(for: target)
    }
}
