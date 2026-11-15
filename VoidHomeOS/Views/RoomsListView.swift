import SwiftUI
import SwiftData
import UIKit

struct RoomsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Floor.floorNumber) private var floors: [Floor]
    @State private var showingAddRoom = false
    @State private var showingAddFloor = false
    @State private var isFloorplanMode = true
    @State private var currentFloor = 0
    @State private var selectedRoom: Room?
    @State private var panOffset = CGSize.zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var isEditMode = true
    @State private var isDoorMode = false
    @State private var selectedDoor: Door?
    
    // Performance optimization: Generate starry background once
    @State private var backgroundStars = StarryBackground.generateStars()
    
    var filteredRooms: [Room] {
        rooms.filter { $0.floorNumber == currentFloor }
    }
    
    var sortedFloors: [Floor] {
        floors.sorted { $0.floorNumber < $1.floorNumber }
    }
    
    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack(alignment: .center) {
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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Text(isFloorplanMode ? "FLOORPLAN" : "ROOMS")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 0) {
                                Button(action: { withAnimation(.spring()) { isFloorplanMode = true } }) {
                                    Image(systemName: "map")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(isFloorplanMode ? .white : Color(red: 0.5, green: 0.45, blue: 0.6))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                        .background(isFloorplanMode ? Color.white.opacity(0.08) : Color.clear)
                                        .cornerRadius(10)
                                }
                                
                                Button(action: { withAnimation(.spring()) { isFloorplanMode = false } }) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(!isFloorplanMode ? .white : Color(red: 0.5, green: 0.45, blue: 0.6))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                        .background(!isFloorplanMode ? Color.white.opacity(0.08) : Color.clear)
                                        .cornerRadius(10)
                                }
                            }
                            .background(Color.white.opacity(0.02))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
                            .cornerRadius(12)
                            
                            if isFloorplanMode {
                                HStack(spacing: 12) {
                                    Button(action: { moveFloor(down: true) }) {
                                        Image(systemName: "arrow.down")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .disabled(sortedFloors.count <= 1)
                                    
                                    Text(currentFloorName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .tracking(1)
                                        .frame(width: 70)
                                    
                                    Button(action: { moveFloor(down: false) }) {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .disabled(sortedFloors.count <= 1)

                                    Button(action: { showingAddFloor = true }) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(red: 0.35, green: 0.55, blue: 0.9))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(BlurView(style: .systemUltraThinMaterialDark))
                                .cornerRadius(18)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                }
                .padding(.bottom, 20)
                
                if isFloorplanMode {
                    ZStack {
                        GeometryReader { geo in
                            ZStack {
                                FloorplanGridLines().opacity(0.25)

                                ForEach(filteredRooms) { room in
                                    InteractiveFloorplanRoom(
                                        room: room,
                                        canvasSize: geo.size,
                                        otherRooms: filteredRooms.filter { $0.id != room.id },
                                        isSelected: selectedRoom?.id == room.id,
                                        isEditMode: isEditMode && !isDoorMode,
                                        onTap: { selectedRoom = room },
                                        onDoorTap: { door in selectedDoor = door }
                                    )
                                }

                                // Door mode: show edge buttons on selected room
                                if isDoorMode, let room = selectedRoom {
                                    DoorPlacementOverlay(
                                        room: room,
                                        canvasSize: geo.size,
                                        scale: 35,
                                        onPlaceDoor: { edge in
                                            let door = Door(edge: edge, position: 0.5, opensLeft: true)
                                            door.room = room
                                            room.doors.append(door)
                                            modelContext.insert(door)
                                        }
                                    )
                                }

                                // Inline door editor — floats over floorplan when a door is tapped
                                if let door = selectedDoor {
                                    InlineDoorEditor(door: door, onClose: { selectedDoor = nil })
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                }

                                if filteredRooms.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "square.dashed")
                                            .font(.system(size: 48))
                                            .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                        Text("No rooms on this floor")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .scaleEffect(zoomScale)
                            .offset(panOffset)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRoom = nil }
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { scale in
                                            zoomScale = max(0.5, min(3.0, scale))
                                        }
                                        .onEnded { _ in
                                            if zoomScale < 0.7 { zoomScale = 1.0; panOffset = .zero }
                                        },
                                    DragGesture()
                                        .onChanged { gesture in
                                            panOffset = CGSize(width: gesture.translation.width, height: gesture.translation.height)
                                        }
                                        .onEnded { _ in
                                            // Keep pan offset as-is (don't reset)
                                        }
                                )
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.01))
                                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        
                        VStack {
                            HStack {
                                Spacer()
                                if zoomScale != 1.0 || panOffset != .zero {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            zoomScale = 1.0
                                            panOffset = .zero
                                        }
                                    }) {
                                        Image(systemName: "scope")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(8)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(Circle())
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 10)
                                }
                            }
                            Spacer()
                            HStack(spacing: 20) {
                                if let room = selectedRoom {
                                    RoomActionBar(
                                        room: room,
                                        floors: sortedFloors,
                                        onDelete: { modelContext.delete(room); selectedRoom = nil }
                                    )
                                } else {
                                    HStack(spacing: 12) {
                                        Button(action: { showingAddRoom = true }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Room")
                                            }
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 14)
                                            .background(Color.blue)
                                            .cornerRadius(25)
                                            .shadow(color: .blue.opacity(0.3), radius: 10)
                                        }

                                        Button(action: { withAnimation { isDoorMode.toggle() } }) {
                                            HStack {
                                                Image(systemName: isDoorMode ? "door.left.hand.open.fill" : "door.left.hand.open")
                                                Text("Doors")
                                            }
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 14)
                                            .background(isDoorMode ? Color(red: 0.3, green: 0.6, blue: 0.5) : Color.white.opacity(0.1))
                                            .cornerRadius(25)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(rooms) { room in
                                Button(action: {
                                    selectedRoom = room
                                    withAnimation { isFloorplanMode = true }
                                }) {
                                    RoomRow(room: room)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) { withAnimation { modelContext.delete(room) } } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            let floorNumbers = sortedFloors.map { $0.floorNumber }
            if !floorNumbers.isEmpty && !floorNumbers.contains(currentFloor) {
                currentFloor = floorNumbers.first ?? 0
            }
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomView(defaultFloor: currentFloor, availableFloors: sortedFloors)
        }
        .sheet(isPresented: $showingAddFloor) {
            AddFloorView(existingFloorNumbers: sortedFloors.map { $0.floorNumber })
        }
    }
    
    private func moveFloor(down: Bool) {
        let floorNumbers = sortedFloors.map { $0.floorNumber }
        guard !floorNumbers.isEmpty else { return }

        if let currentIndex = floorNumbers.firstIndex(of: currentFloor) {
            let nextIndex = down ? currentIndex - 1 : currentIndex + 1
            if floorNumbers.indices.contains(nextIndex) {
                withAnimation { currentFloor = floorNumbers[nextIndex] }
            }
        }
    }

    private func autoArrange() {
        // Tidy up: snap each room to nearest grid point without moving significantly
        let gridStep = 0.02 // ~2% of canvas
        withAnimation(.spring()) {
            for room in filteredRooms {
                room.xPosition = (room.xPosition / gridStep).rounded() * gridStep
                room.yPosition = (room.yPosition / gridStep).rounded() * gridStep
            }
        }
    }

    private func spreadRooms() {
        // Spread all rooms on this floor to non-overlapping positions
        let rooms = filteredRooms
        guard !rooms.isEmpty else { return }

        withAnimation(.spring()) {
            for (index, room) in rooms.enumerated() {
                let col = index % 2
                let row = index / 2
                room.xPosition = col == 0 ? 0.2 : 0.8
                room.yPosition = 0.15 + Double(row) * 0.5
            }
            zoomScale = 1.0
            panOffset = .zero
        }
    }
    
    private var currentFloorName: String {
        if let floor = floors.first(where: { $0.floorNumber == currentFloor }) {
            return floor.displayName.uppercased()
        }
        return floorName(for: currentFloor)
    }
    
    private func floorName(for floor: Int) -> String {
        switch floor {
        case 0: return "GROUND"
        case 1: return "1ST FLOOR"
        case 2: return "2ND FLOOR"
        case -1: return "BASEMENT"
        default: return floor > 0 ? "\(floor)TH FLOOR" : "LEVEL \(floor)"
        }
    }
}

// MARK: - Components

struct ActionButton: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(tint)
            .frame(width: 50)
        }
    }
}

struct InteractiveFloorplanRoom: View {
    @Bindable var room: Room
    let canvasSize: CGSize
    let otherRooms: [Room]
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    var onDoorTap: ((Door) -> Void)? = nil

    private let scale: CGFloat = 35
    private let fineGrid: CGFloat = 4
    private let snapThreshold: CGFloat = 12

    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var snapLineX: CGFloat? = nil
    @State private var snapLineY: CGFloat? = nil
    @State private var wasSnapping = false

    var body: some View {
        let roomWidth = CGFloat(room.width) * scale
        let roomHeight = CGFloat(room.height) * scale
        let initialX = room.xPosition * canvasSize.width
        let initialY = room.yPosition * canvasSize.height

        ZStack {
            // Composite shape drawn as one unified path via Canvas
            CompositeRoomShape(
                roomWidth: roomWidth,
                roomHeight: roomHeight,
                parts: room.parts,
                doors: room.doors,
                scale: scale,
                isSelected: isSelected
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)

            // Room label — centered in the room, inset from edges to avoid doors
            VStack(spacing: 2) {
                Text(room.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(String(format: "%.0fx%.0fm", room.width, room.height))
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: max(roomWidth - 16, 0), height: max(roomHeight - 16, 0))
            .allowsHitTesting(false)

            // Labels for each additional part (measurements only, no name)
            ForEach(room.parts) { part in
                let pw = CGFloat(part.width) * scale
                let ph = CGFloat(part.height) * scale
                let px = CGFloat(part.xOffset) * scale
                let py = CGFloat(part.yOffset) * scale

                if pw >= 30 && ph >= 25 {
                    Text(String(format: "%.0fx%.0fm", part.width, part.height))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                        .minimumScaleFactor(0.5)
                        .frame(width: pw, height: ph)
                        .offset(x: px, y: py)
                        .allowsHitTesting(false)
                }
            }

            // Invisible tap target over the base
            Color.clear
                .frame(width: roomWidth, height: roomHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            if isSelected {
                // Selection indicator removed — blue outline is enough
                EmptyView()
            }
        }
        .rotationEffect(.degrees(room.rotation))
        .position(x: initialX + dragOffset.width, y: initialY + dragOffset.height)
        .overlay {
            // Door tap targets — rendered in canvas coordinate space
            DoorTapTargets(
                room: room,
                roomWidth: roomWidth,
                roomHeight: roomHeight,
                onDoorTap: onDoorTap
            )
            .position(x: initialX + dragOffset.width, y: initialY + dragOffset.height)
            .rotationEffect(.degrees(room.rotation), anchor: .center)
        }
        .overlay {
            // Snap guide lines — show both X and Y simultaneously
            if let x = snapLineX {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.8))
                    .frame(width: 1.5, height: canvasSize.height)
                    .position(x: x, y: canvasSize.height / 2)
                    .allowsHitTesting(false)
            }
            if let y = snapLineY {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.8))
                    .frame(width: canvasSize.width, height: 1.5)
                    .position(x: canvasSize.width / 2, y: y)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    guard isEditMode else { return }
                    isDragging = true
                    let result = computeSnap(
                        initialX: initialX, initialY: initialY,
                        translation: gesture.translation,
                        roomWidth: roomWidth, roomHeight: roomHeight
                    )
                    dragOffset = result.offset
                    snapLineX = result.lineX
                    snapLineY = result.lineY

                    // Haptic feedback when snap engages
                    let isSnapping = result.lineX != nil || result.lineY != nil
                    if isSnapping && !wasSnapping {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    wasSnapping = isSnapping
                }
                .onEnded { gesture in
                    isDragging = false
                    let result = computeSnap(
                        initialX: initialX, initialY: initialY,
                        translation: gesture.translation,
                        roomWidth: roomWidth, roomHeight: roomHeight
                    )
                    let finalX = initialX + result.offset.width
                    let finalY = initialY + result.offset.height
                    room.xPosition = max(0, min(1, finalX / canvasSize.width))
                    room.yPosition = max(0, min(1, finalY / canvasSize.height))
                    dragOffset = .zero
                    snapLineX = nil
                    snapLineY = nil
                }
        )
    }

    private struct SnapResult {
        let offset: CGSize
        let lineX: CGFloat?
        let lineY: CGFloat?
    }

    private func computeSnap(initialX: CGFloat, initialY: CGFloat, translation: CGSize, roomWidth: CGFloat, roomHeight: CGFloat) -> SnapResult {
        let rawX = initialX + translation.width
        let rawY = initialY + translation.height
        let isRotated = Int(room.rotation.truncatingRemainder(dividingBy: 360)) % 180 != 0
        
        // Add 6.0 points to the visual bounding box to account for the 3.0 point wall outline inflation on both sides!
        let myVisW = (isRotated ? roomHeight : roomWidth) + 6.0
        let myVisH = (isRotated ? roomWidth : roomHeight) + 6.0
        let myLeft = rawX - myVisW / 2
        let myRight = rawX + myVisW / 2
        let myTop = rawY - myVisH / 2
        let myBottom = rawY + myVisH / 2

        var bestSnapX: (delta: CGFloat, target: CGFloat?) = (CGFloat.infinity, nil)
        var bestSnapY: (delta: CGFloat, target: CGFloat?) = (CGFloat.infinity, nil)

        for other in otherRooms {
            let otherRotated = Int(other.rotation.truncatingRemainder(dividingBy: 360)) % 180 != 0
            let ow = CGFloat(other.width) * scale
            let oh = CGFloat(other.height) * scale
            
            // Add 6.0 points to other rooms' bounding boxes as well!
            let oVisW: CGFloat = (otherRotated ? oh : ow) + 6.0
            let oVisH: CGFloat = (otherRotated ? ow : oh) + 6.0
            let ox = other.xPosition * canvasSize.width
            let oy = other.yPosition * canvasSize.height
            let oLeft = ox - oVisW / 2
            let oRight = ox + oVisW / 2
            let oTop = oy - oVisH / 2
            let oBottom = oy + oVisH / 2

            let verticalOverlap = min(myBottom, oBottom) - max(myTop, oTop) > 2
            let horizontalOverlap = min(myRight, oRight) - max(myLeft, oLeft) > 2

            var xCandidates: [(CGFloat, CGFloat)] = []
            xCandidates.append((myLeft - oRight, oRight + myVisW / 2))
            xCandidates.append((myRight - oLeft, oLeft - myVisW / 2))
            if !verticalOverlap {
                xCandidates.append((myLeft - oLeft, oLeft + myVisW / 2))
                xCandidates.append((myRight - oRight, oRight - myVisW / 2))
            }

            for (diff, targetCenterX) in xCandidates {
                let absDiff = abs(diff)
                if absDiff < snapThreshold && absDiff < abs(bestSnapX.delta) {
                    bestSnapX = (diff, targetCenterX)
                }
            }

            var yCandidates: [(CGFloat, CGFloat)] = []
            yCandidates.append((myTop - oBottom, oBottom + myVisH / 2))
            yCandidates.append((myBottom - oTop, oTop - myVisH / 2))
            if !horizontalOverlap {
                yCandidates.append((myTop - oTop, oTop + myVisH / 2))
                yCandidates.append((myBottom - oBottom, oBottom - myVisH / 2))
            }

            for (diff, targetCenterY) in yCandidates {
                let absDiff = abs(diff)
                if absDiff < snapThreshold && absDiff < abs(bestSnapY.delta) {
                    bestSnapY = (diff, targetCenterY)
                }
            }
        }

        var snappedX: CGFloat
        var lineX: CGFloat? = nil
        if let targetX = bestSnapX.target {
            snappedX = targetX
            lineX = targetX
        } else {
            snappedX = initialX + round(translation.width / fineGrid) * fineGrid
        }

        var snappedY: CGFloat
        var lineY: CGFloat? = nil
        if let targetY = bestSnapY.target {
            snappedY = targetY
            lineY = targetY
        } else {
            snappedY = initialY + round(translation.height / fineGrid) * fineGrid
        }

        var resolvedX = snappedX
        var resolvedY = snappedY

        for _ in 0..<4 {
            for other in otherRooms {
                let otherRotated = Int(other.rotation.truncatingRemainder(dividingBy: 360)) % 180 != 0
                let ow = CGFloat(other.width) * scale
                let oh = CGFloat(other.height) * scale
                let oVisW: CGFloat = (otherRotated ? oh : ow) + 6.0
                let oVisH: CGFloat = (otherRotated ? ow : oh) + 6.0
                let ox = other.xPosition * canvasSize.width
                let oy = other.yPosition * canvasSize.height
                let oLeft = ox - oVisW / 2
                let oRight = ox + oVisW / 2
                let oTop = oy - oVisH / 2
                let oBottom = oy + oVisH / 2

                let curLeft = resolvedX - myVisW / 2
                let curRight = resolvedX + myVisW / 2
                let curTop = resolvedY - myVisH / 2
                let curBottom = resolvedY + myVisH / 2

                let overlapX = min(curRight, oRight) - max(curLeft, oLeft)
                let overlapY = min(curBottom, oBottom) - max(curTop, oTop)

                if overlapX > 0.1 && overlapY > 0.1 {
                    // Stable AABB Collision Push-Out along path of absolute least resistance
                    if overlapX < overlapY {
                        let pushLeft = curRight - oLeft
                        let pushRight = oRight - curLeft
                        if pushLeft < pushRight {
                            resolvedX -= pushLeft
                        } else {
                            resolvedX += pushRight
                        }
                    } else {
                        let pushUp = curBottom - oTop
                        let pushDown = oBottom - curTop
                        if pushUp < pushDown {
                            resolvedY -= pushUp
                        } else {
                            resolvedY += pushDown
                        }
                    }
                }
            }
        }

        let snappedOffsetW = resolvedX - initialX
        let snappedOffsetH = resolvedY - initialY
        return SnapResult(offset: CGSize(width: snappedOffsetW, height: snappedOffsetH), lineX: lineX, lineY: lineY)
    }
}

// MARK: - Composite Room Shape (Canvas-based, one unified shape)
struct CompositeRoomShape: View {
    let roomWidth: CGFloat
    let roomHeight: CGFloat
    let parts: [RoomPart]
    let doors: [Door]
    let scale: CGFloat
    let isSelected: Bool

    private let doorWidth: CGFloat = 28 // visual width of door gap in points

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Collect all rectangles (base + parts)
            var rects: [CGRect] = []
            let baseRect = CGRect(x: centerX - roomWidth / 2, y: centerY - roomHeight / 2, width: roomWidth, height: roomHeight)
            rects.append(baseRect)
            for part in parts {
                let pw = CGFloat(part.width) * scale
                let ph = CGFloat(part.height) * scale
                let px = centerX + CGFloat(part.xOffset) * scale
                let py = centerY + CGFloat(part.yOffset) * scale
                rects.append(CGRect(x: px - pw / 2, y: py - ph / 2, width: pw, height: ph))
            }

            let strokeColor = isSelected ? Color.blue : Color.white.opacity(0.2)
            let fillColor = isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05)
            let lineWidth: CGFloat = isSelected ? 2 : 1
            let inflate: CGFloat = 3

            // Step 1: Fill inflated rects with stroke color
            var outlinePath = Path()
            for r in rects {
                let inflated = CGRect(x: r.minX - inflate, y: r.minY - inflate,
                                      width: r.width + inflate * 2, height: r.height + inflate * 2)
                outlinePath.addRect(inflated)
            }
            context.fill(outlinePath, with: .color(strokeColor))

            // Step 2: Fill normal rects with fill color
            var fillPath = Path()
            for r in rects {
                fillPath.addRect(r)
            }
            context.fill(fillPath, with: .color(fillColor))
            context.fill(fillPath, with: .color(fillColor))

            // Step 3: Draw doors — erase a gap in the wall and draw swing arc
            for door in doors {
                let doorPos = CGFloat(door.position)
                let dw = door.isDoubleDoor ? doorWidth * 2.0 : doorWidth

                // Calculate door position on the base rect edge
                var doorX: CGFloat = 0
                var doorY: CGFloat = 0
                var isHorizontal = false

                switch door.edge {
                case .top:
                    doorX = baseRect.minX + doorPos * baseRect.width
                    doorY = baseRect.minY
                    isHorizontal = true
                case .bottom:
                    doorX = baseRect.minX + doorPos * baseRect.width
                    doorY = baseRect.maxY
                    isHorizontal = true
                case .left:
                    doorX = baseRect.minX
                    doorY = baseRect.minY + doorPos * baseRect.height
                    isHorizontal = false
                case .right:
                    doorX = baseRect.maxX
                    doorY = baseRect.minY + doorPos * baseRect.height
                    isHorizontal = false
                }

                // Erase the wall segment where the door is (draw fill color over it)
                let eraseRect: CGRect
                if isHorizontal {
                    eraseRect = CGRect(x: doorX - dw/2 - inflate, y: doorY - inflate - 1,
                                       width: dw + inflate * 2, height: inflate * 2 + 2)
                } else {
                    eraseRect = CGRect(x: doorX - inflate - 1, y: doorY - dw/2 - inflate,
                                       width: inflate * 2 + 2, height: dw + inflate * 2)
                }
                context.fill(Path(eraseRect), with: .color(fillColor))

                let doorColor = Color(red: 0.85, green: 0.85, blue: 0.9)
                let arcColor = Color(red: 0.5, green: 0.5, blue: 0.55)
                let doorLen = door.isDoubleDoor ? (dw / 2) - 1.5 : dw

                // Hinge is at one end of the door gap
                // opensLeft = hinge at left/top end; !opensLeft = hinge at right/bottom end
                // opensInward = door swings into room; !opensInward = swings outward

                // Compute hinge point, closed tip (along wall), open tip (perpendicular)
                let hinge: CGPoint
                let closedTip: CGPoint  // where door tip would be if closed (along wall)
                let openTip: CGPoint    // where door tip is when open (perpendicular)

                switch door.edge {
                case .bottom:
                    // Wall is horizontal, interior is above (negative Y)
                    hinge = CGPoint(x: door.opensLeft ? doorX - dw/2 : doorX + dw/2, y: doorY)
                    // Closed: door lies along wall toward the other end of gap
                    closedTip = CGPoint(x: door.opensLeft ? hinge.x + doorLen : hinge.x - doorLen, y: doorY)
                    // Open: perpendicular to wall, inward=up or outward=down
                    openTip = CGPoint(x: hinge.x, y: doorY + (door.opensInward ? -doorLen : doorLen))

                case .top:
                    // Wall is horizontal, interior is below (positive Y)
                    hinge = CGPoint(x: door.opensLeft ? doorX - dw/2 : doorX + dw/2, y: doorY)
                    closedTip = CGPoint(x: door.opensLeft ? hinge.x + doorLen : hinge.x - doorLen, y: doorY)
                    openTip = CGPoint(x: hinge.x, y: doorY + (door.opensInward ? doorLen : -doorLen))

                case .left:
                    // Wall is vertical, interior is to the right (positive X)
                    hinge = CGPoint(x: doorX, y: door.opensLeft ? doorY - dw/2 : doorY + dw/2)
                    closedTip = CGPoint(x: doorX, y: door.opensLeft ? hinge.y + doorLen : hinge.y - doorLen)
                    openTip = CGPoint(x: doorX + (door.opensInward ? doorLen : -doorLen), y: hinge.y)

                case .right:
                    // Wall is vertical, interior is to the left (negative X)
                    hinge = CGPoint(x: doorX, y: door.opensLeft ? doorY - dw/2 : doorY + dw/2)
                    closedTip = CGPoint(x: doorX, y: door.opensLeft ? hinge.y + doorLen : hinge.y - doorLen)
                    openTip = CGPoint(x: doorX + (door.opensInward ? -doorLen : doorLen), y: hinge.y)
                }

                // Compute arc from closedTip to openTip, centered at hinge
                // Angle from hinge to a point: atan2(dy, dx) in screen coords (Y down)
                let startAngle = atan2(closedTip.y - hinge.y, closedTip.x - hinge.x)
                let endAngle = atan2(openTip.y - hinge.y, openTip.x - hinge.x)

                // Determine clockwise: in screen coords (Y down), clockwise = increasing angle
                // We want the short way (90 degrees)
                var delta = endAngle - startAngle
                while delta > .pi { delta -= 2 * .pi }
                while delta < -.pi { delta += 2 * .pi }
                // SwiftUI's flipped coordinate system: clockwise:true = counterclockwise visually
                // We want the short 90-degree arc, so invert the direction
                let clockwise = delta < 0

                var arcPath = Path()
                arcPath.addArc(center: hinge, radius: doorLen,
                               startAngle: .radians(startAngle),
                               endAngle: .radians(endAngle),
                               clockwise: clockwise)

                // Door panel: from hinge to open tip
                var doorPanel = Path()
                doorPanel.move(to: hinge)
                doorPanel.addLine(to: openTip)

                // Draw swing arc
                context.stroke(arcPath, with: .color(arcColor.opacity(0.5)), lineWidth: 0.8)
                // Draw door panel
                context.stroke(doorPanel, with: .color(doorColor), lineWidth: 2)

                // Double door: draw second panel from opposite hinge
                if door.isDoubleDoor {
                    let hinge2: CGPoint
                    let openTip2: CGPoint
                    let closedTip2: CGPoint

                    switch door.edge {
                    case .bottom:
                        hinge2 = CGPoint(x: door.opensLeft ? doorX + dw/2 : doorX - dw/2, y: doorY)
                        closedTip2 = CGPoint(x: door.opensLeft ? hinge2.x - doorLen : hinge2.x + doorLen, y: doorY)
                        openTip2 = CGPoint(x: hinge2.x, y: doorY + (door.opensInward ? -doorLen : doorLen))
                    case .top:
                        hinge2 = CGPoint(x: door.opensLeft ? doorX + dw/2 : doorX - dw/2, y: doorY)
                        closedTip2 = CGPoint(x: door.opensLeft ? hinge2.x - doorLen : hinge2.x + doorLen, y: doorY)
                        openTip2 = CGPoint(x: hinge2.x, y: doorY + (door.opensInward ? doorLen : -doorLen))
                    case .left:
                        hinge2 = CGPoint(x: doorX, y: door.opensLeft ? doorY + dw/2 : doorY - dw/2)
                        closedTip2 = CGPoint(x: doorX, y: door.opensLeft ? hinge2.y - doorLen : hinge2.y + doorLen)
                        openTip2 = CGPoint(x: doorX + (door.opensInward ? doorLen : -doorLen), y: hinge2.y)
                    case .right:
                        hinge2 = CGPoint(x: doorX, y: door.opensLeft ? doorY + dw/2 : doorY - dw/2)
                        closedTip2 = CGPoint(x: doorX, y: door.opensLeft ? hinge2.y - doorLen : hinge2.y + doorLen)
                        openTip2 = CGPoint(x: doorX + (door.opensInward ? -doorLen : doorLen), y: hinge2.y)
                    }

                    let startAngle2 = atan2(closedTip2.y - hinge2.y, closedTip2.x - hinge2.x)
                    let endAngle2 = atan2(openTip2.y - hinge2.y, openTip2.x - hinge2.x)
                    var delta2 = endAngle2 - startAngle2
                    while delta2 > .pi { delta2 -= 2 * .pi }
                    while delta2 < -.pi { delta2 += 2 * .pi }
                    let clockwise2 = delta2 < 0

                    var arcPath2 = Path()
                    arcPath2.addArc(center: hinge2, radius: doorLen,
                                    startAngle: .radians(startAngle2),
                                    endAngle: .radians(endAngle2),
                                    clockwise: clockwise2)

                    var doorPanel2 = Path()
                    doorPanel2.move(to: hinge2)
                    doorPanel2.addLine(to: openTip2)

                    context.stroke(arcPath2, with: .color(arcColor.opacity(0.5)), lineWidth: 0.8)
                    context.stroke(doorPanel2, with: .color(doorColor), lineWidth: 2)
                }
            }
        }
    }
}

// MARK: - Door Tap Targets
struct DoorTapTargets: View {
    let room: Room
    let roomWidth: CGFloat
    let roomHeight: CGFloat
    let onDoorTap: ((Door) -> Void)?

    var body: some View {
        ZStack {
            ForEach(room.doors) { door in
                let doorPos = CGFloat(door.position)
                let baseDw: CGFloat = 36
                let dw: CGFloat = door.isDoubleDoor ? baseDw * 2.0 : baseDw

                Group {
                    switch door.edge {
                    case .top:
                        Color.clear
                            .frame(width: dw, height: 24)
                            .contentShape(Rectangle())
                            .offset(x: (doorPos - 0.5) * roomWidth, y: -roomHeight / 2)
                    case .bottom:
                        Color.clear
                            .frame(width: dw, height: 24)
                            .contentShape(Rectangle())
                            .offset(x: (doorPos - 0.5) * roomWidth, y: roomHeight / 2)
                    case .left:
                        Color.clear
                            .frame(width: 24, height: dw)
                            .contentShape(Rectangle())
                            .offset(x: -roomWidth / 2, y: (doorPos - 0.5) * roomHeight)
                    case .right:
                        Color.clear
                            .frame(width: 24, height: dw)
                            .contentShape(Rectangle())
                            .offset(x: roomWidth / 2, y: (doorPos - 0.5) * roomHeight)
                    }
                }
                .onTapGesture { onDoorTap?(door) }
            }
        }
    }
}

// MARK: - Door Placement Overlay
struct DoorPlacementOverlay: View {
    let room: Room
    let canvasSize: CGSize
    let scale: CGFloat
    let onPlaceDoor: (DoorEdge) -> Void

    var body: some View {
        let roomWidth = CGFloat(room.width) * scale
        let roomHeight = CGFloat(room.height) * scale
        let cx = room.xPosition * canvasSize.width
        let cy = room.yPosition * canvasSize.height
        let gap: CGFloat = 30

        ZStack {
            // Top edge button
            Button(action: { onPlaceDoor(.top) }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Top")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 56, height: 36)
                .background(Color(red: 0.3, green: 0.6, blue: 0.5))
                .cornerRadius(10)
            }
            .position(x: cx, y: cy - roomHeight / 2 - gap)

            // Bottom edge button
            Button(action: { onPlaceDoor(.bottom) }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Bottom")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 56, height: 36)
                .background(Color(red: 0.3, green: 0.6, blue: 0.5))
                .cornerRadius(10)
            }
            .position(x: cx, y: cy + roomHeight / 2 + gap)

            // Left edge button
            Button(action: { onPlaceDoor(.left) }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Left")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 48, height: 36)
                .background(Color(red: 0.3, green: 0.6, blue: 0.5))
                .cornerRadius(10)
            }
            .position(x: cx - roomWidth / 2 - gap, y: cy)

            // Right edge button
            Button(action: { onPlaceDoor(.right) }) {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 48, height: 36)
                .background(Color(red: 0.3, green: 0.6, blue: 0.5))
                .cornerRadius(10)
            }
            .position(x: cx + roomWidth / 2 + gap, y: cy)
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Inline Door Editor (floats over floorplan)
struct InlineDoorEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var door: Door
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("EDIT DOOR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(2)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Edge picker
            Picker("Edge", selection: $door.edge) {
                ForEach(DoorEdge.allCases, id: \.self) { e in
                    Text(e.rawValue).tag(e)
                }
            }
            .pickerStyle(.segmented)

            // Position slider — clamped to keep door on the room edge
            VStack(spacing: 4) {
                Text("Position")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                HStack(spacing: 10) {
                    Text("0%")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Slider(value: $door.position, in: 0.05...0.95)
                        .tint(Color(red: 0.3, green: 0.6, blue: 0.5))
                    Text("100%")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Hinge side + swing direction + double door + delete — icons only
            HStack(spacing: 10) {
                Button(action: { door.opensLeft.toggle() }) {
                    Image(systemName: door.opensLeft ? "arrow.left.to.line" : "arrow.right.to.line")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 36)
                        .background(Color(red: 0.3, green: 0.6, blue: 0.5).opacity(0.3))
                        .cornerRadius(10)
                }

                Button(action: { door.opensInward.toggle() }) {
                    Image(systemName: door.opensInward ? "arrow.down.right.and.arrow.up.left" : "arrow.up.right.and.arrow.down.left")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 36)
                        .background(Color(red: 0.4, green: 0.5, blue: 0.7).opacity(0.3))
                        .cornerRadius(10)
                }

                Button(action: { door.isDoubleDoor.toggle() }) {
                    Image(systemName: door.isDoubleDoor ? "rectangle.split.2x1.fill" : "rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 36)
                        .background(door.isDoubleDoor ? Color(red: 0.5, green: 0.4, blue: 0.7).opacity(0.4) : Color.white.opacity(0.08))
                        .cornerRadius(10)
                }

                Spacer()

                Button(role: .destructive) {
                    modelContext.delete(door)
                    onClose()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 40, height: 36)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 80)
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct FloorplanGridLines: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 30
                for i in 0...Int(geo.size.width / spacing) {
                    let x = CGFloat(i) * spacing
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                for i in 0...Int(geo.size.height / spacing) {
                    let y = CGFloat(i) * spacing
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

struct RoomRow: View {
    let room: Room
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.04)).frame(width: 50, height: 50)
                    .overlay(Circle().stroke(LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5))
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 20, weight: .medium)).foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name).font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                Text(room.floorDisplay).font(.system(size: 14)).foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(room.assets.count)").font(.system(size: 20, weight: .light)).foregroundColor(.white)
                Text("assets").font(.system(size: 11, weight: .medium)).foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6)).tracking(0.5)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.02)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)))
    }
}

// MARK: - Room Doors Section
struct RoomDoorsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DOORS (\(room.doors.count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                .tracking(2)

            ForEach(room.doors) { door in
                DoorRow(door: door) {
                    modelContext.delete(door)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
        )
    }
}

struct DoorRow: View {
    @Bindable var door: Door
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "door.left.hand.open")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.6))

            VStack(alignment: .leading, spacing: 4) {
                Picker("Edge", selection: $door.edge) {
                    ForEach(DoorEdge.allCases, id: \.self) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                HStack(spacing: 8) {
                    Text("Position")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    Slider(value: $door.position, in: 0.05...0.95)
                        .frame(width: 100)
                    Button(action: { door.opensLeft.toggle() }) {
                        Image(systemName: door.opensLeft ? "text.alignleft" : "text.alignright")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.6))
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                    Button(action: { door.opensInward.toggle() }) {
                        Image(systemName: door.opensInward ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.7))
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
        )
    }
}

// MARK: - Room Action Bar (inline editing on floorplan)
struct RoomActionBar: View {
    @Bindable var room: Room
    let floors: [Floor]
    let onDelete: () -> Void

    @State private var widthText: String = ""
    @State private var heightText: String = ""

    var body: some View {
        VStack(spacing: 6) {
            // Name field above the bar — matching pill style
            TextField("Room Name", text: $room.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(BlurView(style: .systemUltraThinMaterialDark))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .frame(maxWidth: 180)

            // Single floating bar — same style as the old action bar
            HStack(spacing: 12) {
                // W
                VStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    TextField("", text: $widthText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .onChange(of: widthText) { _, newVal in
                            if let v = Double(newVal), v > 0 { room.width = v }
                        }
                    Text("W")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                }
                .frame(width: 50)

                // H
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    TextField("", text: $heightText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                        .onChange(of: heightText) { _, newVal in
                            if let v = Double(newVal), v > 0 { room.height = v }
                        }
                    Text("H")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                }
                .frame(width: 50)

                // Floor
                Button(action: {
                    let floorNums = floors.map { $0.floorNumber }
                    if let idx = floorNums.firstIndex(of: room.floorNumber) {
                        let next = (idx + 1) % floorNums.count
                        room.floorNumber = floorNums[next]
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("\(room.floorNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Floor")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    }
                    .frame(width: 50)
                }

                // Shape Editor (Wired up to RoomShapeEditor)
                NavigationLink(destination: RoomShapeEditor(room: room)) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.split.2x2")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                        Text("Shape")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    }
                    .frame(width: 50)
                }

                ActionButton(icon: "trash", label: "Delete", tint: .red) {
                    onDelete()
                }
            }
            .padding(12)
            .background(BlurView(style: .systemUltraThinMaterialDark))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .onAppear {
            widthText = String(format: "%.1f", room.width)
            heightText = String(format: "%.1f", room.height)
        }
    }
}

struct AddRoomView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]

    let defaultFloor: Int
    let availableFloors: [Floor]
    @State private var name = ""
    @State private var floorNumber: Int
    @State private var widthString = "3.0"
    @State private var heightString = "4.0"

    // Optimization
    @State private var backgroundStars = StarryBackground.generateStars()

    init(defaultFloor: Int, availableFloors: [Floor] = []) {
        self.defaultFloor = defaultFloor
        self.availableFloors = availableFloors
        _floorNumber = State(initialValue: defaultFloor)
    }
    
    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("ADD ROOM").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 50)
                        
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FLOOR").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6)).tracking(1.5)
                                Picker("", selection: $floorNumber) {
                                    ForEach(availableFloors, id: \.floorNumber) { floor in
                                        Text(floor.displayName).tag(floor.floorNumber)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            HStack(spacing: 16) {
                                GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue)
                                GlassTextField(title: "Height (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue)
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.font(.system(size: 16)).foregroundColor(.white.opacity(0.8)) }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { saveRoom(); dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .disabled(name.isEmpty)
                            .foregroundColor(name.isEmpty ? .white.opacity(0.3) : Color(red: 0.25, green: 0.45, blue: 0.75))
                    }
                }
            }
        }
    }
    
    private func saveRoom() {
        let w = Double(widthString) ?? 3.0
        let h = Double(heightString) ?? 4.0
        let room = Room(name: name, floorNumber: floorNumber, width: w, height: h)

        // Stack rooms vertically with large gaps — each room gets its own row
        let existingOnFloor = homes.first?.rooms.filter { $0.floorNumber == floorNumber } ?? []
        let index = existingOnFloor.count
        // Alternate left/right, each row 0.5 apart vertically (enough for most rooms)
        let col = index % 2
        let row = index / 2
        room.xPosition = col == 0 ? 0.2 : 0.8
        room.yPosition = 0.15 + Double(row) * 0.5

        if let home = homes.first { home.rooms.append(room) }
        modelContext.insert(room)
    }
}

struct EditRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Floor.floorNumber) private var floors: [Floor]
    @Bindable var room: Room
    @State private var widthString: String
    @State private var heightString: String
    
    // Optimization
    @State private var backgroundStars = StarryBackground.generateStars()
    
    init(room: Room) {
        self.room = room
        _widthString = State(initialValue: String(format: "%.1f", room.width))
        _heightString = State(initialValue: String(format: "%.1f", room.height))
    }
    
    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("EDIT ROOM").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 50)
                        
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $room.name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FLOOR").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6)).tracking(1.5)
                                Picker("", selection: $room.floorNumber) {
                                    ForEach(floors.sorted { $0.floorNumber < $1.floorNumber }, id: \.floorNumber) { floor in
                                        Text(floor.displayName).tag(floor.floorNumber)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            HStack(spacing: 16) {
                                GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue)
                                    .onChange(of: widthString) { _, newValue in room.width = Double(newValue) ?? room.width }
                                GlassTextField(title: "Height (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue)
                                    .onChange(of: heightString) { _, newValue in room.height = Double(newValue) ?? room.height }
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.font(.system(size: 16)).foregroundColor(.white.opacity(0.8)) }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { dismiss() }.font(.system(size: 16, weight: .semibold)).foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75)) }
                }
            }
        }
    }
}

// MARK: - Add Floor View
struct AddFloorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    
    let existingFloorNumbers: [Int]
    @State private var name = ""
    @State private var floorNumber = 1
    
    @State private var backgroundStars = StarryBackground.generateStars()
    
    private var suggestedFloorNumber: Int {
        if existingFloorNumbers.isEmpty { return 0 }
        return (existingFloorNumbers.max() ?? 0) + 1
    }
    
    var body: some View {
        ZStack {
            StarryBackground(stars: backgroundStars).ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID").font(.system(size: 44, weight: .ultraLight, design: .default)).foregroundColor(.white).tracking(6).shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            Text("ADD FLOOR").font(.system(size: 13, weight: .medium)).foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65)).tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 50)
                        
                        VStack(spacing: 16) {
                            GlassTextField(title: "Floor Name (optional)", text: $name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FLOOR NUMBER").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6)).tracking(1.5)
                                HStack(spacing: 12) {
                                    Button(action: { if floorNumber > -5 { floorNumber -= 1 } }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
                                    }
                                    Text("\(floorNumber)")
                                        .font(.system(size: 28, weight: .light, design: .rounded))
                                        .foregroundColor(.white)
                                        .frame(width: 60)
                                    Button(action: { floorNumber += 1 }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
                                
                                if existingFloorNumbers.contains(floorNumber) {
                                    Text("A floor with this number already exists")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                                        .padding(.horizontal, 4)
                                }
                                
                                Text("Tip: Use 0 for Ground, -1 for Basement, 1+ for upper floors")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.font(.system(size: 16)).foregroundColor(.white.opacity(0.8)) }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { saveFloor(); dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .disabled(existingFloorNumbers.contains(floorNumber))
                            .foregroundColor(existingFloorNumbers.contains(floorNumber) ? .white.opacity(0.3) : Color(red: 0.25, green: 0.45, blue: 0.75))
                    }
                }
            }
        }
        .onAppear {
            floorNumber = suggestedFloorNumber
        }
    }
    
    private func saveFloor() {
        let floor = Floor(name: name, floorNumber: floorNumber)
        if let home = homes.first { home.floors.append(floor) }
        modelContext.insert(floor)
    }
}
