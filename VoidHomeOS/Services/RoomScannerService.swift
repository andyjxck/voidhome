import SwiftUI
import SwiftData
import simd
#if canImport(RoomPlan)
import RoomPlan
#endif

/// What a room scan produced, in plan terms: an axis-aligned outline with doors on its edges and the objects it saw.
struct RoomScanSummary {
    var width: Double              // metres, along the longest wall
    var length: Double             // metres, across it
    var doors: [(edge: DoorEdge, position: Double, isDouble: Bool)]
    var objects: [String]          // e.g. "Refrigerator", "Washer Dryer"
}

enum RoomScanner {
    /// True only on devices with LiDAR that RoomPlan supports (iPhone Pro / iPad Pro). False in the Simulator.
    static var isSupported: Bool {
        #if canImport(RoomPlan)
        return RoomCaptureSession.isSupported
        #else
        return false
        #endif
    }
}

#if canImport(RoomPlan)

// MARK: - Converting a CapturedRoom

extension RoomScanSummary {
    init(captured room: CapturedRoom) {
        // Work in the floor plane (x, z). Use the longest wall's direction as the room's x axis so the
        // outline is measured square to the walls, whatever way the phone was facing.
        func floorPoint(_ t: simd_float4x4) -> SIMD2<Float> { SIMD2(t.columns.3.x, t.columns.3.z) }
        func floorDir(_ t: simd_float4x4) -> SIMD2<Float> {
            let d = SIMD2(t.columns.0.x, t.columns.0.z)
            let len = simd_length(d)
            return len > 0 ? d / len : SIMD2(1, 0)
        }

        let longest = room.walls.max { $0.dimensions.x < $1.dimensions.x }
        let axisX = longest.map { floorDir($0.transform) } ?? SIMD2<Float>(1, 0)
        let axisY = SIMD2<Float>(-axisX.y, axisX.x)
        func local(_ p: SIMD2<Float>) -> SIMD2<Float> { SIMD2(simd_dot(p, axisX), simd_dot(p, axisY)) }

        var points: [SIMD2<Float>] = []
        for wall in room.walls {
            let c = floorPoint(wall.transform)
            let d = floorDir(wall.transform) * (wall.dimensions.x / 2)
            points.append(local(c + d))
            points.append(local(c - d))
        }
        let minX = points.map(\.x).min() ?? 0, maxX = points.map(\.x).max() ?? 3
        let minY = points.map(\.y).min() ?? 0, maxY = points.map(\.y).max() ?? 4
        let w = max(Double(maxX - minX), 0.5)
        let l = max(Double(maxY - minY), 0.5)
        width = (w * 10).rounded() / 10
        length = (l * 10).rounded() / 10

        // Put each door on the nearest edge of that outline. Plan y grows downwards, like the floor plan.
        doors = room.doors.map { door in
            let p = local(floorPoint(door.transform))
            let distances: [(DoorEdge, Float)] = [
                (.left, abs(p.x - minX)), (.right, abs(p.x - maxX)),
                (.top, abs(p.y - minY)), (.bottom, abs(p.y - maxY))
            ]
            let edge = distances.min { $0.1 < $1.1 }!.0
            let raw: Float = (edge == .top || edge == .bottom)
                ? (p.x - minX) / max(maxX - minX, 0.01)
                : (p.y - minY) / max(maxY - minY, 0.01)
            let position = Double(min(max(raw, 0.05), 0.95))
            return (edge, position, door.dimensions.x > 1.3)
        }

        objects = room.objects.map { RoomScanSummary.displayName(for: "\($0.category)") }
    }

    /// "washerDryer" -> "Washer Dryer"
    static func displayName(for raw: String) -> String {
        var out = ""
        for ch in raw {
            if ch.isUppercase && !out.isEmpty { out.append(" ") }
            out.append(out.isEmpty ? Character(ch.uppercased()) : ch)
        }
        return out
    }
}

// MARK: - Capture screen

/// Full-screen RoomPlan capture. "Done" stops scanning and shows RoomPlan's processed model;
/// "Use Scan" then hands the result back.
final class RoomCaptureHostController: UIViewController, RoomCaptureViewDelegate {
    var onFinish: ((CapturedRoom?) -> Void)?

    private var captureView: RoomCaptureView!
    private var finalRoom: CapturedRoom?
    private var isScanning = false
    private let doneButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.delegate = self
        view.addSubview(captureView)

        for (button, title, action) in [(cancelButton, "Cancel", #selector(cancelTapped)), (doneButton, "Done", #selector(doneTapped))] {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(button)
        }
        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            doneButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            doneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isScanning, finalRoom == nil else { return }
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        isScanning = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isScanning { captureView.captureSession.stop() }
        isScanning = false
    }

    @objc private func doneTapped() {
        if isScanning {
            captureView.captureSession.stop()
            isScanning = false
            doneButton.isEnabled = false
            doneButton.setTitle("Processing…", for: .normal)
        } else if let room = finalRoom {
            onFinish?(room)
        }
    }

    @objc private func cancelTapped() {
        if isScanning { captureView.captureSession.stop() }
        isScanning = false
        onFinish?(nil)
    }

    // RoomCaptureViewDelegate
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalRoom = processedResult
        doneButton.isEnabled = true
        doneButton.setTitle("Use Scan", for: .normal)
        if let error { print("RoomPlan processing error: \(error)") }
    }
}

struct RoomCaptureScreen: UIViewControllerRepresentable {
    let onFinish: (RoomScanSummary?) -> Void

    func makeUIViewController(context: Context) -> RoomCaptureHostController {
        let controller = RoomCaptureHostController()
        controller.onFinish = { room in onFinish(room.map { RoomScanSummary(captured: $0) }) }
        return controller
    }

    func updateUIViewController(_ uiViewController: RoomCaptureHostController, context: Context) {}
}

#endif

// MARK: - Scan flow (capture, then review and save)

/// Presents the capture screen, then a review form that creates the room — with its measured size,
/// its doors and, if wanted, the detected objects as assets in that room.
struct RoomScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let defaultFloor: Int
    let availableFloors: [Floor]
    let preferredCenter: CGPoint
    let onCreated: (Room) -> Void

    @State private var summary: RoomScanSummary?

    var body: some View {
        Group {
            if let summary {
                RoomScanReviewView(summary: summary, defaultFloor: defaultFloor, availableFloors: availableFloors,
                                   preferredCenter: preferredCenter) { room in
                    onCreated(room)
                    dismiss()
                } onCancel: { dismiss() }
            } else {
                #if canImport(RoomPlan)
                if RoomScanner.isSupported {
                    RoomCaptureScreen { result in
                        if let result { summary = result } else { dismiss() }
                    }
                    .ignoresSafeArea()
                } else {
                    unsupported
                }
                #else
                unsupported
                #endif
            }
        }
    }

    private var unsupported: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown").font(.system(size: 40))
            Text("Room scanning needs an iPhone or iPad with LiDAR.")
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
        }
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct RoomScanReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @Query private var allRooms: [Room]

    let summary: RoomScanSummary
    let availableFloors: [Floor]
    let preferredCenter: CGPoint
    let onSave: (Room) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var floorNumber: Int
    @State private var widthString: String
    @State private var lengthString: String
    @State private var addObjectsAsAssets = false

    init(summary: RoomScanSummary, defaultFloor: Int, availableFloors: [Floor], preferredCenter: CGPoint,
         onSave: @escaping (Room) -> Void, onCancel: @escaping () -> Void) {
        self.summary = summary
        self.availableFloors = availableFloors
        self.preferredCenter = preferredCenter
        self.onSave = onSave
        self.onCancel = onCancel
        _floorNumber = State(initialValue: defaultFloor)
        _widthString = State(initialValue: String(format: "%.1f", summary.width))
        _lengthString = State(initialValue: String(format: "%.1f", summary.length))
    }

    private var width: Double? { Money.parse(widthString).flatMap { $0 >= 0.5 && $0 <= 100 ? $0 : nil } }
    private var length: Double? { Money.parse(lengthString).flatMap { $0 >= 0.5 && $0 <= 100 ? $0 : nil } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && width != nil && length != nil }

    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SCANNED ROOM")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                            .tracking(3)
                            .padding(.top, 40)

                        GlassTextField(title: "Name", text: $name, icon: "textformat", tint: Color(red: 0.25, green: 0.45, blue: 0.75))

                        if availableFloors.count > 1 {
                            Picker("Floor", selection: $floorNumber) {
                                ForEach(availableFloors, id: \.floorNumber) { floor in
                                    Text(floor.displayName).tag(floor.floorNumber)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack(spacing: 16) {
                            GlassTextField(title: "Width (m)", text: $widthString, icon: "arrow.left.and.right", tint: .blue, keyboardType: .decimalPad)
                            GlassTextField(title: "Length (m)", text: $lengthString, icon: "arrow.up.and.down", tint: .blue, keyboardType: .decimalPad)
                        }

                        Text("\(summary.doors.count) door\(summary.doors.count == 1 ? "" : "s") found. The outline is the scan's bounding rectangle; refine an L-shape with the shape editor afterwards.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))

                        if !summary.objects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                GlassSectionHeader(title: "Detected (\(summary.objects.count))")
                                Text(summary.objects.joined(separator: ", "))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.85))
                                Toggle("Add these as assets in this room", isOn: $addObjectsAsAssets)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.03)))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel", action: onCancel).foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save", action: save)
                            .disabled(!canSave)
                            .foregroundColor(canSave ? Color(red: 0.25, green: 0.45, blue: 0.75) : .white.opacity(0.3))
                    }
                }
            }
        }
    }

    private func save() {
        guard let w = width, let l = length else { return }
        let room = Room(name: name.trimmingCharacters(in: .whitespaces), floorNumber: floorNumber, width: w, height: l)
        room.floor = room.floorDisplay
        let others = allRooms.filter { $0.floorNumber == floorNumber }.map { FloorplanGeometry.worldRects(for: $0) }
        let spot = FloorplanGeometry.freeCenter(near: preferredCenter,
                                                localRects: FloorplanGeometry.localRects(width: w, height: l, parts: []),
                                                quarterTurns: 0, obstacles: others)
        room.planX = Double(spot.x)
        room.planY = Double(spot.y)
        modelContext.insert(room)
        if let home = homes.first { home.rooms.append(room) }

        for d in summary.doors {
            let door = Door(edge: d.edge, position: d.position, opensLeft: true)
            door.isDoubleDoor = d.isDouble
            modelContext.insert(door)
            door.room = room
        }

        if addObjectsAsAssets {
            for objectName in summary.objects {
                let asset = Asset(name: objectName, category: objectName)
                modelContext.insert(asset)
                asset.room = room
                if let home = homes.first { home.assets.append(asset) }
            }
        }
        onSave(room)
    }
}
