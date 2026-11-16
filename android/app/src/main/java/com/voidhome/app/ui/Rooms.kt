package com.voidhome.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.RotateRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voidhome.app.data.*
import java.util.Locale
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// Floor plan for Android, drawn the same way as the iOS FloorplanCanvas (RoomsListView.swift):
// thick walls that join where rooms touch, door gaps with leaves and dashed swing arcs, room names, m²,
// item dots, width/depth lines, a scale bar, zoom and pan. Reads the same Firestore room/roomPart/door
// fields as iOS (planX/planY in metres, rotation in quarter turns, door edge/position/opensLeft/opensInward/isDoubleDoor).

private const val PPM = 35f            // points per metre at zoom 1 (FloorplanGeometry.pointsPerMetre)
private const val WALL_M = 0.15f       // wall thickness in metres
private const val GRID_STEP = 0.1      // metres, drag snap when no edge is near
private const val SNAP_DP = 12f        // edge snap distance on screen
private val WallColor = Color(0xFFDBDBEB)
private val LeafColor = Color(0xFFD9D9E6)
private val ArcColor = Color(0xFF999AAD)
private val DimColor = Color(0xFF9EB8F2)
private val GuideColor = Color(0xFF73B3FF)

fun floorDisplay(n: Int): String = when {
    n == 0 -> "Ground"; n == 1 -> "1st Floor"; n == 2 -> "2nd Floor"; n == 3 -> "3rd Floor"
    n > 0 -> "${n}th Floor"; n == -1 -> "Basement"; else -> "Floor $n"
}

private fun fmt1(v: Double) = String.format(Locale.UK, "%.1f", v)
private fun fmt2(v: Double) = String.format(Locale.UK, "%.2f", v).trimEnd('0').trimEnd('.')

/** Width of the canvas (in points) the legacy 0–1 positions were relative to; set when the plan is laid out. */
private var legacyCanvas = Size(390f, 600f)

/** Room centre in metres. Rooms saved before metre positions existed fall back to xPosition/yPosition, as on iOS. */
private fun centreOf(room: Rec): Pair<Double, Double> {
    val px = room.dn("planX"); val py = room.dn("planY")
    if (px != null && py != null) return px to py
    val lx = room.dn("xPosition") ?: 0.5; val ly = room.dn("yPosition") ?: 0.5
    return (lx - 0.5) * legacyCanvas.width / PPM to (ly - 0.5) * legacyCanvas.height / PPM
}

private fun worldRectsOf(room: Rec, c: Pair<Double, Double> = centreOf(room)) = Plan.worldRects(room, c)

/** Everything in the room: things linked straight to it and things linked to items in it. */
object RoomLinks {
    fun assets(room: Rec) = Repo.of(T.ASSET).filter { it.link("room") == room.id }.sortedBy { it.title.lowercase() }
    fun documents(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        return Repo.of(T.DOCUMENT).filter { it.link("room") == room.id || it.link("asset") in assetIds }.sortedBy { it.title.lowercase() }
    }
    fun warranties(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        return Repo.of(T.WARRANTY).filter { it.link("asset") in assetIds }
    }
    fun plans(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        return Repo.of(T.PLAN).filter { it.link("room") == room.id || it.link("asset") in assetIds }.sortedBy { it.title.lowercase() }
    }
    fun logs(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        return Repo.of(T.MAINTENANCE).filter { it.link("room") == room.id || it.link("asset") in assetIds }
            .sortedByDescending { it.t("date") }
    }
    fun projectsDirect(room: Rec) = Repo.of(T.PROJECT).filter { room.id in it.links("rooms") }
    fun projectsViaItems(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        val direct = projectsDirect(room).map { it.id }.toSet()
        return Repo.of(T.PROJECT).filter { it.id !in direct && it.links("assets").any { a -> a in assetIds } }
    }
    fun tasks(room: Rec): List<Rec> {
        val assetIds = assets(room).map { it.id }.toSet()
        return Repo.of(T.TASK).filter { it.link("room") == room.id || it.link("asset") in assetIds }.sortedBy { it.title.lowercase() }
    }
    fun itemCount(room: Rec) = assets(room).size
}

// ------------------------------------------------------------------ Drawing

private class DoorGeo(val opening: Rect, val leaves: List<Triple<Offset, Offset, Offset>>, val leafLength: Float)

/** Port of FloorplanCanvas.doorGeometry: everything in room-local points (scale = points per metre). */
private fun doorGeometry(door: Rec, host: Rect, scale: Float, t: Float): DoorGeo {
    val edge = door.s("edge").lowercase()
    val horizontal = edge == "top" || edge == "bottom"
    val edgeLen = if (horizontal) host.width else host.height
    val width = min(Plan.DOOR_WIDTH.toFloat() * scale * (if (door.b("isDoubleDoor")) 1.6f else 1f), edgeLen * 0.9f)
    val pos = (door.dn("position") ?: 0.5).toFloat().coerceIn(0f, 1f)
    val along = (pos * edgeLen).coerceIn(width / 2, max(width / 2, edgeLen - width / 2))
    val start = (if (horizontal) host.left else host.top) + along - width / 2
    val end = start + width
    val line = when (edge) { "top" -> host.top; "bottom" -> host.bottom; "left" -> host.left; else -> host.right }
    val opening = if (horizontal) Rect(start, line - t / 2 - 1, end, line + t / 2 + 1) else Rect(line - t / 2 - 1, start, line + t / 2 + 1, end)
    val sign = when (edge) { "top", "left" -> 1f; else -> -1f } * (if (door.data["opensInward"] as? Boolean ?: true) 1f else -1f)
    fun pt(a: Float, perp: Float) = if (horizontal) Offset(a, line + perp) else Offset(line + perp, a)
    val opensLeft = door.data["opensLeft"] as? Boolean ?: true
    val leaves = mutableListOf<Triple<Offset, Offset, Offset>>()
    val leafLength: Float
    if (door.b("isDoubleDoor")) {
        leafLength = width / 2
        leaves += Triple(pt(start, 0f), pt(start + leafLength, 0f), pt(start, sign * leafLength))
        leaves += Triple(pt(end, 0f), pt(end - leafLength, 0f), pt(end, sign * leafLength))
    } else {
        leafLength = width
        val hinge = if (opensLeft) start else end
        val free = if (opensLeft) end else start
        leaves += Triple(pt(hinge, 0f), pt(free, 0f), pt(hinge, sign * leafLength))
    }
    return DoorGeo(opening, leaves, leafLength)
}

private fun localRectsPt(room: Rec, scale: Float): List<Rect> = Plan.localRects(room).map {
    Rect(it.minX.toFloat() * scale, it.minY.toFloat() * scale, it.maxX.toFloat() * scale, it.maxY.toFloat() * scale)
}

private fun outlinePath(rects: List<Rect>): Path {
    var acc: Path? = null
    for (r in rects) {
        val p = Path().apply { addRect(r) }
        acc = if (acc == null) p else Path.combine(PathOperation.Union, acc, p)
    }
    return acc ?: Path()
}

private fun hostRectPt(door: Rec, room: Rec, scale: Float): Rect {
    val r = Plan.hostRect(door, room)
    return Rect(r.minX.toFloat() * scale, r.minY.toFloat() * scale, r.maxX.toFloat() * scale, r.maxY.toFloat() * scale)
}

/** Moves the draw origin to the room centre (in plan points) and turns it by its quarter turns. */
private inline fun DrawScope.inRoom(room: Rec, c: Pair<Double, Double>, block: DrawScope.() -> Unit) {
    withTransform({
        translate(c.first.toFloat() * PPM, c.second.toFloat() * PPM)
        rotate(Plan.quarterTurns(room.d("rotation")) * 90f, Offset.Zero)
    }) { block() }
}

private fun DrawScope.drawWallsAndDoors(rooms: List<Rec>, centres: Map<String, Pair<Double, Double>>, sel: String?, editing: Boolean, selectedDoor: String?) {
    val t = max(2f, WALL_M * PPM)
    // Floors first, under everything.
    for (room in rooms) {
        val c = centres[room.id] ?: continue
        val rects = localRectsPt(room, PPM)
        val shared = room.s("ownerUid").isBlank()
        val fill = when {
            room.id == sel -> P.rooms.copy(alpha = 0.32f)
            shared -> Color(0xFF1C1A2E)
            else -> Color(0xFF241C38)
        }
        inRoom(room, c) {
            rects.forEach { drawRect(fill, it.topLeft, it.size) }
            if (room.id == sel) drawPath(outlinePath(rects), P.rooms, style = Stroke(width = t + 3f, join = StrokeJoin.Miter))
        }
    }
    // Walls on their own layer so door openings can cut them, and touching walls merge into one.
    drawIntoCanvas { it.saveLayer(Rect(Offset.Zero, size).inflate(4000f), Paint()) }
    for (room in rooms) {
        val c = centres[room.id] ?: continue
        inRoom(room, c) { drawPath(outlinePath(localRectsPt(room, PPM)), WallColor, style = Stroke(width = t, join = StrokeJoin.Miter)) }
    }
    for (room in rooms) {
        val c = centres[room.id] ?: continue
        inRoom(room, c) {
            for (door in Plan.doors(room)) {
                val g = doorGeometry(door, hostRectPt(door, room, PPM), PPM, t)
                drawRect(Color.Black, g.opening.topLeft, g.opening.size, blendMode = BlendMode.Clear)
            }
        }
    }
    drawIntoCanvas { it.restore() }
    // Door leaves and dashed swing arcs.
    val dash = PathEffect.dashPathEffect(floatArrayOf(3f, 2f))
    for (room in rooms) {
        val c = centres[room.id] ?: continue
        inRoom(room, c) {
            for (door in Plan.doors(room)) {
                val g = doorGeometry(door, hostRectPt(door, room, PPM), PPM, t)
                val hot = editing && door.id == selectedDoor
                for ((hinge, free, open) in g.leaves) {
                    drawLine(if (hot) P.amber else LeafColor, hinge, open, strokeWidth = 1.5f)
                    val a0 = Math.toDegrees(atan2((free.y - hinge.y).toDouble(), (free.x - hinge.x).toDouble())).toFloat()
                    val a1 = Math.toDegrees(atan2((open.y - hinge.y).toDouble(), (open.x - hinge.x).toDouble())).toFloat()
                    var sweep = a1 - a0
                    while (sweep > 180f) sweep -= 360f
                    while (sweep < -180f) sweep += 360f
                    val r = g.leafLength
                    drawArc(if (hot) P.amber else ArcColor, a0, sweep, false, Offset(hinge.x - r, hinge.y - r), Size(2 * r, 2 * r),
                        style = Stroke(width = 0.8f, pathEffect = dash))
                }
            }
        }
    }
}

private fun DrawScope.drawLabels(rooms: List<Rec>, centres: Map<String, Pair<Double, Double>>, tm: TextMeasurer, d: Density) {
    fun sp(pt: Float) = with(d) { pt.toSp() }
    for (room in rooms) {
        val c = centres[room.id] ?: continue
        val cx = c.first.toFloat() * PPM; val cy = c.second.toFloat() * PPM
        val name = tm.measure(room.title.ifBlank { "Room" }, TextStyle(color = Color.White, fontSize = sp(11f), fontWeight = FontWeight.SemiBold), maxLines = 1)
        val area = tm.measure("${fmt1(Plan.area(room))} m²", TextStyle(color = P.muted, fontSize = sp(9f)), maxLines = 1)
        val count = RoomLinks.itemCount(room)
        val dotRow = if (count > 6) tm.measure("+${count - 6}", TextStyle(color = P.muted, fontSize = sp(8f))) else null
        val dotsH = if (count > 0) 8f else 0f
        val total = name.size.height + area.size.height + dotsH
        var y = cy - total / 2
        drawText(name, topLeft = Offset(cx - name.size.width / 2, y)); y += name.size.height
        drawText(area, topLeft = Offset(cx - area.size.width / 2, y)); y += area.size.height
        if (count > 0) {
            val n = min(count, 6)
            val rowW = n * 6f + (dotRow?.size?.width?.plus(3f) ?: 0f)
            var x = cx - rowW / 2
            repeat(n) { drawCircle(P.assets, 2.2f, Offset(x + 2.5f, y + 4f)); x += 6f }
            dotRow?.let { drawText(it, topLeft = Offset(x + 2f, y + 4f - it.size.height / 2)) }
        }
    }
}

private fun DrawScope.drawDimension(a: Offset, b: Offset, label: String, tm: TextMeasurer, d: Density) {
    drawLine(DimColor, a, b, strokeWidth = 1f)
    val horizontal = abs(a.y - b.y) < 0.5f
    val tick = 4f
    for (p in listOf(a, b)) {
        if (horizontal) drawLine(DimColor, Offset(p.x, p.y - tick), Offset(p.x, p.y + tick), strokeWidth = 1f)
        else drawLine(DimColor, Offset(p.x - tick, p.y), Offset(p.x + tick, p.y), strokeWidth = 1f)
    }
    val text = tm.measure(label, TextStyle(color = DimColor, fontSize = with(d) { 8.5f.toSp() }, fontWeight = FontWeight.Medium))
    val mid = Offset((a.x + b.x) / 2, (a.y + b.y) / 2)
    val tl = Offset(mid.x - text.size.width / 2, mid.y - text.size.height / 2)
    drawRoundRect(Color(0xE60D0A1A), Offset(tl.x - 3, tl.y - 1), Size(text.size.width + 6f, text.size.height + 2f), CornerRadius(3f))
    drawText(text, topLeft = tl)
}

private fun DrawScope.drawMeasurements(rooms: List<Rec>, centres: Map<String, Pair<Double, Double>>, sel: Rec?, tm: TextMeasurer, d: Density) {
    val rects = if (sel != null) worldRectsOf(sel, centres[sel.id] ?: centreOf(sel)) else rooms.flatMap { worldRectsOf(it, centres[it.id] ?: centreOf(it)) }
    val b = Plan.bounds(rects) ?: return
    val off = 14f
    val l = b.minX.toFloat() * PPM; val r = b.maxX.toFloat() * PPM; val top = b.minY.toFloat() * PPM; val bot = b.maxY.toFloat() * PPM
    drawDimension(Offset(l, top - off), Offset(r, top - off), "${fmt2(b.w)} m", tm, d)
    drawDimension(Offset(l - off, top), Offset(l - off, bot), "${fmt2(b.h)} m", tm, d)
}

// ------------------------------------------------------------------ Snap and resolve (DraggableRoom.resolve on iOS)

private data class Drop(val c: Pair<Double, Double>, val lineX: Double?, val lineY: Double?)

private fun resolveDrop(room: Rec, proposed: Pair<Double, Double>, others: List<Rec>, centres: Map<String, Pair<Double, Double>>, threshold: Double, lastValid: Pair<Double, Double>): Drop {
    var cx = proposed.first; var cy = proposed.second
    val otherRects = others.map { worldRectsOf(it, centres[it.id] ?: centreOf(it)) }
    val pieces = otherRects.flatten()
    var bestX: Pair<Double, Double>? = null; var bestY: Pair<Double, Double>? = null
    for (m in worldRectsOf(room, cx to cy)) for (o in pieces) {
        val yNear = min(m.maxY, o.maxY) - max(m.minY, o.minY) > -1.0
        val xNear = min(m.maxX, o.maxX) - max(m.minX, o.minX) > -1.0
        if (yNear) for ((mine, theirs) in listOf(m.minX to o.maxX, m.maxX to o.minX, m.minX to o.minX, m.maxX to o.maxX)) {
            val dd = theirs - mine
            if (abs(dd) < threshold && abs(dd) < abs(bestX?.first ?: Double.MAX_VALUE)) bestX = dd to theirs
        }
        if (xNear) for ((mine, theirs) in listOf(m.minY to o.maxY, m.maxY to o.minY, m.minY to o.minY, m.maxY to o.maxY)) {
            val dd = theirs - mine
            if (abs(dd) < threshold && abs(dd) < abs(bestY?.first ?: Double.MAX_VALUE)) bestY = dd to theirs
        }
    }
    bestX?.let { cx += it.first } ?: run { cx = (cx / GRID_STEP).roundToInt() * GRID_STEP }
    bestY?.let { cy += it.first } ?: run { cy = (cy / GRID_STEP).roundToInt() * GRID_STEP }
    repeat(4) {
        val rects = worldRectsOf(room, cx to cy)
        val pair = rects.firstNotNullOfOrNull { r -> pieces.firstOrNull { o -> Plan.overlaps(listOf(r), listOf(o)) }?.let { r to it } } ?: return@repeat
        val (m, o) = pair
        val push = listOf(o.maxX - m.minX to 0.0, o.minX - m.maxX to 0.0, 0.0 to o.maxY - m.minY, 0.0 to o.minY - m.maxY)
            .minBy { hypot(it.first, it.second) }
        cx += push.first; cy += push.second
    }
    val final = worldRectsOf(room, cx to cy)
    if (otherRects.any { Plan.overlaps(final, it) }) return Drop(lastValid, null, null)
    return Drop(cx to cy, bestX?.second, bestY?.second)
}

private fun saveCentre(room: Rec, c: Pair<Double, Double>, extra: Map<String, Any?> = emptyMap()) {
    Repo.update(room, room.data + mapOf("planX" to c.first, "planY" to c.second) + extra)
}

// ------------------------------------------------------------------ Rooms page

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomsScreen(focus: String? = null) {
    val allRooms = Repo.of(T.ROOM)
    val floorRecs = Repo.of(T.FLOOR)
    val floors = (floorRecs.map { it.i("floorNumber") } + allRooms.map { it.i("floorNumber") } + 0).distinct().sorted()
    val focusRoom = Repo.get(focus)?.takeIf { it.type == T.ROOM }
    var floor by remember { mutableIntStateOf(focusRoom?.i("floorNumber") ?: 0) }
    var planMode by remember { mutableStateOf(true) }
    var editing by remember { mutableStateOf(false) }
    var selectedId by remember { mutableStateOf(focusRoom?.id) }
    var zoom by remember { mutableFloatStateOf(1f) }
    var pan by remember { mutableStateOf(Offset.Zero) }   // in px
    var dragId by remember { mutableStateOf<String?>(null) }
    var dragRaw by remember { mutableStateOf(0.0 to 0.0) }
    var guide by remember { mutableStateOf<Drop?>(null) }
    var showAddFloor by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf<Rec?>(null) }
    var menu by remember { mutableStateOf(false) }
    var canvasPx by remember { mutableStateOf(Size.Zero) }
    val density = LocalDensity.current
    val tm = rememberTextMeasurer()

    val rooms = allRooms.filter { it.i("floorNumber") == floor }.sortedBy { it.t("createdAt") }
    val sel = rooms.firstOrNull { it.id == selectedId }
    val scalePx = zoom * density.density   // px per plan point

    // Live centres, with the room being dragged at its snapped spot.
    val centres = rooms.associate { r ->
        r.id to if (r.id == dragId) (guide?.c ?: dragRaw) else centreOf(r)
    }

    fun fitAll() {
        val all = rooms.flatMap { worldRectsOf(it) }
        val b = Plan.bounds(all) ?: return
        if (canvasPx.width <= 0f) return
        val wPt = canvasPx.width / density.density; val hPt = canvasPx.height / density.density
        zoom = min(wPt / ((b.w.toFloat() + 2f) * PPM), hPt / ((b.h.toFloat() + 2f) * PPM)).coerceIn(0.3f, 4f)
        val mx = (b.minX + b.w / 2).toFloat(); val my = (b.minY + b.h / 2).toFloat()
        pan = Offset(-mx * PPM * zoom * density.density, -my * PPM * zoom * density.density)
    }
    fun focusOn(room: Rec) {
        val c = centreOf(room)
        pan = Offset(-c.first.toFloat() * PPM * zoom * density.density, -c.second.toFloat() * PPM * zoom * density.density)
    }

    LaunchedEffect(canvasPx, floor) {
        if (canvasPx.width > 0f) {
            if (focusRoom != null && focusRoom.i("floorNumber") == floor) focusOn(focusRoom) else fitAll()
        }
    }

    val latestRooms by rememberUpdatedState(rooms)
    val latestCentres by rememberUpdatedState(centres)

    Page(
        title = "Rooms",
        onBack = if (Nav.stack.size > 1) ({ Nav.back() }) else null,
        tint = P.rooms,
        actions = {
            IconButton(onClick = { planMode = !planMode; editing = false }) {
                Icon(if (planMode) Icons.AutoMirrored.Filled.List else Icons.Filled.GridView, if (planMode) "List" else "Floor plan")
            }
            if (planMode) {
                IconButton(onClick = { editing = !editing }) { Icon(if (editing) Icons.Filled.Check else Icons.Filled.Edit, if (editing) "Done" else "Edit plan") }
                Box {
                    IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "More") }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(text = { Text("Show all rooms") }, onClick = { menu = false; fitAll() })
                        DropdownMenuItem(text = { Text("Tidy to grid") }, onClick = {
                            menu = false
                            val step = 0.5
                            for (room in rooms) {
                                val old = centreOf(room)
                                val snapped = (old.first / step).roundToInt() * step to (old.second / step).roundToInt() * step
                                val others = rooms.filter { it.id != room.id }.map { worldRectsOf(it) }
                                if (others.none { Plan.overlaps(worldRectsOf(room, snapped), it) }) saveCentre(room, snapped)
                            }
                        })
                        DropdownMenuItem(text = { Text("Untangle overlaps") }, onClick = {
                            menu = false
                            val placed = mutableListOf<List<PRect>>()
                            for (room in rooms) {
                                var rects = worldRectsOf(room)
                                if (placed.any { Plan.overlaps(rects, it) }) {
                                    val free = Plan.freeCenter(centreOf(room), Plan.localRects(room), Plan.quarterTurns(room.d("rotation")), placed, 0.25)
                                    saveCentre(room, free); rects = worldRectsOf(room, free)
                                }
                                placed += rects
                            }
                        })
                    }
                }
            }
        },
        fab = { AddFab("Room", P.rooms) { Nav.edit(T.ROOM, prefill = mapOf("floorNumber" to floor, "floor" to floorDisplay(floor))) } },
        header = {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                floors.reversed().forEach { n ->
                    val name = floorRecs.firstOrNull { it.i("floorNumber") == n }?.title?.takeIf { it.isNotBlank() } ?: floorDisplay(n)
                    FilterChip(selected = n == floor, onClick = { floor = n; selectedId = null }, label = { Text(name) })
                }
                AssistChip(onClick = { showAddFloor = true }, label = { Text("Floor") }, leadingIcon = { Icon(Icons.Filled.Add, null, Modifier.size(16.dp)) })
            }
            if (planMode) {
                Box(Modifier.fillMaxWidth().height((LocalConfiguration.current.screenHeightDp * 0.62f).dp).padding(horizontal = 12.dp).clip(RoundedCornerShape(18.dp)).background(Color(0xFF0B0816)).border(1.dp, P.stroke, RoundedCornerShape(18.dp))) {
                    Canvas(
                        Modifier.fillMaxSize()
                            .onSizeChanged { canvasPx = Size(it.width.toFloat(), it.height.toFloat()) }
                            .pointerInput(editing) {
                                fun toMetres(p: Offset): Pair<Double, Double> {
                                    val s = zoom * density.density * PPM
                                    return ((p.x - size.width / 2f - pan.x) / s).toDouble() to ((p.y - size.height / 2f - pan.y) / s).toDouble()
                                }
                                fun hit(m: Pair<Double, Double>) = latestRooms.lastOrNull { r -> worldRectsOf(r, latestCentres[r.id] ?: centreOf(r)).any { it.contains(m.first, m.second) } }
                                awaitEachGesture {
                                    val down = awaitFirstDown(requireUnconsumed = false)
                                    val startM = toMetres(down.position)
                                    val grabbed = if (editing) hit(startM) else null
                                    var dragging = grabbed != null
                                    var startCentre = 0.0 to 0.0
                                    if (grabbed != null) { selectedId = grabbed.id; startCentre = centreOf(grabbed); dragRaw = startCentre }
                                    var moved = false
                                    var travel = Offset.Zero
                                    var multi = false
                                    while (true) {
                                        val ev = awaitPointerEvent()
                                        val pressed = ev.changes.filter { it.pressed }
                                        if (pressed.isEmpty()) break
                                        if (pressed.size >= 2) {
                                            multi = true; moved = true
                                            if (dragging) { dragging = false; dragId = null; guide = null }
                                            val zf = ev.calculateZoom(); val pc = ev.calculatePan(); val centroid = ev.calculateCentroid(useCurrent = true)
                                            val newZoom = (zoom * zf).coerceIn(0.3f, 4f)
                                            val real = newZoom / zoom
                                            val centre = Offset(size.width / 2f, size.height / 2f)
                                            pan = (centroid - centre) - (centroid - centre - pan) * real + pc
                                            zoom = newZoom
                                        } else if (!multi) {
                                            val ch = pressed.first()
                                            val delta = ch.positionChange()
                                            travel += delta
                                            if (!moved && travel.getDistance() > viewConfiguration.touchSlop) moved = true
                                            if (moved) {
                                                if (dragging && grabbed != null) {
                                                    val s = zoom * density.density * PPM
                                                    dragId = grabbed.id
                                                    dragRaw = startCentre.first + travel.x / s to startCentre.second + travel.y / s
                                                    val others = latestRooms.filter { it.id != grabbed.id }
                                                    guide = resolveDrop(grabbed, dragRaw, others, latestCentres, (SNAP_DP / (PPM * zoom)).toDouble(), guide?.c ?: startCentre)
                                                } else pan += delta
                                            }
                                        }
                                        ev.changes.forEach { if (it.positionChanged()) it.consume() }
                                    }
                                    if (dragging && moved && grabbed != null) {
                                        guide?.let { saveCentre(grabbed, it.c) }
                                    } else if (!moved) {
                                        selectedId = hit(startM)?.id
                                    }
                                    dragId = null; guide = null
                                }
                            }
                    ) {
                        legacyCanvas = Size(size.width / density.density, size.height / density.density)
                        val s = zoom * density.density
                        withTransform({
                            translate(size.width / 2f + pan.x, size.height / 2f + pan.y)
                            scale(s, s, Offset.Zero)
                        }) {
                            // 1 m grid over the visible area.
                            val inv = 1f / (s * PPM)
                            val x0 = ((-size.width / 2f - pan.x) * inv).toInt() - 1; val x1 = ((size.width / 2f - pan.x) * inv).toInt() + 1
                            val y0 = ((-size.height / 2f - pan.y) * inv).toInt() - 1; val y1 = ((size.height / 2f - pan.y) * inv).toInt() + 1
                            if (x1 - x0 < 400 && y1 - y0 < 400) {
                                for (x in x0..x1) drawLine(Color(0x0FFFFFFF), Offset(x * PPM, y0 * PPM), Offset(x * PPM, y1 * PPM), strokeWidth = 0.5f)
                                for (y in y0..y1) drawLine(Color(0x0FFFFFFF), Offset(x0 * PPM, y * PPM), Offset(x1 * PPM, y * PPM), strokeWidth = 0.5f)
                            }
                            drawWallsAndDoors(rooms, centres, selectedId, editing, null)
                            guide?.let { g ->
                                val dash = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))
                                g.lineX?.let { lx -> drawLine(GuideColor, Offset(lx.toFloat() * PPM, y0 * PPM), Offset(lx.toFloat() * PPM, y1 * PPM), 1f, pathEffect = dash) }
                                g.lineY?.let { ly -> drawLine(GuideColor, Offset(x0 * PPM, ly.toFloat() * PPM), Offset(x1 * PPM, ly.toFloat() * PPM), 1f, pathEffect = dash) }
                            }
                            drawLabels(rooms, centres, tm, density)
                            if (rooms.isNotEmpty()) drawMeasurements(rooms, centres, sel, tm, density)
                        }
                    }
                    ScaleBar(zoom, Modifier.align(Alignment.TopStart).padding(10.dp))
                    if (rooms.isEmpty()) Text("No rooms on this floor yet", color = P.muted, modifier = Modifier.align(Alignment.Center))
                    if (editing) Text("Drag rooms to move them", color = P.muted, fontSize = 12.sp, modifier = Modifier.align(Alignment.TopEnd).padding(10.dp))
                }
                // Selected room bar.
                if (sel != null) {
                    Row(Modifier.fillMaxWidth().padding(12.dp, 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(sel.title, color = Color.White, fontSize = 16.sp)
                            Text("${fmt1(Plan.area(sel))} m² · ${RoomLinks.itemCount(sel)} items", color = P.muted, fontSize = 12.sp)
                        }
                        if (editing) {
                            IconButton(onClick = {
                                val turns = (Plan.quarterTurns(sel.d("rotation")) + 1) % 4
                                val others = rooms.filter { it.id != sel.id }.map { worldRectsOf(it) }
                                val free = Plan.freeCenter(centreOf(sel), Plan.localRects(sel), turns, others, 0.0)
                                saveCentre(sel, free, mapOf("rotation" to (turns * 90).toDouble()))
                            }) { Icon(Icons.AutoMirrored.Filled.RotateRight, "Rotate") }
                            IconButton(onClick = { Nav.go(Dest("roomShape", id = sel.id)) }) { Icon(Icons.Filled.Architecture, "Shape and doors") }
                            IconButton(onClick = { confirmDelete = sel }) { Icon(Icons.Filled.Delete, "Delete", tint = P.muted) }
                        }
                        TextButton(onClick = { Nav.go(Dest("room", id = sel.id)) }) { Text("Open") }
                    }
                }
            }
        },
    ) {
        if (!planMode) {
            if (rooms.isEmpty()) item { Empty("No rooms on ${floorDisplay(floor).lowercase()} yet. Add one with the button below.") }
            items(rooms, key = { it.id }) { r ->
                val owner = r.s("ownerUid").takeIf { it.isNotBlank() }?.let { Repo.memberName(it) + "'s room" }
                ItemRow(r.title, listOfNotNull("${fmt1(Plan.area(r))} m²", "${RoomLinks.itemCount(r)} items", owner).joinToString(" · "), P.rooms, Icons.Filled.MeetingRoom) {
                    Nav.go(Dest("room", id = r.id))
                }
            }
        }
    }

    if (showAddFloor) {
        var name by remember { mutableStateOf("") }
        val next = (floors.maxOrNull() ?: 0) + 1
        var number by remember { mutableStateOf(next.toString()) }
        AlertDialog(
            onDismissRequest = { showAddFloor = false },
            title = { Text("New floor") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    FText("Name (optional)", name) { name = it }
                    FText("Floor number (0 ground, -1 basement)", number) { number = it }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val n = number.trim().toIntOrNull() ?: next
                    if (floorRecs.none { it.i("floorNumber") == n }) {
                        Repo.save(T.FLOOR, Repo.newId(), Vis.HOUSE, mapOf("name" to name.trim().ifBlank { floorDisplay(n) }, "floorNumber" to n, "homeId" to Repo.of(T.HOME).firstOrNull()?.id))
                    }
                    floor = n; selectedId = null; showAddFloor = false
                }) { Text("Add") }
            },
            dismissButton = { TextButton(onClick = { showAddFloor = false }) { Text("Cancel") } },
        )
    }
    confirmDelete?.let { r ->
        ConfirmDelete(r.title.ifBlank { "this room" }, onConfirm = { Repo.delete(r); selectedId = null; confirmDelete = null }, onDismiss = { confirmDelete = null })
    }
}

/** Scale bar: the first length from the list that is at least 40 points wide at this zoom, as on iOS. */
@Composable
private fun ScaleBar(zoom: Float, modifier: Modifier = Modifier) {
    val options = listOf(0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0)
    val metres = options.firstOrNull { it * PPM * zoom >= 40 } ?: options.last()
    val w = (metres * PPM * zoom).toFloat()
    Column(modifier.clip(RoundedCornerShape(6.dp)).background(Color(0xCC0D0A1A)).padding(6.dp)) {
        Canvas(Modifier.width(w.dp).height(6.dp)) {
            drawLine(Color.White, Offset(0f, size.height), Offset(size.width, size.height), strokeWidth = 2f)
            drawLine(Color.White, Offset(1f, 0f), Offset(1f, size.height), strokeWidth = 2f)
            drawLine(Color.White, Offset(size.width - 1f, 0f), Offset(size.width - 1f, size.height), strokeWidth = 2f)
        }
        Text(if (metres < 1) "${(metres * 100).roundToInt()} cm" else "${fmt2(metres)} m", color = Color.White, fontSize = 10.sp)
    }
}

/** Draws one room on its own, fitted to the box (used on the room page and the shape editor). */
@Composable
private fun RoomPreview(room: Rec, modifier: Modifier = Modifier, selectedDoor: String? = null) {
    val tm = rememberTextMeasurer()
    val density = LocalDensity.current
    Canvas(modifier.clip(RoundedCornerShape(16.dp)).background(Color(0xFF0B0816))) {
        val rects = worldRectsOf(room, 0.0 to 0.0)
        val b = Plan.bounds(rects) ?: return@Canvas
        val pad = 40f * density.density
        val s = min((size.width - 2 * pad) / (b.w.toFloat() * PPM), (size.height - 2 * pad) / (b.h.toFloat() * PPM)).coerceAtLeast(0.1f)
        val mx = (b.minX + b.w / 2).toFloat() * PPM; val my = (b.minY + b.h / 2).toFloat() * PPM
        withTransform({ translate(size.width / 2f, size.height / 2f); scale(s, s, Offset.Zero); translate(-mx, -my) }) {
            val centres = mapOf(room.id to (0.0 to 0.0))
            drawWallsAndDoors(listOf(room), centres, null, selectedDoor != null, selectedDoor)
            drawLabels(listOf(room), centres, tm, density)
            drawMeasurements(listOf(room), centres, room, tm, density)
        }
    }
}

// ------------------------------------------------------------------ Room page

@Composable
fun RoomPage(id: String) {
    val room = Repo.get(id)
    if (room == null || room.type != T.ROOM) { Page("Room", { Nav.back() }) { item { Empty("This room was deleted.") } }; return }
    var linkKind by remember { mutableStateOf<String?>(null) }
    var confirm by remember { mutableStateOf(false) }
    val assets = RoomLinks.assets(room)
    val owner = room.s("ownerUid").takeIf { it.isNotBlank() }

    Page(
        title = room.title.ifBlank { "Room" },
        onBack = { Nav.back() },
        tint = P.rooms,
        actions = {
            IconButton(onClick = { Nav.edit(T.ROOM, room.id) }) { Icon(Icons.Filled.Edit, "Edit") }
            IconButton(onClick = { confirm = true }) { Icon(Icons.Filled.Delete, "Delete") }
        },
    ) {
        item { RoomPreview(room, Modifier.fillMaxWidth().height(220.dp)) }
        item {
            Glass(tint = P.rooms) {
                Text("${fmt1(Plan.area(room))} m²", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Light)
                Text(listOfNotNull(
                    floorDisplay(room.i("floorNumber")),
                    "${fmt2(Plan.width(room))} m × ${fmt2(Plan.height(room))} m main",
                    Plan.parts(room).size.takeIf { it > 0 }?.let { "$it extra piece${if (it == 1) "" else "s"}" },
                    "${Plan.doors(room).size} door${if (Plan.doors(room).size == 1) "" else "s"}",
                    owner?.let { Repo.memberName(it) + "'s room" } ?: "Shared room",
                ).joinToString(" · "), color = P.muted, fontSize = 13.sp)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { Nav.go(Dest("rooms", id = room.id)) }) { Text("Show on plan") }
                    OutlinedButton(onClick = { Nav.go(Dest("roomShape", id = room.id)) }) { Text("Shape & doors") }
                }
            }
        }
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(onClick = { Nav.edit(T.ASSET, prefill = mapOf("roomId" to room.id)) }, label = { Text("Add item") })
                AssistChip(onClick = { Nav.edit(T.TASK, prefill = mapOf("roomId" to room.id)) }, label = { Text("Add job") })
                AssistChip(onClick = { Nav.edit(T.PLAN, prefill = mapOf("roomId" to room.id)) }, label = { Text("Add plan") })
                AssistChip(onClick = { Nav.edit(T.MAINTENANCE, prefill = mapOf("roomId" to room.id)) }, label = { Text("Log work") })
                AssistChip(onClick = { linkKind = "project" }, label = { Text("Link project") })
                AssistChip(onClick = { linkKind = "document" }, label = { Text("Link document") })
            }
        }
        roomSection("Items", assets, P.assets, Icons.Filled.Inventory2) { a ->
            listOfNotNull(a.s("category").ifBlank { null }, listOf(a.s("manufacturer"), a.s("model")).filter { it.isNotBlank() }.joinToString(" ").ifBlank { null }).joinToString(" · ")
        }
        roomSection("Documents", RoomLinks.documents(room), P.documents, Icons.Filled.Description) { d ->
            listOfNotNull(d.s("type").ifBlank { null }, Repo.get(d.link("asset"))?.takeIf { d.link("room") != room.id }?.let { "via ${it.title}" }).joinToString(" · ")
        }
        roomSection("Warranties", RoomLinks.warranties(room), P.warranties, Icons.Filled.Shield) { w ->
            listOfNotNull(Repo.get(w.link("asset"))?.title, w.t("expiryDate")?.let { "ends " + Fmt.short(it.toLocalDate()) }).joinToString(" · ")
        }
        roomSection("Maintenance plans", RoomLinks.plans(room), P.maintenance, Icons.Filled.Build) { p ->
            listOfNotNull(Repo.get(p.link("asset"))?.title, if (p.b("isPaused")) "Paused" else p.t("nextDueDate")?.let { "next " + Fmt.short(it.toLocalDate()) }).joinToString(" · ")
        }
        roomSection("Maintenance history", RoomLinks.logs(room).take(20), P.maintenance, Icons.Filled.History) { m ->
            listOfNotNull(m.t("date")?.let { Fmt.short(it.toLocalDate()) }, Repo.get(m.link("asset"))?.title, m.d("cost").takeIf { it > 0 }?.let { Fmt.money(it) }).joinToString(" · ")
        }
        roomSection("Projects", RoomLinks.projectsDirect(room), P.projects, Icons.Filled.Construction) { p -> p.s("status") }
        roomSection("Projects via an item here", RoomLinks.projectsViaItems(room), P.projects, Icons.Filled.Construction) { p -> p.s("status") }
        roomSection("To-Do jobs", RoomLinks.tasks(room), P.todo, Icons.Filled.CheckCircle) { t ->
            listOfNotNull(t.s("timeOfDayRaw").ifBlank { null }, t.s("repeatRaw").ifBlank { null }, Repo.get(t.link("asset"))?.takeIf { t.link("room") != room.id }?.let { "via ${it.title}" }).joinToString(" · ")
        }
    }

    when (linkKind) {
        "project" -> PickDialog("Link projects", Repo.of(T.PROJECT).sortedBy { it.title.lowercase() },
            Repo.of(T.PROJECT).filter { room.id in it.links("rooms") }.map { it.id }.toSet(),
            onDone = { chosen ->
                for (p in Repo.of(T.PROJECT)) {
                    val has = room.id in p.links("rooms")
                    if (has != (p.id in chosen)) {
                        val ids = if (has) p.links("rooms") - room.id else p.links("rooms") + room.id
                        Repo.update(p, p.data + mapOf("roomsIds" to ids))
                    }
                }
                linkKind = null
            }, onDismiss = { linkKind = null })
        "document" -> PickDialog("Link documents", Repo.of(T.DOCUMENT).sortedBy { it.title.lowercase() },
            Repo.of(T.DOCUMENT).filter { it.link("room") == room.id }.map { it.id }.toSet(),
            onDone = { chosen ->
                for (d in Repo.of(T.DOCUMENT)) {
                    val has = d.link("room") == room.id
                    if (has && d.id !in chosen) Repo.update(d, d.data + mapOf("roomId" to ""))
                    if (!has && d.id in chosen) Repo.update(d, d.data + mapOf("roomId" to room.id))
                }
                linkKind = null
            }, onDismiss = { linkKind = null })
    }
    if (confirm) ConfirmDelete(room.title.ifBlank { "this room" }, onConfirm = { confirm = false; Repo.delete(room); Nav.back() }, onDismiss = { confirm = false })
}

private fun LazyListScope.roomSection(title: String, recs: List<Rec>, tint: Color, icon: androidx.compose.ui.graphics.vector.ImageVector, sub: (Rec) -> String) {
    if (recs.isEmpty()) return
    item { SectionTitle("$title (${recs.size})", tint) }
    items(recs, key = { title + it.id }) { r ->
        ItemRow(r.title.ifBlank { "Untitled" }, sub(r).ifBlank { null }, tint, icon, trailing = if (r.isPrivate) ({ Pill("Just me", P.muted) }) else null) { Nav.open(r.id) }
    }
}

@Composable
private fun PickDialog(title: String, options: List<Rec>, initial: Set<String>, onDone: (Set<String>) -> Unit, onDismiss: () -> Unit) {
    var chosen by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            if (options.isEmpty()) Text("Nothing to link yet.", color = P.muted)
            else Column(Modifier.heightIn(max = 400.dp).verticalScroll(rememberScrollState())) {
                options.forEach { o ->
                    Row(Modifier.fillMaxWidth().clickable { chosen = if (o.id in chosen) chosen - o.id else chosen + o.id }.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = o.id in chosen, onCheckedChange = { chosen = if (it) chosen + o.id else chosen - o.id })
                        Text(o.title.ifBlank { "Untitled" })
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onDone(chosen) }) { Text("Done") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

// ------------------------------------------------------------------ Shape and doors (RoomShapeEditor on iOS)

@Composable
fun RoomShapeEditor(id: String) {
    val room = Repo.get(id)
    if (room == null || room.type != T.ROOM) { Page("Shape and doors", { Nav.back() }) { item { Empty("This room was deleted.") } }; return }
    var editPart by remember { mutableStateOf<Rec?>(null) }
    var newPart by remember { mutableStateOf(false) }
    var editDoor by remember { mutableStateOf<Rec?>(null) }
    var newDoor by remember { mutableStateOf(false) }
    var editMain by remember { mutableStateOf(false) }
    val parts = Plan.parts(room)
    val doors = Plan.doors(room)

    val others = Repo.of(T.ROOM).filter { it.id != room.id && it.i("floorNumber") == room.i("floorNumber") }.map { worldRectsOf(it) }
    val overlapping = others.any { Plan.overlaps(worldRectsOf(room), it) }

    Page("Shape and doors", { Nav.back() }, P.rooms) {
        item { RoomPreview(room, Modifier.fillMaxWidth().height(260.dp), selectedDoor = editDoor?.id) }
        if (overlapping) item { Text("This room now overlaps another room. Move it on the floor plan.", color = P.amber, fontSize = 13.sp) }
        item { SectionTitle("Pieces", P.rooms) }
        item {
            ItemRow("Main rectangle", "${fmt2(Plan.width(room))} m × ${fmt2(Plan.height(room))} m", P.rooms, Icons.Filled.CropSquare) { editMain = true }
        }
        items(parts, key = { it.id }) { p ->
            ItemRow(p.title.ifBlank { "Piece" }, "${fmt2(p.d("width"))} m × ${fmt2(p.d("height"))} m · offset ${fmt2(p.d("xOffset"))}, ${fmt2(p.d("yOffset"))}", P.rooms, Icons.Filled.CropDin) { editPart = p }
        }
        item { OutlinedButton(onClick = { newPart = true }) { Icon(Icons.Filled.Add, null); Text("Add piece (L or T shape)") } }
        item { SectionTitle("Doors", P.rooms) }
        if (doors.isEmpty()) item { Text("No doors yet.", color = P.muted) }
        items(doors, key = { it.id }) { d ->
            val piece = parts.firstOrNull { it.id == d.link("part") }?.title?.ifBlank { "Piece" } ?: "Main"
            ItemRow(
                (if (d.b("isDoubleDoor")) "Double door" else "Door") + " · " + d.s("edge").replaceFirstChar { it.uppercase() },
                "$piece · ${((d.dn("position") ?: 0.5) * 100).roundToInt()}% along · opens ${if (d.data["opensInward"] as? Boolean ?: true) "in" else "out"}",
                P.rooms, Icons.Filled.DoorFront,
            ) { editDoor = d }
        }
        item { OutlinedButton(onClick = { newDoor = true }) { Icon(Icons.Filled.Add, null); Text("Add door") } }
    }

    if (editMain) RectDialog("Main rectangle", null, Plan.width(room), Plan.height(room), null, null, onDelete = null,
        onSave = { _, w, h, _, _ -> Repo.update(room, room.data + mapOf("width" to w, "height" to h, "dimensions" to Plan.dimensions(w, h))); editMain = false },
        onDismiss = { editMain = false })
    if (newPart || editPart != null) {
        val p = editPart
        RectDialog(if (p == null) "New piece" else "Piece", p?.s("name") ?: "", p?.d("width") ?: 2.0, p?.d("height") ?: 2.0,
            p?.d("xOffset") ?: (Plan.width(room) / 2 + 1.0), p?.d("yOffset") ?: 0.0,
            onDelete = p?.let { { Repo.delete(it); editPart = null } },
            onSave = { name, w, h, x, y ->
                val data = mapOf("name" to (name ?: ""), "width" to w, "height" to h, "xOffset" to (x ?: 0.0), "yOffset" to (y ?: 0.0))
                if (p == null) Repo.save(T.ROOM_PART, Repo.newId(), Vis.HOUSE, data + mapOf("roomId" to room.id))
                else Repo.update(p, p.data + data)
                newPart = false; editPart = null
            },
            onDismiss = { newPart = false; editPart = null })
    }
    if (newDoor || editDoor != null) DoorDialog(room, editDoor, parts, onDone = { newDoor = false; editDoor = null })
}

@Composable
private fun RectDialog(
    title: String, name: String?, w0: Double, h0: Double, x0: Double?, y0: Double?,
    onDelete: (() -> Unit)?, onSave: (String?, Double, Double, Double?, Double?) -> Unit, onDismiss: () -> Unit,
) {
    var n by remember { mutableStateOf(name ?: "") }
    var w by remember { mutableStateOf<Double?>(w0) }
    var h by remember { mutableStateOf<Double?>(h0) }
    var x by remember { mutableStateOf(x0) }
    var y by remember { mutableStateOf(y0) }
    val valid = (w ?: 0.0) > 0.1 && (h ?: 0.0) > 0.1
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (name != null) FText("Name", n) { n = it }
                FNumber("Width (m)", w) { w = it }
                FNumber("Depth (m)", h) { h = it }
                if (x0 != null) {
                    FNumber("Across from room centre (m)", x) { x = it }
                    FNumber("Down from room centre (m)", y) { y = it }
                    Text("Negative numbers move it left or up.", color = P.muted, fontSize = 12.sp)
                }
                onDelete?.let { TextButton(onClick = it) { Text("Delete piece", color = P.muted) } }
            }
        },
        confirmButton = { TextButton(enabled = valid, onClick = { onSave(if (name != null) n.trim() else null, w!!, h!!, x, y) }) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun DoorDialog(room: Rec, door: Rec?, parts: List<Rec>, onDone: () -> Unit) {
    var partId by remember { mutableStateOf(door?.link("part") ?: "") }
    var edge by remember { mutableStateOf(door?.s("edge")?.lowercase()?.ifBlank { null } ?: "bottom") }
    var pos by remember { mutableFloatStateOf((door?.dn("position") ?: 0.5).toFloat()) }
    var opensLeft by remember { mutableStateOf(door?.data?.get("opensLeft") as? Boolean ?: true) }
    var inward by remember { mutableStateOf(door?.data?.get("opensInward") as? Boolean ?: true) }
    var double by remember { mutableStateOf(door?.b("isDoubleDoor") ?: false) }
    AlertDialog(
        onDismissRequest = onDone,
        title = { Text(if (door == null) "New door" else "Door") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (parts.isNotEmpty()) FChoice("On", partId, listOf("") + parts.map { it.id }, { id -> if (id.isBlank()) "Main rectangle" else parts.firstOrNull { it.id == id }?.title?.ifBlank { "Piece" } ?: "Piece" }) { partId = it }
                FChoice("Wall", edge, Enums.doorEdge.map { it.lowercase() }, { it.replaceFirstChar { c -> c.uppercase() } }) { edge = it }
                Text("Position along the wall: ${(pos * 100).roundToInt()}%", color = P.muted, fontSize = 13.sp)
                Slider(value = pos, onValueChange = { pos = it }, valueRange = 0f..1f)
                FSwitch("Double door", double) { double = it }
                if (!double) FSwitch(if (edge == "top" || edge == "bottom") "Hinge on the left" else "Hinge at the top", opensLeft) { opensLeft = it }
                FSwitch("Opens into the room", inward) { inward = it }
                if (door != null) TextButton(onClick = { Repo.delete(door); onDone() }) { Text("Delete door", color = P.muted) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val data = mapOf("edge" to edge, "position" to pos.toDouble(), "opensLeft" to opensLeft, "opensInward" to inward,
                    "isDoubleDoor" to double, "roomId" to room.id, "partId" to partId)
                if (door == null) Repo.save(T.DOOR, Repo.newId(), Vis.HOUSE, data)
                else Repo.update(door, door.data + data)
                onDone()
            }) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDone) { Text("Cancel") } },
    )
}
