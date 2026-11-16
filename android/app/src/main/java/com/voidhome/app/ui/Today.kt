package com.voidhome.app.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voidhome.app.data.*
import java.time.LocalDate
import java.time.temporal.ChronoUnit

// ------------------------------------------------------------------ launcher (HomeScreen on iOS)

@Composable
fun LauncherScreen() {
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
            IconButton(onClick = { Nav.go("house") }) { Icon(Icons.Filled.Groups, "House and members", tint = P.muted) }
        }
        VoidHeader(Repo.home?.title?.takeIf { it != "Untitled" } ?: Repo.house?.name ?: "")
        Spacer(Modifier.height(28.dp))
        val icons = listOf(
            Triple("Rooms", Icons.Filled.GridView, P.rooms) to { Nav.go("rooms") },
            Triple("Assets", Icons.Filled.ViewInAr, P.assets) to { Nav.go(Dest("list", type = T.ASSET)) },
            Triple("Documents", Icons.Filled.Description, P.documents) to { Nav.go(Dest("list", type = T.DOCUMENT)) },
            Triple("Warranties", Icons.Filled.Shield, P.warranties) to { Nav.go(Dest("list", type = T.WARRANTY)) },
            Triple("Maintenance", Icons.Filled.Build, P.maintenance) to { Nav.go(Dest("list", type = T.PLAN)) },
            Triple("Projects", Icons.Filled.Handyman, P.projects) to { Nav.go(Dest("list", type = T.PROJECT)) },
            Triple("Timeline", Icons.Filled.Schedule, P.calm) to { Nav.go("timeline") },
            Triple("Search", Icons.Filled.Search, P.accent) to { Nav.go("search") },
        )
        icons.chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                row.forEach { (t, go) -> AppIcon(t.first, t.second, t.third, go) }
            }
        }
        Spacer(Modifier.weight(1f))
        Row(
            Modifier.fillMaxWidth().padding(bottom = 16.dp).clip(RoundedCornerShape(28.dp)).background(P.card).border(1.dp, P.stroke, RoundedCornerShape(28.dp)).padding(14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            AppIcon("Home", Icons.Filled.Home, Color(0xFF594DA6)) { Nav.go("home") }
            AppIcon("Bills", Icons.Filled.CreditCard, P.bills) { Nav.go("bills") }
            AppIcon("People", Icons.Filled.People, P.people) { Nav.go(Dest("list", type = T.PERSON)) }
            AppIcon("To-Do", Icons.Filled.Checklist, P.todo) { Nav.go("todo") }
        }
    }
}

@Composable
fun AppIcon(title: String, icon: ImageVector, tint: Color, onClick: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(72.dp).clickable(onClick = onClick)) {
        Box(Modifier.size(60.dp).clip(RoundedCornerShape(16.dp)).background(tint.copy(alpha = 0.55f)).border(1.dp, Color(0x33FFFFFF), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, title, tint = Color.White, modifier = Modifier.size(28.dp))
        }
        Spacer(Modifier.height(6.dp))
        Text(title, fontSize = 12.sp, color = Color.White)
    }
}

// ------------------------------------------------------------------ Home dashboard

@Composable
fun HomeDashboard() {
    val today = Dates.today
    val items = TodoFeed.items(today).filter { !it.isInfo }
    val done = items.count { it.isDone }
    val bills = Repo.of(T.BILL).filter { !it.b("isSettled") }
    val dueWeek = bills.filter { b -> b.day("nextDueDate")?.let { it <= today.plusDays(7) } ?: false }
    val overdue = bills.count { Bills.isOverdue(it) }
    val ending = Repo.of(T.WARRANTY).filter { Warranties.status(it) == "Ending soon" }
    val maint = Repo.of(T.PLAN).filter { p -> !p.b("isPaused") && (p.day("nextDueDate")?.let { it <= today.plusDays(7) } ?: false) }
    val projects = Repo.of(T.PROJECT).filter { it.s("status") == "In Progress" }
    val assets = Repo.of(T.ASSET)
    val home = Repo.home
    Page("Home", onBack = Nav::back, actions = { home?.let { h -> IconButton(onClick = { Nav.edit(T.HOME, h.id) }) { Icon(Icons.Filled.Edit, "Edit home") } } }) {
        item {
            Glass(tint = P.todo, onClick = { Nav.go("todo") }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Ring(if (items.isEmpty()) 0f else done.toFloat() / items.size, P.todo, Modifier.size(74.dp))
                    Spacer(Modifier.width(16.dp))
                    Column {
                        Text("Today", fontSize = 20.sp, fontWeight = FontWeight.Light)
                        Text(if (items.isEmpty()) "Nothing on today" else "$done of ${items.size} done", color = P.muted)
                    }
                }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Tile("Bills this week", if (dueWeek.isEmpty()) "None due" else Fmt.money(dueWeek.sumOf { it.d("amount") }),
                    if (overdue > 0) "$overdue overdue" else "${dueWeek.size} due", if (overdue > 0) P.billOverdue else P.bills, Modifier.weight(1f)) { Nav.go("bills") }
                Tile("Warranties ending", "${ending.size}", "next 60 days", P.warranties, Modifier.weight(1f)) { Nav.go(Dest("list", type = T.WARRANTY)) }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Tile("Maintenance", "${maint.size}", "whenever suits this week", P.maintenance, Modifier.weight(1f)) { Nav.go(Dest("list", type = T.PLAN)) }
                Tile("Projects", "${projects.size}", "in progress", P.projects, Modifier.weight(1f)) { Nav.go(Dest("list", type = T.PROJECT)) }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Tile("Assets", "${assets.size}", Fmt.money(assets.sumOf { it.d("purchasePrice") }, true) + " value", P.assets, Modifier.weight(1f)) { Nav.go(Dest("list", type = T.ASSET)) }
                Tile("Rooms", "${Repo.of(T.ROOM).size}", "floor plan", P.rooms, Modifier.weight(1f)) { Nav.go("rooms") }
            }
        }
        val coming = Timeline.build().first.filter { it.date <= today.plusDays(14) }.take(12)
        item { SectionTitle("Coming up") }
        if (coming.isEmpty()) item { Empty("Nothing in the next two weeks.") }
        items(coming, key = { it.id }) { r -> TimelineRowView(r) }
        if (home != null) item {
            SectionTitle("Home details")
            Glass {
                KV("Name", home.title); KV("Address", home.s("address")); KV("House", Repo.house?.name)
                KV("Members", Repo.members.joinToString { it.name })
            }
        }
    }
}

@Composable
fun Ring(fraction: Float, color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val sw = 9.dp.toPx(); val s = Size(size.width - sw, size.height - sw); val o = Offset(sw / 2, sw / 2)
        drawArc(Color(0x22FFFFFF), 0f, 360f, false, o, s, style = Stroke(sw))
        drawArc(color, -90f, 360f * fraction, false, o, s, style = Stroke(sw, cap = StrokeCap.Round))
    }
}

@Composable
fun Tile(title: String, value: String, sub: String, tint: Color, modifier: Modifier, onClick: () -> Unit) {
    Glass(modifier, tint = tint, onClick = onClick) {
        Text(title, color = P.muted, fontSize = 13.sp)
        Text(value, fontSize = 24.sp, fontWeight = FontWeight.Light, color = Color.White)
        Text(sub, color = tint, fontSize = 12.sp)
    }
}

// ------------------------------------------------------------------ To-Do

@Composable
fun TodoScreen() {
    var tab by remember { mutableIntStateOf(0) }
    var day by remember { mutableStateOf(Dates.today) }
    var mine by remember { mutableStateOf(false) }
    var completing by remember { mutableStateOf<TodoItem?>(null) }
    val myPerson = "member-${Repo.uid}"
    Page("To-Do", onBack = Nav::back, tint = P.todo,
        fab = { AddFab("Add job", P.todo) { Nav.edit(T.TASK, prefill = mapOf("startDate" to Dates.ts(day))) } },
        header = {
            TabRow(tab, containerColor = Color.Transparent) {
                listOf("Today", "All jobs", "History").forEachIndexed { i, t -> Tab(tab == i, { tab = i }, text = { Text(t) }) }
            }
        }) {
        when (tab) {
            0 -> {
                item { WeekStrip(day) { day = it } }
                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(Fmt.day(day), fontSize = 22.sp, fontWeight = FontWeight.Light, modifier = Modifier.weight(1f))
                        if (Repo.members.size > 1) FilterChip(mine, { mine = !mine }, label = { Text("Just mine") })
                    }
                }
                val all = TodoFeed.items(day).filter { !mine || it.assigneeId == null || it.assigneeId == myPerson }
                if (all.isEmpty()) item { Empty("Nothing on this day.") }
                for (slot in Enums.timeOfDay) {
                    val list = all.filter { it.timeOfDay == slot }
                    if (list.isEmpty()) continue
                    item(key = "h$slot") { SectionTitle(slot, P.todo) }
                    items(list, key = { it.id }) { it2 -> TodoRow(it2, day, onLong = { completing = it2 }) }
                }
            }
            1 -> {
                val tasks = Repo.of(T.TASK).sortedBy { it.title.lowercase() }
                if (tasks.isEmpty()) item { Empty("No jobs yet. Add one with just a title.") }
                items(tasks, key = { it.id }) { t ->
                    ItemRow(t.title, listOfNotNull(Tasks.summary(t), Tasks.timeOfDay(t), Repo.get(t.link("assignee"))?.title, if (t.isPrivate) "Just me" else null).joinToString(" · "),
                        P.todo, Icons.Filled.Checklist) { Nav.open(t.id) }
                }
            }
            else -> {
                val h = TodoFeed.history()
                if (h.isEmpty()) item { Empty("Nothing ticked off yet.") }
                h.groupBy { it.at.toLocalDate() }.forEach { (d, list) ->
                    item(key = "d$d") { SectionTitle(Fmt.day(d)) }
                    items(list, key = { it.id }) { e ->
                        val who = Repo.get(e.personId)?.title ?: e.by?.let { Repo.memberName(it) }
                        ItemRow(e.title, listOfNotNull(Fmt.time(e.at), e.detail, who, e.note.ifBlank { null }).joinToString(" · "), P.done, Icons.Filled.CheckCircle)
                    }
                }
            }
        }
    }
    completing?.let { CompleteDialog(it, day) { completing = null } }
}

@Composable
fun WeekStrip(selected: LocalDate, onPick: (LocalDate) -> Unit) {
    val start = selected.minusDays(((selected.dayOfWeek.value - 1)).toLong())
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = { onPick(selected.minusWeeks(1)) }) { Icon(Icons.Filled.ChevronLeft, "Previous week") }
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.SpaceBetween) {
            (0..6L).map { start.plusDays(it) }.forEach { d ->
                val sel = d == selected; val isToday = d == Dates.today
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clip(RoundedCornerShape(12.dp))
                    .background(if (sel) P.todo.copy(alpha = 0.45f) else Color.Transparent).clickable { onPick(d) }.padding(horizontal = 6.dp, vertical = 6.dp)) {
                    Text(d.dayOfWeek.name.take(1), color = P.muted, fontSize = 11.sp)
                    Text("${d.dayOfMonth}", color = if (isToday) P.calm else Color.White, fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal)
                }
            }
        }
        IconButton(onClick = { onPick(selected.plusWeeks(1)) }) { Icon(Icons.Filled.ChevronRight, "Next week") }
    }
    if (selected != Dates.today) TextButton(onClick = { onPick(Dates.today) }) { Text("Back to today") }
}

@Composable
fun TodoRow(item: TodoItem, day: LocalDate, onLong: () -> Unit) {
    val tint = when (item.src) { Src.BILL -> P.bills; Src.PLAN -> P.maintenance; Src.WARRANTY -> P.warranties; Src.DOCUMENT -> P.documents; else -> P.todo }
    val who = Repo.get(item.assigneeId)?.title
    val sub = listOfNotNull(item.origin, item.subtitle, who?.let { "for $it" }).joinToString(" · ")
    ItemRow(
        item.title, sub.ifBlank { null }, tint, if (item.isDone) Icons.Filled.CheckCircle else P.icon(item.rec.type),
        titleColor = if (item.isDone) P.muted else Color.White,
        trailing = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Only bills ever show overdue or red.
                if (item.isOverdue && item.src == Src.BILL) Pill("Overdue", P.billOverdue)
                else if (item.isDone) Pill("Done", P.done)
                else if (!item.isInfo) Pill("Due", P.calm)
                if (!item.isInfo) Checkbox(item.isDone, { c -> if (c) TodoFeed.complete(item, day) else TodoFeed.uncomplete(item, day) })
            }
        },
        onLongClick = if (!item.isInfo && !item.isDone) onLong else null,
    ) { Nav.open(item.rec.id) }
}

@Composable
fun CompleteDialog(item: TodoItem, day: LocalDate, onDone: () -> Unit) {
    val context = LocalContext.current
    var note by remember { mutableStateOf("") }
    var person by remember { mutableStateOf(item.assigneeId ?: "member-${Repo.uid}".takeIf { Repo.get(it) != null }) }
    var photo by remember { mutableStateOf<String?>(null) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? -> uri?.let { photo = Repo.importFile(context, it, "jpg") } }
    AlertDialog(
        onDismissRequest = onDone,
        title = { Text(item.title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                FText("Note (optional)", note, multiline = true) { note = it }
                FLink("Done by", T.PERSON, person, filter = { it.s("kindRaw").ifBlank { "Household" } == "Household" }) { person = it }
                if (item.src == Src.TASK) OutlinedButton(onClick = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                    Icon(Icons.Filled.PhotoCamera, null); Spacer(Modifier.width(6.dp)); Text(if (photo == null) "Add a photo" else "Photo added")
                }
            }
        },
        confirmButton = { TextButton(onClick = { TodoFeed.complete(item, day, note, person, photo); onDone() }) { Text("Mark done") } },
        dismissButton = { TextButton(onClick = onDone) { Text("Cancel") } },
    )
}

@Composable
fun TimelineRowView(r: TimelineRow) {
    val tint = when (r.kind) { "Bills" -> if (r.overdue) P.billOverdue else P.bills; "To-Do" -> P.todo; "Maintenance" -> P.maintenance; "Warranties" -> P.warranties; "Projects" -> P.projects; "Assets" -> P.assets; else -> P.documents }
    ItemRow(r.title, listOfNotNull(Fmt.day(r.date), r.detail).joinToString(" · "), tint, P.icon(r.rec.type),
        trailing = when { r.overdue -> { { Pill("Overdue", P.billOverdue) } }; r.calm != null -> { { Pill(r.calm, P.calm) } }; else -> null }) { Nav.open(r.rec.id) }
}
