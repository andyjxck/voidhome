import SwiftUI
import SwiftData

/// Searches every record in the app, grouped by type. Matches in notes and in text read from scanned
/// documents are shown as a short snippet with the matching words picked out.
/// Nothing here is ever labelled late, except a bill that is overdue (bills are the only thing that can be).
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @Query private var rooms: [Room]
    @Query private var documents: [Document]
    @Query private var warranties: [Warranty]
    @Query private var maintenanceRecords: [Maintenance]
    @Query private var plans: [MaintenancePlan]
    @Query private var people: [Person]
    @Query private var projects: [Project]
    @Query private var bills: [Bill]
    @Query private var tasks: [HomeTask]

    @State private var searchText = ""
    /// Recent searches, newest first, one per line. Kept on this phone only.
    @AppStorage("search.recent") private var recentRaw: String = ""
    @FocusState private var fieldFocused: Bool

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var recent: [String] {
        recentRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    var results: [SearchHit] {
        SearchEngine.search(query, assets: assets, rooms: rooms, documents: documents, warranties: warranties,
                            maintenance: maintenanceRecords, plans: plans, people: people, projects: projects,
                            bills: bills, tasks: tasks)
    }

    var body: some View {
        let hits = results
        ZStack {
            StarryBackground().ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
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

                    Text("SEARCH")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 50)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    TextField("Search everything...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .focused($fieldFocused)
                        .onSubmit { remember(query) }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(VoidPalette.faint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                )
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if query.isEmpty {
                            emptyState
                        } else if hits.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
                                Text("Nothing matches \"\(query)\"")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Text("Try a different word.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.4, green: 0.37, blue: 0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            Text("\(hits.count) result\(hits.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VoidPalette.faint)
                            ForEach(SearchKind.allCases) { kind in
                                let group = hits.filter { $0.kind == kind }
                                if !group.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: kind.icon).font(.system(size: 11, weight: .semibold)).foregroundColor(kind.tint)
                                        GlassSectionHeader(title: "\(kind.title) (\(group.count))")
                                    }
                                    .padding(.top, 10)
                                    ForEach(group) { hit in
                                        NavigationLink(destination: destination(for: hit.target)) {
                                            SearchResultRow(hit: hit, query: query)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .simultaneousGesture(TapGesture().onEnded { remember(query) })
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private var emptyState: some View {
        if recent.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
                Text("Search your home")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                Text("Rooms, assets, documents (including the text inside scans), warranties, maintenance, projects, bills, jobs, people and notes.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.4, green: 0.37, blue: 0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            HStack {
                GlassSectionHeader(title: "Recent searches")
                Spacer()
                Button("Clear") { recentRaw = "" }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            ForEach(recent, id: \.self) { term in
                HStack(spacing: 12) {
                    Button {
                        searchText = term
                        remember(term)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14))
                                .foregroundColor(VoidPalette.muted)
                            Text(term)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button { forget(term) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(VoidPalette.faint)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .voidCard(cornerRadius: 14)
            }
        }
    }

    private func remember(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var list = recent.filter { $0.caseInsensitiveCompare(t) != .orderedSame }
        list.insert(t, at: 0)
        recentRaw = list.prefix(8).joined(separator: "\n")
    }

    private func forget(_ term: String) {
        recentRaw = recent.filter { $0 != term }.joined(separator: "\n")
    }

    @ViewBuilder
    private func destination(for target: SearchTarget) -> some View {
        switch target {
        case .asset(let asset): AssetDetailView(asset: asset)
        case .room(let room): RoomDetailView(room: room)
        case .document(let document): DocumentDetailView(document: document)
        case .warranty(let warranty): WarrantyDetailView(warranty: warranty)
        case .maintenance(let record): MaintenanceDetailView(maintenance: record)
        case .plan(let plan): MaintenancePlanDetailView(plan: plan)
        case .person(let person): PersonDetailView(person: person)
        case .project(let project): ProjectDetailView(project: project)
        case .bill(let bill): BillDetailView(bill: bill)
        case .task(let task): TaskDetailView(task: task)
        }
    }
}

// MARK: - Results

/// Result groups, in the order they are shown.
enum SearchKind: String, CaseIterable, Identifiable {
    case room, asset, document, warranty, maintenance, project, bill, todo, person
    var id: String { rawValue }

    var title: String {
        switch self {
        case .room: return "Rooms"
        case .asset: return "Assets"
        case .document: return "Documents"
        case .warranty: return "Warranties"
        case .maintenance: return "Maintenance"
        case .project: return "Projects"
        case .bill: return "Bills"
        case .todo: return "To-Do"
        case .person: return "People"
        }
    }

    var icon: String {
        switch self {
        case .room: return "door.left.hand.open"
        case .asset: return "cube.fill"
        case .document: return "doc.fill"
        case .warranty: return "shield.checkered"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .project: return "hammer.fill"
        case .bill: return "creditcard.fill"
        case .todo: return "checklist"
        case .person: return "person.fill"
        }
    }

    var tint: Color {
        switch self {
        case .room: return VoidPalette.rooms
        case .asset: return VoidPalette.assets
        case .document: return VoidPalette.documents
        case .warranty: return VoidPalette.warranties
        case .maintenance: return VoidPalette.maintenance
        case .project: return VoidPalette.projects
        case .bill: return VoidPalette.bills
        case .todo: return VoidPalette.todo
        case .person: return VoidPalette.people
        }
    }
}

/// The exact record a result opens.
enum SearchTarget {
    case asset(Asset)
    case room(Room)
    case document(Document)
    case warranty(Warranty)
    case maintenance(Maintenance)
    case plan(MaintenancePlan)
    case person(Person)
    case project(Project)
    case bill(Bill)
    case task(HomeTask)
}

struct SearchHitID: Hashable {
    let kind: String
    let record: PersistentIdentifier
}

struct SearchHit: Identifiable {
    let id: SearchHitID
    let kind: SearchKind
    let icon: String
    let title: String
    let subtitle: String
    /// Where the words were found when it was not the title, e.g. "Scanned text" or "Note".
    var snippetLabel: String? = nil
    var snippet: String? = nil
    /// Only ever set for an overdue bill.
    var isOverdueBill: Bool = false
    let target: SearchTarget
}

enum SearchEngine {
    /// One field of a record that can match: its label (nil for the title or a plain detail) and its text.
    private typealias Field = (label: String?, text: String)

    /// The first field that contains the query, if any. Returns the label and a snippet when the match
    /// was not in the first (title) field.
    private static func match(_ fields: [Field], _ q: String) -> (matched: Bool, label: String?, snippet: String?) {
        for (index, field) in fields.enumerated() where !field.text.isEmpty {
            if field.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                if index == 0 || field.label == nil { return (true, nil, nil) }
                return (true, field.label, SearchText.snippet(in: field.text, query: q))
            }
        }
        return (false, nil, nil)
    }

    static func search(_ q: String, assets: [Asset], rooms: [Room], documents: [Document], warranties: [Warranty],
                       maintenance: [Maintenance], plans: [MaintenancePlan], people: [Person], projects: [Project],
                       bills: [Bill], tasks: [HomeTask]) -> [SearchHit] {
        guard !q.isEmpty else { return [] }
        var hits: [SearchHit] = []

        for room in rooms {
            let m = match([(nil, room.name), (nil, room.floorDisplay),
                           ("Piece", room.parts.map { $0.name }.joined(separator: ", "))], q)
            guard m.matched else { continue }
            let detail = String(format: "%.1f m²", room.area)
            hits.append(SearchHit(id: SearchHitID(kind: "room", record: room.persistentModelID), kind: .room, icon: "door.left.hand.open",
                                  title: room.name, subtitle: "\(room.floorDisplay) · \(detail) · \(room.assets.count) item\(room.assets.count == 1 ? "" : "s")",
                                  snippetLabel: m.label, snippet: m.snippet, target: .room(room)))
        }

        for asset in assets {
            let m = match([(nil, asset.name), (nil, asset.category), (nil, asset.manufacturer), (nil, asset.model),
                           ("Serial number", asset.serialNumber), (nil, asset.locationDisplay), ("Note", asset.notes)], q)
            guard m.matched else { continue }
            hits.append(SearchHit(id: SearchHitID(kind: "asset", record: asset.persistentModelID), kind: .asset, icon: "cube.fill",
                                  title: asset.name,
                                  subtitle: asset.locationDisplay.isEmpty ? asset.category : "\(asset.category) · \(asset.locationDisplay)",
                                  snippetLabel: m.label, snippet: m.snippet, target: .asset(asset)))
        }

        for document in documents {
            let m = match([(nil, document.title), (nil, document.type.rawValue), ("Scanned text", document.ocrText)], q)
            guard m.matched else { continue }
            var parts = [document.type.rawValue]
            if let owner = document.asset?.name ?? document.room?.name { parts.append(owner) }
            if let expiry = document.expiryDate { parts.append("Expires \(DayText.short(expiry))") }
            hits.append(SearchHit(id: SearchHitID(kind: "document", record: document.persistentModelID), kind: .document, icon: "doc.fill",
                                  title: document.title, subtitle: parts.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .document(document)))
        }

        for warranty in warranties {
            let m = match([(nil, warranty.provider), (nil, warranty.asset?.name ?? ""), ("Claim contact", warranty.claimContact), ("Note", warranty.notes)], q)
            guard m.matched else { continue }
            let ends = warranty.isExpired ? "Ended \(DayText.short(warranty.expiryDate))" : "Ends \(DayText.short(warranty.expiryDate))"
            hits.append(SearchHit(id: SearchHitID(kind: "warranty", record: warranty.persistentModelID), kind: .warranty, icon: "shield.checkered",
                                  title: warranty.asset.map { "\($0.name) warranty" } ?? warranty.provider,
                                  subtitle: [warranty.provider, ends].joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .warranty(warranty)))
        }

        for plan in plans {
            let m = match([(nil, plan.title), (nil, plan.targetName ?? ""), (nil, plan.person?.name ?? ""), ("Note", plan.notes)], q)
            guard m.matched else { continue }
            let today = Calendar.current.startOfDay(for: Date())
            let next = max(Calendar.current.startOfDay(for: plan.nextDueDate), today)
            let when = plan.isPaused ? "Paused" : "Next \(DayText.relative(next))"
            hits.append(SearchHit(id: SearchHitID(kind: "plan", record: plan.persistentModelID), kind: .maintenance, icon: "repeat",
                                  title: plan.title,
                                  subtitle: [plan.targetName, plan.intervalSummary, when].compactMap { $0 }.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .plan(plan)))
        }

        for record in maintenance {
            let m = match([(nil, record.task), (nil, record.targetName ?? ""), (nil, record.person?.name ?? ""), ("Note", record.notes)], q)
            guard m.matched else { continue }
            var parts: [String] = []
            if let target = record.targetName { parts.append(target) }
            parts.append(DayText.short(record.date))
            if record.cost > 0 { parts.append(Money.format(record.cost)) }
            hits.append(SearchHit(id: SearchHitID(kind: "maintenance", record: record.persistentModelID), kind: .maintenance, icon: "wrench.and.screwdriver.fill",
                                  title: record.task, subtitle: parts.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .maintenance(record)))
        }

        for project in projects {
            let m = match([(nil, project.title), (nil, project.status.rawValue), ("Description", project.projectDescription), ("Note", project.notes)], q)
            guard m.matched else { continue }
            var parts = [project.status.rawValue]
            if project.budget > 0 { parts.append("Budget \(Money.format(project.budget, decimals: 0))") }
            hits.append(SearchHit(id: SearchHitID(kind: "project", record: project.persistentModelID), kind: .project, icon: "hammer.fill",
                                  title: project.title, subtitle: parts.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .project(project)))
        }

        for bill in bills {
            let m = match([(nil, bill.name), (nil, bill.provider?.name ?? ""), (nil, bill.category.rawValue),
                           ("Paid by", bill.paymentMethod), ("Note", bill.notes)], q)
            guard m.matched else { continue }
            var parts = [(bill.isEstimate ? "~" : "") + Money.format(bill.amount), bill.frequency.rawValue]
            if bill.isSettled {
                parts.append("Paid")
            } else if bill.isOverdue {
                parts.append("Overdue since \(DayText.short(bill.nextDueDate))")
            } else {
                parts.append("Due \(DayText.relative(bill.nextDueDate))")
            }
            hits.append(SearchHit(id: SearchHitID(kind: "bill", record: bill.persistentModelID), kind: .bill, icon: bill.category.icon,
                                  title: bill.name, subtitle: parts.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, isOverdueBill: bill.isOverdue, target: .bill(bill)))
        }

        for task in tasks {
            let completionNotes = task.completions.sorted { $0.completedAt > $1.completedAt }
                .map { $0.note }.filter { !$0.isEmpty }.joined(separator: " · ")
            let m = match([(nil, task.title),
                           (nil, task.room?.name ?? ""), (nil, task.asset?.name ?? ""), (nil, task.project?.title ?? ""),
                           (nil, task.assignee?.name ?? ""),
                           ("Checklist", task.sortedChecklist.map { $0.title }.joined(separator: ", ")),
                           ("Note", task.notes), ("Done note", completionNotes)], q)
            guard m.matched else { continue }
            var parts = [task.scheduleSummary]
            if let place = task.room?.name ?? task.asset?.name ?? task.project?.title { parts.append(place) }
            if task.repeatRule == .none && task.isDone { parts.append("Done") }
            hits.append(SearchHit(id: SearchHitID(kind: "task", record: task.persistentModelID), kind: .todo, icon: "checklist",
                                  title: task.title, subtitle: parts.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .task(task)))
        }

        for person in people {
            let m = match([(nil, person.name), (nil, person.company), (nil, person.role), (nil, person.kind.rawValue),
                           (nil, person.phoneNumber), (nil, person.email), ("Note", person.notes)], q)
            guard m.matched else { continue }
            let detail = [person.kind.rawValue, person.company.isEmpty ? person.role : person.company].filter { !$0.isEmpty }
            hits.append(SearchHit(id: SearchHitID(kind: "person", record: person.persistentModelID), kind: .person, icon: "person.fill",
                                  title: person.name, subtitle: detail.joined(separator: " · "),
                                  snippetLabel: m.label, snippet: m.snippet, target: .person(person)))
        }

        // Title matches first within each group, then alphabetical.
        return hits.sorted { a, b in
            let at = a.title.range(of: q, options: .caseInsensitive) != nil
            let bt = b.title.range(of: q, options: .caseInsensitive) != nil
            if at != bt { return at }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }
}

/// Snippets and highlighting for search matches.
enum SearchText {
    /// A short extract around the first match, on one line, with "…" where it was cut.
    static func snippet(in text: String, query: String, radius: Int = 48) -> String {
        let flat = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        guard let r = flat.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(flat.prefix(radius * 2))
        }
        let start = flat.index(r.lowerBound, offsetBy: -radius, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(r.upperBound, offsetBy: radius, limitedBy: flat.endIndex) ?? flat.endIndex
        var out = String(flat[start..<end])
        if start > flat.startIndex { out = "…" + out }
        if end < flat.endIndex { out += "…" }
        return out
    }

    /// The text with every match of the query picked out in the accent colour.
    static func highlighted(_ text: String, query: String, base: Color, highlight: Color = VoidPalette.amber) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = base
        guard !query.isEmpty else { return attributed }
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].foregroundColor = highlight
            attributed[range].font = .system(size: 13, weight: .bold)
            searchStart = range.upperBound
        }
        return attributed
    }
}

struct SearchResultRow: View {
    let hit: SearchHit
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: hit.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(hit.kind.tint)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(hit.kind.tint.opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(SearchText.highlighted(hit.title, query: query, base: .white))
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(2)
                Text(hit.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(hit.isOverdueBill ? VoidPalette.billOverdue : VoidPalette.muted)
                    .lineLimit(1)
                if let snippet = hit.snippet {
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = hit.snippetLabel {
                            Text(label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(VoidPalette.faint)
                        }
                        Text(SearchText.highlighted(snippet, query: query, base: Color.white.opacity(0.7)))
                            .font(.system(size: 13))
                            .lineLimit(3)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
                .padding(.top, 14)
        }
        .padding(12)
        .voidCard(cornerRadius: 16)
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
