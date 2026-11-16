package com.voidhome.app.data

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.FirebaseFirestoreSettings
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.PersistentCacheSettings
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.Source
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.File
import java.util.UUID

data class Member(val uid: String, val name: String)

data class HouseInfo(
    val id: String,
    val name: String,
    val ownerId: String,
    val members: List<Member>,
    val inviteCode: String,
)

/**
 * The shared house, straight from Firestore (offline persistence on). Follows the contract in
 * AI_CONTEXT.md section 15 exactly: same paths, same envelope, same fields, no server code.
 * Android has no separate local database: Firestore's persistent cache is the local copy, so
 * the app works offline and queued writes go up when the signal is back (last write wins).
 */
object Repo {
    private const val TAG = "VoidRepo"
    private val auth get() = FirebaseAuth.getInstance()
    private val db get() = FirebaseFirestore.getInstance()

    var user by mutableStateOf<FirebaseUser?>(null); private set
    var houseId by mutableStateOf<String?>(null); private set
    var house by mutableStateOf<HouseInfo?>(null); private set
    var userLoaded by mutableStateOf(false); private set
    var storageProblem by mutableStateOf<String?>(null)
    var lastError by mutableStateOf<String?>(null)

    private var sharedRecs by mutableStateOf<Map<String, Rec>>(emptyMap())
    private var privateRecs by mutableStateOf<Map<String, Rec>>(emptyMap())
    private var deletedIds by mutableStateOf<Set<String>>(emptySet())
    private var sharedFromServer = false

    /** Everything this person can see: the house's items plus their own Just me items. */
    val all: Map<String, Rec> get() = sharedRecs + privateRecs

    private var userReg: ListenerRegistration? = null
    private var houseReg: ListenerRegistration? = null
    private var itemsReg: ListenerRegistration? = null
    private var privReg: ListenerRegistration? = null
    private var denials = 0
    lateinit var filesDir: File; private set

    val uid: String? get() = user?.uid
    val isOwner: Boolean get() = house != null && house?.ownerId == uid

    fun init(context: Context) {
        filesDir = File(context.filesDir, "VoidFiles").apply { mkdirs() }
        runCatching {
            db.firestoreSettings = FirebaseFirestoreSettings.Builder()
                .setLocalCacheSettings(PersistentCacheSettings.newBuilder().setSizeBytes(200L * 1024 * 1024).build())
                .build()
        }
        auth.addAuthStateListener { a ->
            val u = a.currentUser
            if (u?.uid != user?.uid) { user = u; onUser(u) } else user = u
        }
    }

    // ---------------------------------------------------------------- listeners

    private fun onUser(u: FirebaseUser?) {
        userReg?.remove(); detachHouse(); houseId = null; userLoaded = false
        if (u == null) { userLoaded = true; return }
        db.collection("users").document(u.uid).set(
            mapOf("displayName" to (u.displayName ?: ""), "email" to (u.email ?: ""), "updatedAt" to FieldValue.serverTimestamp()),
            SetOptions.merge(),
        )
        userReg = db.collection("users").document(u.uid).addSnapshotListener { snap, err ->
            if (err != null) { Log.w(TAG, "user", err); userLoaded = true; return@addSnapshotListener }
            val hid = snap?.getString("houseId")?.takeIf { it.isNotBlank() }
            userLoaded = true
            if (hid != houseId) { detachHouse(); houseId = hid; if (hid != null) attachHouse(hid) }
        }
    }

    private fun detachHouse() {
        houseReg?.remove(); itemsReg?.remove(); privReg?.remove()
        houseReg = null; itemsReg = null; privReg = null
        house = null; sharedRecs = emptyMap(); privateRecs = emptyMap(); deletedIds = emptySet()
        sharedFromServer = false; denials = 0
    }

    private fun attachHouse(hid: String) {
        val me = uid ?: return
        houseReg = db.collection("houses").document(hid).addSnapshotListener { snap, err ->
            if (err != null) { onDenied(err); return@addSnapshotListener }
            if (snap == null || !snap.exists()) {
                if (snap?.metadata?.isFromCache == false) onHouseGone()
                return@addSnapshotListener
            }
            denials = 0
            house = parseHouse(snap)
            ensureMemberPeople()
        }
        itemsReg = db.collection("houses").document(hid).collection("items").addSnapshotListener { snap, err ->
            if (err != null) { onDenied(err); return@addSnapshotListener }
            snap ?: return@addSnapshotListener
            val (live, dead) = parse(snap.documents)
            sharedRecs = live; deletedIds = deletedIds + dead
            if (!snap.metadata.isFromCache) { sharedFromServer = true; ensureMemberPeople() }
        }
        privReg = db.collection("houses").document(hid).collection("private").document(me).collection("items")
            .addSnapshotListener { snap, err ->
                if (err != null) { onDenied(err); return@addSnapshotListener }
                snap ?: return@addSnapshotListener
                val (live, dead) = parse(snap.documents)
                privateRecs = live; deletedIds = deletedIds + dead
            }
    }

    private fun parse(docs: List<DocumentSnapshot>): Pair<Map<String, Rec>, Set<String>> {
        val live = HashMap<String, Rec>(); val dead = HashSet<String>()
        for (d in docs) {
            if (d.getBoolean("deleted") == true) { dead += d.id; continue }
            val type = d.getString("type") ?: continue
            @Suppress("UNCHECKED_CAST")
            val data = d.get("data") as? Map<String, Any?> ?: emptyMap()
            live[d.id] = Rec(d.id, type, d.getString("visibility") ?: Vis.HOUSE, d.getString("createdBy") ?: "", d.getString("updatedBy") ?: "", data)
        }
        return live to dead
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseHouse(s: DocumentSnapshot): HouseInfo {
        val ids = (s.get("memberIds") as? List<*>)?.filterIsInstance<String>() ?: emptyList()
        val members = s.get("members") as? Map<String, Any?> ?: emptyMap()
        return HouseInfo(
            id = s.id, name = s.getString("name") ?: "Home", ownerId = s.getString("ownerId") ?: "",
            members = ids.map { id -> Member(id, ((members[id] as? Map<String, Any?>)?.get("name") as? String).orEmpty().ifBlank { "Member" }) },
            inviteCode = s.getString("inviteCode") ?: "",
        )
    }

    /** After three server denials the person was removed: clear the house link (rules hide everything). */
    private fun onDenied(e: FirebaseFirestoreException) {
        Log.w(TAG, "listener", e)
        if (e.code == FirebaseFirestoreException.Code.PERMISSION_DENIED) {
            denials += 1
            if (denials >= 3) onHouseGone()
        }
    }

    private fun onHouseGone() {
        val me = uid ?: return
        lastError = "You're no longer in that house."
        db.collection("users").document(me).update("houseId", FieldValue.delete())
    }

    // ---------------------------------------------------------------- reading helpers

    fun get(id: String?): Rec? = id?.let { all[it] }
    fun of(type: String): List<Rec> = all.values.filter { it.type == type }
    val home: Rec? get() = of(T.HOME).minByOrNull { it.t("createdAt") ?: java.time.LocalDateTime.MAX }
    fun memberName(uid: String?): String = when {
        uid.isNullOrBlank() -> "Someone"
        uid == this.uid -> "You"
        else -> house?.members?.firstOrNull { it.uid == uid }?.name ?: "A former member"
    }
    val members: List<Member> get() = house?.members ?: emptyList()

    // ---------------------------------------------------------------- writing

    private fun itemsRef(vis: String, id: String) = db.collection("houses").document(houseId!!).let {
        if (vis == Vis.ME) it.collection("private").document(uid!!).collection("items").document(id)
        else it.collection("items").document(id)
    }

    fun newId(): String = UUID.randomUUID().toString().uppercase()

    /**
     * Writes a record. `data` is merged over the record's current fields, so fields this app
     * doesn't know about (written by a newer iOS build) are kept. Moving between Just me and
     * Everyone writes a tombstone at the old path, then the full record at the new one.
     */
    fun save(type: String, id: String, vis: String, data: Map<String, Any?>): String {
        val me = uid ?: return id
        if (houseId == null) return id
        val existing = all[id]
        val finalVis = if (type in T.ALWAYS) Vis.HOUSE else vis
        val merged = HashMap<String, Any?>(existing?.data ?: emptyMap())
        if (existing == null) merged["createdAt"] = Dates.now()
        merged.putAll(data)
        val createdBy = existing?.createdBy?.ifBlank { me } ?: me
        if (existing != null && existing.vis != finalVis) tombstone(existing)
        val doc = hashMapOf(
            "type" to type, "syncId" to id, "visibility" to finalVis, "deleted" to false,
            "createdBy" to createdBy, "updatedBy" to me, "updatedAt" to FieldValue.serverTimestamp(), "data" to merged,
        )
        // Show it at once (Firestore also raises a local snapshot, this just avoids a flicker).
        val rec = Rec(id, type, finalVis, createdBy, me, merged)
        if (finalVis == Vis.ME) { privateRecs = privateRecs + (id to rec); sharedRecs = sharedRecs - id }
        else { sharedRecs = sharedRecs + (id to rec); privateRecs = privateRecs - id }
        itemsRef(finalVis, id).set(doc).addOnFailureListener { lastError = it.message; Log.w(TAG, "save", it) }
        return id
    }

    fun update(rec: Rec, data: Map<String, Any?>) { save(rec.type, rec.id, rec.vis, data) }

    private fun tombstone(rec: Rec) {
        val me = uid ?: return
        itemsRef(rec.vis, rec.id).set(hashMapOf(
            "type" to rec.type, "syncId" to rec.id, "visibility" to rec.vis, "deleted" to true,
            "createdBy" to rec.createdBy.ifBlank { me }, "updatedBy" to me,
            "updatedAt" to FieldValue.serverTimestamp(), "data" to emptyMap<String, Any>(),
        )).addOnFailureListener { lastError = it.message }
    }

    /** Children that are deleted with their parent (the iOS cascade rules). */
    private fun cascadeChildren(rec: Rec): List<Rec> = all.values.filter { c ->
        when (rec.type) {
            T.ASSET -> (c.type == T.WARRANTY || c.type == T.MAINTENANCE) && c.link("asset") == rec.id
            T.ROOM -> (c.type == T.ROOM_PART || c.type == T.DOOR) && c.link("room") == rec.id
            T.ROOM_PART -> c.type == T.DOOR && c.link("part") == rec.id
            T.PROJECT -> (c.type == T.TASK || c.type == T.PHOTO || c.type == T.SPEND) && c.link("project") == rec.id
            T.TASK -> (c.type == T.CHECK || c.type == T.COMPLETION) && c.link("task") == rec.id
            T.BILL -> c.type == T.PAYMENT && c.link("bill") == rec.id
            else -> false
        }
    }

    fun delete(rec: Rec) {
        cascadeChildren(rec).forEach { delete(it) }
        sharedRecs = sharedRecs - rec.id; privateRecs = privateRecs - rec.id
        tombstone(rec)
    }

    /** Records that live wherever this record lives ("follows X" in the contract). */
    private fun followers(rec: Rec): List<Rec> = all.values.filter { c ->
        when (rec.type) {
            T.ASSET -> (c.type == T.WARRANTY || c.type == T.PLAN) && c.link("asset") == rec.id ||
                c.type == T.MAINTENANCE && c.link("plan") == null && c.link("asset") == rec.id
            T.PLAN -> c.type == T.MAINTENANCE && c.link("plan") == rec.id
            T.BILL -> c.type == T.PAYMENT && c.link("bill") == rec.id
            T.TASK -> (c.type == T.CHECK || c.type == T.COMPLETION) && c.link("task") == rec.id
            T.PROJECT -> c.type == T.PHOTO && c.link("project") == rec.id ||
                c.type == T.SPEND && c.link("project") == rec.id && (rec.vis == Vis.HOUSE || c.vis == Vis.ME)
            else -> false
        }
    }

    /** Where a new child record goes: with its parent. */
    fun visFor(type: String, parent: Rec?): String = when {
        type in T.ALWAYS -> Vis.HOUSE
        parent != null -> parent.vis
        else -> Vis.HOUSE
    }

    /** Only the creator may change Just me / Everyone. Children move with the record. */
    fun canChangeVisibility(rec: Rec?): Boolean = rec == null || rec.createdBy.isBlank() || rec.createdBy == uid

    fun setVisibility(rec: Rec, vis: String) {
        if (rec.vis == vis || !canChangeVisibility(rec)) return
        val kids = followers(rec)
        save(rec.type, rec.id, vis, emptyMap())
        kids.forEach { k -> if (k.type == T.PLAN) setVisibilityForce(k, vis) else save(k.type, k.id, vis, emptyMap()) }
    }

    private fun setVisibilityForce(rec: Rec, vis: String) {
        val kids = followers(rec)
        save(rec.type, rec.id, vis, emptyMap())
        kids.forEach { save(it.type, it.id, vis, emptyMap()) }
    }

    // ---------------------------------------------------------------- house: create / join / manage

    private const val CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    private fun newCode() = (1..6).map { CODE_CHARS.random() }.joinToString("")
    private val myName get() = user?.displayName?.ifBlank { null } ?: user?.email?.substringBefore('@') ?: "Member"

    suspend fun createHouse(name: String) {
        val me = uid ?: error("Not signed in")
        val ref = db.collection("houses").document()
        val code = newCode()
        val batch = db.batch()
        batch.set(ref, mapOf(
            "name" to name, "ownerId" to me, "memberIds" to listOf(me),
            "members" to mapOf(me to mapOf("name" to myName, "joinedAt" to FieldValue.serverTimestamp())),
            "inviteCode" to code, "createdAt" to FieldValue.serverTimestamp(), "updatedAt" to FieldValue.serverTimestamp(),
        ))
        batch.set(db.collection("invites").document(code), mapOf("houseId" to ref.id, "createdBy" to me, "createdAt" to FieldValue.serverTimestamp()))
        batch.commit().await()
        db.collection("users").document(me).set(mapOf("houseId" to ref.id, "updatedAt" to FieldValue.serverTimestamp()), SetOptions.merge()).await()
        // A new house from Android starts with its home record, like the iOS default "My Home".
        houseId = ref.id
        save(T.HOME, newId(), Vis.HOUSE, mapOf("name" to name, "address" to ""))
    }

    suspend fun joinHouse(rawCode: String) {
        val me = uid ?: error("Not signed in")
        val code = rawCode.trim().uppercase().replace(" ", "")
        require(code.length == 6) { "Codes are 6 characters." }
        val invite = db.collection("invites").document(code).get(Source.SERVER).await()
        val hid = invite.getString("houseId") ?: error("That code doesn't match a house. Check it with the owner.")
        db.collection("houses").document(hid).update(mapOf(
            "memberIds" to FieldValue.arrayUnion(me),
            "members.$me" to mapOf("name" to myName, "joinedAt" to FieldValue.serverTimestamp()),
            "joinCode" to code, "updatedAt" to FieldValue.serverTimestamp(),
        )).await()
        db.collection("users").document(me).set(mapOf("houseId" to hid, "updatedAt" to FieldValue.serverTimestamp()), SetOptions.merge()).await()
    }

    suspend fun newInviteCode() {
        val h = house ?: return; val me = uid ?: return
        val code = newCode()
        val batch = db.batch()
        if (h.inviteCode.isNotBlank()) batch.delete(db.collection("invites").document(h.inviteCode))
        batch.set(db.collection("invites").document(code), mapOf("houseId" to h.id, "createdBy" to me, "createdAt" to FieldValue.serverTimestamp()))
        batch.update(db.collection("houses").document(h.id), mapOf("inviteCode" to code, "updatedAt" to FieldValue.serverTimestamp()))
        batch.commit().await()
    }

    suspend fun removeMember(memberUid: String) {
        val h = house ?: return
        db.collection("houses").document(h.id).update(mapOf(
            "memberIds" to FieldValue.arrayRemove(memberUid), "members.$memberUid" to FieldValue.delete(),
            "updatedAt" to FieldValue.serverTimestamp(),
        )).await()
    }

    suspend fun handOver(memberUid: String) {
        val h = house ?: return
        db.collection("houses").document(h.id).update(mapOf("ownerId" to memberUid, "updatedAt" to FieldValue.serverTimestamp())).await()
    }

    suspend fun renameHouse(name: String) {
        val h = house ?: return
        db.collection("houses").document(h.id).update(mapOf("name" to name, "updatedAt" to FieldValue.serverTimestamp())).await()
    }

    suspend fun leaveHouse() {
        val h = house ?: return; val me = uid ?: return
        require(h.ownerId != me) { "Hand the house over to another member first." }
        db.collection("houses").document(h.id).update(mapOf(
            "memberIds" to FieldValue.arrayRemove(me), "members.$me" to FieldValue.delete(), "updatedAt" to FieldValue.serverTimestamp(),
        )).await()
        db.collection("users").document(me).update("houseId", FieldValue.delete()).await()
    }

    /** Owner alone: delete the invite and the house document. Record documents stay in Firestore. */
    suspend fun closeHouse() {
        val h = house ?: return; val me = uid ?: return
        require(h.ownerId == me && h.members.size == 1) { "Only an owner on their own can close the house." }
        if (h.inviteCode.isNotBlank()) db.collection("invites").document(h.inviteCode).delete().await()
        db.collection("houses").document(h.id).delete().await()
        db.collection("users").document(me).update("houseId", FieldValue.delete()).await()
    }

    fun signOut() { auth.signOut() }

    /** Every member appears on People as a household person `member-<uid>` (fixed ID, no duplicates). */
    private fun ensureMemberPeople() {
        val h = house ?: return
        if (!sharedFromServer || uid == null) return
        for (m in h.members) {
            val id = "member-${m.uid}"
            val existing = sharedRecs[id] ?: sharedRecs.values.firstOrNull { it.type == T.PERSON && it.s("memberUid") == m.uid }
            if (existing != null) {
                if (existing.s("name") != m.name && m.name.isNotBlank() && m.name != "Member" && m.uid == uid) update(existing, mapOf("name" to m.name))
                continue
            }
            if (id in deletedIds) continue
            save(T.PERSON, id, Vis.HOUSE, mapOf(
                "name" to m.name, "company" to "", "role" to "", "phoneNumber" to "", "email" to "", "notes" to "",
                "kindRaw" to "Household", "memberUid" to m.uid,
            ))
        }
    }

    // ---------------------------------------------------------------- files (Firebase Storage)

    fun localFile(name: String): File = File(filesDir, name)

    private fun storagePath(rec: Rec, name: String): String? {
        val hid = houseId ?: return null; val me = uid ?: return null
        val base = if (rec.vis == Vis.ME) "houses/$hid/private/$me/files" else "houses/$hid/files"
        return "$base/${rec.id}/$name"
    }

    /** Copies a picked/captured file into app storage and returns its new file name. */
    fun importFile(context: Context, uri: Uri, ext: String): String? = runCatching {
        val name = "${UUID.randomUUID().toString().uppercase()}.$ext"
        context.contentResolver.openInputStream(uri)!!.use { input -> localFile(name).outputStream().use { input.copyTo(it) } }
        name
    }.getOrNull()

    fun upload(rec: Rec, name: String) {
        val path = storagePath(rec, name) ?: return
        val f = localFile(name); if (!f.exists()) return
        FirebaseStorage.getInstance().reference.child(path).putFile(Uri.fromFile(f))
            .addOnSuccessListener { storageProblem = null }
            .addOnFailureListener { storageProblem = "Photos and scans aren't syncing: " + (it.message ?: "Storage error") + ". Records still sync." }
    }

    /** Fetches a file another phone uploaded, if we don't have it yet. */
    suspend fun ensureLocal(rec: Rec, name: String): File? {
        if (name.isBlank()) return null
        val f = localFile(name)
        if (f.exists() && f.length() > 0) return f
        val path = storagePath(rec, name) ?: return null
        return runCatching {
            FirebaseStorage.getInstance().reference.child(path).getFile(f).await(); f
        }.getOrElse { f.delete(); null }
    }
}

/** The JSON-string maps used for splits (`sharesJSON`, `repaidJSON`, `customSharesJSON`). */
object SplitJSON {
    fun amounts(s: String): Map<String, Double> = runCatching {
        val o = JSONObject(s); o.keys().asSequence().associateWith { o.getDouble(it) }
    }.getOrDefault(emptyMap())

    fun strings(s: String): Map<String, String> = runCatching {
        val o = JSONObject(s); o.keys().asSequence().associateWith { o.get(it).toString() }
    }.getOrDefault(emptyMap())

    fun encode(m: Map<String, Any>): String = if (m.isEmpty()) "" else JSONObject(m).toString()
}
