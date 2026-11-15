import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook

struct DocumentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Document.title) private var documents: [Document]
    @State private var showingAddDocument = false
    @State private var searchText = ""
    @State private var previewURL: URL?

    var filteredDocuments: [Document] {
        if searchText.isEmpty { return documents }
        return documents.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.type.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            StarryBackground()
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
                            Text("DOCUMENTS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddDocument = true }) {
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
                        TextField("Search documents", text: $searchText)
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
                        if filteredDocuments.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.6))
                                Text("No documents yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Button(action: { showingAddDocument = true }) {
                                    Text("Upload Document")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.2, green: 0.45, blue: 0.65)))
                                }
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(filteredDocuments) { document in
                                NavigationLink(destination: DocumentDetailView(document: document)) {
                                    DocumentRow(document: document)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    if let url = document.localFileURL {
                                        Button {
                                            previewURL = url
                                        } label: {
                                            Label("View File", systemImage: "eye")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        withAnimation {
                                            document.deleteStoredFile()
                                            modelContext.delete(document)
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
            .sheet(isPresented: $showingAddDocument) {
                AddDocumentView()
            }
            .sheet(item: $previewURL) { url in
                DocumentPreviewSheet(url: url)
            }
        }
        .navigationBarHidden(true)
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

// MARK: - Document Row
struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    )
                Image(systemName: document.localFileURL != nil ? "doc.fill" : "doc.text")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.55, blue: 0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(document.type.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                    if document.localFileURL != nil {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                        Text(document.fileExtension?.uppercased() ?? "FILE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.6))
                    }
                }
            }

            Spacer()

            if document.localFileURL != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
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
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Document Detail View
struct DocumentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document
    @State private var showingEditDocument = false
    @State private var previewURL: URL?

    var body: some View {
        ZStack {
            StarryBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
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
                            Text("DOCUMENT")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditDocument = true }) {
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
                        GlassDetailCard(label: "Title", value: document.title, icon: "textformat", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                        GlassDetailCard(label: "Type", value: document.type.rawValue, icon: "doc.fill", tint: Color(red: 0.35, green: 0.3, blue: 0.65))

                        if let asset = document.asset {
                            NavigationLink(destination: AssetDetailView(asset: asset)) {
                                GlassDetailCard(label: "Linked Asset", value: asset.name, icon: "cube.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if let room = document.room ?? document.asset?.room {
                            NavigationLink(destination: RoomDetailView(room: room)) {
                                GlassDetailCard(label: document.room == nil ? "Room (via asset)" : "Room", value: "\(room.name) · \(room.floorDisplay)", icon: "square.split.bottomrightquarter", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if let url = document.localFileURL {
                            // View file button
                            Button(action: { previewURL = url }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 16))
                                    Text("View Document")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(red: 0.2, green: 0.45, blue: 0.65).opacity(0.3))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(red: 0.2, green: 0.45, blue: 0.65), lineWidth: 1))
                                )
                            }

                            GlassDetailCard(label: "File", value: url.lastPathComponent, icon: "paperclip", tint: Color(red: 0.3, green: 0.5, blue: 0.55))
                        }

                        if !document.ocrText.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("OCR TEXT")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(2)
                                Text(document.ocrText)
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
            .sheet(isPresented: $showingEditDocument) {
                EditDocumentView(document: document)
            }
            .sheet(item: $previewURL) { url in
                DocumentPreviewSheet(url: url)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Add Document View
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
                        Button("Save") { dismiss() }
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
