import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func scheduleWarrantyExpiryReminder(for warranty: Warranty, daysBefore: Int = 7) {
        let center = UNUserNotificationCenter.current()
        
        guard let daysUntil = warranty.daysUntilExpiry, daysUntil > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Warranty Expiring Soon"
        
        let daysNotice = min(daysBefore, daysUntil)
        if let asset = warranty.asset {
            content.body = "Warranty for \(asset.name) from \(warranty.provider) expires in \(daysNotice) days"
        } else {
            content.body = "Warranty from \(warranty.provider) expires in \(daysNotice) days"
        }
        
        content.sound = .default
        content.badge = 1
        
        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysNotice, to: warranty.expiryDate) else { return }
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "warranty-\(warranty.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling warranty reminder: \(error)")
            }
        }
    }
    
    func scheduleMaintenanceReminder(for maintenance: Maintenance, daysBefore: Int = 7) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Maintenance Reminder"
        content.body = maintenance.task
        
        if let asset = maintenance.asset {
            content.body += " for \(asset.name)"
        }
        
        content.sound = .default
        content.badge = 1
        
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: maintenance.date) else { return }
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "maintenance-\(maintenance.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling maintenance reminder: \(error)")
            }
        }
    }
    
    func scheduleCustomReminder(title: String, body: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling custom reminder: \(error)")
            }
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
