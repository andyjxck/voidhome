import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Palette

enum VoidPalette {
    static let muted = Color(red: 0.55, green: 0.5, blue: 0.65)
    static let faint = Color(red: 0.42, green: 0.38, blue: 0.52)
    static let accent = Color(red: 0.55, green: 0.45, blue: 0.95)
    static let calm = Color(red: 0.45, green: 0.7, blue: 0.85)
    static let done = Color(red: 0.45, green: 0.8, blue: 0.6)
    static let amber = Color(red: 0.95, green: 0.75, blue: 0.4)
    /// Only bills use this: they are the only thing in the app that can be overdue.
    static let billOverdue = Color(red: 0.95, green: 0.42, blue: 0.45)
    static let bills = Color(red: 0.3, green: 0.65, blue: 0.5)
    static let rooms = Color(red: 0.3, green: 0.5, blue: 0.85)
    static let assets = Color(red: 0.65, green: 0.4, blue: 0.75)
    static let documents = Color(red: 0.25, green: 0.6, blue: 0.75)
    static let warranties = Color(red: 0.75, green: 0.5, blue: 0.4)
    static let maintenance = Color(red: 0.35, green: 0.6, blue: 0.62)
    static let projects = Color(red: 0.5, green: 0.5, blue: 0.85)
    static let people = Color(red: 0.6, green: 0.45, blue: 0.75)
    static let todo = Color(red: 0.5, green: 0.55, blue: 0.85)
}

extension View {
    func voidCard(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill((tint ?? Color.white).opacity(tint == nil ? 0.04 : 0.1))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke((tint ?? Color.white).opacity(tint == nil ? 0.08 : 0.25), lineWidth: 0.5))
            )
    }
}

// MARK: - Page scaffold

/// Standard page: starry background, Back, VOID title with a subtitle, optional + button.
struct VoidPage<Content: View>: View {
    let subtitle: String
    var showBack: Bool = true
    var addAction: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            if showBack {
                                Button(action: { dismiss() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                                        Text("Back").font(.system(size: 16))
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.bottom, 4)
                            }
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20)
                            Text(subtitle.uppercased())
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(VoidPalette.muted)
                                .tracking(3)
                        }
                        Spacer()
                        if let addAction {
                            CircleIconButton(icon: "plus", action: addAction)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 50)

                    content()
                }
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
    }
}

struct CircleIconButton: View {
    let icon: String
    var size: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}

struct VoidSearchField: View {
    let prompt: String
    @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(VoidPalette.faint)
            TextField(prompt, text: $text)
                .font(.system(size: 16))
                .foregroundColor(.white)
            if !text.isEmpty {
                Button(action: { text = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(VoidPalette.faint) }
            }
        }
        .padding(14)
        .voidCard(cornerRadius: 16)
        .padding(.horizontal, 24)
    }
}

struct EmptyStateView: View {
    let icon: String
    let text: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44, weight: .thin)).foregroundColor(VoidPalette.faint)
            Text(text).font(.system(size: 15)).foregroundColor(VoidPalette.muted).multilineTextAlignment(.center)
            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VoidPalette.accent.opacity(0.6)))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// Segmented filter chips.
struct ChipBar<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let on = option == selection
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selection = option } }) {
                        Text(label(option))
                            .font(.system(size: 13, weight: on ? .semibold : .regular))
                            .foregroundColor(on ? .white : VoidPalette.muted)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(on ? VoidPalette.accent.opacity(0.45) : Color.white.opacity(0.05)))
                            .overlay(Capsule().stroke(Color.white.opacity(on ? 0.25 : 0.08), lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct TagLabel: View {
    let text: String
    var color: Color = VoidPalette.muted
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

/// Small stat tile used on dashboards and page headers.
struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(tint)
            Text(value).font(.system(size: 22, weight: .light)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(VoidPalette.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .voidCard(tint: tint)
    }
}

// MARK: - Linked records

/// A titled block of links on a detail page. Hidden when empty unless an add action is given.
struct LinkedSection<Content: View>: View {
    let title: String
    var count: Int = 1
    var addTitle: String? = nil
    var addAction: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        if count > 0 || addAction != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    GlassSectionHeader(title: title)
                    if let addAction {
                        Button(action: addAction) {
                            Label(addTitle ?? "Add", systemImage: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VoidPalette.accent)
                        }
                        .fixedSize()
                    }
                }
                if count > 0 {
                    VStack(spacing: 8) { content() }
                } else {
                    Text("Nothing linked yet").font(.system(size: 13)).foregroundColor(VoidPalette.faint)
                }
            }
        }
    }
}

/// One linked record row that opens the record.
struct LinkRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var trailingColor: Color = VoidPalette.muted
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 12)).foregroundColor(VoidPalette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if let trailing {
                    Text(trailing).font(.system(size: 12, weight: .medium)).foregroundColor(trailingColor)
                }
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(VoidPalette.faint)
            }
            .padding(12)
            .voidCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pickers

/// Menu picker over any list of records.
struct MenuPickerField<T: Hashable>: View {
    let title: String
    @Binding var selection: T?
    let options: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VoidPalette.muted)
                .tracking(1.5)
            Picker("", selection: $selection) {
                Text("None").tag(nil as T?)
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option as T?)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

/// Fixed-choice picker for enums.
struct ChoicePickerField<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VoidPalette.muted)
                .tracking(1.5)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in Text(label(option)).tag(option) }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

/// Optional date: a toggle plus a date picker.
struct OptionalDateField: View {
    let title: String
    @Binding var date: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { date != nil }, set: { date = $0 ? (date ?? Date()) : nil })) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(VoidPalette.muted)
                    .tracking(1.5)
            }
            .tint(VoidPalette.accent)
            if let current = date {
                DatePicker("", selection: Binding(get: { current }, set: { date = $0 }), displayedComponents: .date)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
        }
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

struct DateField: View {
    let title: String
    @Binding var date: Date
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VoidPalette.muted)
                .tracking(1.5)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

/// A sheet with a checklist of records to link, e.g. rooms on a project.
struct MultiLinkSheet<T: PersistentModel>: View {
    let title: String
    let options: [T]
    let label: (T) -> String
    let isLinked: (T) -> Bool
    let toggle: (T) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var refresh = 0

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("Nothing to link yet").foregroundColor(.secondary)
                }
                ForEach(options, id: \.persistentModelID) { option in
                    Button(action: { toggle(option); refresh += 1 }) {
                        HStack {
                            Text(label(option)).foregroundColor(.primary)
                            Spacer()
                            if isLinked(option) { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                    }
                }
            }
            .id(refresh)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

/// Standard form sheet chrome: title, Cancel, Save.
struct FormSheet<Content: View>: View {
    let title: String
    var saveTitle: String = "Save"
    var canSave: Bool = true
    let onSave: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackground().ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) { content() }
                        .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle) { onSave(); dismiss() }.disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Photos

/// Saves photos as JPEG files in Documents/Photos and loads them back.
enum PhotoStore {
    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return save(image)
    }

    static func save(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        return UIImage(contentsOfFile: folder.appendingPathComponent(name).path)
    }

    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }
}

/// Shows a stored photo, or a tinted icon when there is none.
struct StoredPhotoView: View {
    let fileName: String?
    var icon: String = "photo"
    var tint: Color = VoidPalette.assets
    var cornerRadius: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image = PhotoStore.image(named: fileName) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: icon).font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .light)).foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Button that lets the user pick a photo from their library and saves it with PhotoStore.
struct PhotoPickButton<Label: View>: View {
    let onSaved: (String) -> Void
    @ViewBuilder var label: () -> Label
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) { label() }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self), let name = PhotoStore.save(data) {
                        await MainActor.run { onSaved(name) }
                    }
                    await MainActor.run { item = nil }
                }
            }
    }
}

// MARK: - Formatting

enum DayText {
    static func relative(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 && days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
