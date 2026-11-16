package com.void.homeos.data

import java.text.NumberFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlin.math.abs
import kotlin.math.roundToInt

object Fmt {
    private val money = NumberFormat.getCurrencyInstance()
    private val money0 = NumberFormat.getCurrencyInstance().apply { maximumFractionDigits = 0 }
    fun money(v: Double, whole: Boolean = false): String = (if (whole) money0 else money).format(v)
    val currencySymbol: String get() = money.currency?.getSymbol() ?: "£"
    private val shortF = DateTimeFormatter.ofPattern("d MMM")
    private val longF = DateTimeFormatter.ofPattern("d MMM yyyy")
    private val dayF = DateTimeFormatter.ofPattern("EEE d MMM")
    private val monthF = DateTimeFormatter.ofPattern("MMMM yyyy")
    private val timeF = DateTimeFormatter.ofPattern("HH:mm")
    fun short(d: LocalDate?) = d?.let { if (it.year == Dates.today.year) shortF.format(it) else longF.format(it) } ?: ""
    fun long(d: LocalDate?) = d?.let { longF.format(it) } ?: ""
    fun day(d: LocalDate) = when (d) { Dates.today -> "Today"; Dates.today.plusDays(1) -> "Tomorrow"; Dates.today.minusDays(1) -> "Yesterday"; else -> dayF.format(d) }
    fun month(d: LocalDate) = monthF.format(d)
    fun time(t: LocalDateTime?) = t?.let { timeF.format(it) } ?: ""
    fun num(v: Double) = if (v == v.roundToInt().toDouble()) v.roundToInt().toString() else "%.2f".format(v)
    fun m(v: Double) = "%.1f".format(v).removeSuffix(".0") + " m"
}

// ------------------------------------------------------------------ To-Do jobs

object Tasks {
    fun repeat(t: Rec) = t.s("repeatRaw").ifBlank { "Once" }
    fun timeOfDay(r: Rec) = r.s("timeOfDayRaw").takeIf { it in Enums.timeOfDay } ?: "Anytime"
    fun weekdays(t: Rec): Set<Int> = t.s("weekdaysRaw").split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
    fun completions(t: Rec) = Repo.of(T.COMPLETION).filter { it.link("task") == t.id }
    fun checklist(t: Rec) = Repo.of(T.CHECK).filter { it.link("task") == t.id }.sortedBy { it.i("order") }
    fun completion(t: Rec, day: LocalDate) = completions(t).firstOrNull { it.day("occurrenceDate") == day }

    /** Same no-pile-up rules as HomeTask.appears(on:) on iOS. */
    fun appears(t: Rec, day: LocalDate): Boolean {
        val today = Dates.today
        val startDate = t.day("startDate")
        val start = startDate ?: t.day("createdAt") ?: today
        return when (repeat(t)) {
            "Daily" -> day >= start
            "Weekly" -> day >= start && (weekdays(t).ifEmpty { setOf(Dates.appleWeekday(start)) }).contains(Dates.appleWeekday(day))
            "Monthly" -> day >= start && day.dayOfMonth == minOf(start.dayOfMonth, day.lengthOfMonth())
            "Yearly" -> day >= start && day.monthValue == start.monthValue && day.dayOfMonth == start.dayOfMonth
            else -> when {
                t.b("isDone") -> completions(t).any { it.day("occurrenceDate") == day }
                startDate == null -> day == today
                start >= today -> day == start
                else -> day == today // not done, day passed: stays quietly on today, no lateness label
            }
        }
    }

    fun isDone(t: Rec, day: LocalDate) = if (repeat(t) == "Once") t.b("isDone") else completion(t, day) != null

    fun summary(t: Rec): String = when (repeat(t)) {
        "Daily" -> "Every day"
        "Weekly" -> {
            val names = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
            val w = weekdays(t).sorted()
            if (w.isEmpty()) "Weekly" else "Every " + w.joinToString(", ") { names[(it - 1).coerceIn(0, 6)] }
        }
        "Monthly" -> "Monthly"; "Yearly" -> "Yearly"
        else -> t.day("startDate")?.let { "Once · " + Fmt.short(it) } ?: "Once"
    }
}

object Plans {
    fun appears(p: Rec, day: LocalDate): Boolean {
        if (p.b("isPaused")) return false
        val due = p.day("nextDueDate") ?: return false
        return if (due >= Dates.today) day == due else day == Dates.today
    }
    fun logs(p: Rec) = Repo.of(T.MAINTENANCE).filter { it.link("plan") == p.id }
    fun interval(p: Rec) = "Every ${maxOf(1, p.i("intervalValue"))} ${p.s("intervalUnitRaw").ifBlank { "Months" }.lowercase().let { if (p.i("intervalValue") <= 1) it.removeSuffix("s") else it }}"
    fun target(r: Rec): String? = Repo.get(r.link("asset"))?.title ?: Repo.get(r.link("room"))?.title
    fun advance(base: LocalDate, p: Rec): LocalDate {
        val n = maxOf(1, p.i("intervalValue")).toLong()
        return when (p.s("intervalUnitRaw")) { "Days" -> base.plusDays(n); "Weeks" -> base.plusWeeks(n); "Years" -> base.plusYears(n); else -> base.plusMonths(n) }
    }

    fun markDone(p: Rec, at: LocalDateTime, note: String = "", cost: Double = 0.0, personId: String? = null) {
        Repo.save(T.MAINTENANCE, Repo.newId(), p.vis, mapOf(
            "task" to p.s("title"), "date" to Dates.ts(at), "cost" to cost, "notes" to note, "remindersEnabled" to false,
            "assetId" to p.link("asset"), "roomId" to p.link("room"), "personId" to (personId ?: p.link("person")), "planId" to p.id,
        ))
        Repo.update(p, mapOf("lastDoneDate" to Dates.ts(at), "nextDueDate" to Dates.ts(advance(at.toLocalDate(), p))))
    }
}

object Bills {
    fun frequency(b: Rec) = b.s("frequencyRaw").ifBlank { "Monthly" }
    fun next(freq: String, d: LocalDate): LocalDate? = when (freq) {
        "Weekly" -> d.plusDays(7); "Fortnightly" -> d.plusDays(14); "Every 4 weeks" -> d.plusDays(28)
        "Monthly" -> d.plusMonths(1); "Quarterly" -> d.plusMonths(3); "Yearly" -> d.plusYears(1); else -> null
    }
    fun perMonth(freq: String) = when (freq) {
        "Weekly" -> 52.0 / 12; "Fortnightly" -> 26.0 / 12; "Every 4 weeks" -> 13.0 / 12; "Monthly" -> 1.0
        "Quarterly" -> 1.0 / 3; "Yearly" -> 1.0 / 12; else -> 0.0
    }
    /** The only thing in the app that can ever be overdue. */
    fun isOverdue(b: Rec): Boolean = !b.b("isSettled") && (b.day("nextDueDate")?.let { it < Dates.today } ?: false)
    fun payments(b: Rec) = Repo.of(T.PAYMENT).filter { it.link("bill") == b.id }.sortedByDescending { it.t("paidDate") }
    fun monthly(b: Rec) = if (b.b("isSettled")) 0.0 else b.d("amount") * perMonth(frequency(b))
    fun isShared(b: Rec) = b.vis == Vis.HOUSE
    fun contractEndingSoon(b: Rec) = b.day("contractEndDate")?.let { ChronoUnit.DAYS.between(Dates.today, it) <= 60 } ?: false

    fun shares(b: Rec, total: Double): Map<String, Double> =
        if (!isShared(b)) emptyMap() else Split.shares(total, b.s("splitModeRaw"), SplitJSON.amounts(b.s("customSharesJSON")))

    fun myMonthly(b: Rec): Double = if (!isShared(b) || Repo.members.size < 2) monthly(b) else shares(b, monthly(b))[Repo.uid] ?: 0.0
    fun myAmount(p: Rec): Double { val s = SplitJSON.amounts(p.s("sharesJSON")); return if (p.s("sharesJSON").isBlank()) p.d("amount") else s[Repo.uid] ?: 0.0 }

    /** "I paid this": records a payment with the split fixed now, and moves the due date on. */
    fun markPaid(b: Rec, at: LocalDateTime = LocalDateTime.now(), note: String = "", amount: Double? = null) {
        val amt = amount ?: b.d("amount")
        val due = b.day("nextDueDate") ?: Dates.today
        val shared = isShared(b) && Repo.members.size > 1
        Repo.save(T.PAYMENT, Repo.newId(), b.vis, mapOf(
            "amount" to amt, "paidDate" to Dates.ts(at), "dueDate" to Dates.ts(due), "note" to note,
            "paidByUid" to if (shared) Repo.uid.orEmpty() else "",
            "sharesJSON" to if (shared) SplitJSON.encode(shares(b, amt)) else "",
            "repaidJSON" to "", "billId" to b.id,
        ))
        val nxt = next(frequency(b), due)
        Repo.update(b, if (nxt != null) mapOf("nextDueDate" to Dates.ts(nxt)) else mapOf("isSettled" to true))
    }

    fun undo(b: Rec, p: Rec) {
        if (payments(b).firstOrNull()?.id == p.id) Repo.update(b, mapOf("nextDueDate" to Dates.ts(p.day("dueDate") ?: Dates.today), "isSettled" to false))
        Repo.delete(p)
    }
}

object Split {
    fun shares(total: Double, mode: String, custom: Map<String, Double>): Map<String, Double> {
        val members = Repo.members.map { it.uid }
        if (members.isEmpty() || total <= 0) return emptyMap()
        var weights = if (mode == "custom") members.mapNotNull { u -> custom[u]?.takeIf { it > 0 }?.let { u to it } }.toMap() else emptyMap()
        if (weights.isEmpty()) weights = members.associateWith { 1.0 }
        val sum = weights.values.sum()
        return members.associateWith { ((total * (weights[it] ?: 0.0) / sum) * 100).roundToInt() / 100.0 }
    }

    data class Owed(val record: Rec, val from: String, val to: String, val amount: Double)
    data class Net(val from: String, val to: String, val amount: Double, val items: List<Owed>)

    fun outstanding(r: Rec): List<Owed> {
        val payer = r.s("paidByUid"); if (payer.isBlank()) return emptyList()
        val repaid = SplitJSON.strings(r.s("repaidJSON"))
        return SplitJSON.amounts(r.s("sharesJSON")).mapNotNull { (u, a) -> if (u == payer || repaid.containsKey(u) || a <= 0.004) null else Owed(r, u, payer, a) }
    }

    fun allOutstanding(): List<Owed> {
        val pays = Repo.of(T.PAYMENT).filter { Repo.get(it.link("bill"))?.vis == Vis.HOUSE }
        val spends = Repo.of(T.SPEND).filter { it.vis == Vis.HOUSE }
        return (pays + spends).flatMap { outstanding(it) }
    }

    fun net(shares: List<Owed>): List<Net> {
        data class E(val a: String, val b: String, var aOwesB: Double, val items: MutableList<Owed>)
        val pairs = LinkedHashMap<String, E>()
        for (s in shares) {
            val (a, b) = if (s.from < s.to) s.from to s.to else s.to to s.from
            val e = pairs.getOrPut("$a|$b") { E(a, b, 0.0, mutableListOf()) }
            e.aOwesB += if (s.from == a) s.amount else -s.amount
            e.items += s
        }
        return pairs.values.mapNotNull { e ->
            val r = (abs(e.aOwesB) * 100).roundToInt() / 100.0
            if (r < 0.01) null else if (e.aOwesB > 0) Net(e.a, e.b, r, e.items) else Net(e.b, e.a, r, e.items)
        }.sortedByDescending { it.amount }
    }

    fun setRepaid(r: Rec, uid: String, repaid: Boolean) {
        val m: MutableMap<String, Any> = SplitJSON.strings(r.s("repaidJSON")).toMutableMap()
        if (repaid) m[uid] = Instant.now().toString() else m.remove(uid)
        Repo.update(r, mapOf("repaidJSON" to SplitJSON.encode(m)))
    }
}

object Warranties {
    fun days(w: Rec) = w.day("expiryDate")?.let { ChronoUnit.DAYS.between(Dates.today, it) }
    fun status(w: Rec): String { val d = days(w) ?: return "Active"; return if (d < 0) "Expired" else if (d <= 60) "Ending soon" else "Active" }
    fun remaining(w: Rec): Float {
        val s = w.day("startDate") ?: return 0f; val e = w.day("expiryDate") ?: return 0f
        val total = ChronoUnit.DAYS.between(s, e).toFloat(); if (total <= 0) return 0f
        return (ChronoUnit.DAYS.between(Dates.today, e) / total).coerceIn(0f, 1f)
    }
}

// ------------------------------------------------------------------ To-Do feed

enum class Src { TASK, BILL, PLAN, WARRANTY, DOCUMENT }

data class TodoItem(
    val id: String, val src: Src, val rec: Rec, val title: String, val subtitle: String?, val timeOfDay: String,
    val origin: String?, val isDone: Boolean, val isOverdue: Boolean, val isInfo: Boolean, val assigneeId: String?,
)

data class HistoryEntry(val id: String, val at: LocalDateTime, val title: String, val detail: String?, val origin: String?, val personId: String?, val note: String, val by: String?)

object TodoFeed {
    fun items(day: LocalDate): List<TodoItem> {
        val today = Dates.today
        val out = mutableListOf<TodoItem>()
        for (t in Repo.of(T.TASK)) {
            if (!Tasks.appears(t, day)) continue
            val sub = mutableListOf<String>()
            Repo.get(t.link("project"))?.let { sub += it.title }
            Repo.get(t.link("room"))?.let { sub += it.title }
            Repo.get(t.link("asset"))?.let { sub += it.title }
            if (Tasks.repeat(t) != "Once") sub += Tasks.summary(t)
            val cl = Tasks.checklist(t)
            if (cl.isNotEmpty()) sub += "${cl.count { it.day("checkedOn") == day }}/${cl.size}"
            out += TodoItem("task-${t.id}", Src.TASK, t, t.title, sub.joinToString(" · ").ifBlank { null }, Tasks.timeOfDay(t),
                if (t.link("project") != null) "Project" else null, Tasks.isDone(t, day), false, false, t.link("assignee"))
        }
        for (b in Repo.of(T.BILL)) {
            val amount = if (b.d("amount") > 0) (if (b.b("isEstimate")) "about " else "") + Fmt.money(b.d("amount")) else null
            val detail = listOfNotNull(amount, b.s("paymentMethod").ifBlank { null }).joinToString(" · ")
            val paid = Bills.payments(b).firstOrNull { it.day("paidDate") == day }
            if (paid != null) {
                out += TodoItem("bill-paid-${paid.id}", Src.BILL, b, "Pay ${b.title}", "Paid ${Fmt.money(paid.d("amount"))}", "Anytime", "Bill", true, false, false, null)
                continue
            }
            if (b.b("isSettled")) continue
            val due = b.day("nextDueDate") ?: continue
            if (!(due == day || (due < today && day == today))) continue
            out += TodoItem("bill-${b.id}", Src.BILL, b, "Pay ${b.title}", detail.ifBlank { null }, "Anytime", "Bill", false, Bills.isOverdue(b), false, null)
        }
        for (p in Repo.of(T.PLAN)) {
            val log = Plans.logs(p).firstOrNull { it.day("date") == day }
            if (log != null) {
                out += TodoItem("plan-done-${log.id}", Src.PLAN, p, p.title, Plans.target(p), Tasks.timeOfDay(p), "Maintenance", true, false, false, log.link("person"))
                continue
            }
            if (!Plans.appears(p, day)) continue
            out += TodoItem("plan-${p.id}", Src.PLAN, p, p.title, listOfNotNull(Plans.target(p), Plans.interval(p)).joinToString(" · "),
                Tasks.timeOfDay(p), "Maintenance", false, false, false, p.link("person"))
        }
        for (w in Repo.of(T.WARRANTY)) {
            val exp = w.day("expiryDate") ?: continue
            if (day != exp && day != exp.minusDays(30)) continue
            val name = Repo.get(w.link("asset"))?.title ?: w.s("provider")
            out += TodoItem("warranty-${w.id}", Src.WARRANTY, w, if (day == exp) "$name warranty ends today" else "$name warranty ends in 30 days",
                if (w.s("claimContact").isBlank()) w.s("provider") else "Claims: ${w.s("claimContact")}", "Anytime", "Warranty", false, false, true, null)
        }
        for (d in Repo.of(T.DOCUMENT)) {
            val exp = d.day("expiryDate") ?: continue
            if (day != exp && day != exp.minusDays(30)) continue
            out += TodoItem("doc-${d.id}", Src.DOCUMENT, d, if (day == exp) "${d.title} expires today" else "${d.title} expires in 30 days",
                d.s("type"), "Anytime", "Document", false, false, true, null)
        }
        return out.sortedWith(compareBy<TodoItem> { it.isDone }.thenBy { !it.isOverdue }.thenBy { it.title.lowercase() })
    }

    fun complete(item: TodoItem, day: LocalDate, note: String = "", personId: String? = null, photo: String? = null) {
        val at = if (day == Dates.today) LocalDateTime.now() else day.atTime(12, 0)
        when (item.src) {
            Src.TASK -> {
                val t = item.rec
                val id = Repo.save(T.COMPLETION, Repo.newId(), t.vis, mapOf(
                    "occurrenceDate" to Dates.ts(day), "completedAt" to Dates.ts(at), "note" to note, "photoFileName" to photo,
                    "completedByUid" to Repo.uid.orEmpty(), "personId" to (personId ?: t.link("assignee")), "taskId" to t.id,
                ))
                if (photo != null) Repo.get(id)?.let { Repo.upload(it, photo) }
                if (Tasks.repeat(t) == "Once") Repo.update(t, mapOf("isDone" to true))
            }
            Src.BILL -> Bills.markPaid(item.rec, at, note)
            Src.PLAN -> Plans.markDone(item.rec, at, note, personId = personId)
            else -> {}
        }
    }

    fun uncomplete(item: TodoItem, day: LocalDate) {
        when (item.src) {
            Src.TASK -> {
                val t = item.rec
                val cs = if (Tasks.repeat(t) == "Once") Tasks.completions(t) else Tasks.completions(t).filter { it.day("occurrenceDate") == day }
                cs.forEach { Repo.delete(it) }
                if (Tasks.repeat(t) == "Once") Repo.update(t, mapOf("isDone" to false))
            }
            Src.BILL -> Bills.payments(item.rec).firstOrNull { it.day("paidDate") == day }?.let { Bills.undo(item.rec, it) }
            Src.PLAN -> {
                val p = item.rec
                val log = Plans.logs(p).firstOrNull { it.day("date") == day } ?: return
                val rest = Plans.logs(p).filter { it.id != log.id }.mapNotNull { it.t("date") }.maxOrNull()
                Repo.update(p, mapOf("nextDueDate" to Dates.ts(log.day("date")!!), "lastDoneDate" to rest?.let { Dates.ts(it) }))
                Repo.delete(log)
            }
            else -> {}
        }
    }

    fun history(): List<HistoryEntry> {
        val out = mutableListOf<HistoryEntry>()
        for (c in Repo.of(T.COMPLETION)) {
            val t = Repo.get(c.link("task")) ?: continue
            out += HistoryEntry("c-${c.id}", c.t("completedAt") ?: continue, t.title, Repo.get(t.link("project"))?.title ?: Repo.get(t.link("room"))?.title,
                if (t.link("project") != null) "Project" else null, c.link("person"), c.s("note"), c.s("completedByUid").ifBlank { null })
        }
        for (p in Repo.of(T.PAYMENT)) {
            val b = Repo.get(p.link("bill")) ?: continue
            out += HistoryEntry("p-${p.id}", p.t("paidDate") ?: continue, "Paid ${b.title}", Fmt.money(p.d("amount")), "Bill", null, p.s("note"), p.s("paidByUid").ifBlank { null })
        }
        for (m in Repo.of(T.MAINTENANCE)) {
            if (m.link("plan") == null) continue
            out += HistoryEntry("m-${m.id}", m.t("date") ?: continue, m.s("task"), Plans.target(m), "Maintenance", m.link("person"), m.s("notes"), null)
        }
        return out.sortedByDescending { it.at }
    }
}

// ------------------------------------------------------------------ Timeline

data class TimelineRow(val id: String, val date: LocalDate, val kind: String, val title: String, val detail: String?, val rec: Rec, val overdue: Boolean = false, val calm: String? = null)

object Timeline {
    val filters = listOf("All", "Bills", "To-Do", "Maintenance", "Warranties", "Projects", "Assets", "Documents")

    fun build(): Pair<List<TimelineRow>, List<TimelineRow>> {
        val today = Dates.today; val horizon = today.plusDays(60)
        val past = mutableListOf<TimelineRow>(); val next = mutableListOf<TimelineRow>()
        for (a in Repo.of(T.ASSET)) a.day("purchaseDate")?.let { if (it <= today) past += TimelineRow("ab" + a.id, it, "Assets", "Bought ${a.title}", a.s("purchasePrice").let { _ -> if (a.d("purchasePrice") > 0) Fmt.money(a.d("purchasePrice")) else null }, a) }
        for (p in Repo.of(T.PROJECT)) {
            p.day("startDate")?.let { (if (it <= today) past else next) += TimelineRow("ps" + p.id, it, "Projects", "${p.title} started", null, p) }
            p.day("endDate")?.let { (if (it <= today) past else next) += TimelineRow("pe" + p.id, it, "Projects", "${p.title} finished", null, p) }
        }
        for (m in Repo.of(T.MAINTENANCE)) {
            val d = m.day("date") ?: continue
            if (d <= today) past += TimelineRow("m" + m.id, d, "Maintenance", m.s("task"), listOfNotNull(Plans.target(m), if (m.d("cost") > 0) Fmt.money(m.d("cost")) else null, Repo.get(m.link("person"))?.title).joinToString(" · ").ifBlank { null }, m)
            else if (d <= horizon) next += TimelineRow("m" + m.id, d, "Maintenance", m.s("task"), Plans.target(m), m)
        }
        for (w in Repo.of(T.WARRANTY)) {
            val name = Repo.get(w.link("asset"))?.title ?: w.s("provider")
            w.day("startDate")?.let { if (it <= today) past += TimelineRow("ws" + w.id, it, "Warranties", "$name warranty started", w.s("provider"), w) }
            w.day("expiryDate")?.let { if (it <= today) past += TimelineRow("we" + w.id, it, "Warranties", "$name warranty ended", w.s("provider"), w) else if (it <= horizon) next += TimelineRow("we" + w.id, it, "Warranties", "$name warranty ends", w.s("provider"), w) }
        }
        for (d in Repo.of(T.DOCUMENT)) {
            d.day("createdAt")?.let { past += TimelineRow("da" + d.id, it, "Documents", "Added ${d.title}", d.s("type"), d) }
            d.day("expiryDate")?.let { if (it <= today) past += TimelineRow("de" + d.id, it, "Documents", "${d.title} expired", d.s("type"), d) else if (it <= horizon) next += TimelineRow("de" + d.id, it, "Documents", "${d.title} expires", d.s("type"), d) }
        }
        for (p in Repo.of(T.PAYMENT)) {
            val b = Repo.get(p.link("bill")) ?: continue
            p.day("paidDate")?.let { past += TimelineRow("bp" + p.id, it, "Bills", "Paid ${b.title}", Fmt.money(p.d("amount")) + (p.s("paidByUid").takeIf { u -> u.isNotBlank() }?.let { u -> " · " + Repo.memberName(u) } ?: ""), p) }
        }
        for (c in Repo.of(T.COMPLETION)) {
            val t = Repo.get(c.link("task")) ?: continue
            val who = Repo.get(c.link("person"))?.title ?: c.s("completedByUid").takeIf { it.isNotBlank() }?.let { Repo.memberName(it) }
            c.day("completedAt")?.let { past += TimelineRow("tc" + c.id, it, "To-Do", t.title, listOfNotNull(who, c.s("note").ifBlank { null }).joinToString(" · ").ifBlank { null }, t) }
        }
        for (b in Repo.of(T.BILL)) {
            if (b.b("isSettled")) continue
            val due = b.day("nextDueDate") ?: continue
            if (Bills.isOverdue(b)) next += TimelineRow("bd" + b.id, today, "Bills", b.title, "Overdue · was due ${Fmt.short(due)}", b, overdue = true)
            else if (due <= horizon) next += TimelineRow("bd" + b.id, due, "Bills", b.title, Fmt.money(b.d("amount")), b)
        }
        for (p in Repo.of(T.PLAN)) {
            if (p.b("isPaused")) continue
            val due = p.day("nextDueDate") ?: continue
            if (due < today) next += TimelineRow("pl" + p.id, today, "Maintenance", p.title, Plans.target(p), p, calm = "Whenever suits")
            else if (due <= horizon) next += TimelineRow("pl" + p.id, due, "Maintenance", p.title, listOfNotNull(Plans.target(p), Plans.interval(p)).joinToString(" · "), p)
        }
        for (t in Repo.of(T.TASK)) {
            val d = (0..60L).map { today.plusDays(it) }.firstOrNull { Tasks.appears(t, it) && !Tasks.isDone(t, it) } ?: continue
            next += TimelineRow("tn" + t.id, d, "To-Do", t.title, Tasks.summary(t), t)
        }
        return next.sortedWith(compareBy<TimelineRow> { !it.overdue }.thenBy { it.date }) to past.sortedByDescending { it.date }
    }
}

// ------------------------------------------------------------------ Search

data class Hit(val rec: Rec, val group: String, val title: String, val snippet: String?, val label: String?, val titleMatch: Boolean)

object Search {
    private val groups = linkedMapOf(
        T.ROOM to "Rooms", T.ASSET to "Assets", T.DOCUMENT to "Documents", T.WARRANTY to "Warranties", T.PLAN to "Maintenance",
        T.MAINTENANCE to "Maintenance", T.PROJECT to "Projects", T.BILL to "Bills", T.TASK to "To-Do", T.PERSON to "People",
    )

    private fun fields(r: Rec): List<Pair<String, String>> = when (r.type) {
        T.ROOM -> listOf("Floor" to r.s("floor")) + Repo.of(T.ROOM_PART).filter { it.link("room") == r.id }.map { "Piece" to it.title }
        T.ASSET -> listOf("Category" to r.s("category"), "Make" to r.s("manufacturer"), "Model" to r.s("model"), "Serial number" to r.s("serialNumber"), "Note" to r.s("notes"))
        T.DOCUMENT -> listOf("Type" to r.s("type"), "Scanned text" to r.s("ocrText"))
        T.WARRANTY -> listOf("Asset" to (Repo.get(r.link("asset"))?.title ?: ""), "Claim contact" to r.s("claimContact"), "Note" to r.s("notes"))
        T.PLAN -> listOf("Note" to r.s("notes"), "Item" to (Plans.target(r) ?: ""))
        T.MAINTENANCE -> listOf("Note" to r.s("notes"), "Item" to (Plans.target(r) ?: ""))
        T.PROJECT -> listOf("Description" to r.s("projectDescription"), "Note" to r.s("notes"))
        T.BILL -> listOf("Provider" to (Repo.get(r.link("provider"))?.title ?: ""), "Category" to r.s("categoryRaw"), "Payment method" to r.s("paymentMethod"), "Note" to r.s("notes"))
        T.TASK -> listOf("Note" to r.s("notes"), "Assigned to" to (Repo.get(r.link("assignee"))?.title ?: ""),
            "Linked" to listOfNotNull(Repo.get(r.link("project"))?.title, Repo.get(r.link("room"))?.title, Repo.get(r.link("asset"))?.title).joinToString(" ")) +
            Tasks.checklist(r).map { "Checklist" to it.title } + Tasks.completions(r).map { "Completion note" to it.s("note") }
        T.PERSON -> listOf("Company" to r.s("company"), "Role" to r.s("role"), "Email" to r.s("email"), "Phone" to r.s("phoneNumber"), "Note" to r.s("notes"))
        else -> emptyList()
    }

    fun run(q: String): Map<String, List<Hit>> {
        val query = q.trim(); if (query.isEmpty()) return emptyMap()
        val hits = mutableListOf<Hit>()
        for (r in Repo.all.values) {
            val group = groups[r.type] ?: continue
            if (r.type == T.MAINTENANCE && r.link("plan") != null && false) continue
            val title = r.title
            if (title.contains(query, true)) { hits += Hit(r, group, title, null, null, true); continue }
            val f = fields(r).firstOrNull { it.second.contains(query, true) } ?: continue
            hits += Hit(r, group, title, snippet(f.second, query), f.first, false)
        }
        return hits.groupBy { it.group }.mapValues { (_, v) -> v.sortedWith(compareBy<Hit> { !it.titleMatch }.thenBy { it.title.lowercase() }) }
            .toList().sortedBy { groups.values.indexOf(it.first) }.toMap()
    }

    private fun snippet(text: String, q: String): String {
        val i = text.indexOf(q, ignoreCase = true).coerceAtLeast(0)
        val s = (i - 40).coerceAtLeast(0); val e = (i + q.length + 60).coerceAtMost(text.length)
        return (if (s > 0) "…" else "") + text.substring(s, e).replace('\n', ' ') + (if (e < text.length) "…" else "")
    }
}

// ------------------------------------------------------------------ Floor plan geometry (FloorplanGeometry on iOS)

data class R(val x: Double, val y: Double, val w: Double, val h: Double) {
    val minX get() = x; val minY get() = y; val maxX get() = x + w; val maxY get() = y + h
    fun union(o: R): R { val a = minOf(minX, o.minX); val b = minOf(minY, o.minY); return R(a, b, maxOf(maxX, o.maxX) - a, maxOf(maxY, o.maxY) - b) }
    fun contains(px: Double, py: Double) = px in minX..maxX && py in minY..maxY
}

object Plan {
    const val DOOR_WIDTH = 0.8

    fun quarterTurns(deg: Double): Int { val n = ((deg % 360) + 360) % 360; return (n / 90).roundToInt() % 4 }
    fun rotate(x: Double, y: Double, q: Int): Pair<Double, Double> = when (q) { 1 -> -y to x; 2 -> -x to -y; 3 -> y to -x; else -> x to y }

    fun parts(room: Rec) = Repo.of(T.ROOM_PART).filter { it.link("room") == room.id }.sortedBy { it.t("createdAt") }
    fun doors(room: Rec) = Repo.of(T.DOOR).filter { it.link("room") == room.id }
    fun width(room: Rec) = room.d("width").takeIf { it > 0 } ?: 3.0
    fun height(room: Rec) = room.d("height").takeIf { it > 0 } ?: 3.0
    fun center(room: Rec) = (room.dn("planX") ?: 0.0) to (room.dn("planY") ?: 0.0)

    fun localRects(room: Rec): List<R> = listOf(R(-width(room) / 2, -height(room) / 2, width(room), height(room))) +
        parts(room).map { R(it.d("xOffset") - it.d("width") / 2, it.d("yOffset") - it.d("height") / 2, it.d("width"), it.d("height")) }

    fun worldRect(l: R, cx: Double, cy: Double, q: Int): R {
        val a = rotate(l.minX, l.minY, q); val b = rotate(l.maxX, l.maxY, q)
        return R(minOf(a.first, b.first) + cx, minOf(a.second, b.second) + cy, abs(a.first - b.first), abs(a.second - b.second))
    }

    fun worldRects(room: Rec, c: Pair<Double, Double> = center(room)): List<R> {
        val q = quarterTurns(room.d("rotation")); return localRects(room).map { worldRect(it, c.first, c.second, q) }
    }

    fun bounds(rs: List<R>): R? = rs.reduceOrNull { a, b -> a.union(b) }

    fun unionArea(rects: List<R>): Double {
        val xs = rects.flatMap { listOf(it.minX, it.maxX) }.distinct().sorted()
        if (xs.size < 2) return 0.0
        var total = 0.0
        for (i in 0 until xs.size - 1) {
            val x0 = xs[i]; val x1 = xs[i + 1]
            val spans = rects.filter { it.minX <= x0 && it.maxX >= x1 }.map { it.minY to it.maxY }.sortedBy { it.first }
            var covered = 0.0; var cur: Pair<Double, Double>? = null
            for (s in spans) {
                val c = cur
                if (c != null && s.first <= c.second) cur = c.first to maxOf(c.second, s.second)
                else { if (c != null) covered += c.second - c.first; cur = s }
            }
            cur?.let { covered += it.second - it.first }
            total += covered * (x1 - x0)
        }
        return total
    }

    fun area(room: Rec) = unionArea(localRects(room))

    fun overlaps(a: List<R>, b: List<R>, tol: Double = 0.02): Boolean = a.any { r -> b.any { o ->
        minOf(r.maxX, o.maxX) - maxOf(r.minX, o.minX) > tol && minOf(r.maxY, o.maxY) - maxOf(r.minY, o.minY) > tol } }

    /** Free spot for a new room near `pref`, same search as iOS freeCenter. */
    fun freeCenter(pref: Pair<Double, Double>, local: List<R>, q: Int, obstacles: List<List<R>>, gap: Double = 0.5): Pair<Double, Double> {
        val padded = obstacles.map { o -> o.map { R(it.x - gap, it.y - gap, it.w + 2 * gap, it.h + 2 * gap) } }
        fun fits(c: Pair<Double, Double>) = local.map { worldRect(it, c.first, c.second, q) }.let { rs -> padded.none { overlaps(rs, it, 0.0) } }
        if (fits(pref)) return pref
        for (ring in 1..80) {
            val cands = mutableListOf<Pair<Double, Double>>()
            for (i in -ring..ring) {
                cands += (pref.first + i * 0.5) to (pref.second - ring * 0.5); cands += (pref.first + i * 0.5) to (pref.second + ring * 0.5)
                cands += (pref.first - ring * 0.5) to (pref.second + i * 0.5); cands += (pref.first + ring * 0.5) to (pref.second + i * 0.5)
            }
            cands.sortedBy { Math.hypot(it.first - pref.first, it.second - pref.second) }.firstOrNull { fits(it) }?.let { return it }
        }
        return pref
    }

    /** The local rect a door sits on: its piece if it has one, else the main rectangle. */
    fun hostRect(door: Rec, room: Rec): R {
        val part = parts(room).firstOrNull { it.id == door.link("part") }
        return if (part != null) R(part.d("xOffset") - part.d("width") / 2, part.d("yOffset") - part.d("height") / 2, part.d("width"), part.d("height"))
        else R(-width(room) / 2, -height(room) / 2, width(room), height(room))
    }

    fun dimensions(w: Double, h: Double) = "${w}m x ${h}m"
}

/** Records linked to `id` from any other record (the two-way "Linked" sections). */
fun backlinks(id: String): List<Rec> = Repo.all.values.filter { r ->
    r.id != id && r.data.any { (k, v) -> (k.endsWith("Id") && v == id) || (k.endsWith("Ids") && v is List<*> && v.contains(id)) }
}
