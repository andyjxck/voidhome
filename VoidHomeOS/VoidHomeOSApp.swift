import SwiftUI
import SwiftData
import UserNotifications
import GoogleSignIn

@main
struct VoidHomeOSApp: App {
    let modelContainer: ModelContainer
    /// Set when the saved data could not be opened. The app then runs on a temporary,
    /// empty store and tells the user; their saved data is copied to a backup and never deleted.
    let storeProblem: String?

    static let schema = Schema([
        Home.self,
        Room.self,
        Asset.self,
        Document.self,
        Warranty.self,
        Maintenance.self,
        Person.self,
        Project.self,
        Floor.self,
        RoomPart.self,
        Door.self,
        // Added for To-Do, Bills, maintenance plans and project photos.
        // Every new field has a default or is optional, so SwiftData migrates
        // the existing store in place (lightweight migration) with no data loss.
        HomeTask.self,
        TaskChecklistItem.self,
        TaskCompletion.self,
        Bill.self,
        BillPayment.self,
        MaintenancePlan.self,
        ProjectPhoto.self,
        // Added for shared households (sync fields all have defaults too).
        ProjectSpend.self
    ])

    init() {
        let configuration = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: Self.schema, configurations: [configuration])
            storeProblem = nil
        } catch {
            let backup = StoreBackup.copyStore(at: configuration.url)
            let memory = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)
            // An in-memory store with this schema cannot fail to open.
            modelContainer = try! ModelContainer(for: Self.schema, configurations: [memory])
            var message = "Your saved home data couldn't be opened by this version, so nothing you change now will be kept. Your data has not been deleted."
            if let backup { message += " A copy is in Files › Void Home › \(backup)." }
            message += "\n\n\(error.localizedDescription)"
            storeProblem = message
        }

        // Sharing never runs on the temporary store, so a failed open can't sync deletions.
        let container = modelContainer
        let allowSync = storeProblem == nil
        MainActor.assumeIsolated {
            HouseStore.shared.configure(container: container, syncAllowed: allowSync)
        }

        Task {
            await NotificationService.shared.requestAuthorization()
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
                .overlay(alignment: .top) {
                    if let storeProblem { StoreProblemBanner(message: storeProblem) }
                }
                .onOpenURL { url in _ = GIDSignIn.sharedInstance.handle(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { SyncEngine.shared.flush() }
        }
    }
}

enum StoreBackup {
    /// Copies the SQLite store and its side files into Documents/Backup-<date>. Returns the folder name.
    static func copyStore(at url: URL) -> String? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: "-")
        let folderName = "Backup-\(stamp)"
        let folder = docs.appendingPathComponent(folderName, isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            var copied = false
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: url.path + suffix)
                if fm.fileExists(atPath: source.path) {
                    try fm.copyItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
                    copied = true
                }
            }
            return copied ? folderName : nil
        } catch {
            return nil
        }
    }
}

struct StoreProblemBanner: View {
    let message: String
    @State private var hidden = false

    var body: some View {
        if !hidden {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved data not loaded")
                    .font(.system(size: 15, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Hide") { hidden = true }
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.25, green: 0.2, blue: 0.4)))
            .padding()
        }
    }
}
