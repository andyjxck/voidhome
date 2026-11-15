import SwiftUI
import SwiftData
import UserNotifications

@main
struct VoidHomeOSApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
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
                Door.self
            ])
            
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        Task {
            await NotificationService.shared.requestAuthorization()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
