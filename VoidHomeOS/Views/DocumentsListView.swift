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
                                        withAnimation { modelContext.delete(document) }
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

                            // File upload button
                            Button(action: { showingFilePicker = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: pickedFileName != nil ? "checkmark.circle.fill" : "arrow.up.doc.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(pickedFileName != nil ? Color.green : Color(red: 0.2, green: 0.55, blue: 0.7))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pickedFileName != nil ? "File Selected" : "Upload File")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        if let name = pickedFileName {
                                            Text(name)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.03))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                                )
                            }

                            GlassTextField(title: "OCR Text (optional)", text: $ocrText, icon: "text.viewfinder", tint: Color(red: 0.35, green: 0.3, blue: 0.65), isMultiline: true)

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
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            )
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
            allowedContentTypes: [
                .pdf, .image, .jpeg, .png, .plainText, .rtf,
                .data, .archive, .item
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pickedFileURL = url
                    pickedFileName = url.lastPathComponent
                    if title.isEmpty {
                        title = url.deletingPathExtension().lastPathComponent
                    }
                }
            case .failure:
                break
            }
        }
    }

    private func saveDocument() {
        var savedPath = ""
        if let url = pickedFileURL {
            // Copy file into app sandbox
            let fm = FileManager.default
            let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destDir = docsDir.appendingPathComponent("UploadedDocuments", isDirectory: true)
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = destDir.appendingPathComponent(url.lastPathComponent)
            // If file already exists, append a number
            var finalDest = dest
            var counter = 1
            while fm.fileExists(atPath: finalDest.path) {
                let name = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                finalDest = destDir.appendingPathComponent("\(name)_\(counter).\(ext)")
                counter += 1
            }
            // Access security-scoped resource
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                try fm.copyItem(at: url, to: finalDest)
                savedPath = finalDest.path
            } catch {
                // If copy fails, try to read data and write
                if let data = try? Data(contentsOf: url) {
                    try? data.write(to: finalDest)
                    savedPath = finalDest.path
                }
            }
        }

        let document = Document(title: title, type: type, fileURL: savedPath, ocrText: ocrText)
        modelContext.insert(document)
    }
}


// MARK: - Edit Document View
struct EditDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: Document

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
                            GlassTextField(title: "OCR Text", text: $document.ocrText, icon: "text.viewfinder", tint: Color(red: 0.35, green: 0.3, blue: 0.65), isMultiline: true)

                            if !document.fileURL.isEmpty {
                                GlassDetailCard(label: "File", value: document.fileURL, icon: "paperclip", tint: Color(red: 0.3, green: 0.5, blue: 0.55))
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
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            )
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
