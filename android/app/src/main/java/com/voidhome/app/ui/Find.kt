package com.voidhome.app.ui

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voidhome.app.data.*

@Composable
fun TimelineScreen() {
    var filter by remember { mutableStateOf("All") }
    val (next, past) = Timeline.build()
    fun keep(r: TimelineRow) = filter == "All" || r.kind == filter
    Page("Timeline", Nav::back, P.calm, header = {
        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(Timeline.filters) { f -> FilterChip(filter == f, { filter = f }, label = { Text(f) }) }
        }
    }) {
        val n = next.filter(::keep); val p = past.filter(::keep)
        item { SectionTitle("Coming up") }
        if (n.isEmpty()) item { Text("Nothing in the next 60 days.", color = P.faint) }
        items(n, key = { "n" + it.id }) { TimelineRowView(it) }
        item {
            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                HorizontalDivider(Modifier.weight(1f).padding(top = 9.dp), color = P.calm)
                Text("  Today, ${Fmt.short(Dates.today)}  ", color = P.calm, fontSize = 13.sp)
                HorizontalDivider(Modifier.weight(1f).padding(top = 9.dp), color = P.calm)
            }
        }
        if (p.isEmpty()) item { Text("No history yet.", color = P.faint) }
        p.groupBy { it.date.withDayOfMonth(1) }.forEach { (m, list) ->
            item(key = "m$m") { SectionTitle(Fmt.month(m)) }
            items(list, key = { "p" + it.id }) { TimelineRowView(it) }
        }
    }
}

private fun recents(ctx: Context): List<String> = ctx.getSharedPreferences("search", 0).getString("recent", "")!!.split("\n").filter { it.isNotBlank() }
private fun saveRecents(ctx: Context, l: List<String>) = ctx.getSharedPreferences("search", 0).edit().putString("recent", l.take(8).joinToString("\n")).apply()

@Composable
fun SearchScreen() {
    val ctx = LocalContext.current
    var q by remember { mutableStateOf("") }
    var recent by remember { mutableStateOf(recents(ctx)) }
    fun remember(term: String) { if (term.isBlank()) return; recent = (listOf(term.trim()) + recent.filter { !it.equals(term.trim(), true) }).take(8); saveRecents(ctx, recent) }
    val results = Search.run(q)
    Page("Search", Nav::back, P.accent, header = {
        OutlinedTextField(q, { q = it }, label = { Text("Search everything") }, singleLine = true, leadingIcon = { Icon(Icons.Filled.Search, null) },
            trailingIcon = { if (q.isNotEmpty()) IconButton(onClick = { q = "" }) { Icon(Icons.Filled.Close, "Clear") } },
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
    }) {
        if (q.isBlank()) {
            if (recent.isNotEmpty()) {
                item { SectionTitle("Recent", trailing = { TextButton(onClick = { recent = emptyList(); saveRecents(ctx, recent) }) { Text("Clear all") } }) }
                items(recent, key = { "r$it" }) { r ->
                    ItemRow(r, null, P.muted, Icons.Filled.History, trailing = { IconButton(onClick = { recent = recent - r; saveRecents(ctx, recent) }) { Icon(Icons.Filled.Close, "Remove") } }) { q = r }
                }
            } else item { Empty("Search rooms, assets, documents (including scanned text), bills, jobs, people and more.") }
        } else {
            if (results.isEmpty()) item { Empty("No matches for \"$q\".") }
            results.forEach { (group, hits) ->
                item(key = "g$group") { SectionTitle("$group (${hits.size})") }
                items(hits, key = { "h" + it.rec.id }) { h ->
                    val tint = P.forType(h.rec.type)
                    Glass(onClick = { remember(q); Nav.open(h.rec.id) }) {
                        Text(highlight(h.title, q), fontSize = 16.sp)
                        if (h.snippet != null) {
                            Text(h.label ?: "", color = tint, fontSize = 12.sp)
                            Text(highlight(h.snippet, q), color = P.muted, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
    }
}

fun highlight(text: String, q: String) = buildAnnotatedString {
    if (q.isBlank()) { append(text); return@buildAnnotatedString }
    var i = 0
    while (i < text.length) {
        val j = text.indexOf(q, i, ignoreCase = true)
        if (j < 0) { append(text.substring(i)); break }
        append(text.substring(i, j))
        withStyle(SpanStyle(color = Color.White, fontWeight = FontWeight.Bold, background = P.accent.copy(alpha = 0.45f))) { append(text.substring(j, j + q.length)) }
        i = j + q.length
    }
}
