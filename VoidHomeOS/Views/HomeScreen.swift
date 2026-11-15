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
                        DockAppIcon(title: "Home", icon: "house.fill", tint: Color(red: 0.35, green: 0.3, blue: 0.65), destination: HomeDetailView())
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "Bills", icon: "creditcard.fill", tint: Color(red: 0.3, green: 0.55, blue: 0.4), destination: PlaceholderView(title: "Bills"))
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "People", icon: "person.2.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65), destination: PeopleListView())
                            .frame(maxWidth: .infinity)
                        DockAppIcon(title: "To-Do", icon: "checklist", tint: Color(red: 0.4, green: 0.45, blue: 0.7), destination: PlaceholderView(title: "To-Do"))
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

// MARK: - Home Detail View (Cosmic visual paradise redesign)
struct HomeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    @State private var showingEditHome = false
    
    var body: some View {
        ZStack {
            // Highly immersive starry background with specific warm & cool celestial tints
            StarryBackground(
                stars: (0..<150).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3.5),
                        opacity: Double.random(in: 0.2...0.85),
                        color: [
                            Color(red: 0.95, green: 0.8, blue: 1.0),
                            Color(red: 0.8, green: 0.9, blue: 1.0),
                            Color(red: 1.0, green: 0.95, blue: 0.9),
                            Color.white
                        ].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            if let home = homes.first {
                ScrollView {
                    VStack(spacing: 36) {
                        // Back Button
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Button(action: { showingEditHome = true }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            }
                            .accessibilityLabel("Edit home details")
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // Nebula/Orb visual anchor
                        ZStack {
                            // Deep ambient radial layers for a cosmic orb
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 0.4, green: 0.3, blue: 0.85).opacity(0.35), Color.clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 110
                                    )
                                )
                                .frame(width: 220, height: 220)
                            
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.2), Color.clear],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                            
                            // Glass Orb
                            Circle()
                                .fill(Color.white.opacity(0.02))
                                .frame(width: 130, height: 130)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.05),
                                                    Color.clear,
                                                    Color(red: 0.4, green: 0.3, blue: 0.8).opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.8).opacity(0.25), radius: 25, x: 0, y: 15)
                            
                            // Glowing central house logo
                            Image(systemName: "house.fill")
                                .font(.system(size: 42, weight: .thin))
                                .foregroundColor(.white)
                                .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 0)
                        }
                        .padding(.top, 40)
                        
                        // Header
                        VStack(spacing: 8) {
                            Text(home.name.uppercased())
                                .font(.system(size: 28, weight: .light, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.4), radius: 15, x: 0, y: 0)
                            
                            if !home.address.isEmpty {
                                Text(home.address)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(Color(red: 0.65, green: 0.6, blue: 0.75))
                                    .tracking(1)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            } else {
                                Text("COSMIC DWELLING")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(3)
                            }
                        }
                        
                        // Interactive Floating Metrics
                        HStack(spacing: 20) {
                            VisualOrbMetric(value: "\(home.rooms.count)", title: "Rooms", icon: "square.grid.2x2", gradientColors: [Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.25, blue: 0.6)])
                            VisualOrbMetric(value: "\(home.assets.count)", title: "Assets", icon: "cube", gradientColors: [Color(red: 0.8, green: 0.4, blue: 0.9), Color(red: 0.4, green: 0.1, blue: 0.5)])
                            VisualOrbMetric(value: "\(home.projects.count)", title: "Projects", icon: "hammer", gradientColors: [Color(red: 0.9, green: 0.5, blue: 0.3), Color(red: 0.6, green: 0.2, blue: 0.1)])
                        }
                        .padding(.horizontal, 24)
                        
                        // Glass Details Card for profile info (Name, Address, and metadata)
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "signature")
                                    .foregroundColor(Color(red: 0.55, green: 0.3, blue: 0.65))
                                Text("Home Name")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.65, green: 0.6, blue: 0.75))
                                Spacer()
                                Text(home.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 4)
                            
                            Divider()
                                .background(Color.white.opacity(0.08))
                            
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
                                Text("Address")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.65, green: 0.6, blue: 0.75))
                                Spacer()
                                Text(home.address.isEmpty ? "Not set" : home.address)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.1),
                                                    Color.white.opacity(0.02),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .padding(.horizontal, 24)
                        
                        Spacer()
                    }
                }
            } else {
                ContentUnavailableView("No home configured", systemImage: "house")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .sheet(isPresented: $showingEditHome) {
            if let home = homes.first {
                EditHomeView(home: home)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
struct PlaceholderView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            StarryBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header with Back Button
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
                    
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 50)
                
                Spacer()
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                        
                        Image(systemName: "hammer")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.65))
                    }
                    
                    VStack(spacing: 8) {
                        Text("Coming Soon")
                            .font(.system(size: 26, weight: .light))
                            .foregroundColor(.white)
                        
                        Text("\(title) module will be available in a future update.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    HomeScreen()
        .modelContainer(for: [Home.self, Room.self, Asset.self, Document.self, Warranty.self, Maintenance.self, Project.self, Person.self, Floor.self], inMemory: true)
}
