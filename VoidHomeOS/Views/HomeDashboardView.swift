import SwiftUI
import SwiftData

/// The Home tab: a calm overview. Only bills can show as overdue; everything else is "on the list" or "coming up".
struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @Query private var tasks: [HomeTask]
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query(sort: \MaintenancePlan.nextDueDate) private var plans: [MaintenancePlan]
    @Query(sort: \Warranty.expiryDate) private var warranties: [Warranty]
    @Query private var documents: [Document]
    @Query private var projects: [Project]
    @Query private var assets: [Asset]
    @Query private var rooms: [Room]
    @State private var showingEditHome = false
    @State private var showingHouse = false
    @ObservedObject private var houseStore = HouseStore.shared

    private var home: Home? { homes.first }
    private var today: [TodoItem] {
        TodoFeed.items(on: Date(), tasks: tasks, bills: bills, plans: plans, warranties: warranties, documents: documents).filter { !$0.isInfo }
    }

    var body: some View {
        VoidPage(subtitle: home?.name.isEmpty == false ? home!.name : "Home", showBack: false) {
            todayCard

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink(destination: BillsView()) { billsTile }.buttonStyle(.plain)
                NavigationLink(destination: WarrantiesListView()) { warrantiesTile }.buttonStyle(.plain)
                NavigationLink(destination: MaintenanceListView()) { maintenanceTile }.buttonStyle(.plain)
                NavigationLink(destination: ProjectsListView()) { projectsTile }.buttonStyle(.plain)
                NavigationLink(destination: AssetsListView()) { assetsTile }.buttonStyle(.plain)
                NavigationLink(destination: RoomsListView()) { roomsTile }.buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            comingUp

            Button(action: { showingHouse = true }) {
                Label(houseStore.house.map { "Shared with \($0.members.count - 1) other\($0.members.count == 2 ? "" : "s")" } ?? "Share this home",
                      systemImage: houseStore.house == nil ? "person.badge.plus" : "person.2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VoidPalette.accent)
            }

            Button(action: {
                if home == nil { modelContext.insert(Home(name: "My Home", address: "")) }
                showingEditHome = true
            }) {
                Label(home == nil ? "Set up your home" : "Home details", systemImage: "house")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VoidPalette.muted)
            }
        }
        .sheet(isPresented: $showingEditHome) {
            if let home { EditHomeView(home: home) }
        }
        .sheet(isPresented: $showingHouse) { HouseView() }
    }

    // MARK: Today

    private var todayCard: some View {
        let items = today
        let done = items.filter(\.isDone).count
        let fraction = items.isEmpty ? 0 : Double(done) / Double(items.count)
        let next = items.filter { !$0.isDone }.prefix(3)
        return NavigationLink(destination: TodoView()) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(LinearGradient(colors: [VoidPalette.calm, VoidPalette.done], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(done)").font(.system(size: 22, weight: .light)).foregroundColor(.white)
                        Text("done").font(.system(size: 10)).foregroundColor(VoidPalette.muted)
                    }
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today").font(.system(size: 13, weight: .semibold)).foregroundColor(VoidPalette.muted).tracking(1)
                    if next.isEmpty {
                        Text(items.isEmpty ? "Nothing on the list" : "All done").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    }
                    ForEach(Array(next)) { item in
                        HStack(spacing: 6) {
                            Circle().fill(item.isOverdue ? VoidPalette.billOverdue : VoidPalette.calm.opacity(0.7)).frame(width: 6, height: 6)
                            Text(item.title).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(VoidPalette.faint)
            }
            .padding(18)
            .voidCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    // MARK: Tiles

    private var billsTile: some View {
        let active = bills.filter { !$0.isSettled }
        let week = active.filter { $0.daysUntilDue >= 0 && $0.daysUntilDue <= 7 }
        let overdue = active.filter(\.isOverdue)
        let total = week.reduce(0) { $0 + $1.amount } + overdue.reduce(0) { $0 + $1.amount }
        return StatTile(icon: "creditcard.fill", tint: overdue.isEmpty ? VoidPalette.bills : VoidPalette.billOverdue,
                        value: active.isEmpty ? "—" : Money.format(total, decimals: 0),
                        label: overdue.isEmpty ? "Bills in the next 7 days (\(week.count))" : "\(overdue.count) overdue · \(week.count) due this week")
    }

    private var warrantiesTile: some View {
        let ending = warranties.filter { $0.status == .endingSoon }
        return StatTile(icon: "shield.lefthalf.filled", tint: VoidPalette.warranties,
                        value: "\(ending.count)", label: ending.isEmpty ? "No warranties ending soon" : "Warranties ending within 60 days")
    }

    private var maintenanceTile: some View {
        let upcoming = plans.filter { !$0.isPaused && $0.nextDueDate <= (Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()) }
        return StatTile(icon: "wrench.and.screwdriver.fill", tint: VoidPalette.maintenance,
                        value: "\(upcoming.count)", label: "Maintenance on the list in the next 30 days")
    }

    private var projectsTile: some View {
        let active = projects.filter { $0.status == .inProgress || $0.status == .planned }
        return StatTile(icon: "hammer.fill", tint: VoidPalette.projects, value: "\(active.count)", label: "Active projects")
    }

    private var assetsTile: some View {
        let value = assets.reduce(0) { $0 + ($1.purchasePrice) }
        return StatTile(icon: "cube.fill", tint: VoidPalette.assets, value: Money.format(value, decimals: 0), label: "\(assets.count) assets")
    }

    private var roomsTile: some View {
        let area = rooms.reduce(0) { $0 + $1.area }
        return StatTile(icon: "square.grid.2x2.fill", tint: VoidPalette.rooms, value: "\(rooms.count)", label: area > 0 ? String(format: "Rooms · %.0f m²", area) : "Rooms")
    }

    // MARK: Coming up

    private var comingUp: some View {
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        let start = Calendar.current.startOfDay(for: Date())
        var rows: [(date: Date, title: String, icon: String, tint: Color)] = []
        for b in bills where !b.isSettled && b.nextDueDate > start && b.nextDueDate <= horizon { rows.append((b.nextDueDate, "\(b.name) · \(Money.format(b.amount))", "creditcard.fill", VoidPalette.bills)) }
        for p in plans where !p.isPaused && p.nextDueDate > start && p.nextDueDate <= horizon { rows.append((p.nextDueDate, p.title, "wrench.and.screwdriver.fill", VoidPalette.maintenance)) }
        for w in warranties where w.expiryDate > start && w.expiryDate <= horizon { rows.append((w.expiryDate, "\(w.asset?.name ?? w.provider) warranty ends", "shield.fill", VoidPalette.warranties)) }
        for t in tasks where t.repeatRule == .none && !t.isDone { if let d = t.startDate, d > start, d <= horizon { rows.append((d, t.title, "checklist", VoidPalette.todo)) } }
        rows.sort { $0.date < $1.date }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    GlassSectionHeader(title: "Coming up")
                    ForEach(Array(rows.prefix(6).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            Image(systemName: row.icon).font(.system(size: 13)).foregroundColor(row.tint).frame(width: 26)
                            Text(row.title).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Text(DayText.relative(row.date)).font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(16)
                .voidCard()
                .padding(.horizontal, 24)
            }
        }
    }
}
