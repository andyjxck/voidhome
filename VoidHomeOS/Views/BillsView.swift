import SwiftUI
import SwiftData

/// Household bills, entered and ticked off by hand. Nothing here connects to a bank or pays anything.
struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @State private var showingAdd = false

    private var active: [Bill] { bills.filter { !$0.isSettled } }
    private var dueSoon: [Bill] {
        active.filter { $0.daysUntilDue <= 30 }.sorted { $0.nextDueDate < $1.nextDueDate }
    }
    private var later: [Bill] { active.filter { $0.daysUntilDue > 30 } }
    private var monthlyTotal: Double { active.reduce(0) { $0 + $1.monthlyEquivalent } }
    private var paidThisMonth: Double {
        let cal = Calendar.current
        return bills.flatMap(\.payments).filter { cal.isDate($0.paidDate, equalTo: Date(), toGranularity: .month) }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VoidPage(subtitle: "Bills", addAction: { showingAdd = true }) {
            HStack(spacing: 12) {
                StatTile(icon: "calendar", tint: VoidPalette.bills, value: Money.format(monthlyTotal, decimals: 0), label: "A month, roughly")
                StatTile(icon: "checkmark.seal.fill", tint: VoidPalette.done, value: Money.format(paidThisMonth, decimals: 0), label: "Paid this month")
            }
            .padding(.horizontal, 24)

            let ending = active.filter(\.contractEndingSoon)
            if !ending.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Contract ending", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(VoidPalette.amber)
                    ForEach(ending) { bill in
                        Text("\(bill.name): ends \(DayText.short(bill.contractEndDate ?? Date())). Worth comparing prices.")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).voidCard(tint: VoidPalette.amber)
                .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 10) {
                if bills.isEmpty {
                    EmptyStateView(icon: "creditcard", text: "Add your regular bills to see what's due and keep a record of payments.", buttonTitle: "Add a bill") { showingAdd = true }
                }
                if !dueSoon.isEmpty {
                    GlassSectionHeader(title: "Next 30 days")
                    ForEach(dueSoon) { bill in billLink(bill) }
                }
                if !later.isEmpty {
                    GlassSectionHeader(title: "Later").padding(.top, 6)
                    ForEach(later) { bill in billLink(bill) }
                }
                let settled = bills.filter(\.isSettled)
                if !settled.isEmpty {
                    GlassSectionHeader(title: "Paid one-offs").padding(.top, 6)
                    ForEach(settled) { bill in billLink(bill) }
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAdd) { EditBillSheet(bill: nil) }
    }

    private func billLink(_ bill: Bill) -> some View {
        BillRow(bill: bill)
            .contextMenu {
                if !bill.isSettled {
                    Button { bill.markPaid(in: modelContext); NotificationService.shared.syncBillReminder(for: bill) } label: { Label("Mark paid", systemImage: "checkmark.circle") }
                }
                Button(role: .destructive) {
                    NotificationService.shared.cancelBillReminder(for: bill)
                    modelContext.delete(bill)
                } label: { Label("Delete", systemImage: "trash") }
            }
    }
}

struct BillRow: View {
    let bill: Bill
    var body: some View {
        NavigationLink(destination: BillDetailView(bill: bill)) {
            HStack(spacing: 12) {
                Image(systemName: bill.category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VoidPalette.bills)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VoidPalette.bills.opacity(0.15)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(bill.name).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                    HStack(spacing: 6) {
                        if bill.isOverdue { TagLabel(text: "Overdue", color: VoidPalette.billOverdue) }
                        Text(statusText).font(.system(size: 12)).foregroundColor(bill.isOverdue ? VoidPalette.billOverdue : VoidPalette.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text((bill.isEstimate ? "~" : "") + Money.format(bill.amount)).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                    Text(bill.frequency.rawValue).font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                }
            }
            .padding(12)
            .voidCard(cornerRadius: 16, tint: bill.isOverdue ? VoidPalette.billOverdue : nil)
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if bill.isSettled { return "Paid" }
        let d = bill.daysUntilDue
        if d < 0 { return "Was due \(DayText.relative(bill.nextDueDate))" }
        if d == 0 { return "Due today" }
        if d == 1 { return "Due tomorrow" }
        return "Due \(DayText.relative(bill.nextDueDate))"
    }
}

struct BillDetailView: View {
    @Bindable var bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Document.title) private var allDocuments: [Document]
    @State private var showingEdit = false
    @State private var showingPay = false
    @State private var linkingDocs = false
    @State private var confirmDelete = false

    var body: some View {
        VoidPage(subtitle: "Bill") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bill.name).font(.system(size: 26, weight: .light)).foregroundColor(.white)
                        HStack(spacing: 6) {
                            TagLabel(text: bill.category.rawValue, color: VoidPalette.bills)
                            if bill.isOverdue { TagLabel(text: "Overdue", color: VoidPalette.billOverdue) }
                        }
                    }
                    Spacer()
                    CircleIconButton(icon: "pencil", size: 38) { showingEdit = true }
                }

                HStack(spacing: 12) {
                    StatTile(icon: Money.symbolName(filled: true), tint: VoidPalette.bills, value: (bill.isEstimate ? "~" : "") + Money.format(bill.amount), label: bill.frequency.rawValue)
                    StatTile(icon: "calendar", tint: bill.isOverdue ? VoidPalette.billOverdue : VoidPalette.calm, value: bill.isSettled ? "Paid" : DayText.relative(bill.nextDueDate), label: bill.isSettled ? "One-off" : "Next due")
                }

                if !bill.isSettled {
                    Button(action: { showingPay = true }) {
                        Label("Mark paid", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VoidPalette.bills.opacity(0.6)))
                    }
                    Text("This only records the payment in the app. Nothing is paid from here.")
                        .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                }

                VStack(spacing: 10) {
                    if !bill.paymentMethod.isEmpty { GlassDetailCard(label: "PAID BY", value: bill.paymentMethod, icon: "creditcard", tint: VoidPalette.bills) }
                    if let end = bill.contractEndDate {
                        GlassDetailCard(label: bill.contractEndingSoon ? "CONTRACT ENDS · COMPARE PRICES" : "CONTRACT ENDS", value: DayText.short(end), icon: "doc.badge.clock", tint: bill.contractEndingSoon ? VoidPalette.amber : VoidPalette.calm)
                    }
                    if !bill.notes.isEmpty { GlassDetailCard(label: "NOTES", value: bill.notes, icon: "note.text", tint: VoidPalette.muted) }
                }

                PaymentChart(payments: bill.sortedPayments)

                LinkedSection(title: "Provider", count: bill.provider == nil ? 0 : 1) {
                    if let provider = bill.provider {
                        LinkRow(icon: "building.2.fill", tint: VoidPalette.people, title: provider.name, subtitle: provider.phoneNumber) { PersonDetailView(person: provider) }
                    }
                }

                LinkedSection(title: "Statements & documents", count: bill.documents.count, addTitle: "Link", addAction: { linkingDocs = true }) {
                    ForEach(bill.documents) { doc in
                        LinkRow(icon: "doc.fill", tint: VoidPalette.documents, title: doc.title, subtitle: doc.type.rawValue) { DocumentDetailView(document: doc) }
                    }
                }

                LinkedSection(title: "Payments", count: bill.payments.count) {
                    ForEach(bill.sortedPayments) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Money.format(payment.amount)).font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                                Text("Paid \(DayText.short(payment.paidDate)) · due \(DayText.short(payment.dueDate))" + (payment.note.isEmpty ? "" : " · \(payment.note)"))
                                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                            }
                            Spacer()
                        }
                        .padding(12).voidCard(cornerRadius: 14)
                        .contextMenu {
                            Button(role: .destructive) {
                                bill.undo(payment, in: modelContext)
                                NotificationService.shared.syncBillReminder(for: bill)
                            } label: { Label("Remove payment", systemImage: "arrow.uturn.backward") }
                        }
                    }
                }

                Button(role: .destructive, action: { confirmDelete = true }) {
                    Label("Delete bill", systemImage: "trash").font(.system(size: 14)).foregroundColor(VoidPalette.muted)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingEdit) { EditBillSheet(bill: bill) }
        .sheet(isPresented: $showingPay) { MarkBillPaidSheet(bill: bill) }
        .sheet(isPresented: $linkingDocs) {
            MultiLinkSheet(title: "Documents", options: allDocuments, label: { $0.title },
                           isLinked: { $0.bill === bill },
                           toggle: { doc in doc.bill = (doc.bill === bill) ? nil : bill })
        }
        .confirmationDialog("Delete this bill and its payment history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelBillReminder(for: bill)
                modelContext.delete(bill)
                dismiss()
            }
        }
    }
}

/// Bar chart of the last twelve payments.
struct PaymentChart: View {
    let payments: [BillPayment]
    var body: some View {
        let recent = Array(payments.prefix(12).reversed())
        let maxAmount = max(recent.map(\.amount).max() ?? 1, 1)
        if recent.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                GlassSectionHeader(title: "Payment history")
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(recent) { payment in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(LinearGradient(colors: [VoidPalette.bills, VoidPalette.bills.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                                .frame(height: max(6, CGFloat(payment.amount / maxAmount) * 110))
                            Text(payment.paidDate.formatted(.dateTime.month(.narrow)))
                                .font(.system(size: 9)).foregroundColor(VoidPalette.faint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 130, alignment: .bottom)
                let avg = recent.reduce(0) { $0 + $1.amount } / Double(recent.count)
                Text("Average \(Money.format(avg)) over the last \(recent.count) payments")
                    .font(.system(size: 12)).foregroundColor(VoidPalette.muted)
            }
            .padding(14).voidCard()
        }
    }
}

struct MarkBillPaidSheet: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        FormSheet(title: "Mark paid", saveTitle: "Paid", onSave: {
            bill.markPaid(amount: Money.parse(amountText) ?? bill.amount, on: date, note: note, in: modelContext)
            NotificationService.shared.syncBillReminder(for: bill)
            try? modelContext.save()
        }) {
            Text("\(bill.name) · due \(DayText.short(bill.nextDueDate))").foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
            GlassTextField(title: "Amount paid", text: $amountText, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            DateField(title: "Paid on", date: $date)
            GlassTextField(title: "Note", text: $note, icon: "note.text", tint: VoidPalette.bills)
        }
        .onAppear { amountText = Money.editString(bill.amount) }
    }
}

struct EditBillSheet: View {
    let bill: Bill?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var name = ""
    @State private var category: BillCategory = .energy
    @State private var amountText = ""
    @State private var isEstimate = false
    @State private var frequency: BillFrequency = .monthly
    @State private var nextDue = Date()
    @State private var paymentMethod = ""
    @State private var contractEnd: Date?
    @State private var provider: Person?
    @State private var notes = ""
    @State private var reminders = true
    @State private var loaded = false

    var body: some View {
        FormSheet(title: bill == nil ? "New bill" : "Edit bill", canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty, onSave: save) {
            GlassTextField(title: "Name", text: $name, icon: "creditcard", tint: VoidPalette.bills)
            ChoicePickerField(title: "Type", selection: $category, options: BillCategory.allCases) { $0.rawValue }
            GlassTextField(title: "Amount", text: $amountText, icon: Money.symbolName(filled: false), tint: VoidPalette.bills, keyboardType: .decimalPad)
            Toggle("Amount changes, this is roughly", isOn: $isEstimate).tint(VoidPalette.bills).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
            ChoicePickerField(title: "How often", selection: $frequency, options: BillFrequency.allCases) { $0.rawValue }
            DateField(title: bill == nil ? "First due" : "Next due", date: $nextDue)
            GlassTextField(title: "How you pay (e.g. direct debit)", text: $paymentMethod, icon: "arrow.left.arrow.right", tint: VoidPalette.bills)
            OptionalDateField(title: "Contract end date", date: $contractEnd)
            MenuPickerField(title: "Provider", selection: $provider, options: people) { $0.name + ($0.company.isEmpty ? "" : " · \($0.company)") }
            Toggle("Reminders (2 days before and on the day)", isOn: $reminders).tint(VoidPalette.bills).foregroundColor(.white).padding(12).voidCard(cornerRadius: 16)
            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: VoidPalette.bills, isMultiline: true)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            guard let bill else { return }
            name = bill.name
            category = bill.category
            amountText = Money.editString(bill.amount)
            isEstimate = bill.isEstimate
            frequency = bill.frequency
            nextDue = bill.nextDueDate
            paymentMethod = bill.paymentMethod
            contractEnd = bill.contractEndDate
            provider = bill.provider
            notes = bill.notes
            reminders = bill.remindersEnabled
        }
    }

    private func save() {
        let target = bill ?? Bill(name: name)
        if bill == nil { modelContext.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.category = category
        target.amount = Money.parse(amountText) ?? 0
        target.isEstimate = isEstimate
        target.frequency = frequency
        target.nextDueDate = Calendar.current.startOfDay(for: nextDue)
        target.paymentMethod = paymentMethod
        target.contractEndDate = contractEnd
        target.provider = provider
        target.notes = notes
        target.remindersEnabled = reminders
        if bill != nil && frequency != .once { target.isSettled = false }
        try? modelContext.save()
        NotificationService.shared.syncBillReminder(for: target)
    }
}
