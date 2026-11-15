import SwiftUI
import SwiftData

/// Visual editor for designing irregular room shapes.
/// Shows the base room rectangle plus draggable/resizable additional parts.
struct RoomShapeEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var room: Room

    @State private var backgroundStars = StarryBackground.generateStars()
    @State private var selectedPart: RoomPart?
    @State private var showingAddPart = false

    /// Where the piece being dragged started, in metres from the room centre.
    @State private var dragStart: CGPoint?

    /// Fits the whole shape on screen, never larger than the floor plan's 35 points per metre.
    private func fittedScale(for size: CGSize) -> CGFloat {
        let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
        let extentX = local.reduce(CGFloat(room.width / 2)) { max($0, abs($1.minX), abs($1.maxX)) }
        let extentY = local.reduce(CGFloat(room.height / 2)) { max($0, abs($1.minY), abs($1.maxY)) }
        let fit = min(size.width / (extentX * 2 + 2), size.height / (extentY * 2 + 2))
        return max(8, min(FloorplanGeometry.pointsPerMetre, fit))
    }

    /// Snaps a piece's centre so its edges sit flush against, or line up with, the main room and the other pieces.
    private func snappedCenter(for part: RoomPart, proposed: CGPoint) -> CGPoint {
        let threshold: CGFloat = 0.3
        let w = CGFloat(part.width), h = CGFloat(part.height)
        var targets = [CGRect(x: -room.width / 2, y: -room.height / 2, width: room.width, height: room.height)]
        for other in room.parts where other.id != part.id {
            targets.append(CGRect(x: other.xOffset - other.width / 2, y: other.yOffset - other.height / 2, width: other.width, height: other.height))
        }
        func snap(_ value: CGFloat, half: CGFloat, edges: [(CGFloat, CGFloat)]) -> CGFloat {
            var best: CGFloat?
            for (lo, hi) in edges {
                // flush outside, aligned edges, and centred
                for candidate in [hi + half, lo - half, lo + half, hi - half, (lo + hi) / 2] {
                    if abs(candidate - value) < threshold, abs(candidate - value) < abs((best ?? .infinity) - value) { best = candidate }
                }
            }
            return best ?? (value * 10).rounded() / 10
        }
        let x = snap(proposed.x, half: w / 2, edges: targets.map { ($0.minX, $0.maxX) })
        let y = snap(proposed.y, half: h / 2, edges: targets.map { ($0.minY, $0.maxY) })
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            Text("Back").font(.system(size: 16))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 4)

                    Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                    Text("ROOM SHAPE").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 50)
                .padding(.bottom, 20)

                // Shape canvas
                GeometryReader { geo in
                    ZStack {
                        // Grid
                        FloorplanGridLines().opacity(0.15)

                        let scale = fittedScale(for: geo.size)

                        // Base room rectangle (centered in canvas)
                        let baseW = CGFloat(room.width) * scale
                        let baseH = CGFloat(room.height) * scale
                        let cx = geo.size.width / 2
                        let cy = geo.size.height / 2

                        RoomShapeRect(
                            label: room.name,
                            width: baseW,
                            height: baseH,
                            isBase: true,
                            isSelected: false,
                            scale: scale
                        )
                        .position(x: cx, y: cy)

                        // Additional parts
                        ForEach(room.parts) { part in
                            let pw = CGFloat(part.width) * scale
                            let ph = CGFloat(part.height) * scale
                            let px = cx + CGFloat(part.xOffset) * scale
                            let py = cy + CGFloat(part.yOffset) * scale

                            RoomShapeRect(
                                label: part.name,
                                width: pw,
                                height: ph,
                                isBase: false,
                                isSelected: selectedPart?.id == part.id,
                                scale: scale
                            )
                            .position(x: px, y: py)
                            .gesture(
                                DragGesture(coordinateSpace: .global)
                                    .onChanged { gesture in
                                        selectedPart = part
                                        let start = dragStart ?? CGPoint(x: part.xOffset, y: part.yOffset)
                                        if dragStart == nil { dragStart = start }
                                        let proposed = CGPoint(x: start.x + gesture.translation.width / scale,
                                                               y: start.y + gesture.translation.height / scale)
                                        let snapped = snappedCenter(for: part, proposed: proposed)
                                        part.xOffset = Double(snapped.x)
                                        part.yOffset = Double(snapped.y)
                                    }
                                    .onEnded { _ in dragStart = nil }
                            )
                            .onTapGesture { selectedPart = part }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedPart = nil }
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.01))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                // Bottom action bar
                VStack {
                    HStack(spacing: 16) {
                        Button(action: { showingAddPart = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.rectangle.on.rectangle")
                                Text("Add Part")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.25, green: 0.45, blue: 0.75))
                            .cornerRadius(20)
                        }

                        if let part = selectedPart {
                            NavigationLink(destination: RoomPartDetailView(part: part)) {
                                VStack(spacing: 4) {
                                    Image(systemName: "pencil").font(.system(size: 18))
                                    Text("Edit").font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(width: 50)
                            }

                            Button(role: .destructive) {
                                modelContext.delete(part)
                                selectedPart = nil
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "trash").font(.system(size: 18))
                                    Text("Delete").font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.red)
                                .frame(width: 50)
                            }
                        }

                        Spacer()

                        Button(action: { dismiss() }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(BlurView(style: .systemUltraThinMaterialDark))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddPart) {
            AddRoomPartView(room: room, defaultXOffset: 0, defaultYOffset: Double(room.height) / 2 + 0.5)
        }
    }
}

// MARK: - Shape Rectangle Component
struct RoomShapeRect: View {
    let label: String
    let width: CGFloat
    let height: CGFloat
    let isBase: Bool
    let isSelected: Bool
    var scale: CGFloat = FloorplanGeometry.pointsPerMetre

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer()
            if !isBase {
                Text(String(format: "%.1fx%.1fm", width / scale, height / scale))
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(8)
        .frame(width: max(width, 30), height: max(height, 30))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isBase ? Color(red: 0.25, green: 0.45, blue: 0.75).opacity(0.2) : (isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.08)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isBase ? Color(red: 0.25, green: 0.45, blue: 0.75) : (isSelected ? Color.blue : Color.white.opacity(0.25)), lineWidth: isBase ? 2 : (isSelected ? 2 : 1))
        )
    }
}

// MARK: - Add Room Part View
struct AddRoomPartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let room: Room
    let defaultXOffset: Double
    let defaultYOffset: Double

    @State private var name = "Part"
    @State private var widthString = "1.0"
    @State private var heightString = "1.0"
    @State private var xOffsetString = "0.0"
    @State private var yOffsetString = "0.0"

    @State private var backgroundStars = StarryBackground.generateStars()

    init(room: Room, defaultXOffset: Double, defaultYOffset: Double) {
        self.room = room
        self.defaultXOffset = defaultXOffset
        self.defaultYOffset = defaultYOffset
        _xOffsetString = State(initialValue: String(format: "%.1f", defaultXOffset))
        _yOffsetString = State(initialValue: String(format: "%.1f", defaultYOffset))
    }

    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("ADD PART").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 50)

                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))

                            HStack(spacing: 16) {
                                GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue)
                                GlassTextField(title: "Height (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue)
                            }

                            HStack(spacing: 16) {
                                GlassTextField(title: "X Offset (m)", text: $xOffsetString, icon: "arrow.left.and.right", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                                GlassTextField(title: "Y Offset (m)", text: $yOffsetString, icon: "arrow.up.and.down", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            }

                            Text("Offsets are relative to the room's center. Positive Y = down, Positive X = right.")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.white.opacity(0.7)) }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { savePart(); dismiss() }.foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func savePart() {
        let part = RoomPart(
            name: name,
            width: Double(widthString) ?? 1.0,
            height: Double(heightString) ?? 1.0,
            xOffset: Double(xOffsetString) ?? 0,
            yOffset: Double(yOffsetString) ?? 0
        )
        part.room = room
        room.parts.append(part)
        modelContext.insert(part)
    }
}

// MARK: - Room Part Detail View (edit dimensions)
struct RoomPartDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var part: RoomPart

    @State private var widthString: String
    @State private var heightString: String
    @State private var xOffsetString: String
    @State private var yOffsetString: String

    @State private var backgroundStars = StarryBackground.generateStars()

    init(part: RoomPart) {
        self.part = part
        _widthString = State(initialValue: String(format: "%.1f", part.width))
        _heightString = State(initialValue: String(format: "%.1f", part.height))
        _xOffsetString = State(initialValue: String(format: "%.1f", part.xOffset))
        _yOffsetString = State(initialValue: String(format: "%.1f", part.yOffset))
    }

    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                                Text("Back").font(.system(size: 16))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 4)
                        Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                        Text("EDIT PART").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 50)

                    VStack(spacing: 16) {
                        GlassTextField(title: "Name", text: $part.name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))

                        HStack(spacing: 16) {
                            GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue)
                                .onChange(of: widthString) { _, v in part.width = Double(v) ?? part.width }
                            GlassTextField(title: "Height (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue)
                                .onChange(of: heightString) { _, v in part.height = Double(v) ?? part.height }
                        }

                        HStack(spacing: 16) {
                            GlassTextField(title: "X Offset (m)", text: $xOffsetString, icon: "arrow.left.and.right", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                                .onChange(of: xOffsetString) { _, v in part.xOffset = Double(v) ?? part.xOffset }
                            GlassTextField(title: "Y Offset (m)", text: $yOffsetString, icon: "arrow.up.and.down", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                                .onChange(of: yOffsetString) { _, v in part.yOffset = Double(v) ?? part.yOffset }
                        }

                        Text("Drag the part in the shape editor to reposition visually.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 24).padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
