package com.voidhome.app.data

import com.google.firebase.Timestamp
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Date

/** Record types, exactly as in AI_CONTEXT.md section 15.3. */
object T {
    const val HOME = "home"; const val FLOOR = "floor"; const val ROOM = "room"; const val ROOM_PART = "roomPart"
    const val DOOR = "door"; const val PERSON = "person"; const val ASSET = "asset"; const val PROJECT = "project"
    const val WARRANTY = "warranty"; const val PLAN = "maintenancePlan"; const val MAINTENANCE = "maintenance"
    const val BILL = "bill"; const val PAYMENT = "billPayment"; const val TASK = "task"; const val CHECK = "checklistItem"
    const val COMPLETION = "taskCompletion"; const val DOCUMENT = "document"; const val PHOTO = "projectPhoto"
    const val SPEND = "projectSpend"

    /** Types that always live in the shared `items` collection. */
    val ALWAYS = setOf(HOME, FLOOR, ROOM, ROOM_PART, DOOR)
    /** Types with their own Just me / Everyone choice. */
    val OWN = setOf(PERSON, ASSET, PROJECT, BILL, TASK, DOCUMENT)
}

object Vis { const val HOUSE = "house"; const val ME = "me" }

/** Enum raw strings shared with iOS. */
object Enums {
    val billFrequency = listOf("Weekly", "Fortnightly", "Every 4 weeks", "Monthly", "Quarterly", "Yearly", "One-off")
    val billCategory = listOf("Energy", "Water", "Council Tax", "Broadband", "Phone", "Insurance", "Mortgage / Rent", "Subscription", "TV Licence", "Other")
    val documentType = listOf("Manual", "Receipt", "Invoice", "Certificate", "Guarantee", "Other")
    val doorEdge = listOf("Top", "Bottom", "Left", "Right")
    val timeOfDay = listOf("Morning", "Afternoon", "Evening", "Anytime")
    val taskRepeat = listOf("Once", "Daily", "Weekly", "Monthly", "Yearly")
    val intervalUnit = listOf("Days", "Weeks", "Months", "Years")
    val personKind = listOf("Household", "Tradesperson", "Provider")
    val projectStatus = listOf("Planned", "In Progress", "Completed", "On Hold")
    val assetCategory = listOf("Appliance", "Electronics", "Furniture", "Heating", "Plumbing", "Garden", "Vehicle", "Tools", "Other")
}

/** One Firestore record document (the envelope plus its `data`). */
data class Rec(
    val id: String,
    val type: String,
    val vis: String,
    val createdBy: String,
    val updatedBy: String,
    val data: Map<String, Any?>,
) {
    fun s(k: String): String = data[k] as? String ?: ""
    fun d(k: String): Double = (data[k] as? Number)?.toDouble() ?: 0.0
    fun dn(k: String): Double? = (data[k] as? Number)?.toDouble()
    fun i(k: String): Int = (data[k] as? Number)?.toInt() ?: 0
    fun b(k: String): Boolean = data[k] as? Boolean ?: false
    fun t(k: String): LocalDateTime? = Dates.toLocal(data[k])
    fun day(k: String): LocalDate? = t(k)?.toLocalDate()
    fun link(k: String): String? = (data[k + "Id"] as? String)?.takeIf { it.isNotBlank() }
    fun links(k: String): List<String> = (data[k + "Ids"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
    val isPrivate get() = vis == Vis.ME

    /** Display name for any record. */
    val title: String
        get() = when (type) {
            T.PROJECT, T.TASK, T.DOCUMENT, T.PLAN, T.CHECK -> s("title")
            T.WARRANTY -> s("provider").ifBlank { "Warranty" }
            T.MAINTENANCE -> s("task")
            T.PAYMENT -> "Payment"
            T.SPEND -> s("note").ifBlank { "Spending" }
            T.PHOTO -> s("caption").ifBlank { "Photo" }
            T.DOOR -> "Door"
            else -> s("name")
        }.ifBlank { "Untitled" }
}

object Dates {
    val zone: ZoneId get() = ZoneId.systemDefault()

    fun toLocal(v: Any?): LocalDateTime? = when (v) {
        is Timestamp -> LocalDateTime.ofInstant(v.toDate().toInstant(), zone)
        is Date -> LocalDateTime.ofInstant(v.toInstant(), zone)
        is Number -> LocalDateTime.ofInstant(Instant.ofEpochMilli((v.toDouble() * 1000).toLong()), zone)
        is String -> runCatching { LocalDateTime.ofInstant(Instant.parse(v), zone) }.getOrNull()
        else -> null
    }

    fun ts(dt: LocalDateTime): Timestamp = Timestamp(Date.from(dt.atZone(zone).toInstant()))
    fun ts(d: LocalDate): Timestamp = ts(d.atStartOfDay())
    fun tsOrNull(d: LocalDate?): Timestamp? = d?.let { ts(it) }
    fun now(): Timestamp = Timestamp.now()
    val today: LocalDate get() = LocalDate.now()

    /** iOS Calendar weekday: 1 = Sunday ... 7 = Saturday. */
    fun appleWeekday(d: LocalDate): Int = d.dayOfWeek.value % 7 + 1
}
