package com.voidhome.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.voidhome.app.data.*
import java.time.YearMonth

@Composable
fun BillsScreen() {
    val bills = Repo.of(T.BILL)
    val today = Dates.today
    val active = bills.filter { !it.b("isSettled") }
    val myMonthly = active.sumOf { Bills.myMonthly(it) }
    val thisMonth = YearMonth.from(today)
    val paidThisMonth = Repo.of(T.PAYMENT).filter { p -> p.day("paidDate")?.let { YearMonth.from(it) == thisMonth } ?: false && Repo.get(p.link("bill")) != null }.sumOf { Bills.myAmount(it) }
    val nets = Split.net(Split.allOutstanding())
    Page("Bills", Nav::back, P.bills, fab = { AddFab("Add bill", P.bills) { Nav.edit(T.BILL) } }) {
        item {
            Glass(tint = P.bills) {
                Text("Your monthly total", color = P.muted, fontSize = 13.sp)
                Text("about " + Fmt.money(myMonthly), fontSize = 28.sp, fontWeight = FontWeight.Light)
                Text("Paid this month: ${Fmt.money(paidThisMonth)}", color = P.muted, fontSize = 13.sp)
                if (Repo.members.size > 1) Text("Shared bills count your share only.", color = P.faint, fontSize = 12.sp)
                Text("Void Home never connects to a bank or pays anything.", color = P.faint, fontSize = 12.sp)
            }
        }
        if (Repo.members.size > 1) item { WhoOwesWho(nets) }
        val overdue = active.filter { Bills.isOverdue(it) }.sortedBy { it.day("nextDueDate") }
        val soon = active.filter { !Bills.isOverdue(it) && (it.day("nextDueDate")?.let { d -> d <= today.plusDays(14) } ?: false) }.sortedBy { it.day("nextDueDate") }
        val later = active.filter { it !in overdue && it !in soon }.sortedBy { it.day("nextDueDate") }
        val settled = bills.filter { it.b("isSettled") }
        if (bills.isEmpty()) item { Empty("No bills yet.") }
        for ((title, list) in listOf("Overdue" to overdue, "Due soon" to soon, "Later" to later, "Finished" to settled)) {
            if (list.isEmpty()) continue
            item(key = title) { SectionTitle(title, if (title == "Overdue") P.billOverdue else P.muted) }
            items(list, key = { it.id }) { b -> BillRow(b) }
        }
    }
}

@Composable
fun BillRow(b: Rec) {
    val over = Bills.isOverdue(b)
    val shared = Bills.isShared(b) && Repo.members.size > 1
    val due = b.day("nextDueDate")
    val sub = listOfNotNull(
        Bills.frequency(b), if (b.b("isSettled")) "Finished" else due?.let { (if (over) "was due " else "due ") + Fmt.short(it) },
        if (shared) "your share ${Fmt.money(Bills.shares(b, b.d("amount"))[Repo.uid] ?: 0.0)}" else null,
        if (b.isPrivate) "Just me" else if (shared) "Everyone" else null,
        if (Bills.contractEndingSoon(b)) "contract ending" else null,
    ).joinToString(" · ")
    ItemRow(b.title, sub, if (over) P.billOverdue else P.bills, Icons.Filled.CreditCard,
        titleColor = if (over) P.billOverdue else Color.White,
        trailing = {
            Column(horizontalAlignment = Alignment.End) {
                Text((if (b.b("isEstimate")) "~" else "") + Fmt.money(b.d("amount")), color = if (over) P.billOverdue else Color.White)
                if (over) Pill("Overdue", P.billOverdue)
            }
        }) { Nav.open(b.id) }
}

@Composable
fun WhoOwesWho(nets: List<Split.Net>) {
    var open by remember { mutableStateOf<Split.Net?>(null) }
    Glass(tint = P.accent) {
        Text("Who owes who", fontSize = 16.sp)
        if (nets.isEmpty()) Text("Everyone's square.", color = P.muted, fontSize = 13.sp)
        nets.forEach { n ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${Repo.memberName(n.from)} owes ${Repo.memberName(n.to).let { if (it == "You") "you" else it }}", modifier = Modifier.weight(1f))
                Text(Fmt.money(n.amount), color = P.amber)
                TextButton(onClick = { open = n }) { Text("Details") }
            }
        }
    }
    open?.let { n ->
        AlertDialog(onDismissRequest = { open = null }, title = { Text("${Repo.memberName(n.from)} and ${Repo.memberName(n.to)}") },
            text = {
                Column {
                    n.items.forEach { o ->
                        val name = if (o.record.type == T.PAYMENT) Repo.get(o.record.link("bill"))?.title ?: "Bill" else o.record.s("note").ifBlank { "Spending" }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("$name: ${Repo.memberName(o.from)} → ${Repo.memberName(o.to)}", modifier = Modifier.weight(1f), fontSize = 14.sp)
                            Text(Fmt.money(o.amount), fontSize = 14.sp)
                            TextButton(onClick = { Split.setRepaid(o.record, o.from, true) }) { Text("Paid back") }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { n.items.forEach { Split.setRepaid(it.record, it.from, true) }; open = null }) { Text("Settle all") }
            },
            dismissButton = { TextButton(onClick = { open = null }) { Text("Close") } })
    }
}

fun LazyListScope.billBody(b: Rec) {
    val over = Bills.isOverdue(b)
    val shared = Bills.isShared(b) && Repo.members.size > 1
    item {
        Glass(tint = if (over) P.billOverdue else P.bills) {
            Text((if (b.b("isEstimate")) "about " else "") + Fmt.money(b.d("amount")), fontSize = 28.sp, fontWeight = FontWeight.Light)
            Text(Bills.frequency(b) + " · about ${Fmt.money(Bills.monthly(b))} a month", color = P.muted, fontSize = 13.sp)
            if (over) Pill("Overdue since ${Fmt.short(b.day("nextDueDate"))}", P.billOverdue)
            Spacer(Modifier.height(6.dp))
            KV("Next due", if (b.b("isSettled")) "Finished" else Fmt.long(b.day("nextDueDate"))); KV("Category", b.s("categoryRaw")); KV("Provider", Repo.get(b.link("provider"))?.title)
            KV("Pay by", b.s("paymentMethod")); KV("Contract ends", Fmt.long(b.day("contractEndDate"))); KV("Notes", b.s("notes"))
            if (Bills.contractEndingSoon(b)) Text("Contract ending soon: worth checking for a better deal.", color = P.amber, fontSize = 13.sp)
            if (!b.b("isSettled")) Button(onClick = { Bills.markPaid(b) }, modifier = Modifier.padding(top = 8.dp)) { Text(if (shared) "I paid this" else "Mark paid") }
        }
    }
    if (shared) item {
        Glass {
            Text(if (b.s("splitModeRaw") == "custom") "Custom split" else "Split equally", color = P.muted, fontSize = 13.sp)
            Bills.shares(b, b.d("amount")).forEach { (u, a) -> KV(Repo.memberName(u), Fmt.money(a)) }
        }
    }
    val pays = Bills.payments(b)
    if (pays.isNotEmpty()) item { PaymentChart(pays) }
    item { SectionTitle("Payment history") }
    if (pays.isEmpty()) item { Text("No payments yet.", color = P.faint) }
    items(pays, key = { "p" + it.id }) { p ->
        Glass {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(Fmt.money(p.d("amount")))
                    Text(listOfNotNull("paid " + Fmt.short(p.day("paidDate")), "for " + Fmt.short(p.day("dueDate")), p.s("paidByUid").ifBlank { null }?.let { "by " + Repo.memberName(it) }, p.s("note").ifBlank { null }).joinToString(" · "), color = P.muted, fontSize = 13.sp)
                }
                if (pays.firstOrNull()?.id == p.id) TextButton(onClick = { Bills.undo(b, p) }) { Text("Undo") }
            }
            SharesList(p)
        }
    }
    childSection("Statements", Repo.of(T.DOCUMENT).filter { it.link("bill") == b.id }, "Add") { Nav.edit(T.DOCUMENT, prefill = mapOf("billId" to b.id, "type" to "Invoice")) }
}

@Composable
fun PaymentChart(pays: List<Rec>) {
    val last = pays.take(12).reversed()
    val max = (last.maxOfOrNull { it.d("amount") } ?: 1.0).coerceAtLeast(1.0)
    Glass {
        Text("Last ${last.size} payments", color = P.muted, fontSize = 13.sp)
        Canvas(Modifier.fillMaxWidth().height(90.dp).padding(top = 8.dp)) {
            val gap = 6.dp.toPx(); val w = (size.width - gap * (last.size - 1)) / last.size.coerceAtLeast(1)
            last.forEachIndexed { i, p ->
                val h = (p.d("amount") / max * size.height).toFloat().coerceAtLeast(2f)
                drawRoundRect(P.bills, Offset(i * (w + gap), size.height - h), Size(w, h), CornerRadius(4.dp.toPx()))
            }
        }
    }
}
