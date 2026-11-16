import Foundation
import SwiftData
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

struct HouseInfo: Equatable {
    var id: String
    var name: String
    var ownerId: String
    var inviteCode: String
    var members: [HouseMember]
}

/// Signing in, and creating, joining and running a shared house. Data sync itself is SyncEngine.
/// Firestore layout and rules are documented in AI_CONTEXT.md (shared with the Android app).
@MainActor
final class HouseStore: ObservableObject {
    static let shared = HouseStore()

    @Published private(set) var uid: String?
    @Published private(set) var displayName: String = ""
    @Published private(set) var email: String = ""
    @Published private(set) var house: HouseInfo?
    @Published var busy = false
    @Published var message: String?
    /// False when GoogleService-Info.plist is missing, so the app stays solo-only.
    @Published private(set) var isAvailable = false

    private var container: ModelContainer?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private var houseListener: ListenerRegistration?
    private var currentNonce: String?
    private var syncAllowed = true

    var isOwner: Bool { house != nil && house?.ownerId == uid }
    var isSignedIn: Bool { uid != nil }

    private var db: Firestore { Firestore.firestore() }

    // MARK: Setup

    func configure(container: ModelContainer, syncAllowed: Bool) {
        self.container = container
        self.syncAllowed = syncAllowed
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 200 * 1024 * 1024))
        Firestore.firestore().settings = settings
        SyncDateConverter.convert = { value in
            if let ts = value as? Timestamp { return ts.dateValue() }
            return value as? Date
        }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        isAvailable = true
        SyncEngine.shared.configure(container: container)
        NotificationCenter.default.addObserver(forName: .houseAccessLost, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.checkStillMember() }
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.authChanged(user) }
        }
    }

    private func authChanged(_ user: User?) {
        userListener?.remove()
        userListener = nil
        guard let user else {
            uid = nil
            displayName = ""
            email = ""
            setHouse(nil)
            return
        }
        uid = user.uid
        email = user.email ?? ""
        if displayName.isEmpty { displayName = user.displayName ?? (user.email?.components(separatedBy: "@").first ?? "Me") }
        HouseContext.uid = user.uid
        userListener = db.collection("users").document(user.uid).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self else { return }
                let data = snap?.data() ?? [:]
                if let name = data["displayName"] as? String, !name.isEmpty { self.displayName = name }
                self.listenToHouse(data["houseId"] as? String)
            }
        }
    }

    private func listenToHouse(_ houseId: String?) {
        if houseId == house?.id && houseListener != nil { return }
        houseListener?.remove()
        houseListener = nil
        guard let houseId, !houseId.isEmpty else {
            setHouse(nil)
            return
        }
        houseListener = db.collection("houses").document(houseId).addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil || snap?.exists == false {
                    // Possibly removed or closed, or just a network hiccup: confirm with the server first.
                    self.houseListener?.remove()
                    self.houseListener = nil
                    self.confirmMembership(houseId: houseId, attempt: 1)
                    return
                }
                guard let data = snap?.data() else { return }
                self.setHouse(Self.parseHouse(id: houseId, data: data))
            }
        }
    }

    static func parseHouse(id: String, data: [String: Any]) -> HouseInfo {
        let ids = data["memberIds"] as? [String] ?? []
        let map = data["members"] as? [String: Any] ?? [:]
        let owner = data["ownerId"] as? String ?? ""
        let members = ids.map { uid -> HouseMember in
            let entry = map[uid] as? [String: Any] ?? [:]
            return HouseMember(uid: uid, name: entry["name"] as? String ?? "Member", role: uid == owner ? "owner" : "member")
        }
        return HouseInfo(id: id, name: data["name"] as? String ?? "Home", ownerId: owner,
                         inviteCode: data["inviteCode"] as? String ?? "", members: members)
    }

    private func setHouse(_ info: HouseInfo?) {
        house = info
        HouseContext.houseId = info?.id
        HouseContext.ownerId = info?.ownerId
        HouseContext.members = info?.members ?? []
        guard let info, let uid, info.members.contains(where: { $0.uid == uid }) else {
            SyncEngine.shared.stop()
            return
        }
        if syncAllowed { SyncEngine.shared.start(houseId: info.id, uid: uid) }
        ensureMemberPeople(info)
    }

    /// Every house member appears on People as a household person with a Member badge.
    /// The syncId is fixed per member, so two phones creating it at once make one record.
    private func ensureMemberPeople(_ info: HouseInfo) {
        guard let context = container?.mainContext else { return }
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        for member in info.members {
            if let existing = people.first(where: { $0.memberUid == member.uid || $0.syncId == "member-\(member.uid)" }) {
                if existing.memberUid.isEmpty { existing.memberUid = member.uid }
                if existing.name != member.name && !member.name.isEmpty { existing.name = member.name }
                continue
            }
            let person = Person(name: member.name)
            person.kindRaw = "household"
            person.memberUid = member.uid
            person.syncId = "member-\(member.uid)"
            person.visibilityRaw = Visibility.house.rawValue
            context.insert(person)
        }
        try? context.save()
    }

    // MARK: Sign in

    /// Configures the Sign in with Apple request with a hashed nonce for Firebase.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                message = "Sign in with Apple didn't return a token."
                return
            }
            let firebaseCredential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce, fullName: credential.fullName)
            let given = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            signIn(with: firebaseCredential, name: given)
        }
    }

    func signInWithGoogle() {
        guard GIDSignIn.sharedInstance.configuration != nil else {
            message = "Google sign-in isn't set up in this build yet."
            return
        }
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        GIDSignIn.sharedInstance.signIn(withPresenting: top) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    if (error as NSError).code != GIDSignInError.canceled.rawValue { self.message = error.localizedDescription }
                    return
                }
                guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                self.signIn(with: credential, name: user.profile?.name ?? "")
            }
        }
    }

    private func signIn(with credential: AuthCredential, name: String) {
        busy = true
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                if let error {
                    self.message = error.localizedDescription
                    return
                }
                guard let user = result?.user else { return }
                let finalName = !name.isEmpty ? name : (user.displayName ?? user.email?.components(separatedBy: "@").first ?? "Me")
                var data: [String: Any] = ["email": user.email ?? "", "updatedAt": FieldValue.serverTimestamp()]
                if !name.isEmpty || self.displayName.isEmpty { data["displayName"] = finalName; self.displayName = finalName }
                self.db.collection("users").document(user.uid).setData(data, merge: true)
            }
        }
    }

    func signOut() {
        SyncEngine.shared.flush()
        SyncEngine.shared.stop()
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let uid, !trimmed.isEmpty else { return }
        displayName = trimmed
        db.collection("users").document(uid).setData(["displayName": trimmed], merge: true)
        if let house { db.collection("houses").document(house.id).updateData(["members.\(uid).name": trimmed]) }
    }

    // MARK: Create / join

    /// Makes a house from this phone's data. The saved data is copied to a backup first,
    /// then uploaded once by SyncEngine. Nothing local is deleted.
    func createHouse(name: String) {
        guard let uid, house == nil else { return }
        busy = true
        _ = backupStore(reason: "before-sharing")
        let houseRef = db.collection("houses").document()
        let code = Self.makeCode()
        let batch = db.batch()
        batch.setData([
            "name": name.isEmpty ? "Home" : name,
            "ownerId": uid,
            "memberIds": [uid],
            "members": [uid: ["name": displayName, "joinedAt": FieldValue.serverTimestamp()]],
            "inviteCode": code,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: houseRef)
        batch.setData(["houseId": houseRef.documentID, "createdBy": uid, "createdAt": FieldValue.serverTimestamp()],
                      forDocument: db.collection("invites").document(code))
        batch.commit { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.busy = false
                    self.message = "Couldn't create the house: \(error.localizedDescription)"
                    return
                }
                self.db.collection("users").document(uid).setData(["houseId": houseRef.documentID], merge: true) { _ in
                    Task { @MainActor in self.busy = false }
                }
            }
        }
    }

    /// Joins the house that owns `code`. This phone's own data is copied to a backup
    /// (Files › Void Home) and cleared, then the house loads.
    func join(code raw: String) {
        guard let uid, house == nil else { return }
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count >= 4 else {
            message = "That code looks too short."
            return
        }
        busy = true
        db.collection("invites").document(code).getDocument(source: .server) { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                guard let houseId = snap?.data()?["houseId"] as? String else {
                    self.busy = false
                    self.message = error.map { "Couldn't check the code: \($0.localizedDescription)" } ?? "No house uses that code. Check it with the owner."
                    return
                }
                let houseRef = self.db.collection("houses").document(houseId)
                houseRef.updateData([
                    "memberIds": FieldValue.arrayUnion([uid]),
                    "members.\(uid)": ["name": self.displayName, "joinedAt": FieldValue.serverTimestamp()],
                    "joinCode": code,
                    "updatedAt": FieldValue.serverTimestamp()
                ]) { error in
                    Task { @MainActor in
                        if let error {
                            self.busy = false
                            self.message = "Couldn't join: \(error.localizedDescription)"
                            return
                        }
                        let backup = self.backupStore(reason: "before-joining")
                        self.clearLocalData(keepPrivate: false)
                        self.db.collection("users").document(uid).setData(["houseId": houseId], merge: true) { _ in
                            Task { @MainActor in
                                self.busy = false
                                if let backup { self.message = "Joined. Your own data from before is saved in Files › Void Home › \(backup)." }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Owner tools

    func newInviteCode() {
        guard let house, isOwner, let uid else { return }
        let code = Self.makeCode()
        let batch = db.batch()
        if !house.inviteCode.isEmpty { batch.deleteDocument(db.collection("invites").document(house.inviteCode)) }
        batch.setData(["houseId": house.id, "createdBy": uid, "createdAt": FieldValue.serverTimestamp()],
                      forDocument: db.collection("invites").document(code))
        batch.updateData(["inviteCode": code, "updatedAt": FieldValue.serverTimestamp()], forDocument: db.collection("houses").document(house.id))
        batch.commit { [weak self] error in
            Task { @MainActor in if let error { self?.message = error.localizedDescription } }
        }
    }

    func remove(member: HouseMember) {
        guard let house, isOwner, member.uid != uid else { return }
        db.collection("houses").document(house.id).updateData([
            "memberIds": FieldValue.arrayRemove([member.uid]),
            "members.\(member.uid)": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { [weak self] error in
            Task { @MainActor in if let error { self?.message = error.localizedDescription } }
        }
    }

    func makeOwner(_ member: HouseMember) {
        guard let house, isOwner else { return }
        db.collection("houses").document(house.id).updateData(["ownerId": member.uid, "updatedAt": FieldValue.serverTimestamp()]) { [weak self] error in
            Task { @MainActor in if let error { self?.message = error.localizedDescription } }
        }
    }

    /// A member leaves. The owner hands over first, or closes the house when alone.
    func leave() {
        guard let house, let uid else { return }
        if isOwner && house.members.count > 1 {
            message = "Make someone else the owner before you leave."
            return
        }
        SyncEngine.shared.flush()
        let batch = db.batch()
        let houseRef = db.collection("houses").document(house.id)
        if isOwner {
            // Alone in the house: close it. Everything stays on this phone as before.
            if !house.inviteCode.isEmpty { batch.deleteDocument(db.collection("invites").document(house.inviteCode)) }
            batch.deleteDocument(houseRef)
        } else {
            batch.updateData(["memberIds": FieldValue.arrayRemove([uid]), "members.\(uid)": FieldValue.delete(),
                              "updatedAt": FieldValue.serverTimestamp()], forDocument: houseRef)
        }
        batch.updateData(["houseId": FieldValue.delete()], forDocument: db.collection("users").document(uid))
        let wasOwner = isOwner
        batch.commit { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.message = error.localizedDescription
                    return
                }
                SyncEngine.shared.stop()
                SyncEngine.clearState(houseId: house.id, uid: uid)
                if wasOwner { self.resetSyncMarks() } else { self.clearLocalData(keepPrivate: true) }
                self.setHouse(nil)
            }
        }
    }

    private func checkStillMember() {
        guard let house else { return }
        confirmMembership(houseId: house.id, attempt: 1)
    }

    /// Asks the server whether this account is still in the house. Only a definite answer
    /// (three denials in a row, a few seconds apart) counts as being removed.
    private func confirmMembership(houseId: String, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let uid = self.uid else { return }
            self.db.collection("houses").document(houseId).getDocument(source: .server) { snap, error in
                Task { @MainActor in
                    if let data = snap?.data() {
                        let ids = data["memberIds"] as? [String] ?? []
                        if ids.contains(uid) {
                            // Still a member: listen again and restart sync.
                            self.listenToHouse(houseId)
                            if self.syncAllowed { SyncEngine.shared.start(houseId: houseId, uid: uid) }
                        } else {
                            self.handleRemoved(houseId: houseId)
                        }
                        return
                    }
                    let denied = (error as NSError?)?.code == FirestoreErrorCode.permissionDenied.rawValue
                    if denied && attempt >= 3 {
                        self.handleRemoved(houseId: houseId)
                    } else if denied || error != nil {
                        // Offline or not sure yet: try again later and keep everything.
                        self.confirmMembership(houseId: houseId, attempt: denied ? attempt + 1 : attempt)
                    }
                }
            }
        }
    }

    /// Removed by the owner (or the house closed): shared items go, "Just me" items stay.
    private func handleRemoved(houseId: String) {
        guard let uid, house?.id == houseId else { return }
        houseListener?.remove()
        houseListener = nil
        SyncEngine.shared.stop()
        SyncEngine.clearState(houseId: houseId, uid: uid)
        _ = backupStore(reason: "removed-from-house")
        clearLocalData(keepPrivate: true)
        db.collection("users").document(uid).updateData(["houseId": FieldValue.delete()])
        setHouse(nil)
        message = "You're no longer part of that house. Your own \"Just me\" items are still here."
    }

    // MARK: Local data helpers

    @discardableResult
    private func backupStore(reason: String) -> String? {
        guard let url = container?.configurations.first?.url else { return nil }
        try? container?.mainContext.save()
        return StoreBackup.copyStore(at: url)
    }

    /// Deletes local records (all of them, or only house ones) so a different house can load.
    private func clearLocalData(keepPrivate: Bool) {
        guard let context = container?.mainContext else { return }
        for type in SyncRegistry.types { clear(type, context: context, keepPrivate: keepPrivate) }
        try? context.save()
    }

    private func clear<T: SyncRecord>(_ type: T.Type, context: ModelContext, keepPrivate: Bool) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items {
            if keepPrivate && item.isPrivate && (item.createdBy.isEmpty || item.createdBy == uid) {
                item.syncHash = ""
                item.syncScope = ""
                continue
            }
            context.delete(item)
        }
    }

    /// After closing a house the data stays, but it is no longer tied to it.
    private func resetSyncMarks() {
        guard let context = container?.mainContext else { return }
        for type in SyncRegistry.types { resetMarks(type, context: context) }
        try? context.save()
    }

    private func resetMarks<T: SyncRecord>(_ type: T.Type, context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
            item.syncHash = ""
            item.syncScope = ""
        }
    }

    // MARK: Utilities

    /// Six characters without look-alikes (no 0/O, 1/I/L).
    static func makeCode() -> String {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
