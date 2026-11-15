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
    @State private var showingRoomScan = false
    @State private var isFloorplanMode = true
    @State private var currentFloor = 0
    @State private var selectedRoom: Room?
    // Pan and zoom carry on from where the last gesture left them, and are kept between visits.
    @AppStorage("floorplan.zoom") private var zoomScale: Double = 1.0
    @AppStorage("floorplan.panX") private var panX: Double = 0
    @AppStorage("floorplan.panY") private var panY: Double = 0
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var panDrag: CGSize = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var openedRoom: Room?
    @State private var editingRoom: Room?

    /// A room to select and centre on when the screen opens (e.g. from search or a room's page).
    var initialRoom: Room? = nil

    init(initialRoom: Room? = nil) {
        self.initialRoom = initialRoom
    }
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
                                        onTap: { selectedDoor = nil; selectedRoom = room },
                                        onDoorTap: { door in selectedDoor = door }
                                    )
                                }

                                // Door mode: "+" buttons on every outside edge of the selected room, its extra pieces included
                                if isDoorMode, let room = selectedRoom, room.floorNumber == currentFloor {
                                    DoorPlacementOverlay(
                                        room: room,
                                        canvasSize: geo.size,
                                        onPlaceDoor: { edge, part in
                                            let door = Door(edge: edge, position: 0.5, opensLeft: true)
                                            modelContext.insert(door)
                                            door.room = room
                                            door.part = part
                                            selectedDoor = door
                                        }
                                    )
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
                                    .allowsHitTesting(false)
                                }
                            }
                            .coordinateSpace(name: FloorplanCanvas.space)
                            .scaleEffect(effectiveZoom)
                            .offset(effectivePan)
                            .onAppear { canvasSize = geo.size; migrateLegacyPositions(canvasSize: geo.size) }
                            .onChange(of: geo.size) { _, newSize in canvasSize = newSize; migrateLegacyPositions(canvasSize: newSize) }
                            .onChange(of: rooms.count) { _, _ in migrateLegacyPositions(canvasSize: geo.size) }
                        }
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { resetView() }
                        .onTapGesture { selectedRoom = nil; selectedDoor = nil }
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .updating($pinchScale) { value, state, _ in state = value }
                                    .onEnded { value in
                                        // Zoom about the middle of the screen: scale the pan with the zoom.
                                        let old = CGFloat(zoomScale)
                                        let new = clampZoom(old * value)
                                        panX *= Double(new / old)
                                        panY *= Double(new / old)
                                        zoomScale = Double(new)
                                    },
                                DragGesture()
                                    .updating($panDrag) { value, state, _ in state = value.translation }
                                    .onEnded { value in
                                        panX += Double(value.translation.width)
                                        panY += Double(value.translation.height)
                                    }
                            )
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.01))
                                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        
                        VStack {
                            HStack {
                                if isDoorMode {
                                    Text(selectedRoom == nil ? "Tap a room, then a + to add a door" : "Tap + to add a door, or a door to edit it")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(BlurView(style: .systemUltraThinMaterialDark))
                                        .clipShape(Capsule())
                                        .padding(.leading, 28)
                                        .padding(.top, 10)
                                }
                                Spacer()
                                if zoomScale != 1.0 || panX != 0 || panY != 0 {
                                    Button(action: { resetView() }) {
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

                            // Inline door editor — floats over the floorplan when a door is tapped
                            if let door = selectedDoor {
                                InlineDoorEditor(door: door, onClose: { selectedDoor = nil })
                                    .padding(.bottom, 8)
                            }

                            HStack(spacing: 20) {
                                if let room = selectedRoom, room.floorNumber == currentFloor {
                                    RoomActionBar(
                                        room: room,
                                        floors: sortedFloors,
                                        onRotate: { rotate(room) },
                                        onFloorChange: { newFloor in move(room, toFloor: newFloor) },
                                        onOpen: { openedRoom = room },
                                        onEdit: { editingRoom = room },
                                        onDelete: { delete(room) }
                                    )
                                    .id(room.id)
                                } else {
                                    HStack(spacing: 12) {
                                        Menu {
                                            Button { showingAddRoom = true } label: { Label("Draw a Room", systemImage: "square.dashed") }
                                            if RoomScanner.isSupported {
                                                Button { showingRoomScan = true } label: { Label("Scan a Room (LiDAR)", systemImage: "camera.metering.matrix") }
                                            }
                                        } label: {
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

                                        Button(action: { withAnimation { isDoorMode.toggle(); selectedDoor = nil } }) {
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

                                        if filteredRooms.count > 1 {
                                            Menu {
                                                Button { tidyRooms() } label: { Label("Tidy to grid", systemImage: "square.grid.3x3") }
                                                Button { spreadRooms() } label: { Label("Untangle overlaps", systemImage: "arrow.up.left.and.arrow.down.right") }
                                                Button { fitAll() } label: { Label("Show all rooms", systemImage: "viewfinder") }
                                            } label: {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 46, height: 46)
                                                    .background(Color.white.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                            .accessibilityLabel("Arrange rooms")
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
                            ForEach(roomsByFloor) { room in
                                NavigationLink(destination: RoomDetailView(room: room, onShowOnPlan: { focus(on: room) })) {
                                    RoomRow(room: room)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button { focus(on: room) } label: { Label("Show on Floor Plan", systemImage: "map") }
                                    Button(role: .destructive) { withAnimation { delete(room) } } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                            if rooms.isEmpty {
                                Text("No rooms yet. Add one from the floor plan.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .padding(.top, 40)
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
            if let focusRoom = initialRoom {
                focus(on: focusRoom)
            } else if !floorNumbers.isEmpty && !floorNumbers.contains(currentFloor) {
                currentFloor = floorNumbers.first ?? 0
            }
        }
        .onChange(of: currentFloor) { _, newFloor in
            // Never leave a room selected on a floor that isn't showing.
            if let room = selectedRoom, room.floorNumber != newFloor { selectedRoom = nil; selectedDoor = nil }
        }
        .sheet(isPresented: $showingAddRoom) {
            AddRoomView(defaultFloor: currentFloor, availableFloors: sortedFloors, preferredCenter: visibleCenter) { room in
                focus(on: room)
            }
        }
        .fullScreenCover(isPresented: $showingRoomScan) {
            RoomScanFlowView(defaultFloor: currentFloor, availableFloors: sortedFloors, preferredCenter: visibleCenter) { room in
                focus(on: room)
            }
        }
        .sheet(isPresented: $showingAddFloor) {
            AddFloorView(existingFloorNumbers: sortedFloors.map { $0.floorNumber })
        }
        .sheet(item: $editingRoom) { room in
            EditRoomView(room: room)
        }
        .navigationDestination(item: $openedRoom) { room in
            RoomDetailView(room: room, onShowOnPlan: { focus(on: room) })
        }
    }

    // MARK: - View state helpers

    private var effectiveZoom: CGFloat { clampZoom(CGFloat(zoomScale) * pinchScale) }
    private var effectivePan: CGSize {
        let ratio = effectiveZoom / CGFloat(zoomScale)
        return CGSize(width: CGFloat(panX) * ratio + panDrag.width, height: CGFloat(panY) * ratio + panDrag.height)
    }

    private func clampZoom(_ z: CGFloat) -> CGFloat { max(0.5, min(3.0, z)) }

    /// The plan point (metres) at the middle of the visible canvas.
    private var visibleCenter: CGPoint {
        let ppm = FloorplanGeometry.pointsPerMetre
        let z = CGFloat(zoomScale)
        return CGPoint(x: -CGFloat(panX) / (z * ppm), y: -CGFloat(panY) / (z * ppm))
    }

    private var roomsByFloor: [Room] {
        rooms.sorted { ($0.floorNumber, $0.name) < ($1.floorNumber, $1.name) }
    }

    private func resetView() {
        withAnimation(.spring()) {
            zoomScale = 1.0
            panX = 0
            panY = 0
        }
    }

    /// Switches to the room's floor, selects it and pans so it is in the middle of the canvas.
    private func focus(on room: Room) {
        if room.planX == nil, canvasSize.width > 0 {
            FloorplanGeometry.migrateLegacyPosition(of: room, canvasSize: canvasSize)
        }
        withAnimation(.spring()) {
            isFloorplanMode = true
            isDoorMode = false
            selectedDoor = nil
            currentFloor = room.floorNumber
            selectedRoom = room
            let c = FloorplanGeometry.center(of: room)
            let ppm = FloorplanGeometry.pointsPerMetre
            panX = Double(-c.x * ppm * CGFloat(zoomScale))
            panY = Double(-c.y * ppm * CGFloat(zoomScale))
        }
    }

    /// Converts rooms saved with canvas-share positions into metres, once, using this screen's canvas.
    private func migrateLegacyPositions(canvasSize: CGSize) {
        for room in rooms where room.planX == nil || room.planY == nil {
            FloorplanGeometry.migrateLegacyPosition(of: room, canvasSize: canvasSize)
        }
    }

    private func rotate(_ room: Room) {
        let others = rooms.filter { $0.floorNumber == room.floorNumber && $0.id != room.id }
        let turns = (FloorplanGeometry.quarterTurns(room.rotation) + 1) % 4
        let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
        let center = FloorplanGeometry.center(of: room)
        // Keep the room where it is if it fits; otherwise nudge it to the nearest free spot.
        let free = FloorplanGeometry.freeCenter(near: center, localRects: local, quarterTurns: turns,
                                                obstacles: others.map { FloorplanGeometry.worldRects(for: $0) }, gap: 0)
        withAnimation(.spring()) {
            room.rotation = Double(turns * 90)
            room.planX = Double(free.x)
            room.planY = Double(free.y)
        }
    }

    /// Moves a room to another floor, finds it a free spot there, and follows it.
    private func move(_ room: Room, toFloor newFloor: Int) {
        guard newFloor != room.floorNumber else { return }
        let others = rooms.filter { $0.floorNumber == newFloor && $0.id != room.id }
        let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
        let free = FloorplanGeometry.freeCenter(near: FloorplanGeometry.center(of: room), localRects: local,
                                                quarterTurns: FloorplanGeometry.quarterTurns(room.rotation),
                                                obstacles: others.map { FloorplanGeometry.worldRects(for: $0) })
        room.floorNumber = newFloor
        room.floor = room.floorDisplay
        room.planX = Double(free.x)
        room.planY = Double(free.y)
        focus(on: room)
    }

    private func delete(_ room: Room) {
        if selectedRoom?.id == room.id { selectedRoom = nil }
        selectedDoor = nil
        modelContext.delete(room)
    }

    /// Snaps every room on this floor to the nearest 0.5 m, leaving any room that would then overlap where it was.
    private func tidyRooms() {
        let step = 0.5
        withAnimation(.spring()) {
            for room in filteredRooms {
                let old = FloorplanGeometry.center(of: room)
                let snapped = CGPoint(x: (Double(old.x) / step).rounded() * step, y: (Double(old.y) / step).rounded() * step)
                let others = filteredRooms.filter { $0.id != room.id }.map { FloorplanGeometry.worldRects(for: $0) }
                let rects = FloorplanGeometry.worldRects(for: room, center: snapped)
                if !others.contains(where: { FloorplanGeometry.overlaps(rects, $0) }) {
                    room.planX = Double(snapped.x)
                    room.planY = Double(snapped.y)
                }
            }
        }
    }

    /// Moves any overlapping rooms on this floor to the nearest free spot; rooms that don't overlap stay put.
    private func spreadRooms() {
        withAnimation(.spring()) {
            var placed: [[CGRect]] = []
            for room in filteredRooms.sorted(by: { $0.createdAt < $1.createdAt }) {
                let rects = FloorplanGeometry.worldRects(for: room)
                if placed.contains(where: { FloorplanGeometry.overlaps(rects, $0) }) {
                    let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
                    let free = FloorplanGeometry.freeCenter(near: FloorplanGeometry.center(of: room), localRects: local,
                                                            quarterTurns: FloorplanGeometry.quarterTurns(room.rotation),
                                                            obstacles: placed, gap: 0.25)
                    room.planX = Double(free.x)
                    room.planY = Double(free.y)
                }
                placed.append(FloorplanGeometry.worldRects(for: room))
            }
        }
    }

    /// Zooms and pans so every room on this floor fits the canvas.
    private func fitAll() {
        let all = filteredRooms.flatMap { FloorplanGeometry.worldRects(for: $0) }
        guard !all.isEmpty, canvasSize.width > 0 else { return }
        let b = FloorplanGeometry.bounds(of: all)
        let ppm = FloorplanGeometry.pointsPerMetre
        let zoom = clampZoom(min(canvasSize.width / ((b.width + 2) * ppm), canvasSize.height / ((b.height + 2) * ppm)))
        withAnimation(.spring()) {
            zoomScale = Double(zoom)
            panX = Double(-b.midX * ppm * zoom)
            panY = Double(-b.midY * ppm * zoom)
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
        } else if let first = floorNumbers.first {
            withAnimation { currentFloor = first }
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
        case 3: return "3RD FLOOR"
        case -1: return "BASEMENT"
        default: return floor > 0 ? "\(floor)TH FLOOR" : "LEVEL \(floor)"
        }
    }
}

/// Shared names for the floor plan canvas.
enum FloorplanCanvas {
    /// Coordinate space of the unscaled plan content, so drags measure in plan points at any zoom.
    static let space = "floorplanCanvas"
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

    private let ppm = FloorplanGeometry.pointsPerMetre
    private let gridStep: CGFloat = 0.1          // metres; used when no edge is close enough to snap to
    private let snapThresholdPoints: CGFloat = 12

    /// Room centre in plan metres while a drag is in progress.
    @State private var dragCenter: CGPoint? = nil
    @State private var lastValidCenter: CGPoint? = nil
    @State private var snapLineX: CGFloat? = nil   // plan metres
    @State private var snapLineY: CGFloat? = nil
    @State private var wasSnapping = false

    private var origin: CGPoint { CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2) }

    private func toCanvas(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * ppm, y: origin.y + p.y * ppm)
    }

    var body: some View {
        let center = dragCenter ?? FloorplanGeometry.center(of: room)
        let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
        let extent = local.reduce(CGFloat(0)) { max($0, abs($1.minX), abs($1.maxX), abs($1.minY), abs($1.maxY)) } * ppm
        let side = extent * 2 + 90   // room for walls and door swings
        let roomWidth = CGFloat(room.width) * ppm
        let roomHeight = CGFloat(room.height) * ppm
        let turns = FloorplanGeometry.quarterTurns(room.rotation)

        ZStack {
            // Composite shape drawn as one unified path via Canvas
            CompositeRoomShape(
                roomWidth: roomWidth,
                roomHeight: roomHeight,
                parts: room.parts,
                doors: room.doors,
                scale: ppm,
                isSelected: isSelected,
                hostRect: { door in FloorplanGeometry.hostRect(for: door, in: room) }
            )
            .frame(width: side, height: side)
            .allowsHitTesting(false)

            // Room label — counter-rotated so it always reads upright
            VStack(spacing: 2) {
                Text(room.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(String(format: "%.1fx%.1fm", room.width, room.height))
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.5)
                if !room.assets.isEmpty {
                    Text("\(room.assets.count) item\(room.assets.count == 1 ? "" : "s")")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.75, blue: 1.0).opacity(0.8))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: max((turns % 2 == 0 ? roomWidth : roomHeight) - 16, 0),
                   height: max((turns % 2 == 0 ? roomHeight : roomWidth) - 16, 0))
            .rotationEffect(.degrees(Double(-turns * 90)))
            .allowsHitTesting(false)

            // Measurements for each extra piece
            ForEach(room.parts) { part in
                let pw = CGFloat(part.width) * ppm
                let ph = CGFloat(part.height) * ppm
                if pw >= 30 && ph >= 25 {
                    Text(String(format: "%.1fx%.1fm", part.width, part.height))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                        .minimumScaleFactor(0.5)
                        .rotationEffect(.degrees(Double(-turns * 90)))
                        .frame(width: pw, height: ph)
                        .offset(x: CGFloat(part.xOffset) * ppm, y: CGFloat(part.yOffset) * ppm)
                        .allowsHitTesting(false)
                }
            }

            // Tap and drag targets over every piece of the room, not just the main rectangle
            ForEach(Array(local.enumerated()), id: \.offset) { _, r in
                Color.clear
                    .frame(width: r.width * ppm, height: r.height * ppm)
                    .contentShape(Rectangle())
                    .offset(x: r.midX * ppm, y: r.midY * ppm)
            }

            // Door tap targets rotate with the room
            DoorTapTargets(room: room, scale: ppm, onDoorTap: onDoorTap)
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(Double(turns * 90)))
        .position(toCanvas(center))
        .onTapGesture { onTap() }
        .gesture(dragGesture, including: isEditMode ? .all : .subviews)
        .overlay {
            // Snap guide lines
            if let x = snapLineX {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.8))
                    .frame(width: 1.5, height: canvasSize.height * 4)
                    .position(x: origin.x + x * ppm, y: canvasSize.height / 2)
                    .allowsHitTesting(false)
            }
            if let y = snapLineY {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.8))
                    .frame(width: canvasSize.width * 4, height: 1.5)
                    .position(x: canvasSize.width / 2, y: origin.y + y * ppm)
                    .allowsHitTesting(false)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(FloorplanCanvas.space))
            .onChanged { gesture in
                guard isEditMode else { return }
                let start = FloorplanGeometry.center(of: room)
                if lastValidCenter == nil { lastValidCenter = start }
                let proposed = CGPoint(x: start.x + gesture.translation.width / ppm,
                                       y: start.y + gesture.translation.height / ppm)
                let result = resolve(proposed)
                dragCenter = result.center
                lastValidCenter = result.center
                snapLineX = result.lineX
                snapLineY = result.lineY

                let isSnapping = result.lineX != nil || result.lineY != nil
                if isSnapping && !wasSnapping {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                wasSnapping = isSnapping
            }
            .onEnded { _ in
                guard isEditMode else { return }
                if let final = dragCenter {
                    room.planX = Double(final.x)
                    room.planY = Double(final.y)
                }
                dragCenter = nil
                lastValidCenter = nil
                snapLineX = nil
                snapLineY = nil
                wasSnapping = false
            }
    }

    private struct SnapResult {
        let center: CGPoint
        let lineX: CGFloat?
        let lineY: CGFloat?
    }

    /// Snaps the proposed centre to nearby edges of other rooms (every piece counts), otherwise to a 10 cm grid,
    /// then pushes it out of any overlap. If it still overlaps, the room stays at its last valid spot.
    private func resolve(_ proposed: CGPoint) -> SnapResult {
        let threshold = snapThresholdPoints / ppm
        var c = proposed
        let moving = FloorplanGeometry.worldRects(for: room, center: c)
        let others = otherRooms.map { FloorplanGeometry.worldRects(for: $0) }
        let otherPieces = others.flatMap { $0 }

        var bestX: (delta: CGFloat, line: CGFloat)?
        var bestY: (delta: CGFloat, line: CGFloat)?
        for m in moving {
            for o in otherPieces {
                // Only line up with pieces that are roughly alongside, not ones far across the plan.
                let yNear = min(m.maxY, o.maxY) - max(m.minY, o.minY) > -1.0
                let xNear = min(m.maxX, o.maxX) - max(m.minX, o.minX) > -1.0
                if yNear {
                    for (mine, theirs) in [(m.minX, o.maxX), (m.maxX, o.minX), (m.minX, o.minX), (m.maxX, o.maxX)] {
                        let d = theirs - mine
                        if abs(d) < threshold && abs(d) < abs(bestX?.delta ?? .infinity) { bestX = (d, theirs) }
                    }
                }
                if xNear {
                    for (mine, theirs) in [(m.minY, o.maxY), (m.maxY, o.minY), (m.minY, o.minY), (m.maxY, o.maxY)] {
                        let d = theirs - mine
                        if abs(d) < threshold && abs(d) < abs(bestY?.delta ?? .infinity) { bestY = (d, theirs) }
                    }
                }
            }
        }
        if let b = bestX { c.x += b.delta } else { c.x = (c.x / gridStep).rounded() * gridStep }
        if let b = bestY { c.y += b.delta } else { c.y = (c.y / gridStep).rounded() * gridStep }

        // Push out of overlaps along the shortest direction, a few times for corners.
        for _ in 0..<4 {
            let rects = FloorplanGeometry.worldRects(for: room, center: c)
            guard let pair = firstOverlap(rects, otherPieces) else { break }
            let (m, o) = pair
            let pushes: [CGPoint] = [
                CGPoint(x: o.maxX - m.minX, y: 0), CGPoint(x: o.minX - m.maxX, y: 0),
                CGPoint(x: 0, y: o.maxY - m.minY), CGPoint(x: 0, y: o.minY - m.maxY)
            ]
            let push = pushes.min { hypot($0.x, $0.y) < hypot($1.x, $1.y) }!
            c.x += push.x
            c.y += push.y
        }
        let finalRects = FloorplanGeometry.worldRects(for: room, center: c)
        if others.contains(where: { FloorplanGeometry.overlaps(finalRects, $0) }) {
            return SnapResult(center: lastValidCenter ?? FloorplanGeometry.center(of: room), lineX: nil, lineY: nil)
        }
        return SnapResult(center: c, lineX: bestX?.line, lineY: bestY?.line)
    }

    private func firstOverlap(_ a: [CGRect], _ b: [CGRect]) -> (CGRect, CGRect)? {
        for r in a {
            for o in b where FloorplanGeometry.overlaps([r], [o]) { return (r, o) }
        }
        return nil
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
    /// The piece each door sits on, in metres relative to the room centre. Nil means the main rectangle.
    var hostRect: ((Door) -> CGRect)? = nil

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
                let doorHostRect: CGRect = {
                    guard let host = hostRect?(door) else { return baseRect }
                    return CGRect(x: centerX + host.minX * scale, y: centerY + host.minY * scale,
                                  width: host.width * scale, height: host.height * scale)
                }()
                let dw = door.isDoubleDoor ? doorWidth * 2.0 : doorWidth

                // Calculate door position on the base rect edge
                var doorX: CGFloat = 0
                var doorY: CGFloat = 0
                var isHorizontal = false

                switch door.edge {
                case .top:
                    doorX = doorHostRect.minX + doorPos * doorHostRect.width
                    doorY = doorHostRect.minY
                    isHorizontal = true
                case .bottom:
                    doorX = doorHostRect.minX + doorPos * doorHostRect.width
                    doorY = doorHostRect.maxY
                    isHorizontal = true
                case .left:
                    doorX = doorHostRect.minX
                    doorY = doorHostRect.minY + doorPos * doorHostRect.height
                    isHorizontal = false
                case .right:
                    doorX = doorHostRect.maxX
                    doorY = doorHostRect.minY + doorPos * doorHostRect.height
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
/// Tap areas over each door, laid out in the room's own frame so they rotate with it.
struct DoorTapTargets: View {
    let room: Room
    let scale: CGFloat
    let onDoorTap: ((Door) -> Void)?

    var body: some View {
        ZStack {
            ForEach(room.doors) { door in
                let r = FloorplanGeometry.hostRect(for: door, in: room)
                let p = CGFloat(door.position)
                let dw: CGFloat = door.isDoubleDoor ? 72 : 36
                let horizontal = door.edge == .top || door.edge == .bottom
                let point: CGPoint = {
                    switch door.edge {
                    case .top: return CGPoint(x: r.minX + p * r.width, y: r.minY)
                    case .bottom: return CGPoint(x: r.minX + p * r.width, y: r.maxY)
                    case .left: return CGPoint(x: r.minX, y: r.minY + p * r.height)
                    case .right: return CGPoint(x: r.maxX, y: r.minY + p * r.height)
                    }
                }()

                Color.clear
                    .frame(width: horizontal ? dw : 24, height: horizontal ? 24 : dw)
                    .contentShape(Rectangle())
                    .offset(x: point.x * scale, y: point.y * scale)
                    .onTapGesture { onDoorTap?(door) }
            }
        }
    }
}

// MARK: - Door Placement Overlay
/// A "+" just outside every outer edge of the room — the main rectangle and each extra piece —
/// placed with the room's rotation, so the button sits by the wall the door will go on.
struct DoorPlacementOverlay: View {
    let room: Room
    let canvasSize: CGSize
    let onPlaceDoor: (DoorEdge, RoomPart?) -> Void

    private struct EdgeSlot: Identifiable {
        let id: String
        let edge: DoorEdge
        let part: RoomPart?
        let canvasPoint: CGPoint
    }

    private var slots: [EdgeSlot] {
        let ppm = FloorplanGeometry.pointsPerMetre
        let origin = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let center = FloorplanGeometry.center(of: room)
        let turns = FloorplanGeometry.quarterTurns(room.rotation)
        let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
        let gap: CGFloat = 0.6 // metres outside the wall
        var result: [EdgeSlot] = []

        for (index, r) in local.enumerated() {
            let part: RoomPart? = index == 0 ? nil : room.parts[index - 1]
            let edges: [(DoorEdge, CGPoint, CGPoint)] = [
                (.top, CGPoint(x: r.midX, y: r.minY), CGPoint(x: 0, y: -1)),
                (.bottom, CGPoint(x: r.midX, y: r.maxY), CGPoint(x: 0, y: 1)),
                (.left, CGPoint(x: r.minX, y: r.midY), CGPoint(x: -1, y: 0)),
                (.right, CGPoint(x: r.maxX, y: r.midY), CGPoint(x: 1, y: 0))
            ]
            for (edge, mid, normal) in edges {
                // Skip walls that face into another piece of the same room.
                let probe = CGPoint(x: mid.x + normal.x * 0.05, y: mid.y + normal.y * 0.05)
                let interior = local.enumerated().contains { $0.offset != index && $0.element.contains(probe) }
                if interior { continue }
                let outside = CGPoint(x: mid.x + normal.x * gap, y: mid.y + normal.y * gap)
                let rotated = FloorplanGeometry.rotate(outside, quarterTurns: turns)
                let canvas = CGPoint(x: origin.x + (center.x + rotated.x) * ppm, y: origin.y + (center.y + rotated.y) * ppm)
                result.append(EdgeSlot(id: "\(index)-\(edge.rawValue)", edge: edge, part: part, canvasPoint: canvas))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(slots) { slot in
                Button(action: { onPlaceDoor(slot.edge, slot.part) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(red: 0.3, green: 0.6, blue: 0.5)))
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                }
                .accessibilityLabel("Add door")
                .position(slot.canvasPoint)
            }
        }
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
    let onRotate: () -> Void
    let onFloorChange: (Int) -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var widthText: String = ""
    @State private var heightText: String = ""
    @State private var confirmingDelete = false

    private let labelColor = Color(red: 0.5, green: 0.45, blue: 0.6)

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    sizeField(icon: "arrow.left.and.right", label: "W", text: $widthText) { room.width = $0 }
                    sizeField(icon: "arrow.up.and.down", label: "H", text: $heightText) { room.height = $0 }

                    ActionButton(icon: "rotate.right", label: "\(FloorplanGeometry.quarterTurns(room.rotation) * 90)°", tint: .white) {
                        onRotate()
                    }

                    // Floor: pick any floor; the plan follows the room there
                    Menu {
                        ForEach(floors, id: \.floorNumber) { floor in
                            Button {
                                onFloorChange(floor.floorNumber)
                            } label: {
                                if floor.floorNumber == room.floorNumber {
                                    Label(floor.displayName, systemImage: "checkmark")
                                } else {
                                    Text(floor.displayName)
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            Text(room.floorDisplay)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(labelColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 56)
                    }

                    NavigationLink(destination: RoomShapeEditor(room: room)) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.split.2x2")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            Text("Shape")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(labelColor)
                        }
                        .frame(width: 50)
                    }

                    ActionButton(icon: "slider.horizontal.3", label: "Edit", tint: .white) { onEdit() }

                    ActionButton(icon: "shippingbox", label: "Contents", tint: .white) { onOpen() }

                    ActionButton(icon: "trash", label: "Delete", tint: .red) {
                        confirmingDelete = true
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: 380)
            .background(BlurView(style: .systemUltraThinMaterialDark))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            .padding(.horizontal, 16)
        }
        .onAppear(perform: syncText)
        .onChange(of: room.width) { _, _ in syncText() }
        .onChange(of: room.height) { _, _ in syncText() }
        .confirmationDialog("Delete \(room.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Room", role: .destructive) { onDelete() }
        } message: {
            Text(room.assets.isEmpty && room.documents.isEmpty
                 ? "Its doors and shape go with it."
                 : "Its assets and documents are kept, just no longer linked to a room.")
        }
    }

    private func syncText() {
        let w = String(format: "%.1f", room.width)
        let h = String(format: "%.1f", room.height)
        if Double(widthText) != room.width { widthText = w }
        if Double(heightText) != room.height { heightText = h }
    }

    private func sizeField(icon: String, label: String, text: Binding<String>, apply: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(labelColor)
            TextField("", text: text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .frame(width: 40)
                .onChange(of: text.wrappedValue) { _, newVal in
                    if let v = Money.parse(newVal), v >= 0.5, v <= 100 { apply(v) }
                }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(labelColor)
        }
        .frame(width: 50)
    }
}

struct AddRoomView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    @Query private var allRooms: [Room]

    let defaultFloor: Int
    let availableFloors: [Floor]
    /// Plan point (metres) the user is looking at; the new room goes in the nearest free spot to it.
    let preferredCenter: CGPoint
    let onCreated: ((Room) -> Void)?
    @State private var name = ""
    @State private var floorNumber: Int
    @State private var widthString = "3.0"
    @State private var heightString = "4.0"

    // Optimization
    @State private var backgroundStars = StarryBackground.generateStars()

    init(defaultFloor: Int, availableFloors: [Floor] = [], preferredCenter: CGPoint = .zero, onCreated: ((Room) -> Void)? = nil) {
        self.defaultFloor = defaultFloor
        self.availableFloors = availableFloors
        self.preferredCenter = preferredCenter
        self.onCreated = onCreated
        _floorNumber = State(initialValue: defaultFloor)
    }

    private var width: Double? { Money.parse(widthString).flatMap { $0 >= 0.5 && $0 <= 100 ? $0 : nil } }
    private var height: Double? { Money.parse(heightString).flatMap { $0 >= 0.5 && $0 <= 100 ? $0 : nil } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && width != nil && height != nil }

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

                            if availableFloors.count > 1 {
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
                            }

                            HStack(spacing: 16) {
                                GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue, keyboardType: .decimalPad)
                                GlassTextField(title: "Length (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue, keyboardType: .decimalPad)
                            }
                            if width == nil || height == nil {
                                Text("Sizes must be between 0.5 and 100 metres.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            .disabled(!canSave)
                            .foregroundColor(canSave ? Color(red: 0.25, green: 0.45, blue: 0.75) : .white.opacity(0.3))
                    }
                }
            }
        }
    }

    private func saveRoom() {
        guard let w = width, let h = height else { return }
        let room = Room(name: name.trimmingCharacters(in: .whitespaces), floorNumber: floorNumber, width: w, height: h)
        room.floor = room.floorDisplay

        // Place it in the nearest free spot to the middle of what's on screen, so it is always visible.
        let others = allRooms.filter { $0.floorNumber == floorNumber }.map { FloorplanGeometry.worldRects(for: $0) }
        let local = FloorplanGeometry.localRects(width: w, height: h, parts: [])
        let spot = FloorplanGeometry.freeCenter(near: preferredCenter, localRects: local, quarterTurns: 0, obstacles: others)
        room.planX = Double(spot.x)
        room.planY = Double(spot.y)

        modelContext.insert(room)
        if let home = homes.first { home.rooms.append(room) }
        onCreated?(room)
    }
}

struct EditRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Floor.floorNumber) private var floors: [Floor]
    @Query private var allRooms: [Room]
    @Bindable var room: Room
    @State private var widthString: String
    @State private var heightString: String
    @State private var rotationTurns: Int
    @State private var originalFloor: Int

    // Optimization
    @State private var backgroundStars = StarryBackground.generateStars()

    init(room: Room) {
        self.room = room
        _widthString = State(initialValue: String(format: "%.1f", room.width))
        _heightString = State(initialValue: String(format: "%.1f", room.height))
        _rotationTurns = State(initialValue: FloorplanGeometry.quarterTurns(room.rotation))
        _originalFloor = State(initialValue: room.floorNumber)
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
                                    ForEach(floors, id: \.floorNumber) { floor in
                                        Text(floor.displayName).tag(floor.floorNumber)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            HStack(spacing: 16) {
                                GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: Color.blue, keyboardType: .decimalPad)
                                    .onChange(of: widthString) { _, newValue in
                                        if let v = Money.parse(newValue), v >= 0.5, v <= 100 { room.width = v }
                                    }
                                GlassTextField(title: "Length (m)", text: $heightString, icon: "arrow.up.and.down", tint: Color.blue, keyboardType: .decimalPad)
                                    .onChange(of: heightString) { _, newValue in
                                        if let v = Money.parse(newValue), v >= 0.5, v <= 100 { room.height = v }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("ROTATION").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6)).tracking(1.5)
                                Picker("", selection: $rotationTurns) {
                                    ForEach(0..<4) { t in Text("\(t * 90)°").tag(t) }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: rotationTurns) { _, t in room.rotation = Double(t * 90) }
                            }
                            .padding(12).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))

                            NavigationLink(destination: RoomShapeEditor(room: room)) {
                                HStack {
                                    Image(systemName: "square.split.2x2")
                                    Text("Edit Shape (\(room.parts.count) extra piece\(room.parts.count == 1 ? "" : "s"))")
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13))
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5)))
                            }

                            if !room.doors.isEmpty {
                                RoomDoorsSection(room: room)
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.font(.system(size: 16, weight: .semibold)).foregroundColor(Color(red: 0.25, green: 0.45, blue: 0.75)) }
                }
            }
        }
        .onDisappear(perform: settle)
    }

    /// After edits, keep the floor label in sync and make sure the room doesn't overlap anything.
    private func settle() {
        room.floor = room.floorDisplay
        let others = allRooms.filter { $0.floorNumber == room.floorNumber && $0.id != room.id }
            .map { FloorplanGeometry.worldRects(for: $0) }
        let mine = FloorplanGeometry.worldRects(for: room)
        if others.contains(where: { FloorplanGeometry.overlaps(mine, $0) }) {
            let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
            let free = FloorplanGeometry.freeCenter(near: FloorplanGeometry.center(of: room), localRects: local,
                                                    quarterTurns: FloorplanGeometry.quarterTurns(room.rotation),
                                                    obstacles: others, gap: 0)
            room.planX = Double(free.x)
            room.planY = Double(free.y)
        }
    }
}

// MARK: - Room Detail View (what's in a room)
struct RoomDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var room: Room
    /// When opened from the Rooms screen, shows the room on the plan there instead of pushing a new plan.
    var onShowOnPlan: (() -> Void)? = nil

    @Query(sort: \Asset.name) private var allAssets: [Asset]
    @Query(sort: \Document.createdAt, order: .reverse) private var allDocuments: [Document]

    @State private var showingAddAsset = false
    @State private var showingAddDocument = false
    @State private var showingEditRoom = false
    @State private var showingLinkAssets = false
    @State private var showingLinkDocuments = false

    private let labelColor = Color(red: 0.5, green: 0.45, blue: 0.6)

    /// Documents linked to the room directly, plus documents of its assets (marked as such).
    private var roomDocuments: [Document] { room.documents.sorted { $0.createdAt > $1.createdAt } }
    private var assetDocuments: [Document] {
        let direct = Set(room.documents.map { $0.persistentModelID })
        return room.assets.flatMap { $0.documents }.filter { !direct.contains($0.persistentModelID) }
    }
    private var maintenance: [Maintenance] {
        room.assets.flatMap { $0.maintenanceRecords }.sorted { $0.date > $1.date }
    }
    private var warranties: [Warranty] {
        room.assets.flatMap { $0.warranties }.sorted { $0.expiryDate < $1.expiryDate }
    }

    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text(room.name.uppercased())
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(.white)
                            .tracking(4)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Text("\(room.floorDisplay.uppercased()) · \(String(format: "%.1f × %.1f M", room.width, room.height)) · \(String(format: "%.1f", room.width * room.height)) M²")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Mini plan of this room
                    RoomMiniPlan(room: room)
                        .frame(height: 160)
                        .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        if let onShowOnPlan {
                            pillButton("Show on Plan", icon: "map") {
                                onShowOnPlan()
                                dismiss()
                            }
                        } else {
                            NavigationLink(destination: RoomsListView(initialRoom: room)) {
                                pillLabel("Show on Plan", icon: "map")
                            }
                        }
                        pillButton("Edit Room", icon: "slider.horizontal.3") { showingEditRoom = true }
                    }
                    .padding(.horizontal, 24)

                    // Assets
                    section(title: "Assets (\(room.assets.count))", addLabel: "Add", onAdd: { showingAddAsset = true },
                            secondaryLabel: unassignedAssets.isEmpty ? nil : "Move here", onSecondary: { showingLinkAssets = true }) {
                        if room.assets.isEmpty {
                            emptyText("Nothing in this room yet.")
                        } else {
                            ForEach(room.assets.sorted { $0.name < $1.name }) { asset in
                                NavigationLink(destination: AssetDetailView(asset: asset)) {
                                    AssetRow(asset: asset)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button { asset.room = nil } label: { Label("Remove from Room", systemImage: "minus.circle") }
                                }
                            }
                        }
                    }

                    // Documents
                    section(title: "Documents (\(roomDocuments.count + assetDocuments.count))", addLabel: "Add", onAdd: { showingAddDocument = true },
                            secondaryLabel: unlinkedDocuments.isEmpty ? nil : "Link", onSecondary: { showingLinkDocuments = true }) {
                        if roomDocuments.isEmpty && assetDocuments.isEmpty {
                            emptyText("No documents for this room.")
                        } else {
                            ForEach(roomDocuments) { document in
                                NavigationLink(destination: DocumentDetailView(document: document)) {
                                    DocumentRow(document: document)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button { document.room = nil } label: { Label("Unlink from Room", systemImage: "minus.circle") }
                                }
                            }
                            ForEach(assetDocuments) { document in
                                NavigationLink(destination: DocumentDetailView(document: document)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        DocumentRow(document: document)
                                        if let asset = document.asset {
                                            Text("via \(asset.name)")
                                                .font(.system(size: 11))
                                                .foregroundColor(labelColor)
                                                .padding(.leading, 16)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    if !warranties.isEmpty {
                        section(title: "Warranties (\(warranties.count))") {
                            ForEach(warranties) { warranty in
                                NavigationLink(destination: WarrantyDetailView(warranty: warranty)) {
                                    WarrantyRow(warranty: warranty)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    if !maintenance.isEmpty {
                        section(title: "Maintenance (\(maintenance.count))") {
                            ForEach(maintenance) { record in
                                NavigationLink(destination: MaintenanceDetailView(maintenance: record)) {
                                    MaintenanceRow(maintenance: record)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingAddAsset) { AddAssetView(initialRoom: room) }
        .sheet(isPresented: $showingAddDocument) { AddDocumentView(initialRoom: room) }
        .sheet(isPresented: $showingEditRoom) { EditRoomView(room: room) }
        .sheet(isPresented: $showingLinkAssets) {
            LinkPickerSheet(title: "Move assets here", items: unassignedAssets.map { LinkPickerItem(id: $0.persistentModelID, title: $0.name, subtitle: $0.location.isEmpty ? $0.category : "\($0.category) · \($0.location)") }) { ids in
                for asset in allAssets where ids.contains(asset.persistentModelID) { asset.room = room }
            }
        }
        .sheet(isPresented: $showingLinkDocuments) {
            LinkPickerSheet(title: "Link documents", items: unlinkedDocuments.map { LinkPickerItem(id: $0.persistentModelID, title: $0.title, subtitle: $0.type.rawValue) }) { ids in
                for doc in allDocuments where ids.contains(doc.persistentModelID) { doc.room = room }
            }
        }
    }

    /// Assets not yet in any room, plus assets whose old free-text location mentions this room's name, first.
    private var unassignedAssets: [Asset] {
        let name = room.name.lowercased()
        return allAssets.filter { $0.room == nil }.sorted {
            let a = !name.isEmpty && $0.location.lowercased().contains(name)
            let b = !name.isEmpty && $1.location.lowercased().contains(name)
            return a != b ? a : $0.name < $1.name
        }
    }

    private var unlinkedDocuments: [Document] {
        allDocuments.filter { $0.room == nil }
    }

    // MARK: Building blocks

    private func section<Content: View>(title: String, addLabel: String? = nil, onAdd: (() -> Void)? = nil,
                                        secondaryLabel: String? = nil, onSecondary: (() -> Void)? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlassSectionHeader(title: title)
                Spacer()
                if let secondaryLabel, let onSecondary {
                    Button(secondaryLabel, action: onSecondary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                if let addLabel, let onAdd {
                    Button(action: onAdd) {
                        Label(addLabel, systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            VStack(spacing: 12) { content() }
        }
        .padding(.horizontal, 24)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(labelColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pillLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }

    private func pillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { pillLabel(title, icon: icon) }
    }
}

/// A small, read-only drawing of one room with its pieces and doors, fitted to the space.
struct RoomMiniPlan: View {
    let room: Room

    var body: some View {
        GeometryReader { geo in
            let local = FloorplanGeometry.localRects(width: room.width, height: room.height, parts: room.parts)
            let b = FloorplanGeometry.bounds(of: local)
            let fit = min(geo.size.width / max(b.width + 2, 1), geo.size.height / max(b.height + 2, 1))
            let turns = FloorplanGeometry.quarterTurns(room.rotation)
            let side = max(b.width, b.height, abs(b.minX) * 2, abs(b.maxX) * 2, abs(b.minY) * 2, abs(b.maxY) * 2) * fit + 90
            CompositeRoomShape(
                roomWidth: CGFloat(room.width) * fit,
                roomHeight: CGFloat(room.height) * fit,
                parts: room.parts,
                doors: room.doors,
                scale: fit,
                isSelected: false,
                hostRect: { door in FloorplanGeometry.hostRect(for: door, in: room) }
            )
            .frame(width: side, height: side)
            .offset(x: -b.midX * fit, y: -b.midY * fit)
            .rotationEffect(.degrees(Double(turns * 90)))
            .scaleEffect(turns % 2 == 1 ? min(1, geo.size.height / max(b.width * fit + 20, 1)) : 1)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .allowsHitTesting(false)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 0.5))
        )
    }
}

/// One row in LinkPickerSheet.
struct LinkPickerItem: Identifiable {
    let id: PersistentIdentifier
    let title: String
    let subtitle: String
}

/// A multi-select list used to link existing assets or documents to a room.
struct LinkPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [LinkPickerItem]
    let onLink: (Set<PersistentIdentifier>) -> Void
    @State private var selected: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).foregroundColor(.primary)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected.contains(item.id) ? .blue : .secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") { onLink(selected); dismiss() }
                        .disabled(selected.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
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
