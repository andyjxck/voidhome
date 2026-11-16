import Foundation

// Splitting shared bills and shared project spending between house members.
// Shares are fixed on each payment when it is recorded, so a membership change only
// affects payments from then on. Owing a share is never overdue and never red.

extension Bill {
    var isShared: Bool { visibilityRaw == Visibility.house.rawValue }
    var customShares: [String: Double] { SplitJSON.amounts(customSharesJSON) }

    /// Each current member's share of `total` for this bill. Empty when the bill is not shared.
    func shares(of total: Double) -> [String: Double] {
        guard isShared, HouseContext.isShared else { return [:] }
        return HouseSplit.shares(of: total, mode: splitModeRaw, custom: customShares)
    }

    /// The viewer's part of this bill's rough monthly figure. A "Just me" bill counts in full.
    var myMonthlyShare: Double {
        guard isShared, HouseContext.isShared, let me = HouseContext.uid else { return monthlyEquivalent }
        return shares(of: monthlyEquivalent)[me] ?? 0
    }
}

enum HouseSplit {
    /// Equal split between current members, or custom percentages (normalised over current members).
    static func shares(of total: Double, mode: String, custom: [String: Double]) -> [String: Double] {
        let members = HouseContext.members.map(\.uid)
        guard !members.isEmpty, total > 0 else { return [:] }
        var weights: [String: Double] = [:]
        if mode == "custom" {
            for uid in members { if let w = custom[uid], w > 0 { weights[uid] = w } }
        }
        if weights.isEmpty { for uid in members { weights[uid] = 1 } }
        let sum = weights.values.reduce(0, +)
        var out: [String: Double] = [:]
        for uid in members { out[uid] = ((total * (weights[uid] ?? 0) / sum) * 100).rounded() / 100 }
        return out
    }
}

extension BillPayment {
    /// What this payment cost the viewer: their share when it was split, else all of it.
    var myAmount: Double {
        guard !sharesJSON.isEmpty, let me = HouseContext.uid else { return amount }
        return shares[me] ?? 0
    }

    /// Called when a shared bill is ticked off: whoever ticked it paid the provider.
    func recordSplit(for bill: Bill) {
        guard HouseContext.isShared, let me = HouseContext.uid, bill.isShared else { return }
        paidByUid = me
        sharesJSON = SplitJSON.encode(bill.shares(of: amount))
    }
}

/// A payment or spend whose cost is shared out.
protocol SplitRecord: AnyObject {
    var paidByUid: String { get }
    var sharesJSON: String { get }
    var repaidJSON: String { get set }
    var splitTitle: String { get }
    var splitDate: Date { get }
}

extension BillPayment: SplitRecord {
    var splitTitle: String { bill?.name ?? "Bill" }
    var splitDate: Date { paidDate }
}

extension ProjectSpend: SplitRecord {
    var splitTitle: String { note.isEmpty ? (project?.title ?? "Project") : "\(project?.title ?? "Project") · \(note)" }
    var splitDate: Date { date }
}

struct OwedShare: Identifiable {
    let id = UUID()
    let record: SplitRecord
    let from: String
    let to: String
    let amount: Double
}

extension SplitRecord {
    var shares: [String: Double] { SplitJSON.amounts(sharesJSON) }
    var repaid: [String: String] { SplitJSON.strings(repaidJSON) }

    /// Shares still owed to the payer.
    var outstandingShares: [OwedShare] {
        guard !paidByUid.isEmpty else { return [] }
        let done = repaid
        return shares.compactMap { uid, amount in
            guard uid != paidByUid, done[uid] == nil, amount > 0.004 else { return nil }
            return OwedShare(record: self, from: uid, to: paidByUid, amount: amount)
        }
    }

    func setRepaid(_ uid: String, _ isRepaid: Bool) {
        var map: [String: Any] = repaid
        if isRepaid { map[uid] = ISO8601DateFormatter().string(from: Date()) } else { map.removeValue(forKey: uid) }
        repaidJSON = SplitJSON.encode(map)
    }
}

/// Net balance between two members after cancelling out what they owe each other.
struct NetBalance: Identifiable {
    let from: String
    let to: String
    let amount: Double
    let shares: [OwedShare]
    var id: String { from + ">" + to }
}

enum WhoOwesWho {
    static func outstanding(payments: [BillPayment], spends: [ProjectSpend]) -> [OwedShare] {
        let p = payments.filter { $0.bill?.isShared == true }.flatMap(\.outstandingShares)
        let s = spends.filter { $0.visibilityRaw == Visibility.house.rawValue }.flatMap(\.outstandingShares)
        return p + s
    }

    static func net(_ shares: [OwedShare]) -> [NetBalance] {
        var pairs: [String: (a: String, b: String, aOwesB: Double, items: [OwedShare])] = [:]
        for share in shares {
            let (a, b) = share.from < share.to ? (share.from, share.to) : (share.to, share.from)
            let key = a + "|" + b
            var entry = pairs[key] ?? (a, b, 0, [])
            entry.aOwesB += share.from == a ? share.amount : -share.amount
            entry.items.append(share)
            pairs[key] = entry
        }
        return pairs.values.compactMap { e in
            let rounded = (abs(e.aOwesB) * 100).rounded() / 100
            guard rounded >= 0.01 else { return nil }
            return e.aOwesB > 0
                ? NetBalance(from: e.a, to: e.b, amount: rounded, shares: e.items)
                : NetBalance(from: e.b, to: e.a, amount: rounded, shares: e.items)
        }
        .sorted { $0.amount > $1.amount }
    }
}
