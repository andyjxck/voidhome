import SwiftUI
import SwiftData

// MARK: - Shared Starry Background Component
struct StarryBackground: View {
    // Optimization: Store stars as a constant array rather than using @State 
    // to avoid re-calculating or tracking them during high-frequency parent updates (like typing)
    let stars: [Star]
    
    init(stars: [Star] = StarryBackground.generateStars()) {
        self.stars = stars
    }
    
    static func generateStars() -> [Star] {
        (0..<80).map { _ in
            Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...2.5),
                opacity: Double.random(in: 0.15...0.5),
                color: [Color.white, Color(red: 0.9, green: 0.9, blue: 1.0), Color(red: 1.0, green: 0.95, blue: 0.85)].randomElement()!
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Deep midnight base
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.01, blue: 0.06),
                    Color(red: 0.05, green: 0.02, blue: 0.1),
                    Color(red: 0.03, green: 0.015, blue: 0.08),
                    Color(red: 0.01, green: 0.005, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle purple glow regions
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.05, blue: 0.25).opacity(0.15),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            
            RadialGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.2).opacity(0.12),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 350
            )
            
            // Drawing stars as a single path or non-dynamic view to save CPU
            Canvas { context, size in
                for star in stars {
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.size,
                        height: star.size
                    )
                    context.opacity = star.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(star.color))
                }
            }
            .blur(radius: 0.3)
            
            // Very subtle vignette
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .drawingGroup() // Flatten layer for GPU rendering
    }
}

struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let color: Color
}

// MARK: - Glassmorphic Stat Card (Shared)
struct GlassStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: tint.opacity(0.2), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(tint)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .light, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            ZStack {
                // Glass base
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
                
                // Glass highlight
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Tinted edge glow
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.4),
                                tint.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .overlay(
            // Inner highlight
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .blur(radius: 0.5)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .shadow(color: tint.opacity(0.08), radius: 30, x: 0, y: 15)
    }
}

// MARK: - Glassmorphic App Icon (Shared)
struct GlassAppIcon<Destination: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let destination: Destination
    
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 10) {
                // Icon container - rounded square like iOS
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                    
                    // Tinted glass layer
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black, Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                    
                    // Subtle inner border
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: tint.opacity(0.5), radius: 8, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .frame(width: 76, height: 76)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
                
                // Label
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(width: 84)
            }
        }
        .buttonStyle(GlassAppButtonStyle(isPressed: $isPressed))
    }
}

// Custom button style for press animation
struct GlassAppButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}

// MARK: - Glass Detail Card
struct GlassDetailCard: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: tint.opacity(0.15), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(tint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    .tracking(1)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.3),
                                    tint.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Glass Text Field
struct GlassTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let tint: Color
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                .tracking(1.5)
            
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(tint.opacity(0.25), lineWidth: 0.5)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(tint)
                }
                
                if isMultiline {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                } else {
                    TextField("", text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .keyboardType(keyboardType)
                        .autocapitalization(autocapitalization)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.02),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.25),
                                        tint.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
        }
    }
}

// MARK: - Person Row
struct PersonRow: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                
                Text(String(person.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.65))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                if !person.company.isEmpty {
                    Text(person.company)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                }
            }
            
            Spacer()
            
            if !person.role.isEmpty {
                Text(person.role)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
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
                                colors: [
                                    Color.white.opacity(0.08),
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
    }
}

// MARK: - Asset Row
struct AssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                
                Image(systemName: "cube.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.3, blue: 0.6))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                Text(asset.locationDisplay.isEmpty ? asset.category : "\(asset.category) · \(asset.locationDisplay)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(asset.warranties.count)")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                
                Text("warranties")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    .tracking(0.5)
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
                                colors: [
                                    Color.white.opacity(0.08),
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
    }
}


// MARK: - Money (locale-aware currency)

/// Formats and parses amounts in the currency of the user's region instead of a hard-coded "$".
enum Money {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "GBP" }

    static func format(_ value: Double, decimals: Int = 2) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(decimals)))
    }

    /// Plain number for an edit field, using the locale's decimal separator ("12.50" or "12,50").
    static func editString(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    /// Parses what the user typed, accepting the locale's decimal separator, a "." and currency symbols.
    static func parse(_ text: String) -> Double? {
        let allowed = CharacterSet(charactersIn: "0123456789.,-")
        let cleaned = String(text.unicodeScalars.filter { allowed.contains($0) })
        guard !cleaned.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        if let n = formatter.number(from: cleaned) { return n.doubleValue }
        return Double(cleaned.replacingOccurrences(of: ",", with: ""))
    }

    /// SF Symbol for the local currency.
    static func symbolName(filled: Bool) -> String {
        let base: String
        switch currencyCode {
        case "GBP": base = "sterlingsign.circle"
        case "EUR": base = "eurosign.circle"
        case "JPY", "CNY": base = "yensign.circle"
        case "INR": base = "indianrupeesign.circle"
        default: base = "dollarsign.circle"
        }
        return filled ? base + ".fill" : base
    }
}

// MARK: - Shared pickers

/// Menu picker for choosing a room, labelled with its floor.
struct RoomPickerField: View {
    var title: String = "Room"
    @Binding var selection: Room?
    @Query(sort: \Room.name) private var rooms: [Room]

    private var sortedRooms: [Room] {
        rooms.sorted { ($0.floorNumber, $0.name) < ($1.floorNumber, $1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                .tracking(1.5)
            Picker("", selection: $selection) {
                Text("None").tag(nil as Room?)
                ForEach(sortedRooms) { room in
                    Text("\(room.name) · \(room.floorDisplay)").tag(room as Room?)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
    }
}

/// Menu picker for choosing an asset.
struct AssetPickerField: View {
    var title: String = "Linked Asset"
    @Binding var selection: Asset?
    @Query(sort: \Asset.name) private var assets: [Asset]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                .tracking(1.5)
            Picker("", selection: $selection) {
                Text("None").tag(nil as Asset?)
                ForEach(assets) { asset in
                    Text(asset.room == nil ? asset.name : "\(asset.name) · \(asset.room!.name)").tag(asset as Asset?)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
    }
}

/// Small section header used on detail pages.
struct GlassSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
