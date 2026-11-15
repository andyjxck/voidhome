import UserNotifications
import Foundation

/// Schedules, reschedules and cancels local reminders for warranties and maintenance.
///
/// Each reminder uses a stable identifier built from the record's `reminderID`, which is
/// assigned the first time a reminder is synced. SwiftData's own `id` is temporary until the
/// record is saved, so it cannot be used to find the reminder again later.
final class NotificationService {
    static let shared = NotificationService()

    /// Hour of day (local time) at which date-only reminders fire.
    private let reminderHour = 9

    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }

    // MARK: - Identifiers

    func identifier(for warranty: Warranty) -> String {
        if warranty.reminderID == nil { warranty.reminderID = UUID().uuidString }
        return "warranty-\(warranty.reminderID!)"
    }

    func identifier(for maintenance: Maintenance) -> String {
        if maintenance.reminderID == nil { maintenance.reminderID = UUID().uuidString }
        return "maintenance-\(maintenance.reminderID!)"
    }

    // MARK: - Warranties

    /// Cancels any existing reminder for this warranty and schedules a fresh one from its current values.
    /// Call after creating or editing a warranty.
    func syncWarrantyReminder(for warranty: Warranty, daysBefore: Int = 7) {
        let id = identifier(for: warranty)
        cancelNotification(withIdentifier: id)

        guard warranty.remindersEnabled, warranty.expiryDate > Date() else { return }
        let daysUntil = max(0, warranty.daysUntilExpiry ?? 0)
        let daysNotice = min(daysBefore, daysUntil)

        let content = UNMutableNotificationContent()
        content.title = "Warranty Expiring Soon"
        let when = daysNotice == 0 ? "today" : (daysNotice == 1 ? "tomorrow" : "in \(daysNotice) days")
        if let asset = warranty.asset {
            content.body = "Warranty for \(asset.name) from \(warranty.provider) expires \(when)"
        } else {
            content.body = "Warranty from \(warranty.provider) expires \(when)"
        }
        content.sound = .default

        guard let fireDate = reminderDate(daysBefore: daysNotice, target: warranty.expiryDate) else { return }
        add(id: id, content: content, at: fireDate)
    }

    func cancelWarrantyReminder(for warranty: Warranty) {
        guard let rid = warranty.reminderID else { return }
        cancelNotification(withIdentifier: "warranty-\(rid)")
    }

    /// Kept for source compatibility with older call sites.
    func scheduleWarrantyExpiryReminder(for warranty: Warranty, daysBefore: Int = 7) {
        syncWarrantyReminder(for: warranty, daysBefore: daysBefore)
    }

    // MARK: - Maintenance

    /// Cancels any existing reminder for this maintenance task and schedules a fresh one if it is in the future.
    /// Call after creating or editing a maintenance record.
    func syncMaintenanceReminder(for maintenance: Maintenance, daysBefore: Int = 7) {
        let id = identifier(for: maintenance)
        cancelNotification(withIdentifier: id)

        guard maintenance.remindersEnabled, maintenance.date > Date() else { return }
        let daysUntil = max(0, Calendar.current.dateComponents([.day], from: Date(), to: maintenance.date).day ?? 0)
        let daysNotice = min(daysBefore, daysUntil)

        let content = UNMutableNotificationContent()
        content.title = "Maintenance Reminder"
        var body = maintenance.task
        if let asset = maintenance.asset { body += " for \(asset.name)" }
        let when = daysNotice == 0 ? "today" : (daysNotice == 1 ? "tomorrow" : "in \(daysNotice) days")
        content.body = "\(body) is due \(when)"
        content.sound = .default

        guard let fireDate = reminderDate(daysBefore: daysNotice, target: maintenance.date) else { return }
        add(id: id, content: content, at: fireDate)
    }

    func cancelMaintenanceReminder(for maintenance: Maintenance) {
        guard let rid = maintenance.reminderID else { return }
        cancelNotification(withIdentifier: "maintenance-\(rid)")
    }

    func scheduleMaintenanceReminder(for maintenance: Maintenance, daysBefore: Int = 7) {
        syncMaintenanceReminder(for: maintenance, daysBefore: daysBefore)
    }

    /// Deleting an asset deletes its warranties and maintenance records (cascade), so cancel their reminders first.
    func cancelReminders(forAssetBeingDeleted asset: Asset) {
        asset.warranties.forEach { cancelWarrantyReminder(for: $0) }
        asset.maintenanceRecords.forEach { cancelMaintenanceReminder(for: $0) }
    }

    // MARK: - Generic

    func scheduleCustomReminder(title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        add(id: UUID().uuidString, content: content, at: date)
    }

    func cancelNotification(withIdentifier identifier: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    /// The moment to fire a reminder `daysBefore` days ahead of `target`, at `reminderHour` local time.
    /// If that moment has already passed (e.g. the target is later today), fires a minute from now instead,
    /// as long as the target itself is still ahead.
    private func reminderDate(daysBefore: Int, target: Date) -> Date? {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: -daysBefore, to: target) else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = reminderHour
        comps.minute = 0
        guard let candidate = cal.date(from: comps) else { return nil }
        if candidate > Date() { return min(candidate, target) }
        guard target > Date() else { return nil }
        return Date().addingTimeInterval(60)
    }

    private func add(id: String, content: UNMutableNotificationContent, at date: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        // Ask for permission the first time a reminder is needed (iOS only prompts once), then schedule.
        Task {
            guard await requestAuthorization() else { return }
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Error scheduling reminder \(id): \(error)")
            }
        }
    }
}
