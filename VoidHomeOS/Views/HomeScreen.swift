import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Static starry background
                StarryBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 28) {
                            // Header
                            VStack(alignment: .center, spacing: 10) {
                                Text("VOID")
                                    .font(.system(size: 44, weight: .ultraLight, design: .default))
                                    .foregroundColor(.white)
                                    .tracking(6)
                                    .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                                
                                if let home = homes.first {
                                    Text(home.name.uppercased())
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                        .tracking(3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 24)
                            .padding(.top, 50)
                            
                            // App Grid - Phone home screen style
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ], spacing: 24) {
                                GlassAppIcon(title: "Rooms", icon: "square.grid.2x2.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75), destination: RoomsListView())
                                GlassAppIcon(title: "Assets", icon: "cube.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6), destination: AssetsListView())
                                GlassAppIcon(title: "Documents", icon: "doc.fill", tint: Color(red: 0.2, green: 0.55, blue: 0.7), destination: DocumentsListView())
                                GlassAppIcon(title: "Warranties", icon: "shield.checkered", tint: Color(red: 0.65, green: 0.4, blue: 0.35), destination: WarrantiesListView())
                                GlassAppIcon(title: "Maintenance", icon: "wrench.and.screwdriver.fill", tint: Color(red: 0.3, green: 0.5, blue: 0.55), destination: MaintenanceListView())
                                GlassAppIcon(title: "Projects", icon: "hammer.fill", tint: Color(red: 0.4, green: 0.4, blue: 0.7), destination: ProjectsListView())
                                GlassAppIcon(title: "Timeline", icon: "clock.fill", tint: Color(red: 0.25, green: 0.5, blue: 0.6), destination: TimelineView())
                                GlassAppIcon(title: "Search", icon: "magnifyingglass", tint: Color(red: 0.45, green: 0.3, blue: 0.7), destination: SearchView())
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                    
                    // Dock pill - like iOS dock at the bottom
                    HStack(spacing: 0) {
                        DockAppIcon(title: "Home", icon: "house.fill", tint: Color(red: 0.35, green: 0.3, blue: 0.65), destination: HomeDashboardView())
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "Bills", icon: "creditcard.fill", tint: Color(red: 0.3, green: 0.55, blue: 0.4), destination: BillsView())
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "People", icon: "person.2.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65), destination: PeopleListView())
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "To-Do", icon: "checklist", tint: Color(red: 0.4, green: 0.45, blue: 0.7), destination: TodoView())
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.03),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.18),
                                                Color.white.opacity(0.05),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if homes.isEmpty {
                createDefaultHome()
            }
        }
    }
    
    private func createDefaultHome() {
        let home = Home(name: "My Home", address: "")
        modelContext.insert(home)
        let groundFloor = Floor(name: "Ground", floorNumber: 0)
        groundFloor.home = home
        modelContext.insert(groundFloor)
    }
}

// MARK: - Edit Home View
struct EditHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var home: Home

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
                            Text("EDIT HOME")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Home Name", text: $home.name, icon: "house.fill", tint: Color(red: 0.35, green: 0.3, blue: 0.65))
                            GlassTextField(title: "Address", text: $home.address, icon: "mappin.and.ellipse", tint: Color(red: 0.25, green: 0.45, blue: 0.75), isMultiline: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            if home.name.trimmingCharacters(in: .whitespaces).isEmpty { home.name = "My Home" }
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.3, blue: 0.65))
                    }
                }
            }
        }
        .onDisappear {
            if home.name.trimmingCharacters(in: .whitespaces).isEmpty { home.name = "My Home" }
        }
    }
}

// Highly stylized physical bubble/orb metrics
struct VisualOrbMetric: View {
    let value: String
    let title: String
    let icon: String
    let gradientColors: [Color]
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer ring glow
                Circle()
                    .stroke(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.5
                    )
                    .frame(width: 72, height: 72)
                    .opacity(0.4)
                
                // Frosted background
                Circle()
                    .fill(Color.white.opacity(0.02))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                
                // Fluid color core
                Circle()
                    .fill(
                        LinearGradient(colors: gradientColors.map { $0.opacity(0.15) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 54, height: 54)
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(gradientColors[0])
                    
                    Text(value)
                        .font(.system(size: 18, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: gradientColors[0].opacity(0.2), radius: 10, x: 0, y: 5)
            
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dock App Icon (for the bottom dock pill)
struct DockAppIcon<Destination: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let destination: Destination
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 6) {
                ZStack {
                // Base glass layer
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                
                // Tinted glass layer
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.25),
                                tint.opacity(0.1),
                                tint.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Top highlight (glossy)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black, Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                
                // Subtle inner border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05),
                                Color.clear,
                                tint.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: tint.opacity(0.5), radius: 8, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .frame(width: 60, height: 60)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
                
                // Label
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .buttonStyle(GlassAppButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Placeholder View (Updated)
