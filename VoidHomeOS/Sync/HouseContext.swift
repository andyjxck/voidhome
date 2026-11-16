import Foundation

/// A member of the shared house, as stored in houses/{houseId}.members.
struct HouseMember: Identifiable, Hashable {
    let uid: String
    var name: String
    var role: String   // "owner" or "member"
    var id: String { uid }
}

/// Plain snapshot of who is signed in and which house they are in, readable from models
/// and views without touching Firebase. Kept up to date by HouseStore on the main thread.
enum HouseContext {
    static var uid: String?
    static var houseId: String?
    static var ownerId: String?
    static var members: [HouseMember] = []

    /// True when signed in and part of a house, so sharing choices matter.
    static var isShared: Bool { uid != nil && houseId != nil }

    static func name(for uid: String) -> String {
        if uid == self.uid { return "You" }
        return members.first { $0.uid == uid }?.name ?? "A former member"
    }
}

/// "Just me" / "Everyone" values stored in visibilityRaw.
enum Visibility: String, CaseIterable, Identifiable {
    case house
    case me
    var id: String { rawValue }
    var label: String { self == .house ? "Everyone" : "Just me" }
}

/// Small JSON helpers for the split maps stored as strings (Firestore stores them as strings too).
enum SplitJSON {
    static func amounts(_ json: String) -> [String: Double] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: Double] = [:]
        for (k, v) in obj {
            if let d = v as? Double { out[k] = d } else if let n = v as? NSNumber { out[k] = n.doubleValue }
        }
        return out
    }

    static func strings(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return [:] }
        return obj
    }

    static func encode(_ dict: [String: Any]) -> String {
        guard !dict.isEmpty, let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
