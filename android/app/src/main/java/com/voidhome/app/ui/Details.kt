package com.void.homeos.ui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import coil.compose.AsyncImage
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.void.homeos.data.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.io.File

@Composable
fun LocalImage(rec: Rec, name: String, modifier: Modifier) {
    var file by remember(name) { mutableStateOf<File?>(null) }
    LaunchedEffect(name, rec.id) { file = if (name.isBlank()) null else Repo.ensureLocal(rec, name) }
    Box(modifier.clip(RoundedCornerShape(12.dp)).background(P.forType(rec.type).copy(alpha = 0.2f)), contentAlignment = Alignment.Center) {
        val f = file
        if (f != null) AsyncImage(f, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        else Icon(P.icon(rec.type), null, tint = P.forType(rec.type))
    }
}

fun openFile(context: android.content.Context, f: File) {
    val uri = FileProvider.getUriForFile(context, context.packageName + ".files", f)
    val mime = when (f.extension.lowercase()) { "pdf" -> "application/pdf"; "jpg", "jpeg" -> "image/jpeg"; "png" -> "image/png"; else -> "*/*" }
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)) }
        .onFailure { Repo.lastError = "No app on this phone can open this file." }
}

@Composable
fun DetailScreen(id: String) {
    val r = Repo.get(id)
    if (r == null) {
        Page("Not found", Nav::back) { item { Empty("This was deleted, or it's private to someone else.") } }
        return
    }
    if (r.type == T.ROOM) { RoomPage(r.id); return }
    var confirmDelete by remember { mutableStateOf(false) }
    val editable = r.type !in setOf(T.PAYMENT, T.COMPLETION, T.CHECK, T.PHOTO)
    Page(r.title, Nav::back, P.forType(r.type), actions = {
        if (editable) IconButton(onClick = { Nav.edit(r.type, r.id) }) { Icon(Icons.Filled.Edit, "Edit") }
        IconButton(onClick = { confirmDelete = true }) { Icon(Icons.Filled.Delete, "Delete") }
    }) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                if (r.type in T.OWN) Pill(if (r.isPrivate) "Just me" else "Everyone", if (r.isPrivate) P.amber else P.calm)
                if (Repo.members.size > 1 && r.createdBy.isNotBlank()) Text("Added by ${Repo.memberName(r.createdBy)}", color = P.faint, fontSize = 12.sp)
            }
        }
        when (r.type) {
            T.ASSET -> assetBody(r)
            T.WARRANTY -> warrantyBody(r)
            T.DOCUMENT -> item { DocumentBody(r) }
            T.PLAN -> item { PlanBody(r) }
            T.MAINTENANCE -> item { Glass { KV("Date", Fmt.long(r.day("date"))); KV("Cost", if (r.d("cost") > 0) Fmt.money(r.d("cost")) else null); KV("Done by", Repo.get(r.link("person"))?.title); KV("Item", Plans.target(r)); KV("Notes", r.s("notes")) } }
            T.PROJECT -> projectBody(r)
            T.PERSON -> personBody(r)
            T.BILL -> billBody(r)
            T.TASK -> taskBody(r)
            T.SPEND -> item { SpendRow(r) }
            T.HOME -> item { Glass { KV("Address", r.s("address")) } }
            else -> {}
        }
        linkedSection(r)
    }
    if (confirmDelete) ConfirmDelete(Specs.noun(r.type), { Repo.delete(r); Nav.back() }, { confirmDelete = false })
}

/** Two-way "Linked" section: what this links to, and what links to it. */
fun LazyListScope.linkedSection(r: Rec) {
    val shownChildTypes = setOf(T.CHECK, T.COMPLETION, T.PAYMENT, T.PHOTO, T.SPEND, T.ROOM_PART, T.DOOR)
    val forward = r.data.flatMap { (k, v) -> when { k.endsWith("Ids") -> (v as? List<*>)?.filterIsInstance<String>() ?: emptyList(); k.endsWith("Id") && v is String -> listOf(v); else -> emptyList() } }
        .mapNotNull { Repo.get(it) }.filter { it.type != T.HOME && it.type != T.FLOOR }
    val back = backlinks(r.id).filter { it.type !in shownChildTypes }
    val all = (forward + back).distinctBy { it.id }.filter { it.type !in shownChildTypes }
    if (all.isEmpty()) return
    item { SectionTitle("Linked") }
    items(all, key = { "l" + it.id }) { l -> ItemRow(l.title, typeLabel(l.type), P.forType(l.type), P.icon(l.type)) { Nav.open(l.id) } }
}

fun typeLabel(t: String) = when (t) { T.PLAN -> "Maintenance plan"; T.MAINTENANCE -> "Work log"; T.TASK -> "Job"; else -> Specs.noun(t).replaceFirstChar { it.uppercase() } }

// ------------------------------------------------------------------ Asset

fun LazyListScope.assetBody(a: Rec) {
    item {
        val context = LocalContext.current
        val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
            uri?.let { Repo.importFile(context, it, "jpg") }?.let { name -> Repo.update(a, mapOf("photoFileName" to name)); Repo.get(a.id)?.let { Repo.upload(it, name) } }
        }
        Glass(tint = P.assets) {
            Row {
                LocalImage(a, a.s("photoFileName"), Modifier.size(96.dp).clip(RoundedCornerShape(12.dp)))
                Spacer(Modifier.width(12.dp))
                Column {
                    KV("Category", a.s("category")); KV("Make", a.s("manufacturer")); KV("Model", a.s("model"))
                    TextButton(onClick = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text(if (a.s("photoFileName").isBlank()) "Add photo" else "Change photo") }
                }
            }
            KV("Serial", a.s("serialNumber")); KV("Bought", Fmt.long(a.day("purchaseDate"))); KV("Price", if (a.d("purchasePrice") > 0) Fmt.money(a.d("purchasePrice")) else null); KV("Notes", a.s("notes"))
        }
    }
    Repo.get(a.link("room"))?.let { room -> item { ItemRow(room.title, "Room · Show on plan", P.rooms, Icons.Filled.GridView) { Nav.go(Dest("room", id = room.id)) } } }
    childSection("Warranties", Repo.of(T.WARRANTY).filter { it.link("asset") == a.id }, "Add warranty") { Nav.edit(T.WARRANTY, prefill = mapOf("assetId" to a.id, "__vis" to a.vis)) }
    childSection("Maintenance plans", Repo.of(T.PLAN).filter { it.link("asset") == a.id }, "Add plan") { Nav.edit(T.PLAN, prefill = mapOf("assetId" to a.id, "title" to "Service ${a.title}", "__vis" to a.vis)) }
    childSection("Work done", Repo.of(T.MAINTENANCE).filter { it.link("asset") == a.id }.sortedByDescending { it.t("date") }, "Log work") { Nav.edit(T.MAINTENANCE, prefill = mapOf("assetId" to a.id, "__vis" to a.vis)) }
    childSection("Documents", Repo.of(T.DOCUMENT).filter { it.link("asset") == a.id }, "Add document") { Nav.edit(T.DOCUMENT, prefill = mapOf("assetId" to a.id)) }
    childSection("Jobs", Repo.of(T.TASK).filter { it.link("asset") == a.id }, "Add job") { Nav.edit(T.TASK, prefill = mapOf("assetId" to a.id)) }
}

fun LazyListScope.childSection(title: String, list: List<Rec>, add: String?, onAdd: () -> Unit) {
    item(key = "cs$title") { SectionTitle(title, trailing = if (add != null) { { TextButton(onClick = onAdd) { Text(add) } } } else null) }
    items(list, key = { "c$title" + it.id }) { r ->
        val sub = when (r.type) {
            T.WARRANTY -> Warranties.status(r) + " · ends " + Fmt.short(r.day("expiryDate"))
            T.PLAN -> Plans.interval(r)
            T.MAINTENANCE -> Fmt.short(r.day("date")) + if (r.d("cost") > 0) " · " + Fmt.money(r.d("cost")) else ""
            T.TASK -> Tasks.summary(r)
            T.DOCUMENT -> r.s("type")
            T.BILL -> Fmt.money(r.d("amount")) + " · " + Bills.frequency(r)
            T.PROJECT -> r.s("status")
            else -> null
        }
        ItemRow(r.title, sub, P.forType(r.type), P.icon(r.type)) { Nav.open(r.id) }
    }
}

// ------------------------------------------------------------------ Warranty

fun LazyListScope.warrantyBody(w: Rec) {
    item { WarrantyCard(w) }
    item {
        Glass {
            KV("Asset", Repo.get(w.link("asset"))?.title); KV("Provider", w.s("provider")); KV("Starts", Fmt.long(w.day("startDate"))); KV("Ends", Fmt.long(w.day("expiryDate")))
            KV("Claims", w.s("claimContact")); KV("Reminders", if (w.b("remindersEnabled")) "30 days before and on the day" else "Off"); KV("Notes", w.s("notes"))
        }
    }
    childSection("Receipts and documents", Repo.of(T.DOCUMENT).filter { it.link("warranty") == w.id }, "Add") { Nav.edit(T.DOCUMENT, prefill = mapOf("warrantyId" to w.id, "assetId" to w.link("asset"), "type" to "Receipt")) }
}

// ------------------------------------------------------------------ Document (scan, OCR, open)

@Composable
fun DocumentBody(d: Rec) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    fun attach(name: String, ocr: String?) {
        val data = mutableMapOf<String, Any?>("fileURL" to name)
        if (ocr != null) data["ocrText"] = ocr
        Repo.update(d, data); Repo.get(d.id)?.let { Repo.upload(it, name) }
    }
    val scanner = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        if (res.resultCode != Activity.RESULT_OK) return@rememberLauncherForActivityResult
        val scan = GmsDocumentScanningResult.fromActivityResultIntent(res.data) ?: return@rememberLauncherForActivityResult
        busy = true
        scope.launch {
            try {
                val name = scan.pdf?.uri?.let { Repo.importFile(context, it, "pdf") }
                    ?: scan.pages?.firstOrNull()?.imageUri?.let { Repo.importFile(context, it, "jpg") }
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                val text = scan.pages.orEmpty().mapNotNull { p -> runCatching { recognizer.process(InputImage.fromFilePath(context, p.imageUri)).await().text }.getOrNull() }.joinToString("\n")
                if (name != null) attach(name, text)
            } finally { busy = false }
        }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val mime = context.contentResolver.getType(uri) ?: ""
        val ext = when { mime.contains("pdf") -> "pdf"; mime.contains("png") -> "png"; else -> "jpg" }
        val name = Repo.importFile(context, uri, ext) ?: return@rememberLauncherForActivityResult
        busy = true
        scope.launch {
            try {
                val text = if (ext != "pdf") runCatching { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(InputImage.fromFilePath(context, uri)).await().text }.getOrNull() else null
                attach(name, text)
            } finally { busy = false }
        }
    }
    var file by remember(d.s("fileURL")) { mutableStateOf<File?>(null) }
    LaunchedEffect(d.s("fileURL")) { file = Repo.ensureLocal(d, d.s("fileURL")) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Glass(tint = P.documents) {
            KV("Type", d.s("type")); KV("Added", Fmt.long(d.day("createdAt"))); KV("Expires", Fmt.long(d.day("expiryDate")))
            val f = file
            if (f != null && f.extension.lowercase() != "pdf") AsyncImage(f, null, modifier = Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Fit)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                if (f != null) Button(onClick = { openFile(context, f) }) { Text("Open") }
                else if (d.s("fileURL").isNotBlank()) Text("File not downloaded yet", color = P.faint, fontSize = 13.sp)
                OutlinedButton(enabled = !busy, onClick = {
                    val opts = GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG, GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
                        .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
                    GmsDocumentScanning.getClient(opts).getStartScanIntent(context as Activity)
                        .addOnSuccessListener { scanner.launch(IntentSenderRequest.Builder(it).build()) }
                        .addOnFailureListener { Repo.lastError = "The scanner isn't available on this phone: ${it.message}" }
                }) { Icon(Icons.Filled.DocumentScanner, null); Spacer(Modifier.width(6.dp)); Text("Scan") }
                OutlinedButton(enabled = !busy, onClick = { picker.launch(arrayOf("application/pdf", "image/*")) }) { Text("Attach file") }
            }
            if (busy) LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 6.dp))
        }
        if (d.s("ocrText").isNotBlank()) Glass { Text("Scanned text", color = P.muted, fontSize = 13.sp); Text(d.s("ocrText"), fontSize = 13.sp, maxLines = 30) }
    }
}

// ------------------------------------------------------------------ Maintenance plan

@Composable
fun PlanBody(p: Rec) {
    var marking by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Glass(tint = P.maintenance) {
            KV("Repeats", Plans.interval(p)); KV("Next", p.day("nextDueDate")?.let { if (it <= Dates.today) "Whenever suits" else Fmt.long(it) }); KV("Last done", Fmt.long(p.day("lastDoneDate")))
            KV("Time of day", Tasks.timeOfDay(p)); KV("Item", Plans.target(p)); KV("Usually", Repo.get(p.link("person"))?.title); KV("Notes", p.s("notes"))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                Button(onClick = { marking = true }) { Text("Mark done") }
                OutlinedButton(onClick = { Repo.update(p, mapOf("isPaused" to !p.b("isPaused"))) }) { Text(if (p.b("isPaused")) "Resume" else "Pause") }
            }
        }
        SectionTitle("Log")
        val logs = Plans.logs(p).sortedByDescending { it.t("date") }
        if (logs.isEmpty()) Text("Not done yet.", color = P.faint)
        logs.forEach { LogRow(it) }
    }
    if (marking) {
        var note by remember { mutableStateOf("") }; var cost by remember { mutableStateOf<Double?>(null) }; var person by remember { mutableStateOf(p.link("person")) }
        AlertDialog(onDismissRequest = { marking = false }, title = { Text(p.title) },
            text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { FNumber("Cost (optional)", null) { cost = it }; FLink("Done by", T.PERSON, person) { person = it }; FText("Note", note, true) { note = it } } },
            confirmButton = { TextButton(onClick = { Plans.markDone(p, java.time.LocalDateTime.now(), note, cost ?: 0.0, person); marking = false }) { Text("Save") } },
            dismissButton = { TextButton(onClick = { marking = false }) { Text("Cancel") } })
    }
}

// ------------------------------------------------------------------ Project

fun LazyListScope.projectBody(p: Rec) {
    val jobs = Repo.of(T.TASK).filter { it.link("project") == p.id }
    val done = jobs.count { it.b("isDone") }
    val spent = projectSpent(p)
    item {
        Glass(tint = P.projects) {
            KV("Status", p.s("status")); KV("Start", Fmt.long(p.day("startDate"))); KV("Finish", Fmt.long(p.day("endDate"))); KV("About", p.s("projectDescription"))
            Spacer(Modifier.height(6.dp))
            Text(if (jobs.isEmpty()) "No jobs yet" else "$done of ${jobs.size} jobs done", color = P.muted, fontSize = 13.sp); Bar(if (jobs.isEmpty()) 0f else done.toFloat() / jobs.size, P.projects)
            if (p.d("budget") > 0) {
                Spacer(Modifier.height(8.dp))
                Text("${Fmt.money(spent)} of ${Fmt.money(p.d("budget"))} budget", color = P.muted, fontSize = 13.sp)
                Bar((spent / p.d("budget")).toFloat(), if (spent > p.d("budget")) P.amber else P.bills)
            }
            KV("Notes", p.s("notes"))
        }
    }
    childSection("Jobs", jobs, "Add job") { Nav.edit(T.TASK, prefill = mapOf("projectId" to p.id)) }
    item(key = "spend") { SectionTitle("Spending", trailing = { TextButton(onClick = { Nav.edit(T.SPEND, prefill = mapOf("projectId" to p.id, "__vis" to p.vis)) }) { Text("Add spending") } }) }
    items(projectSpends(p), key = { "s" + it.id }) { s -> SpendRow(s) }
    item(key = "photos") { ProjectPhotos(p) }
    childSection("People", p.links("contractors").mapNotNull { Repo.get(it) }, null) {}
    childSection("Rooms", p.links("rooms").mapNotNull { Repo.get(it) }, null) {}
    childSection("Assets", p.links("assets").mapNotNull { Repo.get(it) }, null) {}
    childSection("Documents and quotes", Repo.of(T.DOCUMENT).filter { it.link("project") == p.id }, "Add") { Nav.edit(T.DOCUMENT, prefill = mapOf("projectId" to p.id, "type" to "Invoice")) }
}

@Composable
fun SpendRow(s: Rec) {
    val owed = Split.outstanding(s)
    Glass {
        Row { Text(s.s("note").ifBlank { "Spending" }, modifier = Modifier.weight(1f)); Text(Fmt.money(s.d("amount"))) }
        Text(listOfNotNull(Fmt.short(s.day("date")), s.s("paidByUid").ifBlank { null }?.let { "paid by " + Repo.memberName(it) }, privacy(s)).joinToString(" · "), color = P.muted, fontSize = 13.sp)
        SharesList(s)
        if (owed.isEmpty() && s.s("sharesJSON").isNotBlank()) Text("All paid back", color = P.done, fontSize = 13.sp)
    }
}

/** Each person's share with a tick for "paid back". No red: owing is not overdue. */
@Composable
fun SharesList(r: Rec) {
    val payer = r.s("paidByUid"); if (payer.isBlank()) return
    val repaid = SplitJSON.strings(r.s("repaidJSON"))
    SplitJSON.amounts(r.s("sharesJSON")).forEach { (u, a) ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(Repo.memberName(u), modifier = Modifier.weight(1f), fontSize = 14.sp)
            Text(Fmt.money(a), fontSize = 14.sp, color = P.muted)
            if (u == payer) Text("  paid", color = P.done, fontSize = 13.sp)
            else Checkbox(repaid.containsKey(u), { Split.setRepaid(r, u, it) })
        }
    }
}

@Composable
fun ProjectPhotos(p: Rec) {
    val context = LocalContext.current
    var stage by remember { mutableStateOf("Before") }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        val name = uri?.let { Repo.importFile(context, it, "jpg") } ?: return@rememberLauncherForActivityResult
        val id = Repo.save(T.PHOTO, Repo.newId(), p.vis, mapOf("fileName" to name, "caption" to "", "isAfter" to (stage == "After"), "projectId" to p.id))
        Repo.get(id)?.let { Repo.upload(it, name) }
    }
    val photos = Repo.of(T.PHOTO).filter { it.link("project") == p.id }
    Column {
        SectionTitle("Before and after", trailing = {
            Row {
                TextButton(onClick = { stage = "Before"; pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text("+ Before") }
                TextButton(onClick = { stage = "After"; pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text("+ After") }
            }
        })
        for ((label, list) in listOf("Before" to photos.filter { !it.b("isAfter") }, "After" to photos.filter { it.b("isAfter") })) {
            if (list.isEmpty()) continue
            Text(label, color = P.muted, fontSize = 13.sp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) { items(list, key = { it.id }) { ph -> LocalImage(ph, ph.s("fileName"), Modifier.size(110.dp)) } }
        }
    }
}

// ------------------------------------------------------------------ Person

fun LazyListScope.personBody(p: Rec) {
    item {
        val context = LocalContext.current
        Glass(tint = P.people) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p.s("kindRaw").ifBlank { "Household" }, color = P.muted, modifier = Modifier.weight(1f))
                if (p.s("memberUid").isNotBlank()) Pill("Member", P.accent)
            }
            KV("Company", p.s("company")); KV("Role", p.s("role")); KV("Phone", p.s("phoneNumber")); KV("Email", p.s("email")); KV("Notes", p.s("notes"))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                val phone = p.s("phoneNumber"); val email = p.s("email")
                fun go(i: Intent) = runCatching { context.startActivity(i) }
                if (phone.isNotBlank()) {
                    OutlinedButton(onClick = { go(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phone"))) }) { Text("Text") }
                    OutlinedButton(onClick = { go(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))) }) { Text("Call") }
                }
                if (email.isNotBlank()) OutlinedButton(onClick = { go(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email"))) }) { Text("Email") }
            }
        }
    }
    childSection("Jobs for them", Repo.of(T.TASK).filter { it.link("assignee") == p.id }, "Assign a job") { Nav.edit(T.TASK, prefill = mapOf("assigneeId" to p.id)) }
    childSection("Projects", Repo.of(T.PROJECT).filter { p.id in it.links("contractors") }, null) {}
    childSection("Bills", Repo.of(T.BILL).filter { it.link("provider") == p.id }, null) {}
    childSection("Maintenance plans", Repo.of(T.PLAN).filter { it.link("person") == p.id }, null) {}
    childSection("Work done", Repo.of(T.MAINTENANCE).filter { it.link("person") == p.id }.sortedByDescending { it.t("date") }, null) {}
    val ticked = Repo.of(T.COMPLETION).filter { it.link("person") == p.id || (p.s("memberUid").isNotBlank() && it.s("completedByUid") == p.s("memberUid")) }.sortedByDescending { it.t("completedAt") }.take(20)
    if (ticked.isNotEmpty()) {
        item { SectionTitle("Ticked off") }
        items(ticked, key = { "t" + it.id }) { c -> ItemRow(Repo.get(c.link("task"))?.title ?: "Job", listOfNotNull(Fmt.short(c.day("completedAt")), Fmt.time(c.t("completedAt")), c.s("note").ifBlank { null }).joinToString(" · "), P.done, Icons.Filled.CheckCircle) }
    }
}

// ------------------------------------------------------------------ To-Do job

fun LazyListScope.taskBody(t: Rec) {
    item {
        Glass(tint = P.todo) {
            KV("Repeats", Tasks.summary(t)); KV("Time of day", Tasks.timeOfDay(t)); KV("For", Repo.get(t.link("assignee"))?.title)
            KV("Project", Repo.get(t.link("project"))?.title); KV("Room", Repo.get(t.link("room"))?.title); KV("Asset", Repo.get(t.link("asset"))?.title); KV("Notes", t.s("notes"))
            val today = Dates.today
            if (Tasks.appears(t, today)) {
                val done = Tasks.isDone(t, today)
                val item = TodoFeed.items(today).firstOrNull { it.id == "task-${t.id}" }
                if (item != null) Button(onClick = { if (done) TodoFeed.uncomplete(item, today) else TodoFeed.complete(item, today) }, modifier = Modifier.padding(top = 8.dp)) { Text(if (done) "Undo today" else "Mark done today") }
            }
        }
    }
    item { ChecklistEditor(t) }
    val hist = Tasks.completions(t).sortedByDescending { it.t("completedAt") }
    item { SectionTitle("History") }
    if (hist.isEmpty()) item { Text("Not done yet.", color = P.faint) }
    items(hist, key = { "h" + it.id }) { c ->
        val who = Repo.get(c.link("person"))?.title ?: Repo.memberName(c.s("completedByUid").ifBlank { null })
        ItemRow(Fmt.day(c.day("occurrenceDate") ?: Dates.today), listOfNotNull("at " + Fmt.time(c.t("completedAt")), who, c.s("note").ifBlank { null }).joinToString(" · "), P.done, Icons.Filled.CheckCircle)
    }
}

@Composable
fun ChecklistEditor(t: Rec) {
    var new by remember { mutableStateOf("") }
    val list = Tasks.checklist(t); val today = Dates.today
    Column {
        SectionTitle("Checklist")
        list.forEach { c ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(c.day("checkedOn") == today, { on -> Repo.update(c, mapOf("checkedOn" to if (on) Dates.ts(today) else null)) })
                Text(c.title, modifier = Modifier.weight(1f))
                IconButton(onClick = { Repo.delete(c) }) { Icon(Icons.Filled.Close, "Remove", tint = P.faint) }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(new, { new = it }, label = { Text("Add a step") }, singleLine = true, modifier = Modifier.weight(1f))
            TextButton(enabled = new.isNotBlank(), onClick = {
                Repo.save(T.CHECK, Repo.newId(), t.vis, mapOf("title" to new.trim(), "order" to (list.maxOfOrNull { it.i("order") } ?: -1) + 1, "checkedOn" to null, "taskId" to t.id)); new = ""
            }) { Text("Add") }
        }
    }
}
