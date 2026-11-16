package com.voidhome.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voidhome.app.data.*
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

object P {
    val muted = Color(0xFF8C80A6); val faint = Color(0xFF6B6185); val accent = Color(0xFF8C73F2)
    val calm = Color(0xFF73B3D9); val done = Color(0xFF73CC99); val amber = Color(0xFFF2BF66)
    val billOverdue = Color(0xFFF26B73); val bills = Color(0xFF4DA680); val rooms = Color(0xFF4D80D9)
    val assets = Color(0xFFA666BF); val documents = Color(0xFF4099BF); val warranties = Color(0xFFBF8066)
    val maintenance = Color(0xFF59999E); val projects = Color(0xFF8080D9); val people = Color(0xFF9973BF)
    val todo = Color(0xFF808CD9); val bg1 = Color(0xFF05030F); val bg2 = Color(0xFF0D051A); val bg3 = Color(0xFF02010A)
    val card = Color(0x14FFFFFF); val stroke = Color(0x1FFFFFFF)
    fun forType(t: String) = when (t) {
        T.ROOM -> rooms; T.ASSET -> assets; T.DOCUMENT -> documents; T.WARRANTY -> warranties
        T.PLAN, T.MAINTENANCE -> maintenance; T.PROJECT -> projects; T.PERSON -> people; T.BILL, T.PAYMENT -> bills
        T.TASK -> todo; else -> accent
    }
    fun icon(t: String): ImageVector = when (t) {
        T.ROOM -> Icons.Filled.GridView; T.ASSET -> Icons.Filled.ViewInAr; T.DOCUMENT -> Icons.Filled.Description
        T.WARRANTY -> Icons.Filled.Shield; T.PLAN, T.MAINTENANCE -> Icons.Filled.Build; T.PROJECT -> Icons.Filled.Handyman
        T.PERSON -> Icons.Filled.Person; T.BILL, T.PAYMENT -> Icons.Filled.CreditCard; T.TASK -> Icons.Filled.Checklist
        else -> Icons.Filled.Home
    }
}

@Composable
fun VoidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = P.accent, secondary = P.calm, background = P.bg1, surface = Color(0xFF130C22),
            surfaceContainer = Color(0xFF17102A), surfaceContainerHigh = Color(0xFF1D1533), onSurface = Color.White,
            onBackground = Color.White, surfaceVariant = Color(0xFF221A38), onSurfaceVariant = P.muted, error = P.billOverdue,
        ),
        content = content,
    )
}

@Composable
fun VoidBackground(content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(P.bg1, P.bg2, Color(0xFF080414), P.bg3))), content = content)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Page(
    title: String,
    onBack: (() -> Unit)?,
    tint: Color = P.accent,
    actions: @Composable RowScope.() -> Unit = {},
    fab: (@Composable () -> Unit)? = null,
    header: @Composable ColumnScope.() -> Unit = {},
    content: LazyListScope.() -> Unit,
) {
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(title, fontWeight = FontWeight.Light, letterSpacing = 1.sp) },
                navigationIcon = { if (onBack != null) IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                actions = actions,
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = Color.White),
            )
        },
        floatingActionButton = { fab?.invoke() },
    ) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            header()
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp, 4.dp, 16.dp, 96.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
        }
    }
}

@Composable
fun AddFab(label: String = "Add", tint: Color = P.accent, onClick: () -> Unit) {
    ExtendedFloatingActionButton(onClick = onClick, containerColor = tint, contentColor = Color.White, icon = { Icon(Icons.Filled.Add, null) }, text = { Text(label) })
}

@Composable
fun Glass(modifier: Modifier = Modifier, tint: Color? = null, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier.fillMaxWidth().clip(shape)
            .background(if (tint != null) Brush.linearGradient(listOf(tint.copy(alpha = 0.18f), P.card)) else Brush.linearGradient(listOf(P.card, P.card)))
            .border(BorderStroke(1.dp, P.stroke), shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(14.dp),
        content = content,
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ItemRow(
    title: String,
    subtitle: String? = null,
    tint: Color = P.accent,
    icon: ImageVector? = null,
    trailing: (@Composable () -> Unit)? = null,
    titleColor: Color = Color.White,
    onLongClick: (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(P.card).border(BorderStroke(1.dp, P.stroke), shape)
            .combinedClickable(enabled = onClick != null || onLongClick != null, onClick = { onClick?.invoke() }, onLongClick = onLongClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(tint.copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, color = titleColor, fontSize = 16.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (!subtitle.isNullOrBlank()) Text(subtitle, color = P.muted, fontSize = 13.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
        trailing?.let { Spacer(Modifier.width(8.dp)); it() }
    }
}

@Composable
fun SectionTitle(text: String, tint: Color = P.muted, trailing: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(top = 10.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text.uppercase(), color = tint, fontSize = 12.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        trailing?.invoke()
    }
}

@Composable
fun Pill(text: String, color: Color) {
    Text(text, color = color, fontSize = 12.sp, modifier = Modifier.clip(RoundedCornerShape(50)).background(color.copy(alpha = 0.16f)).padding(horizontal = 9.dp, vertical = 3.dp))
}

@Composable
fun Empty(text: String) {
    Text(text, color = P.muted, modifier = Modifier.fillMaxWidth().padding(24.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}

@Composable
fun KV(label: String, value: String?) {
    if (value.isNullOrBlank()) return
    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
        Text(label, color = P.muted, modifier = Modifier.width(120.dp), fontSize = 14.sp)
        Text(value, color = Color.White, fontSize = 14.sp)
    }
}

@Composable
fun Bar(fraction: Float, color: Color, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(8.dp).clip(CircleShape).background(Color(0x22FFFFFF))) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).fillMaxHeight().clip(CircleShape).background(color))
    }
}

/** Just me / Everyone. Only the creator may change it. */
@Composable
fun VisToggle(vis: String, enabled: Boolean, onChange: (String) -> Unit) {
    Column {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            SegmentedButton(selected = vis == Vis.ME, onClick = { onChange(Vis.ME) }, enabled = enabled, shape = SegmentedButtonDefaults.itemShape(0, 2),
                icon = { Icon(Icons.Filled.Lock, null, Modifier.size(16.dp)) }) { Text("Just me") }
            SegmentedButton(selected = vis == Vis.HOUSE, onClick = { onChange(Vis.HOUSE) }, enabled = enabled, shape = SegmentedButtonDefaults.itemShape(1, 2),
                icon = { Icon(Icons.Filled.Groups, null, Modifier.size(16.dp)) }) { Text("Everyone") }
        }
        if (!enabled) Text("Only the person who added this can change who sees it.", color = P.faint, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
fun ConfirmDelete(what: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Delete $what?") },
        text = { Text("This removes it for everyone who can see it.") },
        confirmButton = { TextButton(onClick = { onConfirm(); onDismiss() }) { Text("Delete", color = P.billOverdue) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

// ------------------------------------------------------------------ form fields

@Composable
fun FText(label: String, value: String, multiline: Boolean = false, keyboard: KeyboardType = KeyboardType.Text, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = onChange, label = { Text(label) }, singleLine = !multiline, minLines = if (multiline) 3 else 1,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard), modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun FNumber(label: String, value: Double?, onChange: (Double?) -> Unit) {
    var text by remember { mutableStateOf(value?.let { Fmt.num(it) } ?: "") }
    FText(label, text, keyboard = KeyboardType.Decimal) { t -> text = t; onChange(t.replace(",", ".").toDoubleOrNull()) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FDate(label: String, value: LocalDate?, optional: Boolean = true, onChange: (LocalDate?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        OutlinedButton(onClick = { open = true }, modifier = Modifier.weight(1f)) {
            Icon(Icons.Filled.CalendarMonth, null, Modifier.size(18.dp)); Spacer(Modifier.width(8.dp))
            Text(if (value == null) "$label: not set" else "$label: ${Fmt.long(value)}")
        }
        if (optional && value != null) IconButton(onClick = { onChange(null) }) { Icon(Icons.Filled.Close, "Clear") }
    }
    if (open) {
        val st = rememberDatePickerState(initialSelectedDateMillis = (value ?: Dates.today).atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = { TextButton(onClick = { st.selectedDateMillis?.let { onChange(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }; open = false }) { Text("OK") } },
            dismissButton = { TextButton(onClick = { open = false }) { Text("Cancel") } },
        ) { DatePicker(st) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FChoice(label: String, value: String, options: List<String>, display: (String) -> String = { it.ifBlank { "None" } }, onChange: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = open, onExpandedChange = { open = it }) {
        OutlinedTextField(
            value = display(value), onValueChange = {}, readOnly = true, label = { Text(label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(open) },
            modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { o -> DropdownMenuItem(text = { Text(display(o)) }, onClick = { onChange(o); open = false }) }
        }
    }
}

/** Pick one record (or none) of a type. */
@Composable
fun FLink(label: String, type: String, value: String?, filter: (Rec) -> Boolean = { true }, onChange: (String?) -> Unit) {
    val recs = Repo.of(type).filter(filter).sortedBy { it.title.lowercase() }
    FChoice(label, value ?: "", listOf("") + recs.map { it.id }, display = { id -> if (id.isBlank()) "None" else Repo.get(id)?.title ?: "Unknown" }) { onChange(it.ifBlank { null }) }
}

/** Pick several records of a type. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FLinks(label: String, type: String, value: List<String>, onChange: (List<String>) -> Unit) {
    val recs = Repo.of(type).sortedBy { it.title.lowercase() }
    Column {
        Text(label, color = P.muted, fontSize = 13.sp)
        if (recs.isEmpty()) Text("Nothing to link yet", color = P.faint, fontSize = 13.sp)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            recs.forEach { r ->
                val on = r.id in value
                FilterChip(selected = on, onClick = { onChange(if (on) value - r.id else value + r.id) }, label = { Text(r.title) })
            }
        }
    }
}

@Composable
fun FSwitch(label: String, value: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f)); Switch(checked = value, onCheckedChange = onChange)
    }
}
