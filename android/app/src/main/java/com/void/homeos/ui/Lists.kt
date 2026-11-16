package com.void.homeos.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.void.homeos.data.*

@Composable
fun ListScreen(type: String) {
    when (type) {
        T.ASSET -> AssetsList()
        T.DOCUMENT -> DocumentsList()
        T.WARRANTY -> WarrantiesList()
        T.PLAN -> MaintenanceList()
        T.PROJECT -> ProjectsList()
        T.PERSON -> PeopleList()
        else -> AssetsList()
    }
}

fun privacy(r: Rec): String? = if (r.isPrivate) "Just me" else null

@Composable
fun AssetsList() {
    var q by remember { mutableStateOf("") }
    val assets = Repo.of(T.ASSET).filter { q.isBlank() || it.title.contains(q, true) || it.s("category").contains(q, true) }.sortedBy { it.title.lowercase() }
    Page("Assets", Nav::back, P.assets, fab = { AddFab("Add asset", P.assets) { Nav.edit(T.ASSET) } }) {
        item { OutlinedTextField(q, { q = it }, label = { Text("Filter") }, singleLine = true, modifier = Modifier.fillMaxWidth()) }
        if (assets.isEmpty()) item { Empty("No assets yet.") }
        items(assets, key = { it.id }) { a ->
            val w = Repo.of(T.WARRANTY).filter { it.link("asset") == a.id }.minByOrNull { Warranties.days(it) ?: Long.MAX_VALUE }
            AssetCard(a, w)
        }
    }
}

@Composable
fun AssetCard(a: Rec, w: Rec?) {
    Glass(tint = P.assets, onClick = { Nav.open(a.id) }) {
        Row {
            LocalImage(a, a.s("photoFileName"), Modifier.size(64.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(a.title, fontSize = 17.sp)
                Text(listOfNotNull(a.s("category").ifBlank { null }, Repo.get(a.link("room"))?.title, privacy(a)).joinToString(" · "), color = P.muted, fontSize = 13.sp)
                if (a.d("purchasePrice") > 0) Text(Fmt.money(a.d("purchasePrice")), color = P.muted, fontSize = 13.sp)
            }
            if (w != null) {
                val st = Warranties.status(w)
                Pill(st, when (st) { "Expired" -> P.faint; "Ending soon" -> P.amber; else -> P.done })
            }
        }
    }
}

@Composable
fun DocumentsList() {
    var folder by remember { mutableStateOf<String?>(null) }
    val docs = Repo.of(T.DOCUMENT)
    val colors = mapOf("Manual" to P.calm, "Receipt" to P.bills, "Invoice" to P.amber, "Certificate" to P.documents, "Guarantee" to P.warranties, "Other" to P.muted)
    Page(folder ?: "Documents", { if (folder != null) folder = null else Nav.back() }, P.documents,
        fab = { AddFab("Add document", P.documents) { Nav.edit(T.DOCUMENT, prefill = folder?.let { mapOf("type" to it) } ?: emptyMap()) } }) {
        if (folder == null) {
            items(Enums.documentType) { t ->
                val n = docs.count { it.s("type").ifBlank { "Other" } == t }
                ItemRow(t + "s".takeIf { t != "Other" }.orEmpty(), "$n", colors[t] ?: P.documents, Icons.Filled.Folder) { folder = t }
            }
            val expiring = docs.filter { d -> d.day("expiryDate")?.let { it <= Dates.today.plusDays(60) } ?: false }.sortedBy { it.day("expiryDate") }
            if (expiring.isNotEmpty()) {
                item { SectionTitle("Expiring") }
                items(expiring, key = { "e" + it.id }) { d -> ItemRow(d.title, "Expires ${Fmt.short(d.day("expiryDate"))}", P.documents, Icons.Filled.Description) { Nav.open(d.id) } }
            }
        } else {
            val list = docs.filter { it.s("type").ifBlank { "Other" } == folder }.sortedByDescending { it.t("createdAt") }
            if (list.isEmpty()) item { Empty("Nothing in this folder.") }
            items(list, key = { it.id }) { d ->
                ItemRow(d.title, listOfNotNull(Fmt.short(d.day("createdAt")), d.day("expiryDate")?.let { "expires " + Fmt.short(it) }, privacy(d), if (d.s("fileURL").isBlank()) "no file" else null).joinToString(" · "),
                    colors[folder] ?: P.documents, Icons.Filled.Description) { Nav.open(d.id) }
            }
        }
    }
}

@Composable
fun WarrantiesList() {
    val all = Repo.of(T.WARRANTY).sortedBy { it.day("expiryDate") }
    Page("Warranties", Nav::back, P.warranties, fab = { AddFab("Add warranty", P.warranties) { Nav.edit(T.WARRANTY) } }) {
        if (all.isEmpty()) item { Empty("No warranties yet.") }
        for (g in listOf("Ending soon", "Active", "Expired")) {
            val list = all.filter { Warranties.status(it) == g }
            if (list.isEmpty()) continue
            item(key = g) { SectionTitle(g) }
            items(list, key = { it.id }) { w -> WarrantyCard(w) }
        }
    }
}

@Composable
fun WarrantyCard(w: Rec) {
    val st = Warranties.status(w); val d = Warranties.days(w) ?: 0
    val c = when (st) { "Expired" -> P.faint; "Ending soon" -> P.amber; else -> P.done }
    Glass(tint = P.warranties, onClick = { Nav.open(w.id) }) {
        Row {
            Icon(Icons.Filled.Shield, null, tint = c, modifier = Modifier.size(34.dp)); Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(Repo.get(w.link("asset"))?.title ?: w.s("provider"), fontSize = 17.sp)
                Text(w.s("provider") + " · ends " + Fmt.short(w.day("expiryDate")), color = P.muted, fontSize = 13.sp)
            }
            Text(if (d < 0) "Ended" else "$d days", color = c)
        }
        Spacer(Modifier.height(8.dp)); Bar(Warranties.remaining(w), c)
    }
}

@Composable
fun MaintenanceList() {
    var tab by remember { mutableIntStateOf(0) }
    Page("Maintenance", Nav::back, P.maintenance,
        fab = { AddFab(if (tab == 1) "Log work" else "Add plan", P.maintenance) { Nav.edit(if (tab == 1) T.MAINTENANCE else T.PLAN) } },
        header = { TabRow(tab, containerColor = Color.Transparent) { listOf("Plans", "Log", "By item").forEachIndexed { i, t -> Tab(tab == i, { tab = i }, text = { Text(t) }) } } }) {
        when (tab) {
            0 -> {
                val plans = Repo.of(T.PLAN).sortedBy { it.day("nextDueDate") }
                if (plans.isEmpty()) item { Empty("No repeating jobs yet.") }
                items(plans, key = { it.id }) { p -> PlanRow(p) }
            }
            1 -> {
                val logs = Repo.of(T.MAINTENANCE).sortedByDescending { it.t("date") }
                if (logs.isEmpty()) item { Empty("No work logged yet.") }
                items(logs, key = { it.id }) { m -> LogRow(m) }
            }
            else -> {
                val groups = (Repo.of(T.PLAN) + Repo.of(T.MAINTENANCE)).groupBy { Plans.target(it) ?: "Not linked" }.toSortedMap()
                groups.forEach { (name, list) ->
                    item(key = "g$name") { SectionTitle(name) }
                    items(list, key = { it.id }) { r -> if (r.type == T.PLAN) PlanRow(r) else LogRow(r) }
                }
            }
        }
    }
}

@Composable
fun PlanRow(p: Rec) {
    val due = p.day("nextDueDate")
    val label = when { p.b("isPaused") -> "Paused"; due == null -> ""; due <= Dates.today -> "Whenever suits"; else -> "Next " + Fmt.short(due) }
    ItemRow(p.title, listOfNotNull(Plans.target(p), Plans.interval(p), privacy(p)).joinToString(" · "), P.maintenance, Icons.Filled.Build,
        trailing = { Pill(label, P.calm) }) { Nav.open(p.id) }
}

@Composable
fun LogRow(m: Rec) {
    ItemRow(m.s("task").ifBlank { "Work" }, listOfNotNull(Fmt.short(m.day("date")), Plans.target(m), if (m.d("cost") > 0) Fmt.money(m.d("cost")) else null, Repo.get(m.link("person"))?.title).joinToString(" · "),
        P.maintenance, Icons.Filled.History) { Nav.open(m.id) }
}

@Composable
fun ProjectsList() {
    val list = Repo.of(T.PROJECT).sortedWith(compareBy({ Enums.projectStatus.indexOf(it.s("status")).let { i -> if (i == 1) -1 else i } }, { it.title.lowercase() }))
    Page("Projects", Nav::back, P.projects, fab = { AddFab("Add project", P.projects) { Nav.edit(T.PROJECT) } }) {
        if (list.isEmpty()) item { Empty("No projects yet.") }
        items(list, key = { it.id }) { p ->
            val jobs = Repo.of(T.TASK).filter { it.link("project") == p.id }
            val done = jobs.count { it.b("isDone") }
            val spent = projectSpent(p)
            Glass(tint = P.projects, onClick = { Nav.open(p.id) }) {
                Row { Text(p.title, fontSize = 17.sp, modifier = Modifier.weight(1f)); Pill(p.s("status").ifBlank { "Planned" }, P.projects) }
                Text(listOfNotNull(if (jobs.isEmpty()) "No jobs" else "$done of ${jobs.size} jobs", if (p.d("budget") > 0) "${Fmt.money(spent, true)} of ${Fmt.money(p.d("budget"), true)}" else null, privacy(p)).joinToString(" · "), color = P.muted, fontSize = 13.sp)
                if (jobs.isNotEmpty()) { Spacer(Modifier.height(6.dp)); Bar(done.toFloat() / jobs.size, P.projects) }
            }
        }
    }
}

fun projectSpends(p: Rec) = Repo.of(T.SPEND).filter { it.link("project") == p.id }.sortedByDescending { it.t("date") }
fun projectSpent(p: Rec): Double { val s = projectSpends(p); return if (s.isEmpty()) p.d("actualCost") else s.sumOf { it.d("amount") } }

@Composable
fun PeopleList() {
    var kind by remember { mutableStateOf("All") }
    val people = Repo.of(T.PERSON).filter { kind == "All" || it.s("kindRaw").ifBlank { "Household" } == kind }
        .sortedWith(compareBy({ it.s("memberUid").isBlank() }, { it.title.lowercase() }))
    Page("People", Nav::back, P.people, fab = { AddFab("Add person", P.people) { Nav.edit(T.PERSON, prefill = if (kind != "All") mapOf("kindRaw" to kind) else emptyMap()) } }) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                (listOf("All") + Enums.personKind).forEach { k -> FilterChip(kind == k, { kind = k }, label = { Text(k) }) }
            }
        }
        if (people.isEmpty()) item { Empty("No one here yet.") }
        items(people, key = { it.id }) { p ->
            ItemRow(p.title, listOfNotNull(p.s("kindRaw").ifBlank { "Household" }, p.s("company").ifBlank { null }, p.s("role").ifBlank { null }, privacy(p)).joinToString(" · "),
                P.people, Icons.Filled.Person, trailing = if (p.s("memberUid").isNotBlank()) { { Pill("Member", P.accent) } } else null) { Nav.open(p.id) }
        }
    }
}
