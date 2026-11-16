import Foundation
import SwiftData
import CryptoKit

/// A file (photo or scanned document) that travels with a record through Firebase Storage.
struct SyncFile: Hashable {
    enum Kind { case photo, document }
    let field: String
    let name: String
    let kind: Kind

    var localURL: URL {
        switch kind {
        case .photo: return PhotoStore.folder.appendingPathComponent(name)
        case .document: return DocumentStorage.directory.appendingPathComponent(name)
        }
    }
}

/// Every synced SwiftData model conforms to this. The field mapping is generated in SyncRecords.swift.
protocol SyncRecord: PersistentModel {
    static var syncType: String { get }
    /// Floor plan, rooms, doors and house details are always shared.
    static var alwaysShared: Bool { get }
    /// Warranties, plans, logs, payments, checklist items, completions and photos follow their parent.
    static var followsParent: Bool { get }
    static func blank() -> Self

    var syncId: String { get set }
    var visibilityRaw: String { get set }
    var createdBy: String { get set }
    var updatedBy: String { get set }
    var syncHash: String { get set }
    var syncScope: String { get set }

    var syncParent: (any SyncRecord)? { get }
    var syncFiles: [SyncFile] { get }
    func syncFields() -> [String: Any]
    func applySyncFields(_ d: SyncData)
    func applySyncRefs(_ d: SyncData, _ r: SyncResolver)
}

extension SyncRecord {
    var syncIdOrNull: Any { syncId.isEmpty ? NSNull() : syncId }

    /// "house" or "me", after following the parent chain.
    var effectiveVisibility: String {
        if Self.alwaysShared { return Visibility.house.rawValue }
        if Self.followsParent {
            return syncParent?.effectiveVisibility ?? (visibilityRaw == Visibility.me.rawValue ? "me" : "house")
        }
        if let parent = syncParent, parent.effectiveVisibility == Visibility.me.rawValue { return "me" }
        return visibilityRaw == Visibility.me.rawValue ? "me" : "house"
    }

    var isPrivate: Bool { effectiveVisibility == Visibility.me.rawValue }

    /// Stable fingerprint of what would be uploaded. Used to spot local edits that still need pushing.
    func computeSyncHash() -> String {
        var fields = syncFields()
        fields["__visibility"] = effectiveVisibility
        let text = SyncData.canonical(fields)
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}

/// Read-only access to a Firestore `data` map with forgiving type conversion.
struct SyncData {
    let raw: [String: Any]

    func has(_ key: String) -> Bool { raw[key] != nil }

    func string(_ key: String) -> String? {
        guard let v = raw[key], !(v is NSNull) else { return nil }
        return v as? String
    }

    func strings(_ key: String) -> [String]? { raw[key] as? [String] }

    func double(_ key: String) -> Double? {
        guard let v = raw[key] else { return nil }
        if let n = v as? NSNumber { return n.doubleValue }
        return v as? Double
    }

    func int(_ key: String) -> Int? {
        guard let v = raw[key] else { return nil }
        if let n = v as? NSNumber { return n.intValue }
        return v as? Int
    }

    func bool(_ key: String) -> Bool? {
        guard let v = raw[key] else { return nil }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        return nil
    }

    func date(_ key: String) -> Date? {
        guard let v = raw[key], !(v is NSNull) else { return nil }
        return SyncDateConverter.date(from: v)
    }

    /// Deterministic text for hashing: sorted keys, dates as seconds.
    static func canonical(_ value: Any) -> String {
        switch value {
        case let dict as [String: Any]:
            return "{" + dict.keys.sorted().map { "\($0):" + canonical(dict[$0]!) }.joined(separator: ",") + "}"
        case let arr as [Any]:
            return "[" + arr.map { canonical($0) }.joined(separator: ",") + "]"
        case let date as Date:
            return String(format: "t%.3f", date.timeIntervalSince1970)
        case is NSNull:
            return "null"
        case let b as Bool:
            return b ? "true" : "false"
        case let d as Double:
            return String(format: "%.6f", d)
        case let i as Int:
            return String(format: "%.6f", Double(i))
        default:
            return "\"\(value)\""
        }
    }
}

/// Set by FirebaseSync so this file needs no Firebase import (Timestamp -> Date).
enum SyncDateConverter {
    static var convert: (Any) -> Date? = { $0 as? Date }
    static func date(from value: Any) -> Date? { convert(value) }
}

/// Finds local records by syncId while a batch of remote changes is applied.
final class SyncResolver {
    private let context: ModelContext
    private var cache: [String: [String: any PersistentModel]] = [:]

    init(context: ModelContext) { self.context = context }

    func find<T: SyncRecord>(_ type: T.Type, _ id: String?) -> T? {
        guard let id, !id.isEmpty else { return nil }
        return index(type)[id] as? T
    }

    func index<T: SyncRecord>(_ type: T.Type) -> [String: any PersistentModel] {
        if let cached = cache[T.syncType] { return cached }
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        var map: [String: any PersistentModel] = [:]
        for item in all where !item.syncId.isEmpty { map[item.syncId] = item }
        cache[T.syncType] = map
        return map
    }

    func register<T: SyncRecord>(_ item: T) {
        _ = index(T.self)
        cache[T.syncType]?[item.syncId] = item
    }

    func forget<T: SyncRecord>(_ item: T) {
        cache[T.syncType]?.removeValue(forKey: item.syncId)
    }
}
