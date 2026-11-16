import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseStorage

/// Two-way sync between the local SwiftData store and Firestore for one house.
///
/// - Shared records live at houses/{houseId}/items/{syncId}.
/// - "Just me" records live at houses/{houseId}/private/{uid}/items/{syncId}.
/// - Local edits are found by comparing each record's fingerprint with the one last synced,
///   and pushed every few seconds. Firestore's offline cache queues writes without signal.
/// - Remote changes arrive through snapshot listeners. A record with an unpushed local edit
///   keeps the local edit (it is pushed next), so the last write to reach the server wins.
/// - Deleting is a tombstone (`deleted: true`), so other phones (and Android) see it.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    /// Shown in the house screen when photos or scans can't sync (e.g. Storage not enabled yet).
    @Published private(set) var fileProblem: String?
    @Published private(set) var lastSynced: Date?
    @Published private(set) var syncProblem: String?

    private var container: ModelContainer?
    private var houseId: String?
    private var uid: String?
    private var listeners: [ListenerRegistration] = []
    private var timer: Timer?
    private var applying = false
    private var pendingInitial = 0
    private var known: [String: String] = [:]      // syncId -> "scope|type"
    private var uploadedFiles: Set<String> = []
    private var filesInFlight: Set<String> = []

    var isRunning: Bool { houseId != nil }

    func configure(container: ModelContainer) { self.container = container }

    // MARK: Start / stop

    func start(houseId: String, uid: String) {
        guard container != nil else { return }
        if self.houseId == houseId && self.uid == uid { return }
        stop()
        self.houseId = houseId
        self.uid = uid
        loadState()

        let house = Firestore.firestore().collection("houses").document(houseId)
        let shared = house.collection("items")
        let mine = house.collection("private").document(uid).collection("items")
        pendingInitial = 2
        listeners.append(shared.addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in self?.handle(snap, error, scope: "house") }
        })
        listeners.append(mine.addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in self?.handle(snap, error, scope: "me") }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pushChanges() }
        }
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
        timer?.invalidate()
        timer = nil
        houseId = nil
        uid = nil
        known = [:]
        uploadedFiles = []
        pendingInitial = 0
    }

    /// Push now (called when the app goes to the background).
    func flush() { pushChanges() }

    // MARK: Saved state

    private var stateKey: String { "sync.state.\(houseId ?? "").\(uid ?? "")" }

    private func loadState() {
        let d = UserDefaults.standard
        known = d.dictionary(forKey: stateKey + ".known") as? [String: String] ?? [:]
        uploadedFiles = Set(d.stringArray(forKey: stateKey + ".files") ?? [])
    }

    private func saveState() {
        let d = UserDefaults.standard
        d.set(known, forKey: stateKey + ".known")
        d.set(Array(uploadedFiles), forKey: stateKey + ".files")
    }

    /// Forgets what was synced for a house on this phone (used when leaving or being removed).
    static func clearState(houseId: String, uid: String) {
        let key = "sync.state.\(houseId).\(uid)"
        UserDefaults.standard.removeObject(forKey: key + ".known")
        UserDefaults.standard.removeObject(forKey: key + ".files")
    }

    // MARK: Push

    private struct Write {
        let type: String
        let syncId: String
        let scope: String
        let doc: [String: Any]
    }

    private func collection(_ scope: String) -> CollectionReference? {
        guard let houseId, let uid else { return nil }
        let house = Firestore.firestore().collection("houses").document(houseId)
        return scope == "me" ? house.collection("private").document(uid).collection("items") : house.collection("items")
    }

    func pushChanges() {
        guard let container, let uid, houseId != nil, !applying, pendingInitial == 0 else { return }
        let context = container.mainContext
        var writes: [Write] = []
        var present = Set<String>()
        var uploads: [(SyncFile, String, String)] = []   // file, scope, syncId
        do {
            for type in SyncRegistry.types {
                try collect(type, context: context, uid: uid, writes: &writes, present: &present, uploads: &uploads)
            }
        } catch {
            // Never treat a failed read as "everything was deleted".
            syncProblem = "Couldn't read saved data to sync: \(error.localizedDescription)"
            return
        }

        // Local deletions: synced before, gone now. If nothing at all is here any more, that's a
        // store problem, not the user deleting their whole home: never send that as deletions.
        let gone = known.keys.filter { !present.contains($0) }
        if present.isEmpty && !gone.isEmpty {
            syncProblem = "Nothing saved on this phone, so deletions weren't sent."
            return
        }
        for (id, entry) in known where !present.contains(id) {
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { known.removeValue(forKey: id); continue }
            writes.append(Write(type: parts[1], syncId: id, scope: parts[0], doc: tombstone(type: parts[1], id: id, scope: parts[0], uid: uid)))
            known.removeValue(forKey: id)
        }

        guard !writes.isEmpty || !uploads.isEmpty else { return }
        let db = Firestore.firestore()
        var batch = db.batch()
        var count = 0
        for write in writes {
            guard let ref = collection(write.scope)?.document(write.syncId) else { continue }
            batch.setData(write.doc, forDocument: ref)
            count += 1
            if count == 450 {
                commit(batch)
                batch = db.batch()
                count = 0
            }
        }
        if count > 0 { commit(batch) }
        try? context.save()
        saveState()
        lastSynced = Date()
        for (file, scope, id) in uploads { upload(file, scope: scope, syncId: id) }
    }

    private func commit(_ batch: WriteBatch) {
        // Without signal the completion waits; the writes are already in the offline queue.
        batch.commit { [weak self] error in
            Task { @MainActor in
                if let error { self?.syncProblem = "Sync error: \(error.localizedDescription)" } else { self?.syncProblem = nil }
            }
        }
    }

    private func tombstone(type: String, id: String, scope: String, uid: String) -> [String: Any] {
        ["type": type, "syncId": id, "visibility": scope, "deleted": true,
         "updatedBy": uid, "updatedAt": FieldValue.serverTimestamp(), "data": [String: Any]()]
    }

    private func collect<T: SyncRecord>(_ type: T.Type, context: ModelContext, uid: String,
                                        writes: inout [Write], present: inout Set<String>,
                                        uploads: inout [(SyncFile, String, String)]) throws {
        let records = try context.fetch(FetchDescriptor<T>())
        for record in records {
            if record.syncId.isEmpty { record.syncId = UUID().uuidString }
            if record.createdBy.isEmpty { record.createdBy = uid }
            present.insert(record.syncId)
            let scope = record.effectiveVisibility == Visibility.me.rawValue ? "me" : "house"
            let hash = record.computeSyncHash()
            let changed = hash != record.syncHash || record.syncScope != scope
            if changed {
                if !record.syncScope.isEmpty && record.syncScope != scope {
                    // Moved between Everyone and Just me: remove it from where it was.
                    writes.append(Write(type: T.syncType, syncId: record.syncId, scope: record.syncScope,
                                        doc: tombstone(type: T.syncType, id: record.syncId, scope: record.syncScope, uid: uid)))
                }
                let doc: [String: Any] = [
                    "type": T.syncType,
                    "syncId": record.syncId,
                    "visibility": scope,
                    "deleted": false,
                    "createdBy": record.createdBy,
                    "updatedBy": uid,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "data": record.syncFields()
                ]
                writes.append(Write(type: T.syncType, syncId: record.syncId, scope: scope, doc: doc))
                record.syncHash = hash
                record.syncScope = scope
                record.updatedBy = uid
                known[record.syncId] = scope + "|" + T.syncType
            }
            for file in record.syncFiles where !uploadedFiles.contains(fileKey(file, scope: scope, syncId: record.syncId)) {
                uploads.append((file, scope, record.syncId))
            }
        }
    }

    // MARK: Pull

    private func handle(_ snapshot: QuerySnapshot?, _ error: Error?, scope: String) {
        if let error {
            syncProblem = "Sync paused: \(error.localizedDescription)"
            // A failed listener is finished; stop, and let HouseStore check membership and restart.
            pushChanges()
            stop()
            NotificationCenter.default.post(name: .houseAccessLost, object: nil, userInfo: ["error": error])
            return
        }
        guard let snapshot, let container else { return }
        let context = container.mainContext
        applying = true
        defer { applying = false }

        let order = Dictionary(uniqueKeysWithValues: SyncRegistry.types.enumerated().map { ($1.syncType, $0) })
        let changes = snapshot.documentChanges
            .filter { !$0.document.metadata.hasPendingWrites }
            .sorted { (order[$0.document.data()["type"] as? String ?? ""] ?? 99) < (order[$1.document.data()["type"] as? String ?? ""] ?? 99) }

        let resolver = SyncResolver(context: context)
        var applied: [(any SyncRecord, SyncData)] = []
        for change in changes {
            let doc = change.document
            let data = doc.data()
            guard let typeName = data["type"] as? String, let type = SyncRegistry.type(named: typeName) else { continue }
            let deleted = change.type == .removed || (data["deleted"] as? Bool) == true
            if let item = apply(type, id: doc.documentID, data: data, deleted: deleted, scope: scope, context: context, resolver: resolver) {
                applied.append(item)
            }
        }
        // Links second, once every record in the batch exists.
        for (record, fields) in applied { record.applySyncRefs(fields, resolver) }
        for (record, _) in applied {
            record.syncHash = record.computeSyncHash()
            record.syncScope = scope
            known[record.syncId] = scope + "|" + type(of: record).syncType
            for file in record.syncFiles where !FileManager.default.fileExists(atPath: file.localURL.path) {
                download(file, scope: scope, syncId: record.syncId)
            }
        }
        if !changes.isEmpty {
            try? context.save()
            saveState()
        }
        if pendingInitial > 0 { pendingInitial -= 1 }
        lastSynced = Date()
        if changes.isEmpty == false || pendingInitial == 0 { syncProblem = nil }
    }

    private func apply<T: SyncRecord>(_ type: T.Type, id: String, data: [String: Any], deleted: Bool, scope: String,
                                      context: ModelContext, resolver: SyncResolver) -> (any SyncRecord, SyncData)? {
        let existing = resolver.find(T.self, id)
        if deleted {
            if let existing {
                resolver.forget(existing)
                context.delete(existing)
            }
            known.removeValue(forKey: id)
            return nil
        }
        let fields = SyncData(raw: data["data"] as? [String: Any] ?? [:])
        let record: T
        if let existing {
            // An edit made here that hasn't been pushed yet wins; it goes up on the next push.
            if !existing.syncHash.isEmpty && existing.computeSyncHash() != existing.syncHash { return nil }
            record = existing
        } else {
            record = T.blank()
            record.syncId = id
            context.insert(record)
            resolver.register(record)
        }
        record.applySyncFields(fields)
        if !T.alwaysShared && !T.followsParent, let vis = data["visibility"] as? String {
            record.visibilityRaw = vis == "me" ? Visibility.me.rawValue : Visibility.house.rawValue
        }
        if let createdBy = data["createdBy"] as? String { record.createdBy = createdBy }
        if let updatedBy = data["updatedBy"] as? String { record.updatedBy = updatedBy }
        return (record, fields)
    }

    // MARK: Files (Firebase Storage)

    private func fileKey(_ file: SyncFile, scope: String, syncId: String) -> String { "\(scope)/\(syncId)/\(file.name)" }

    /// houses/{houseId}/files/{syncId}/{name} or houses/{houseId}/private/{uid}/files/{syncId}/{name}
    private func storageRef(_ file: SyncFile, scope: String, syncId: String) -> StorageReference? {
        guard let houseId, let uid else { return nil }
        let base = scope == "me" ? "houses/\(houseId)/private/\(uid)/files" : "houses/\(houseId)/files"
        return Storage.storage().reference(withPath: "\(base)/\(syncId)/\(file.name)")
    }

    private func upload(_ file: SyncFile, scope: String, syncId: String) {
        let key = fileKey(file, scope: scope, syncId: syncId)
        guard !filesInFlight.contains(key), FileManager.default.fileExists(atPath: file.localURL.path),
              let ref = storageRef(file, scope: scope, syncId: syncId) else { return }
        filesInFlight.insert(key)
        ref.putFile(from: file.localURL, metadata: nil) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                self.filesInFlight.remove(key)
                if let error {
                    self.fileProblem = "Photos and scanned documents aren't syncing yet: \(error.localizedDescription)"
                } else {
                    self.uploadedFiles.insert(key)
                    self.fileProblem = nil
                    self.saveState()
                }
            }
        }
    }

    private func download(_ file: SyncFile, scope: String, syncId: String) {
        let key = "down:" + fileKey(file, scope: scope, syncId: syncId)
        guard !filesInFlight.contains(key), let ref = storageRef(file, scope: scope, syncId: syncId) else { return }
        filesInFlight.insert(key)
        ref.write(toFile: file.localURL) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                self.filesInFlight.remove(key)
                if let error {
                    self.fileProblem = "Some photos or scans couldn't be downloaded yet: \(error.localizedDescription)"
                } else {
                    self.uploadedFiles.insert(self.fileKey(file, scope: scope, syncId: syncId))
                    self.saveState()
                }
            }
        }
    }
}

extension Notification.Name {
    static let houseAccessLost = Notification.Name("houseAccessLost")
}
