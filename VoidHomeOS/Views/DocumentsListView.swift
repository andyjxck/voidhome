import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing


extension DocumentType {
    var icon: String {
        switch self {
        case .manual: return "book.closed.fill"
        case .receipt: return "receipt"
        case .invoice: return "doc.text.fill"
        case .certificate: return "rosette"
        case .guarantee: return "checkmark.seal.fill"
        case .other: return "folder.fill"
        }
    }
    var folderColor: Color {
        switch self {
        case .manual: return Color(red: 0.35, green: 0.55, blue: 0.85)
        case .receipt: return Color(red: 0.4, green: 0.7, blue: 0.5)
        case .invoice: return Color(red: 0.85, green: 0.6, blue: 0.35)
        case .certificate: return Color(red: 0.7, green: 0.45, blue: 0.8)
        case .guarantee: return Color(red: 0.8, green: 0.45, blue: 0.5)
        case .other: return Color(red: 0.5, green: 0.5, blue: 0.6)
        }
    }
}

/// Documents as a filing cabinet: one coloured folder per type, with first-page previews.
struct DocumentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]
    @State private var showingAdd = false
    @State private var searchText = ""
    @State private var openFolder: DocumentType?

    private var filtered: [Document] {
        documents.filter { doc in
            (openFolder == nil || doc.type == openFolder) &&
            (searchText.isEmpty || doc.title.localizedCaseInsensitiveContains(searchText) || doc.ocrText.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VoidPage(subtitle: openFolder.map { "Documents · \($0.rawValue)" } ?? "Documents", addAction: { showingAdd = true }) {
            if !documents.isEmpty {
                VoidSearchField(prompt: "Search titles and text inside scans", text: $searchText)
            }

            if documents.isEmpty {
                EmptyStateView(icon: "doc.viewfinder", text: "Scan or import manuals, receipts and certificates. The text in scans is read so you can search it.", buttonTitle: "Add a document") { showingAdd = true }
            }

            if searchText.isEmpty && !documents.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                    ForEach(DocumentType.allCases, id: \.self) { type in
                        let count = documents.filter { $0.type == type }.count
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { openFolder = openFolder == type ? nil : type } }) {
                            FolderTile(type: type, count: count, isOpen: openFolder == type)
                        }
                        .buttonStyle(.plain)
                        .opacity(count == 0 ? 0.45 : 1)
                    }
                }
                .padding(.horizontal, 24)
            }

            let expiring = documents.filter { d in d.expiryDate.map { $0 > Date() && $0 < (Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date()) } ?? false }
            if !expiring.isEmpty && openFolder == nil && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    GlassSectionHeader(title: "Expiring soon")
                    ForEach(expiring) { doc in
                        LinkRow(icon: "calendar.badge.clock", tint: VoidPalette.amber, title: doc.title, subtitle: "Expires \(DayText.short(doc.expiryDate!))") { DocumentDetailView(document: doc) }
                    }
                }
                .padding(.horizontal, 24)
            }

            if !filtered.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    GlassSectionHeader(title: openFolder == nil && searchText.isEmpty ? "Recent" : "\(filtered.count) found")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(openFolder == nil && searchText.isEmpty ? Array(filtered.prefix(8)) : filtered) { doc in
                            NavigationLink(destination: DocumentDetailView(document: doc)) { DocumentCard(document: doc, highlight: searchText) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { deleteDocument(doc) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
                .padding(.horizontal, 24)
            } else if !documents.isEmpty && !searchText.isEmpty {
                EmptyStateView(icon: "magnifyingglass", text: "Nothing matches.")
            }
        }
        .sheet(isPresented: $showingAdd) { AddDocumentView() }
    }

    private func deleteDocument(_ doc: Document) {
        NotificationService.shared.cancelDocumentExpiryReminder(for: doc)
        doc.deleteStoredFile()
        modelContext.delete(doc)
    }
}

struct FolderTile: View {
    let type: DocumentType
    let count: Int
    let isOpen: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Image(systemName: isOpen ? "folder.fill.badge.minus" : "folder.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient(colors: [type.folderColor, type.folderColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                Image(systemName: type.icon).font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.9)).padding(.leading, 8).padding(.bottom, 8)
            }
            Text(type.rawValue).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
            Text("\(count)").font(.system(size: 11)).foregroundColor(VoidPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .voidCard(cornerRadius: 16, tint: isOpen ? type.folderColor : nil)
    }
}

/// First-page thumbnail of a stored file, made with QuickLook.
struct DocumentThumbnail: View {
    let document: Document
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [document.type.folderColor.opacity(0.35), document.type.folderColor.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                } else {
                    Image(systemName: document.type.icon).font(.system(size: 28, weight: .light)).foregroundColor(.white.opacity(0.8))
                }
            }
            .task(id: document.fileURL) { await load(size: geo.size) }
        }
    }

    private func load(size: CGSize) async {
        guard let url = document.localFileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: max(size.width, 120), height: max(size.height, 120)), scale: UIScreen.main.scale, representationTypes: .thumbnail)
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            await MainActor.run { image = rep.uiImage }
        }
    }
}

struct DocumentCard: View {
    let document: Document
    var highlight: String = ""

    /// A short piece of the scanned text around the search words.
    private var snippet: String? {
        let text = document.ocrText
        guard !highlight.isEmpty, let range = text.range(of: highlight, options: .caseInsensitive) else { return nil }
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
        return (start > text.startIndex ? "…" : "") + text[start..<end].replacingOccurrences(of: "\n", with: " ") + (end < text.endIndex ? "…" : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DocumentThumbnail(document: document).frame(height: 110).clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Circle().fill(document.type.folderColor).frame(width: 6, height: 6)
                    Text(document.type.rawValue).font(.system(size: 11)).foregroundColor(VoidPalette.muted)
                }
                if let snippet {
                    HighlightedText(text: snippet, highlight: highlight).font(.system(size: 11)).lineLimit(3)
                }
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .voidCard(cornerRadius: 16)
    }
}

/// Text with the matching words picked out.
struct HighlightedText: View {
    let text: String
    let highlight: String
    var body: some View {
        Text(attributed)
    }
    private var attributed: AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = VoidPalette.muted
        guard !highlight.isEmpty else { return result }
        var searchStart = result.startIndex
        while searchStart < result.endIndex, let range = result[searchStart...].range(of: highlight, options: .caseInsensitive) {
            result[range].foregroundColor = .white
            result[range].backgroundColor = VoidPalette.accent.opacity(0.45)
            searchStart = range.upperBound
        }
        return result
    }
}

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document
    @State private var showingEdit = false
    @State private var previewURL: URL?
    @State private var confirmDelete = false
    @State private var showText = false

    var body: some View {
        VoidPage(subtitle: "Document") {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: { if let url = document.localFileURL { previewURL = url } }) {
                    ZStack(alignment: .bottomTrailing) {
                        DocumentThumbnail(document: document)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        if document.localFileURL != nil {
                            Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                                .padding(10)
                        }
                    }
                }
                .buttonStyle(.plain)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.title).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        HStack(spacing: 6) {
                            TagLabel(text: document.type.rawValue, color: document.type.folderColor)
                            Text(DayText.short(document.createdAt)).font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                        }
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                VStack(spacing: 10) {
                    if let expiry = document.expiryDate {
                        GlassDetailCard(label: expiry < Date() ? "EXPIRED" : "EXPIRES", value: DayText.short(expiry), icon: "calendar.badge.clock", tint: VoidPalette.amber)
                    }
                }

                let linkCount = [document.asset == nil, document.room == nil, document.warranty == nil, document.bill == nil, document.project == nil, document.maintenance == nil].filter { !$0 }.count
                LinkedSection(title: "Linked", count: linkCount, addTitle: "Edit links", addAction: { showingEdit = true }) {
                    if let asset = document.asset {
                        LinkRow(icon: "cube.fill", tint: VoidPalette.assets, title: asset.name, subtitle: "Asset") { AssetDetailView(asset: asset) }
                    }
                    if let room = document.room {
                        LinkRow(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, title: room.name, subtitle: "Room") { RoomDetailView(room: room) }
                    }
                    if let warranty = document.warranty {
                        LinkRow(icon: "shield.fill", tint: VoidPalette.warranties, title: warranty.asset?.name ?? warranty.provider, subtitle: "Warranty") { WarrantyDetailView(warranty: warranty) }
                    }
                    if let bill = document.bill {
                        LinkRow(icon: "creditcard.fill", tint: VoidPalette.bills, title: bill.name, subtitle: "Bill") { BillDetailView(bill: bill) }
                    }
                    if let project = document.project {
                        LinkRow(icon: "hammer.fill", tint: VoidPalette.projects, title: project.title, subtitle: "Project") { ProjectDetailView(project: project) }
                    }
                    if let record = document.maintenance {
                        LinkRow(icon: "wrench.and.screwdriver.fill", tint: VoidPalette.maintenance, title: record.task, subtitle: "Maintenance") { MaintenanceDetailView(maintenance: record) }
                    }
                }

                let text = document.ocrText
                if !text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation { showText.toggle() } }) {
                            HStack {
                                GlassSectionHeader(title: "Text read from the scan")
                                Image(systemName: showText ? "chevron.up" : "chevron.down").foregroundColor(VoidPalette.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        if showText {
                            Text(text).font(.system(size: 13)).foregroundColor(.white.opacity(0.85)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(14).voidCard(cornerRadius: 14)
                        }
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete document", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditDocumentView(document: document) }
        .quickLookPreview($previewURL)
        .confirmationDialog("Delete this document and its file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelDocumentExpiryReminder(for: document)
                document.deleteStoredFile()
                modelContext.delete(document)
                dismiss()
            }
        }
    }
}

/// Optional links and expiry date for the add and edit document forms.
struct DocumentExtraLinksFields: View {
    @Binding var warranty: Warranty?
    @Binding var bill: Bill?
    @Binding var project: Project?
    @Binding var maintenance: Maintenance?
    @Binding var expiryDate: Date?
    @Query(sort: \Warranty.provider) private var warranties: [Warranty]
    @Query(sort: \Bill.name) private var bills: [Bill]
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Maintenance.date, order: .reverse) private var records: [Maintenance]

    var body: some View {
        VStack(spacing: 14) {
            MenuPickerField(title: "Warranty", selection: $warranty, options: warranties) { w in w.asset.map { "\($0.name) · \(w.provider)" } ?? w.provider }
            MenuPickerField(title: "Bill", selection: $bill, options: bills) { $0.name }
            MenuPickerField(title: "Project", selection: $project, options: projects) { $0.title }
            MenuPickerField(title: "Maintenance", selection: $maintenance, options: records) { "\($0.task) · \(DayText.short($0.date))" }
            OptionalDateField(title: "Expiry date (e.g. gas safety)", date: $expiryDate)
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - QuickLook Preview Sheet
struct DocumentPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DocumentPreviewView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    }
                }
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - QuickLook Preview
struct DocumentPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as NSURL
        }
    }
}

struct AddDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: DocumentType = .manual
    @State private var ocrText = ""
    @State private var showingFilePicker = false
    @State private var pickedFileURL: URL?
    @State private var pickedFileName: String?
    @State private var selectedAsset: Asset?
    @State private var selectedRoom: Room?
    @State private var selectedWarranty: Warranty?
    @State private var selectedBill: Bill?
    @State private var selectedProject: Project?
    @State private var selectedMaintenance: Maintenance?
    @State private var expiryDate: Date?

    // Scanning and text reading
    @State private var showingScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var isReadingText = false
    @State private var receiptInfo: ReceiptInfo?
    @State private var applyReceiptToAsset = true

    init(initialAsset: Asset? = nil, initialRoom: Room? = nil) {
        _selectedAsset = State(initialValue: initialAsset)
        _selectedRoom = State(initialValue: initialRoom ?? initialAsset?.room)
    }

    private var hasAttachment: Bool { pickedFileURL != nil || !scannedImages.isEmpty }

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
                            Text("ADD DOCUMENT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Title", text: $title, icon: "textformat", tint: Color(red: 0.2, green: 0.55, blue: 0.7))

                            HStack(spacing: 12) {
                                if DocumentScanner.isSupported {
                                    attachButton(
                                        icon: scannedImages.isEmpty ? "doc.viewfinder" : "checkmark.circle.fill",
                                        title: scannedImages.isEmpty ? "Scan" : "\(scannedImages.count) page\(scannedImages.count == 1 ? "" : "s")",
                                        done: !scannedImages.isEmpty
                                    ) { showingScanner = true }
                                }
                                attachButton(
                                    icon: pickedFileName != nil ? "checkmark.circle.fill" : "arrow.up.doc.fill",
                                    title: pickedFileName ?? "Upload File",
                                    done: pickedFileName != nil
                                ) { showingFilePicker = true }
                            }

                            if !DocumentScanner.isSupported {
                                Text("Scanning needs a device camera. You can still upload a file or photo.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if isReadingText {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Reading text…")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("TYPE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                Picker("", selection: $type) {
                                    ForEach(DocumentType.allCases, id: \.self) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            )

                            AssetPickerField(selection: $selectedAsset)
                                .onChange(of: selectedAsset) { _, asset in
                                    if selectedRoom == nil, let room = asset?.room { selectedRoom = room }
                                }
                            RoomPickerField(selection: $selectedRoom)
                            DocumentExtraLinksFields(warranty: $selectedWarranty, bill: $selectedBill, project: $selectedProject, maintenance: $selectedMaintenance, expiryDate: $expiryDate)

                            if type == .receipt, let info = receiptInfo, info.total > 0 || info.date != nil || !info.retailer.isEmpty {
                                receiptCard(info)
                            }

                            GlassTextField(title: "Text (read automatically, editable)", text: $ocrText, icon: "text.viewfinder", tint: Color(red: 0.35, green: 0.3, blue: 0.65), isMultiline: true)
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
                        Button("Save") { saveDocument(); dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .disabled(title.isEmpty)
                            .foregroundColor(title.isEmpty ? .white.opacity(0.3) : Color(red: 0.2, green: 0.55, blue: 0.7))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .image, .jpeg, .png, .plainText, .rtf, .data, .archive, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                pickedFileURL = url
                pickedFileName = url.lastPathComponent
                scannedImages = []
                if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
                readText(fromPicked: url)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView(isPresented: $showingScanner, scannedImages: $scannedImages)
                .ignoresSafeArea()
        }
        .onChange(of: scannedImages.count) { _, count in
            guard count > 0 else { return }
            pickedFileURL = nil
            pickedFileName = nil
            if title.isEmpty { title = "Scan \(Date().formatted(date: .abbreviated, time: .omitted))" }
            readText(fromImages: scannedImages)
        }
        .onChange(of: type) { _, _ in updateReceiptInfo() }
    }

    private func attachButton(icon: String, title: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(done ? Color.green : Color(red: 0.2, green: 0.55, blue: 0.7))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            )
        }
    }

    private func receiptCard(_ info: ReceiptInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassSectionHeader(title: "Receipt details found")
            if !info.retailer.isEmpty {
                Text("Shop: \(info.retailer)").font(.system(size: 14)).foregroundColor(.white)
            }
            if let date = info.date {
                Text("Date: \(date.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 14)).foregroundColor(.white)
            }
            if info.total > 0 {
                Text("Total: \(Money.format(info.total))").font(.system(size: 14)).foregroundColor(.white)
            }
            if let asset = selectedAsset {
                Toggle(isOn: $applyReceiptToAsset) {
                    Text("Use for \(asset.name)'s price and purchase date where they're empty")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
    }

    private func readText(fromPicked url: URL) {
        isReadingText = true
        Task {
            let didAccess = url.startAccessingSecurityScopedResource()
            let text = await OCRService.extractText(fromFileAt: url)
            if didAccess { url.stopAccessingSecurityScopedResource() }
            await MainActor.run {
                if ocrText.isEmpty { ocrText = text }
                isReadingText = false
                updateReceiptInfo()
            }
        }
    }

    private func readText(fromImages images: [UIImage]) {
        isReadingText = true
        Task {
            let text = await OCRService.recognizeText(from: images)
            await MainActor.run {
                if ocrText.isEmpty { ocrText = text }
                isReadingText = false
                updateReceiptInfo()
            }
        }
    }

    private func updateReceiptInfo() {
        receiptInfo = (type == .receipt && !ocrText.isEmpty) ? OCRService.extractReceiptInfo(from: ocrText) : nil
    }

    private func saveDocument() {
        var savedPath = ""
        if let url = pickedFileURL {
            savedPath = DocumentStorage.importFile(from: url) ?? ""
        } else if !scannedImages.isEmpty, let pdf = DocumentScanner.makePDF(from: scannedImages) {
            savedPath = DocumentStorage.write(pdf, baseName: title, ext: "pdf") ?? ""
        }

        let document = Document(title: title, type: type, fileURL: savedPath, ocrText: ocrText)
        document.asset = selectedAsset
        document.room = selectedRoom
        modelContext.insert(document)
        document.warranty = selectedWarranty
        document.bill = selectedBill
        document.project = selectedProject
        document.maintenance = selectedMaintenance
        document.expiryDate = expiryDate
        NotificationService.shared.syncDocumentExpiryReminder(for: document)

        if type == .receipt, applyReceiptToAsset, let asset = selectedAsset, let info = receiptInfo {
            if asset.purchasePrice == 0, info.total > 0 { asset.purchasePrice = info.total }
            if asset.purchaseDate == nil, let date = info.date { asset.purchaseDate = date }
        }
    }
}


// MARK: - Edit Document View
struct EditDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document
    @State private var isReadingText = false

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
                            Text("EDIT DOCUMENT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Title", text: $document.title, icon: "textformat", tint: Color(red: 0.2, green: 0.55, blue: 0.7))

                            if let url = document.localFileURL {
                                GlassDetailCard(label: "File", value: url.lastPathComponent, icon: "paperclip", tint: Color(red: 0.3, green: 0.5, blue: 0.55))
                                Button {
                                    isReadingText = true
                                    Task {
                                        let text = await OCRService.extractText(fromFileAt: url)
                                        await MainActor.run {
                                            if !text.isEmpty { document.ocrText = text }
                                            isReadingText = false
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isReadingText { ProgressView().tint(.white) } else { Image(systemName: "text.viewfinder") }
                                        Text(isReadingText ? "Reading text…" : "Read text from file again")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
                                }
                                .disabled(isReadingText)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("TYPE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(1.5)
                                Picker("", selection: $document.type) {
                                    ForEach(DocumentType.allCases, id: \.self) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            )

                            AssetPickerField(selection: $document.asset)
                            RoomPickerField(selection: $document.room)
                            DocumentExtraLinksFields(warranty: $document.warranty, bill: $document.bill, project: $document.project, maintenance: $document.maintenance, expiryDate: $document.expiryDate)

                            GlassTextField(title: "Text", text: $document.ocrText, icon: "text.viewfinder", tint: Color(red: 0.35, green: 0.3, blue: 0.65), isMultiline: true)
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
                            NotificationService.shared.syncDocumentExpiryReminder(for: document)
                            dismiss()
                        }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.55, blue: 0.7))
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DocumentsListView()
    }
    .modelContainer(for: [Document.self, Asset.self], inMemory: true)
}

/// Compact document row used inside other pages.
struct DocumentRow: View {
    let document: Document
    var body: some View {
        HStack(spacing: 12) {
            DocumentThumbnail(document: document)
                .frame(width: 44, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineLimit(1)
                Text([document.type.rawValue, DayText.short(document.createdAt)].joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(VoidPalette.faint)
        }
        .padding(12)
        .voidCard(cornerRadius: 14)
    }
}
