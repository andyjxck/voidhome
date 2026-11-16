package com.voidhome.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.Timestamp
import com.voidhome.app.data.*

sealed class F(val key: String, val label: String) {
    class Text(k: String, l: String, val multi: Boolean = false) : F(k, l)
    class Num(k: String, l: String, val int: Boolean = false) : F(k, l)
    class Day(k: String, l: String, val optional: Boolean = true) : F(k, l)
    class Choice(k: String, l: String, val options: List<String>) : F(k, l)
    class Link(k: String, l: String, val type: String) : F(k, l)
    class Links(k: String, l: String, val type: String) : F(k, l)
    class Bool(k: String, l: String) : F(k, l)
    class Weekdays : F("weekdaysRaw", "Days")
    class Member(k: String, l: String) : F(k, l)
}

object Specs {
    fun fields(type: String): List<F> = when (type) {
        T.HOME -> listOf(F.Text("name", "Home name"), F.Text("address", "Address", true))
        T.ROOM -> listOf(F.Text("name", "Room name"), F.Num("width", "Width (m)"), F.Num("height", "Depth (m)"), F.Num("floorNumber", "Floor number (0 = ground)", true), F.Member("ownerUid", "Whose room"))
        T.ASSET -> listOf(F.Text("name", "Name"), F.Choice("category", "Category", Enums.assetCategory), F.Link("room", "Room", T.ROOM), F.Text("manufacturer", "Make"),
            F.Text("model", "Model"), F.Text("serialNumber", "Serial number"), F.Day("purchaseDate", "Bought"), F.Num("purchasePrice", "Price"), F.Text("notes", "Notes", true))
        T.WARRANTY -> listOf(F.Link("asset", "Asset", T.ASSET), F.Text("provider", "Provider"), F.Day("startDate", "Starts", false), F.Day("expiryDate", "Ends", false),
            F.Text("claimContact", "Claim contact"), F.Bool("remindersEnabled", "Remind me 30 days before"), F.Text("notes", "Notes", true))
        T.PLAN -> listOf(F.Text("title", "Job"), F.Num("intervalValue", "Every", true), F.Choice("intervalUnitRaw", "Unit", Enums.intervalUnit), F.Day("nextDueDate", "Next", false),
            F.Choice("timeOfDayRaw", "Time of day", Enums.timeOfDay), F.Link("asset", "Asset", T.ASSET), F.Link("room", "Room", T.ROOM), F.Link("person", "Who usually does it", T.PERSON),
            F.Bool("remindersEnabled", "Gentle reminder"), F.Bool("isPaused", "Paused"), F.Text("notes", "Notes", true))
        T.MAINTENANCE -> listOf(F.Text("task", "Work done"), F.Day("date", "Date", false), F.Num("cost", "Cost"), F.Link("person", "Done by", T.PERSON),
            F.Link("asset", "Asset", T.ASSET), F.Link("room", "Room", T.ROOM), F.Text("notes", "Notes", true))
        T.PROJECT -> listOf(F.Text("title", "Title"), F.Text("projectDescription", "Description", true), F.Choice("status", "Status", Enums.projectStatus), F.Day("startDate", "Start"),
            F.Day("endDate", "Finish"), F.Num("budget", "Budget"), F.Links("contractors", "People", T.PERSON), F.Links("rooms", "Rooms", T.ROOM), F.Links("assets", "Assets", T.ASSET), F.Text("notes", "Notes", true))
        T.PERSON -> listOf(F.Text("name", "Name"), F.Choice("kindRaw", "Type", Enums.personKind), F.Text("company", "Company"), F.Text("role", "Role"),
            F.Text("phoneNumber", "Phone"), F.Text("email", "Email"), F.Text("notes", "Notes", true))
        T.BILL -> listOf(F.Text("name", "Bill"), F.Choice("categoryRaw", "Category", Enums.billCategory), F.Link("provider", "Provider", T.PERSON), F.Num("amount", "Amount"),
            F.Bool("isEstimate", "Rough figure"), F.Choice("frequencyRaw", "How often", Enums.billFrequency), F.Day("nextDueDate", "Next due", false), F.Text("paymentMethod", "How you pay"),
            F.Day("contractEndDate", "Contract ends"), F.Bool("remindersEnabled", "Remind me"), F.Text("notes", "Notes", true))
        T.TASK -> listOf(F.Text("title", "Job"), F.Choice("timeOfDayRaw", "Time of day", Enums.timeOfDay), F.Choice("repeatRaw", "Repeat", Enums.taskRepeat), F.Weekdays(),
            F.Day("startDate", "Day"), F.Link("assignee", "For", T.PERSON), F.Link("project", "Project", T.PROJECT), F.Link("room", "Room", T.ROOM), F.Link("asset", "Asset", T.ASSET), F.Text("notes", "Notes", true))
        T.DOCUMENT -> listOf(F.Text("title", "Title"), F.Choice("type", "Type", Enums.documentType), F.Day("expiryDate", "Expires"), F.Link("asset", "Asset", T.ASSET),
            F.Link("room", "Room", T.ROOM), F.Link("warranty", "Warranty", T.WARRANTY), F.Link("bill", "Bill", T.BILL), F.Link("project", "Project", T.PROJECT), F.Link("maintenance", "Maintenance", T.MAINTENANCE))
        T.SPEND -> listOf(F.Num("amount", "Amount"), F.Text("note", "What for"), F.Day("date", "Date", false))
        else -> listOf(F.Text("name", "Name"))
    }

    /** Full field set for a new record, same defaults as the Swift initialisers. */
    fun defaults(type: String): Map<String, Any?> {
        val now = Dates.ts(Dates.today); val home = Repo.home?.id
        return when (type) {
            T.HOME -> mapOf("name" to "My Home", "address" to "")
            T.ROOM -> mapOf("name" to "", "floor" to "", "floorNumber" to 0, "width" to 3.0, "height" to 4.0, "dimensions" to "", "rotation" to 0.0,
                "xPosition" to 0.5, "yPosition" to 0.5, "ownerUid" to "", "homeId" to home)
            T.ASSET -> mapOf("name" to "", "category" to "Other", "manufacturer" to "", "model" to "", "serialNumber" to "", "purchaseDate" to null, "purchasePrice" to 0.0,
                "location" to "", "notes" to "", "photoFileName" to null, "homeId" to home, "roomId" to null)
            T.WARRANTY -> mapOf("provider" to "", "startDate" to now, "expiryDate" to Dates.ts(Dates.today.plusYears(1)), "notes" to "", "remindersEnabled" to true, "claimContact" to "", "assetId" to null)
            T.PLAN -> mapOf("title" to "", "intervalValue" to 3, "intervalUnitRaw" to "Months", "nextDueDate" to now, "lastDoneDate" to null, "timeOfDayRaw" to "Anytime",
                "notes" to "", "remindersEnabled" to true, "isPaused" to false, "assetId" to null, "roomId" to null, "personId" to null)
            T.MAINTENANCE -> mapOf("task" to "", "date" to now, "cost" to 0.0, "notes" to "", "remindersEnabled" to false, "assetId" to null, "roomId" to null, "personId" to null, "planId" to null)
            T.PROJECT -> mapOf("title" to "", "projectDescription" to "", "startDate" to null, "endDate" to null, "budget" to 0.0, "actualCost" to 0.0, "status" to "Planned",
                "notes" to "", "homeId" to home, "contractorsIds" to emptyList<String>(), "roomsIds" to emptyList<String>(), "assetsIds" to emptyList<String>())
            T.PERSON -> mapOf("name" to "", "company" to "", "role" to "", "phoneNumber" to "", "email" to "", "notes" to "", "kindRaw" to "Tradesperson", "memberUid" to "")
            T.BILL -> mapOf("name" to "", "categoryRaw" to "Other", "amount" to 0.0, "isEstimate" to false, "frequencyRaw" to "Monthly", "nextDueDate" to now, "paymentMethod" to "",
                "contractEndDate" to null, "notes" to "", "remindersEnabled" to true, "isSettled" to false, "splitModeRaw" to "equal", "customSharesJSON" to "", "providerId" to null)
            T.TASK -> mapOf("title" to "", "notes" to "", "timeOfDayRaw" to "Anytime", "startDate" to null, "repeatRaw" to "Once", "weekdaysRaw" to "", "isDone" to false,
                "assigneeId" to null, "projectId" to null, "roomId" to null, "assetId" to null)
            T.DOCUMENT -> mapOf("title" to "", "type" to "Other", "fileURL" to "", "ocrText" to "", "expiryDate" to null, "warrantyId" to null, "billId" to null,
                "projectId" to null, "maintenanceId" to null, "assetId" to null, "roomId" to null)
            T.SPEND -> mapOf("amount" to 0.0, "note" to "", "date" to now, "paidByUid" to "", "sharesJSON" to "", "repaidJSON" to "", "projectId" to null)
            else -> emptyMap()
        }
    }

    fun noun(type: String) = when (type) {
        T.ASSET -> "asset"; T.WARRANTY -> "warranty"; T.PLAN -> "maintenance plan"; T.MAINTENANCE -> "work log"; T.PROJECT -> "project"; T.PERSON -> "person"
        T.BILL -> "bill"; T.TASK -> "job"; T.DOCUMENT -> "document"; T.ROOM -> "room"; T.HOME -> "home"; T.SPEND -> "spending"; else -> "item"
    }
}

/** Default Just me / Everyone for something new: documents start private, everything else shared. */
fun defaultVis(type: String) = if (type == T.DOCUMENT) Vis.ME else Vis.HOUSE

@Composable
fun EditScreen(type: String, id: String?, prefill: Map<String, Any?>) {
    val existing = Repo.get(id)
    val newId = remember { id ?: Repo.newId() }
    val state = remember { mutableStateMapOf<String, Any?>().apply { putAll(existing?.data ?: (Specs.defaults(type) + prefill)) } }
    val parent = remember { listOf("asset", "plan", "bill", "task", "project").firstNotNullOfOrNull { k -> (prefill["${k}Id"] as? String)?.let { Repo.get(it) } } }
    var vis by remember { mutableStateOf(existing?.vis ?: (prefill["__vis"] as? String) ?: if (type in T.OWN) defaultVis(type) else Repo.visFor(type, parent)) }
    var confirmDelete by remember { mutableStateOf(false) }
    val required = Specs.fields(type).firstOrNull()?.key
    val canSave = required == null || Specs.fields(type).first() !is F.Text || (state[required] as? String).orEmpty().isNotBlank()

    Page(if (existing == null) "New ${Specs.noun(type)}" else "Edit ${Specs.noun(type)}", onBack = Nav::back, tint = P.forType(type),
        actions = {
            if (existing != null) IconButton(onClick = { confirmDelete = true }) { Icon(Icons.Filled.Delete, "Delete") }
            TextButton(enabled = canSave, onClick = {
                val data = state.toMap().filterKeys { it != "__vis" }.toMutableMap()
                if (type == T.ROOM) prepareRoom(data, existing)
                if (type == T.SPEND && existing == null) {
                    val project = Repo.get(data["projectId"] as? String)
                    val amt = (data["amount"] as? Number)?.toDouble() ?: 0.0
                    if (vis == Vis.HOUSE && project?.vis == Vis.HOUSE && Repo.members.size > 1) {
                        data["paidByUid"] = Repo.uid.orEmpty(); data["sharesJSON"] = SplitJSON.encode(Split.shares(amt, "equal", emptyMap()))
                    }
                }
                Repo.save(type, newId, vis, data)
                Nav.back()
            }) { Text("Save") }
        }) {
        if (type in T.OWN || type == T.SPEND) item {
            Glass {
                Text("Who can see this", color = P.muted, fontSize = 13.sp); Spacer(Modifier.height(6.dp))
                val enabled = Repo.canChangeVisibility(existing) && !(type == T.SPEND && parent?.vis == Vis.ME)
                VisToggle(vis, enabled) { vis = it }
                if (type == T.BILL) Text(if (vis == Vis.ME) "Only you see it, and it counts toward your own total." else "Split between the house, and everyone sees their share.", color = P.faint, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
            }
        }
        items(Specs.fields(type).size) { i ->
            val f = Specs.fields(type)[i]
            if (f is F.Weekdays && state["repeatRaw"] != "Weekly") return@items
            FieldView(f, state)
        }
        if (type == T.BILL && vis == Vis.HOUSE && Repo.members.size > 1) item { SplitEditor(state) }
    }
    if (confirmDelete && existing != null) ConfirmDelete(Specs.noun(type), { Repo.delete(existing); Nav.back(); if (Nav.top.id == existing.id) Nav.back() }, { confirmDelete = false })
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FieldView(f: F, state: MutableMap<String, Any?>) {
    when (f) {
        is F.Text -> FText(f.label, state[f.key] as? String ?: "", f.multi) { state[f.key] = it }
        is F.Num -> FNumber(f.label, (state[f.key] as? Number)?.toDouble()) { v -> state[f.key] = if (f.int) (v ?: 0.0).toInt() else (v ?: 0.0) }
        is F.Day -> FDate(f.label, Dates.toLocal(state[f.key])?.toLocalDate(), f.optional) { d -> state[f.key] = d?.let { Dates.ts(it) } ?: if (f.optional) null else Dates.ts(Dates.today) }
        is F.Choice -> FChoice(f.label, state[f.key] as? String ?: "", f.options) { state[f.key] = it }
        is F.Link -> FLink(f.label, f.type, state[f.key + "Id"] as? String) { state[f.key + "Id"] = it }
        is F.Links -> FLinks(f.label, f.type, (state[f.key + "Ids"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()) { state[f.key + "Ids"] = it.sorted() }
        is F.Bool -> FSwitch(f.label, state[f.key] as? Boolean ?: false) { state[f.key] = it }
        is F.Member -> FChoice(f.label, state[f.key] as? String ?: "", listOf("") + Repo.members.map { it.uid }, display = { if (it.isBlank()) "Shared room" else Repo.memberName(it) }) { state[f.key] = it }
        is F.Weekdays -> {
            val names = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
            val cur = (state[f.key] as? String).orEmpty().split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
            Column {
                Text("On these days", color = P.muted, fontSize = 13.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    // Show Monday first, store Apple weekday numbers (1 = Sunday).
                    listOf(2, 3, 4, 5, 6, 7, 1).forEach { n ->
                        FilterChip(n in cur, { state[f.key] = (if (n in cur) cur - n else cur + n).sorted().joinToString(",") }, label = { Text(names[n - 1]) })
                    }
                }
            }
        }
    }
}

@Composable
fun SplitEditor(state: MutableMap<String, Any?>) {
    val mode = state["splitModeRaw"] as? String ?: "equal"
    val custom = SplitJSON.amounts(state["customSharesJSON"] as? String ?: "")
    Glass(tint = P.bills) {
        Text("Split", fontSize = 16.sp)
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
            SegmentedButton(mode != "custom", { state["splitModeRaw"] = "equal" }, SegmentedButtonDefaults.itemShape(0, 2)) { Text("Equal") }
            SegmentedButton(mode == "custom", { state["splitModeRaw"] = "custom" }, SegmentedButtonDefaults.itemShape(1, 2)) { Text("Custom") }
        }
        val amount = (state["amount"] as? Number)?.toDouble() ?: 0.0
        if (mode == "custom") {
            Text("Shares are weights: 60 and 40, or 1 and 0 for one person covering it.", color = P.faint, fontSize = 12.sp)
            Repo.members.forEach { m ->
                FNumber(m.name, custom[m.uid] ?: 1.0) { v ->
                    val next = (Repo.members.associate { it.uid to (custom[it.uid] ?: 1.0) } + (m.uid to (v ?: 0.0)))
                    state["customSharesJSON"] = SplitJSON.encode(next)
                }
            }
        }
        val shares = Split.shares(amount, mode, if (mode == "custom") SplitJSON.amounts(state["customSharesJSON"] as? String ?: "") else emptyMap())
        shares.forEach { (u, a) -> KV(Repo.memberName(u), Fmt.money(a)) }
    }
}

/** Places a new room in free space on its floor, like the iOS plan does, and keeps `dimensions` text in step. */
private fun prepareRoom(data: MutableMap<String, Any?>, existing: Rec?) {
    val w = (data["width"] as? Number)?.toDouble()?.takeIf { it > 0 } ?: 3.0
    val h = (data["height"] as? Number)?.toDouble()?.takeIf { it > 0 } ?: 4.0
    data["width"] = w; data["height"] = h
    data["dimensions"] = Plan.dimensions(w, h)
    val floor = (data["floorNumber"] as? Number)?.toInt() ?: 0
    data["floorNumber"] = floor
    data["floor"] = floorDisplay(floor)
    val movedFloor = existing != null && existing.i("floorNumber") != floor
    if (existing == null || data["planX"] == null || movedFloor) {
        val others = Repo.of(T.ROOM).filter { it.id != existing?.id && it.i("floorNumber") == floor && it.dn("planX") != null }.map { Plan.worldRects(it) }
        val pref = if (existing != null) ((data["planX"] as? Number)?.toDouble() ?: 0.0) to ((data["planY"] as? Number)?.toDouble() ?: 0.0) else 0.0 to 0.0
        val local = existing?.let { Plan.localRects(it).let { l -> listOf(PRect(-w / 2, -h / 2, w, h)) + l.drop(1) } } ?: listOf(PRect(-w / 2, -h / 2, w, h))
        val c = Plan.freeCenter(pref, local, Plan.quarterTurns((data["rotation"] as? Number)?.toDouble() ?: 0.0), others)
        data["planX"] = c.first; data["planY"] = c.second
    }
}

@Suppress("unused") private val keepTimestamp: Class<Timestamp> = Timestamp::class.java
