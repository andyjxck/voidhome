import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Just me / Everyone

/// "Who can see this" picker. Only shown in a shared house. Only the creator can change it,
/// so nobody can take a house item away from the others.
struct VisibilityField: View {
    @Binding var raw: String
    var createdBy: String = ""
    var tint: Color = VoidPalette.accent
    var note: String? = nil
    @ObservedObject private var house = HouseStore.shared

    private var canChange: Bool { createdBy.isEmpty || createdBy == house.uid }

    var body: some View {
        if house.house != nil {
            VStack(alignment: .leading, spacing: 6) {
                Text("WHO CAN SEE THIS").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(VoidPalette.faint)
                Picker("Who can see this", selection: $raw) {
                    ForEach(Visibility.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .disabled(!canChange)
                Text(!canChange ? "Added by \(HouseContext.name(for: createdBy)). Only they can change this." :
                        (note ?? (raw == Visibility.me.rawValue ? "Only you can see this, not even the house owner." : "Everyone in the house can see this.")))
                    .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
            }
            .padding(12).voidCard(cornerRadius: 16)
        }
    }
}

struct MemberBadge: View {
    var body: some View { TagLabel(text: "Member", color: VoidPalette.accent) }
}

struct PrivateBadge: View {
    var body: some View { TagLabel(text: "Just me", color: VoidPalette.faint) }
}

/// "Whose room is this?" for bedrooms. The room itself and the plan stay shared; personal
/// items in it are only seen by the person who added them as "Just me".
struct RoomOwnerField: View {
    @Binding var ownerUid: String
    @ObservedObject private var house = HouseStore.shared

    var body: some View {
        if let info = house.house {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHOSE ROOM").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(VoidPalette.faint)
                Picker("Whose room", selection: $ownerUid) {
                    Text("Shared").tag("")
                    ForEach(info.members) { Text($0.uid == house.uid ? "Mine" : $0.name).tag($0.uid) }
                }
                .pickerStyle(.menu)
                Text("Items added to your own room start as Just me, so only you see them. The room stays on everyone's plan.")
                    .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).voidCard(cornerRadius: 16)
        }
    }
}

// MARK: - Bill split settings

struct BillSplitFields: View {
    @Binding var visibility: String
    @Binding var mode: String
    @Binding var custom: [String: Double]
    var createdBy: String = ""
    @ObservedObject private var house = HouseStore.shared

    var body: some View {
        if let info = house.house {
            VisibilityField(raw: $visibility, createdBy: createdBy, tint: VoidPalette.bills,
                            note: visibility == Visibility.me.rawValue ? "Private. Counts only towards your totals." : "Split between everyone in the house.")
            if visibility == Visibility.house.rawValue {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Split", selection: $mode) {
                        Text("Equally").tag("equal")
                        Text("Custom shares").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    if mode == "custom" {
                        ForEach(info.members) { member in
                            HStack {
                                Text(member.uid == house.uid ? "You" : member.name).foregroundColor(.white)
                                Spacer()
                                TextField("0", value: Binding(get: { custom[member.uid] ?? 0 }, set: { custom[member.uid] = max(0, $0) }), format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                                    .foregroundColor(.white)
                                Text("%").foregroundColor(VoidPalette.muted)
                            }
                        }
                        let total = info.members.reduce(0) { $0 + (custom[$1.uid] ?? 0) }
                        Text(total == 100 ? "Adds up to 100%." : "Adds up to \(Int(total))%. Shares are scaled so they cover the whole bill. Put 100 next to one person if they cover it.")
                            .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                    } else {
                        Text("Split equally between the \(info.members.count) people in the house. If someone joins or leaves, the split changes from the next payment.")
                            .font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                    }
                }
                .padding(12).voidCard(cornerRadius: 16)
            }
        }
    }
}

// MARK: - Shares on one payment or spend

/// Who owes the payer what for one payment, each share ticked off once paid back.
/// Shown neutrally: owing a share is never overdue and never red.
struct SplitSharesView: View {
    let record: SplitRecord
    @State private var refresh = 0

    var body: some View {
        let shares = record.shares
        if !record.paidByUid.isEmpty && !shares.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(HouseContext.name(for: record.paidByUid)) paid").font(.system(size: 12)).foregroundColor(VoidPalette.muted)
                ForEach(shares.keys.sorted(), id: \.self) { uid in
                    let amount = shares[uid] ?? 0
                    if uid == record.paidByUid {
                        Text("\(HouseContext.name(for: uid)): \(Money.format(amount)) (their own share)")
                            .font(.system(size: 12)).foregroundColor(VoidPalette.faint)
                    } else {
                        let repaid = record.repaid[uid] != nil
                        let canTick = uid == HouseContext.uid || record.paidByUid == HouseContext.uid
                        Button {
                            record.setRepaid(uid, !repaid)
                            refresh += 1
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: repaid ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(repaid ? VoidPalette.done : VoidPalette.muted)
                                Text("\(HouseContext.name(for: uid)) \(repaid ? "paid back" : "owes") \(Money.format(amount))")
                                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canTick)
                    }
                }
            }
            .id(refresh)
        }
    }
}

// MARK: - Who owes who

struct WhoOwesWhoCard: View {
    @Query private var payments: [BillPayment]
    @Query private var spends: [ProjectSpend]
    @ObservedObject private var house = HouseStore.shared
    @State private var expanded = false

    var body: some View {
        if house.house != nil {
            let outstanding = WhoOwesWho.outstanding(payments: payments, spends: spends)
            let balances = WhoOwesWho.net(outstanding)
            VStack(alignment: .leading, spacing: 8) {
                Label("Who owes who", systemImage: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(VoidPalette.calm)
                if balances.isEmpty {
                    Text("Everyone's square.").font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                } else {
                    ForEach(balances) { balance in
                        Text("\(HouseContext.name(for: balance.from)) owes \(HouseContext.name(for: balance.to).replacingOccurrences(of: "You", with: "you")) \(Money.format(balance.amount))")
                            .font(.system(size: 14)).foregroundColor(.white)
                    }
                    Button(expanded ? "Hide shares" : "Show shares to tick off") { expanded.toggle() }
                        .font(.system(size: 12)).foregroundColor(VoidPalette.calm)
                    if expanded {
                        ForEach(outstanding) { share in
                            let canTick = share.from == HouseContext.uid || share.to == HouseContext.uid
                            Button {
                                share.record.setRepaid(share.from, true)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "circle").foregroundColor(VoidPalette.muted)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(share.record.splitTitle): \(HouseContext.name(for: share.from)) → \(HouseContext.name(for: share.to)) \(Money.format(share.amount))")
                                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                                        Text(DayText.short(share.record.splitDate)).font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canTick)
                        }
                        Text("Tick a share once it's been paid back.").font(.system(size: 11)).foregroundColor(VoidPalette.faint)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).voidCard(tint: VoidPalette.calm)
        }
    }
}

// MARK: - House screen

struct HouseView: View {
    @ObservedObject private var store = HouseStore.shared
    @ObservedObject private var sync = SyncEngine.shared
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    @State private var code = ""
    @State private var houseName = ""
    @State private var name = ""
    @State private var confirmLeave = false
    @State private var confirmJoin = false
    @State private var memberAction: HouseMember?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !store.isAvailable {
                        info("Sharing isn't available in this build (Firebase isn't set up).")
                    } else if !store.isSignedIn {
                        signInSection
                    } else if let house = store.house {
                        houseSection(house)
                    } else {
                        noHouseSection
                    }
                    if let message = store.message {
                        Text(message).font(.system(size: 13)).foregroundColor(VoidPalette.amber)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).voidCard(tint: VoidPalette.amber)
                            .onTapGesture { store.message = nil }
                    }
                    if store.busy { ProgressView().tint(.white) }
                }
                .padding(24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Your house")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = store.displayName
            houseName = homes.first?.name ?? "Home"
        }
    }

    private func info(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundColor(VoidPalette.muted)
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Share your home").font(.system(size: 24, weight: .light)).foregroundColor(.white)
            info("Sign in to share this home with a partner or housemates, or to join theirs with a code. You can keep using the app without an account.")
            SignInWithAppleButton(.signIn, onRequest: { store.prepareAppleRequest($0) }, onCompletion: { store.completeApple($0) })
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button(action: { store.signInWithGoogle() }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Sign in with Google").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).frame(height: 50)
                .foregroundColor(.black)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            }
        }
    }

    private var accountRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR NAME IN THE HOUSE").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(VoidPalette.faint)
            HStack {
                TextField("Your name", text: $name).foregroundColor(.white)
                Button("Save") { store.updateDisplayName(name) }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !store.email.isEmpty { Text(store.email).font(.system(size: 12)).foregroundColor(VoidPalette.faint) }
        }
        .padding(12).voidCard(cornerRadius: 16)
    }

    private var noHouseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            accountRow
            VStack(alignment: .leading, spacing: 10) {
                Text("Share this home").font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                info("Makes a shared house from what's on this phone and gives you a code for others to join. A backup is saved to Files › Void Home first.")
                TextField("House name", text: $houseName).foregroundColor(.white).padding(10).voidCard(cornerRadius: 12)
                Button("Create house") { store.createHouse(name: houseName) }
                    .buttonStyle(.borderedProminent).tint(VoidPalette.accent).disabled(store.busy)
            }
            .padding(14).voidCard()
            VStack(alignment: .leading, spacing: 10) {
                Text("Join a house").font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                info("Enter the code from the person who owns the house.")
                TextField("Code, e.g. K7M2QX", text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white).padding(10).voidCard(cornerRadius: 12)
                Button("Join") { confirmJoin = true }
                    .buttonStyle(.borderedProminent).tint(VoidPalette.accent).disabled(code.count < 4 || store.busy)
            }
            .padding(14).voidCard()
            Button("Sign out") { store.signOut() }.font(.system(size: 13)).foregroundColor(VoidPalette.muted)
        }
        .confirmationDialog("Join this house?", isPresented: $confirmJoin, titleVisibility: .visible) {
            Button("Join") { store.join(code: code) }
        } message: {
            Text("The house's home replaces what's on this phone. What's here now is copied to Files › Void Home as a backup first, so nothing is lost.")
        }
    }

    private func houseSection(_ house: HouseInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(house.name).font(.system(size: 24, weight: .light)).foregroundColor(.white)
            if store.isOwner {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INVITE CODE").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(VoidPalette.faint)
                    Text(house.inviteCode).font(.system(size: 34, weight: .semibold, design: .monospaced)).foregroundColor(.white)
                        .textSelection(.enabled)
                    info("Others sign in to Void Home, tap Join a house and enter this code.")
                    HStack {
                        ShareLink(item: "Join my home on Void Home with the code \(house.inviteCode)") { Label("Share code", systemImage: "square.and.arrow.up") }
                        Spacer()
                        Button("Make a new code") { store.newInviteCode() }
                    }
                    .font(.system(size: 14))
                }
                .padding(14).voidCard(tint: VoidPalette.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PEOPLE IN THIS HOUSE").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(VoidPalette.faint)
                ForEach(house.members) { member in
                    HStack {
                        Text(member.uid == store.uid ? "\(member.name) (you)" : member.name).foregroundColor(.white)
                        if member.role == "owner" { TagLabel(text: "Owner", color: VoidPalette.accent) }
                        Spacer()
                        if store.isOwner && member.uid != store.uid {
                            Button { memberAction = member } label: { Image(systemName: "ellipsis.circle").foregroundColor(VoidPalette.muted) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14).voidCard()

            accountRow

            VStack(alignment: .leading, spacing: 4) {
                if let date = sync.lastSynced {
                    info("Last synced \(date.formatted(date: .omitted, time: .shortened)). Changes made without signal sync when you're back online.")
                }
                if let problem = sync.syncProblem { Text(problem).font(.system(size: 12)).foregroundColor(VoidPalette.amber) }
                if let problem = sync.fileProblem { Text(problem).font(.system(size: 12)).foregroundColor(VoidPalette.amber) }
            }

            Button(store.isOwner && house.members.count == 1 ? "Stop sharing" : "Leave house") { confirmLeave = true }
                .font(.system(size: 14)).foregroundColor(VoidPalette.muted)
        }
        .confirmationDialog("", isPresented: Binding(get: { memberAction != nil }, set: { if !$0 { memberAction = nil } })) {
            if let member = memberAction {
                Button("Make \(member.name) the owner") { store.makeOwner(member) }
                Button("Remove \(member.name)", role: .destructive) { store.remove(member: member) }
            }
        }
        .confirmationDialog(store.isOwner ? "Stop sharing this home?" : "Leave this house?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(store.isOwner ? "Stop sharing" : "Leave", role: .destructive) { store.leave() }
        } message: {
            Text(store.isOwner ? "Everything stays on this phone. The invite code stops working." : "The house's items are removed from this phone. Your \"Just me\" items stay.")
        }
    }
}
