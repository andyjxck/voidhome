# VoidHomeOS — Project Rundown for AI Assistants

This file describes the code on the `wire-up-everything` branch as it actually is. Check the code before relying on anything here; update this file when you change behaviour.

## 1. What This App Is

**VoidHomeOS** ("Void Home") is a native iOS app that keeps the memory of a home: rooms and a floor plan, assets, documents, warranties, maintenance, projects, people, bills and a household To-Do list. Everything links to everything else, and every detail page has a "Linked" section that goes both ways.

All data is **local only** (SwiftData on the device, files in the app's Documents folder). There is no account, no sync, no bank connection and nothing is ever paid from the app.

## 2. Product rules that must be kept

1. **Only bills can ever be overdue or red.** Cleaning, maintenance, project jobs and every other non-bill job stay neutral everywhere (To-Do, Home, Timeline, Search, notifications). No lateness labels, no scores, no streaks.
   - A repeating job that is missed simply drops off; it never piles up.
   - An unfinished one-off job stays quietly on today's list.
   - A maintenance plan past its date shows on today as "Whenever suits".
   - `VoidPalette.billOverdue` is the only red, and it is only used for `Bill.isOverdue`.
2. **To-Do never copies records.** Only manual and project jobs are stored as `HomeTask`. Bills, maintenance plans, warranty expiries and document expiries are read live from their own records by `TodoFeed`. Ticking a bill records a `BillPayment` and moves its due date on; ticking a plan writes a `Maintenance` log and sets the next date; unticking undoes both.
3. **Timeline and Search store nothing.** Both are built on the fly from existing records.
4. **Never wipe saved data.** See section 5 (migration and backup).
5. Deleting a project never deletes people.

## 3. Platform & Toolchain

- iOS 17.0 deployment target, Swift. Swift packages: firebase-ios-sdk (FirebaseCore, FirebaseAuth, FirebaseFirestore, FirebaseStorage) and GoogleSignIn-iOS. The app still works solo with no account.
- SwiftUI, SwiftData, NavigationStack, VisionKit (document camera), Vision (OCR), PDFKit, PhotosUI, UserNotifications, RoomPlan (LiDAR room scanning, behind `#if canImport(RoomPlan)` and `RoomScanner.isSupported`).
- Forced dark UI (`.preferredColorScheme(.dark)`).
- CI: `.github/workflows/ios-build.yml` builds the app for the iOS Simulator SDK (no signing) on `macos-latest` for every push to `wire-up-everything`, and reports compiled files, warnings and errors as annotations. It does not run the app or any tests (there are none).

## 4. Project Structure

```
VoidHomeOS/
├── AI_CONTEXT.md, README.md
├── .github/workflows/ios-build.yml
├── VoidHomeOS.xcodeproj/
└── VoidHomeOS/
    ├── VoidHomeOSApp.swift     # @main, schema, safe store opening, backup, banner
    ├── Info.plist              # camera, photo library, documents usage strings
    ├── GoogleService-Info.plist, VoidHomeOS.entitlements (Sign in with Apple)
    ├── Sync/                   # shared households on Firebase (section 15)
    ├── Models/                 # SwiftData @Model classes (see section 6)
    │   Asset, Bill (+BillPayment), Document, Door, Floor, Home,
    │   HomeTask (+TaskChecklistItem, TaskCompletion), Maintenance,
    │   MaintenancePlan (+ProjectPhoto), Person, Project, ProjectSpend, Room (+FloorplanGeometry), RoomPart, Warranty
    ├── Services/
    │   ├── TodoFeed.swift              # builds To-Do rows and history from live records
    │   ├── NotificationService.swift   # local reminders
    │   ├── OCRService.swift            # Vision text recognition + receipt reader
    │   ├── DocumentScannerService.swift # VisionKit scanner + DocumentStorage (files)
    │   └── RoomScannerService.swift    # RoomPlan capture -> RoomScanSummary
    └── Views/
        HomeScreen (launcher + dock), HomeDashboardView, TodoView, BillsView,
        RoomsListView (floor plan + room pages), RoomShapeEditor, AssetsListView,
        DocumentsListView, WarrantiesListView, MaintenanceListView, ProjectsListView,
        PeopleListView, TimelineView, SearchView, SharedViews, VoidUI
```

## 5. App Entry, Migration and Backup

`VoidHomeOSApp` declares one `Schema` with every model. Every field added since the first release has a default value or is optional, so SwiftData migrates the existing store in place (lightweight migration). There is no `VersionedSchema`/`SchemaMigrationPlan`.

If the store still fails to open, the app **does not delete it**: `StoreBackup.copyStore` copies the SQLite file and its `-wal`/`-shm` side files to `Documents/Backup-<date>` (visible in Files › Void Home), the app runs on an empty in-memory store, and `StoreProblemBanner` tells the user that nothing they change will be kept and where the backup is. This has not been tested against a real old store.

Rules for schema changes: give every new stored property a default or make it optional; never rename or remove a stored property without a proper migration plan; never add code that deletes the store.

A default "My Home" is created on first launch if none exists.

## 6. Data Model (SwiftData)

All models are `@Model final class`. Enums are stored as raw strings (`...Raw`) with computed accessors where they were added later.

- **Home** — `name`, `address`. Cascades to `rooms`, `assets`, `projects`, `floors`.
- **Floor** — `name`, `floorNumber` (0 Ground, 1 1st, -1 Basement).
- **Room** — `name`, `floorNumber`, `width`/`height` (metres), `rotation` (degrees, used in quarter turns), `planX`/`planY` (centre in metres from the plan origin; legacy `xPosition`/`yPosition` are migrated once). Links: `assets`, `documents`, `projects`, `tasks`, `maintenanceRecords`, `maintenancePlans`, `parts` (cascade), `doors` (cascade). `area` is the union area of all pieces.
- **RoomPart** — extra rectangle of an L/T/U-shaped room: `name`, `width`, `height`, `xOffset`, `yOffset` (from room centre), its own `doors`.
- **Door** — `edge` (top/bottom/left/right), `position` (0–1 along the edge), `opensLeft` (hinge at the left/top end), `opensInward`, `isDoubleDoor`; belongs to a `room` and optionally a `part`.
- **Asset** — name, category, manufacturer, model, serial number, purchase date/price, location, notes, `photoFileName`. Links: `room`, `documents`, `warranties` (cascade), `maintenanceRecords` (cascade), `maintenancePlans`, `projects`, `tasks`.
- **Document** — `title`, `type` (Manual, Receipt, Invoice, Certificate, Guarantee, Other), `fileURL` (file name in `Documents/UploadedDocuments`), `ocrText`, optional `expiryDate`. Links: `asset`, `room`, `warranty`, `bill`, `project`, `maintenance`.
- **Warranty** — provider, start/expiry dates, notes, `claimContact`, `documents`, `asset`. `status`: Active, Ending soon (60 days), Expired.
- **Maintenance** (log entry) — `task`, `date`, `cost`, notes, `asset` or `room`, `person`, `plan`, `documents`.
- **MaintenancePlan** (repeating) — `title`, interval value + unit, `nextDueDate`, `lastDoneDate`, time of day, notes, `isPaused`, `asset` or `room`, `person`, `logs`.
- **Project** — title, description, start/end dates, budget, actual cost, status (Planned, In Progress, Completed, On Hold), notes. Links: `contractors` (nullify), `rooms`, `assets`, `documents`, `tasks` (cascade), `photos` (`ProjectPhoto`, before/after, cascade).
- **Person** — name, company, role, phone, email, notes, `kind` (Household, Tradesperson, Provider). Reverse links: assigned tasks, task completions, maintenance work, bills, maintenance plans.
- **Bill** — name, category, amount, `isEstimate`, frequency (weekly … yearly, one-off), `nextDueDate`, `paymentMethod` (typed text), `contractEndDate`, notes, `isSettled` (one-off paid), `provider` (Person), `payments` (`BillPayment`: amount, paid date, due date, note), `documents`. `isOverdue` = unpaid and past due.
- **HomeTask** (To-Do job) — title, notes, time of day, optional `startDate`, repeat (Once, Daily, Weekly on chosen weekdays, Monthly, Yearly), `isDone` (one-offs), `assignee`, `project`, `room`, `asset`, `checklist` (`TaskChecklistItem`), `completions` (`TaskCompletion`: occurrence date, completed at, note, photo, person). `appears(on:)` holds the no-pile-up rules.

`FloorplanGeometry` (in `Room.swift`) holds plan maths: `pointsPerMetre`, local and world rects for a room's pieces, quarter-turn rotation, bounds, overlap checks, snapping, free-spot search and `hostRect(for:in:)` for doors on extra pieces.

## 7. Services

- **TodoFeed** — builds To-Do rows (`TodoItem` with a `TodoSource` of task, bill, plan, warranty or document) and the History list for any day, and performs tick/untick.
- **NotificationService** — local reminders with stable identifiers from each record's `reminderID`:
  - warranties: 30 days before (or fewer if sooner) and on the day;
  - one-off maintenance records: 7 days before;
  - bills: 2 days before and on the day, plus 30 days before a contract ends;
  - maintenance plans: on the day, worded "Whenever suits";
  - document expiry: 30 days before and on the day.
  To-Do jobs have no notifications.
- **OCRService** — Vision text recognition for images, scans and PDFs (async, via continuation), plus a simple receipt reader (amount, date).
- **DocumentScannerService** — VisionKit scanner, and `DocumentStorage` for files in `Documents/UploadedDocuments`.
- **RoomScannerService** — RoomPlan capture on LiDAR devices, turned into an axis-aligned room outline with doors and detected objects. `isSupported` is false in the Simulator.
- **PhotoStore** (in `VoidUI.swift`) — JPEGs in `Documents/Photos` for asset, project and completion photos.

## 8. Screens

- **HomeScreen** — launcher. Grid of eight: Rooms, Assets, Documents, Warranties, Maintenance, Projects, Timeline, Search. Dock of four: Home, Bills, People, To-Do.
- **HomeDashboardView** — Today ring, tiles that open each page (bills this week, warranties ending, maintenance, projects, assets, rooms), Coming up for two weeks, home details.
- **TodoView** — Today grouped Morning/Afternoon/Evening/Anytime with a week strip; All jobs and History tabs; add needs only a title; long-press to complete with note, photo and person; `TaskDetailView` with its own history.
- **BillsView** — bills list, rough monthly total, paid this month, Mark paid, payment history chart, contract-ending warning. Never connects to a bank.
- **RoomsListView** — floor plan and room pages (see section 9).
- **AssetsListView** — photo cards with warranty badge; asset page links to room, warranties, documents, plans, history, jobs, projects.
- **DocumentsListView** — coloured folders by type, first-page previews, search inside scanned text, expiry dates, links.
- **WarrantiesListView** — shield cards with countdown bar, grouped Active / Ending soon / Expired, claim contact, receipts.
- **MaintenanceListView** — Plans, Log and By item views.
- **ProjectsListView** — jobs with progress, budget bar, spending, before/after photos, links to people, rooms, assets, documents.
- **PeopleListView** — people by kind; person page shows jobs, projects, bills, plans, work done and completions, with Text/Email/Call.
- **TimelineView** — see below.
- **SearchView** — see below.

### SearchView
Searches rooms (name, floor, piece names), assets (incl. serial number and notes), documents (title, type and **scanned text**), warranties (provider, asset, claim contact, notes), maintenance plans and logs, projects (incl. description and notes), bills (name, provider, category, payment method, notes), To-Do jobs (title, links, assignee, checklist, notes, completion notes) and people (incl. notes). Results are grouped by type with counts; title matches sort first. When the match is not in the title, a snippet around it is shown with a label (e.g. "Scanned text", "Note"), and matching words are highlighted in titles and snippets. Each result opens the exact record's detail page. The last eight searches are kept in `@AppStorage("search.recent")` on the device, with per-item remove and Clear. Only an overdue bill's subtitle is red.

### TimelineView
Built by `TimelineBuilder.build` from records; stores nothing. Layout: filter chips (All, Bills, To-Do, Maintenance, Warranties, Projects, Assets, Documents), a **Coming up** section for the next 60 days (soonest first, overdue bills pinned at the top), a **Today** line, then history newest-first under month headers on a vertical rail.
- History: assets bought, project start/finish, maintenance logs, warranty start/end, documents added and expired, bill payments, To-Do completions (with who and the note).
- Coming up: bills due (an unpaid bill past due shows on today as "Overdue" in red — the only red), maintenance plans (past-due plans sit on today as "Whenever suits"), maintenance records dated in the future, warranty endings, document expiries, project dates, and the next day each To-Do job is on the list and not yet done.
Every row opens its record.

## 9. Floor plan (RoomsListView)

- One canvas per floor, with grid, pinch zoom and pan (zoom about the screen centre), double-tap to reset, floor switcher, edit mode, door mode, rotation in quarter turns, magnetic snapping to other rooms with guide lines and a haptic, overlap prevention, "Tidy to grid" auto-arrange, `RoomShapeEditor` for extra pieces, and LiDAR scanning on supported devices.
- Drawing (`FloorplanDrawing` helpers):
  - `InteractiveFloorplanRoom` draws each room's floor (blue when selected) and an upright label with name, m² (union area) and up to six asset dots ("+n" beyond).
  - `FloorplanWallsLayer` draws walls for all rooms on the floor in one pass, as a 0.15 m band centred on each room's outline (pieces of one room are unioned so there's no wall between them). Walls of touching rooms overlap exactly, so a shared wall reads as one. Door openings are cleared through every wall at that spot, then door leaves (0.8 m, two for double doors) and dashed swing arcs are drawn. It also draws measurement lines: width and depth of the selected room, or of the whole floor when nothing is selected. It ignores touches.
  - While a room is dragged, the layer leaves that room out and the room draws its own walls and doors (`FloorplanRoomLayer.complete`) so they follow the finger.
  - `FloorplanScaleBar` (top left) picks 25 cm … 20 m to suit the zoom.
  - Door swing direction is consistent on every edge: `opensInward` swings into the room.
- **Room page** (`RoomDetailView`): name, floor, area, and sections for assets, documents, warranties (of items in the room), maintenance plans and history (room's own plus its items'), projects (linked to the room or to its items, with "via an item here"), and To-Do jobs for the room or its items (finished one-offs hidden). Add/Link buttons create plans, logs and jobs pre-linked to the room, and link projects.

## 10. Design System

Cosmic glass look: `StarryBackground`, muted per-module tints in `VoidPalette` (`VoidUI.swift`), glass cards via `.voidCard(cornerRadius:)`, uppercase letter-spaced labels, system fonts only. Shared building blocks: `VoidPage`, `ChipBar`, `StatTile`, `LinkedSection`, `LinkRow`, `MultiLinkSheet`, `FormSheet`, picker/date fields, `PhotoStore`, `DayText`, `Money` (in `SharedViews.swift`), `GlassSectionHeader`. Module pages use a custom Back button with `@Environment(\.dismiss)` and hide the nav bar.

## 11. Known Issues & Not Verified

- Nothing on this branch has been run in a simulator or on a phone by the AI; only CI compile checks have passed.
- Lightweight migration and the backup path have not been tested against the user's real saved data.
- Shared households (section 15) compile in CI, and the Firestore rules passed emulator tests, but sign-in, joining and multi-device sync have not been run on a phone.
- No tests, no ViewModels (logic lives in views and `TodoFeed`).
- Compiler warnings: missing `AccentColor` asset, deprecated `contentEdgeInsets` in `RoomScannerService`, and a retroactive `Identifiable` conformance on `URL` in `DocumentsListView`.
- Not built: barcode scanning, Spotlight, export, Watch app, Android app (contract in section 15).

## 12. Build & Run

```bash
git fetch && git checkout wire-up-everything && git pull
open VoidHomeOS.xcodeproj
```
Pick an iOS 17+ simulator and press Cmd+R. LiDAR scanning needs a Pro iPhone or iPad.

## 13. Conventions

- Persist with `@Environment(\.modelContext)` and `@Query`.
- New stored properties need defaults (section 5).
- Keep the bill-only overdue rule (section 2) in any new screen.
- Push work to `wire-up-everything`; leave `main`/`master` alone.

## 14. License

Proprietary — all rights reserved (per README).

## 15. Shared households (Firebase) — contract for iOS and Android

This section is the contract between the iOS app and the planned native Android app
(Kotlin / Jetpack Compose). Both talk to the same Firebase project with no server code.
Android must follow it exactly; anything not listed here is iOS-local.

### 15.1 Firebase project

- Project ID: `void-home-app` (display name "Void Home"). Firestore `(default)` database, Native mode, region `europe-west2` (London).
- iOS app: bundle `com.void.homeos`, team `T963633DC5`, config in `VoidHomeOS/GoogleService-Info.plist` (client config only, no secrets).
- Android app: register package name + SHA-1/SHA-256 in the Firebase console, download `google-services.json`. Google sign-in on Android uses the **Web client ID** (`default_web_client_id`) with Credential Manager, then `GoogleAuthProvider.getCredential(idToken, null)`.
- Sign-in providers: **Apple** and **Google** (Firebase Auth). Either account type can create or join a house. There is no anonymous or email/password sign-in. Android can offer Sign in with Apple through `OAuthProvider("apple.com")` only after an Apple Services ID is created in the Apple Developer portal with return URL `https://void-home-app.firebaseapp.com/__/auth/handler`, and its Services ID, Team ID, key ID and private key are added to the Apple provider in Firebase. iOS doesn't need that (it uses the bundle ID `com.void.homeos`). Google is the expected Android route.
- iOS Google sign-in: `CLIENT_ID` / `REVERSED_CLIENT_ID` are in `GoogleService-Info.plist`; the reversed client ID is registered as a URL scheme in `VoidHomeOS/Info.plist` (now used via `INFOPLIST_FILE`, merged with the generated keys).
- Rules live in the repo: `firebase/firestore.rules`, `firebase/storage.rules` (`firebase.json`, `.firebaserc`). Deploy with `firebase deploy --only firestore:rules,storage`.
- Offline: iOS uses Firestore's persistent cache (200 MB). Android should keep the default persistent cache on. Conflict policy is **last write wins** per document.

### 15.2 Collections

```
users/{uid}
  displayName: string
  email: string
  houseId: string            // absent when not in a house
  updatedAt: timestamp

invites/{code}               // code = 6 chars from ABCDEFGHJKMNPQRSTUVWXYZ23456789
  houseId: string
  createdBy: uid
  createdAt: timestamp

houses/{houseId}             // auto ID
  name: string
  ownerId: uid
  memberIds: [uid]           // the access list used by the rules
  members: { uid: { name: string, joinedAt: timestamp } }
  inviteCode: string         // the one current code; "" disables joining
  joinCode: string           // written by a joiner; must equal inviteCode (see 15.4)
  createdAt, updatedAt: timestamp

houses/{houseId}/items/{syncId}                   // "Everyone" records
houses/{houseId}/private/{uid}/items/{syncId}     // "Just me" records of that uid
```

Every record document (both paths) has the same envelope:

| field | type | meaning |
|---|---|---|
| `type` | string | record type, table below |
| `syncId` | string | same as the document ID; a UUID string (member people use `member-<uid>`) |
| `visibility` | string | `"house"` or `"me"`, matches the path |
| `deleted` | bool | tombstone; `true` means delete locally. `data` is then `{}` |
| `createdBy` | uid | who first made it (only they may change Just me / Everyone) |
| `updatedBy` | uid | last writer; **must equal the writer's uid** (rules) |
| `updatedAt` | timestamp | `serverTimestamp()` on every write |
| `data` | map | the record's fields, below |

Rules for `data`:
- Field names are exactly the property names below.
- Dates are Firestore `timestamp`. Optional fields are `null` when empty.
- To-one links are `<name>Id: syncId | null`. To-many links are `<name>Ids: [syncId]` (sorted).
- Enums are their raw strings. Money is a plain number in the phone's currency.
- Split maps are **JSON strings** (`sharesJSON`, `repaidJSON`, `customSharesJSON`), e.g. `"{\"uidA\":12.5,\"uidB\":12.5}"`.
- Readers must ignore unknown fields and keep their local value for missing fields.
- Moving a record between Everyone and Just me = write a tombstone at the old path and the full record at the new path.
- A deleted record is never removed from Firestore, only tombstoned, so offline phones learn about it.

### 15.3 Record types and fields (`type` → `data`)

Visibility column: **always** = always in `items` (shared); **own** = has its own Just me / Everyone choice; **follows X** = lives wherever its parent X lives.

| type | visibility | data fields |
|---|---|---|
| `home` | always | name, address, createdAt |
| `floor` | always | name, floorNumber(int), createdAt, homeId |
| `room` | always | name, floor, floorNumber(int), width, height (metres), dimensions, rotation (0/90/180/270), createdAt, xPosition, yPosition, planX?, planY? (metres), ownerUid ("" = shared room; else whose bedroom), homeId |
| `roomPart` | always | name, width, height, xOffset, yOffset, createdAt, roomId |
| `door` | always | edge (top/bottom/left/right raw), position (0–1), opensLeft, opensInward, isDoubleDoor, createdAt, roomId, partId |
| `person` | own | name, company, role, phoneNumber, email, notes, createdAt, kindRaw (household/tradesperson/provider), memberUid (set = real account, "Member" badge) |
| `asset` | own | name, category, manufacturer, model, serialNumber, purchaseDate?, purchasePrice, location, notes, createdAt, photoFileName?, homeId, roomId |
| `project` | own | title, projectDescription, startDate?, endDate?, budget, actualCost (house spending total), status (raw), notes, createdAt, homeId, contractorsIds, roomsIds, assetsIds |
| `warranty` | follows asset | provider, startDate, expiryDate, notes, createdAt, remindersEnabled, claimContact, assetId |
| `maintenancePlan` | follows asset | title, intervalValue(int), intervalUnitRaw, nextDueDate, lastDoneDate?, timeOfDayRaw, notes, remindersEnabled, isPaused, createdAt, assetId, roomId, personId |
| `maintenance` | follows plan, else asset | task, date, cost, notes, createdAt, remindersEnabled, assetId, roomId, personId, planId |
| `bill` | own | name, categoryRaw, amount, isEstimate, frequencyRaw, nextDueDate, paymentMethod, contractEndDate?, notes, remindersEnabled, isSettled, createdAt, splitModeRaw ("equal"/"custom"), customSharesJSON ({uid: percent}), providerId |
| `billPayment` | follows bill | amount, paidDate, dueDate, note, paidByUid, sharesJSON ({uid: amount}), repaidJSON ({uid: ISO date}), billId |
| `task` | own | title, notes, timeOfDayRaw, startDate?, repeatRaw, weekdaysRaw, isDone, createdAt, assigneeId (person), projectId, roomId, assetId |
| `checklistItem` | follows task | title, order(int), createdAt, checkedOn?, taskId |
| `taskCompletion` | follows task | occurrenceDate, completedAt, note, photoFileName?, completedByUid, personId, taskId |
| `document` | own (new ones default to Just me) | title, type (DocumentType raw), fileURL (file **name** only), ocrText, createdAt, expiryDate?, warrantyId, billId, projectId, maintenanceId, assetId, roomId |
| `projectPhoto` | follows project | fileName, isAfter, caption, createdAt, projectId |
| `projectSpend` | own (Just me only allowed on a house project; follows project if the project is Just me) | amount, note, date, paidByUid, sharesJSON, repaidJSON, createdAt, projectId |

Apply order for a batch (parents first): home, floor, room, roomPart, door, person, asset, project, warranty, maintenancePlan, maintenance, bill, billPayment, task, checklistItem, taskCompletion, document, projectPhoto, projectSpend. Apply all fields first, links second.

What each viewer sees: Home, Timeline, Search, To-Do etc. show everything in `items` plus that viewer's own `private/{uid}/items`. A link to a record the viewer can't see resolves to nothing.

### 15.4 Invite and join flow

1. **Sign in** (Apple or Google). Write `users/{uid}` `{displayName, email, updatedAt}` with merge.
2. **Create house** (owner). One batch:
   - `houses/{newId}`: `{name, ownerId: uid, memberIds: [uid], members: {uid: {name, joinedAt}}, inviteCode: CODE, createdAt, updatedAt}`
   - `invites/{CODE}`: `{houseId, createdBy: uid, createdAt}`
   then `users/{uid}.houseId = newId`. The phone's existing local data is backed up and then uploaded to `items` / `private` by the sync engine. Nothing local is deleted.
3. **Join** (anyone signed in):
   - `get invites/{CODE}` from the server → `houseId` (list is denied, so codes can't be enumerated).
   - `update houses/{houseId}`: `memberIds: arrayUnion(uid)`, `members.<uid>: {name, joinedAt}`, `joinCode: CODE`, `updatedAt`. The rules accept this only if `joinCode == inviteCode` and nothing else changes.
   - Then `users/{uid}.houseId = houseId`. iOS backs up the joiner's local store, clears it, and loads the house.
4. **New code** (owner only). One batch: delete `invites/{OLD}`, create `invites/{NEW}`, set `houses/{id}.inviteCode = NEW`. The old code stops working at once.
5. **Remove member** (owner): `memberIds: arrayRemove(uid)`, `members.<uid>: delete()`. The removed phone's listener gets permission-denied; after three server denials it backs up, deletes house records locally, keeps its own Just me records, and clears `users/{uid}.houseId`.
6. **Hand over ownership** (owner): set `ownerId` to another member's uid.
7. **Leave** (member): remove self from `memberIds` and `members`. An owner must hand over first; an owner alone may close the house (delete `invites/{code}` and `houses/{id}`), keeping all data locally.
8. Every member also appears as a `person` record with `syncId = member-<uid>`, `kindRaw = household`, `memberUid = uid` (fixed ID, so two phones never make duplicates).

### 15.5 Security rules (summary of `firebase/firestore.rules`)

- `users/{uid}`: read/write only by that uid.
- `invites/{code}`: `get` by any signed-in user, no `list`. Create only by the house owner, and only for the house's current `inviteCode` (checked with `getAfter`, so it works in the create batch). Delete by the owner, or by anyone once the house is gone. No updates.
- `houses/{id}`: `get` only by members, no `list`. Create only as sole member and owner. Update:
  - owner: anything, as long as `ownerId` stays in `memberIds`;
  - member: only `name`, `address`, `updatedAt`, their own `members.<uid>` entry, or removing themselves;
  - non-member: join only (adds just themselves, `joinCode == inviteCode`, `inviteCode` non-empty, nothing else).
  Delete only by the owner.
- `houses/{id}/items/{syncId}`: members read and write; `updatedBy` must be the writer and `syncId` must equal the document ID.
- `houses/{id}/private/{uid}/items/{syncId}`: only that uid, while a member. Not even the owner can read it.
- Storage (`firebase/storage.rules`): `houses/{id}/files/{syncId}/{name}` for members; `houses/{id}/private/{uid}/files/{syncId}/{name}` for that uid only; 25 MB per file.

The rules were tested on the Firestore emulator with `@firebase/rules-unit-testing` (create, join with right/wrong/old code, privacy of Just me records, owner tools, leaving, removal).

### 15.6 Files (photos and scans)

Photos (`photoFileName`, `fileName`) and scanned documents (`fileURL`) are uploaded to Firebase Storage at the paths above, using the record's `syncId` and the file name. Phones download missing files when the record arrives. **Firebase Storage needs the Blaze (pay-as-you-go) plan on new projects.** Until Storage is enabled, records sync but photos and scans stay on the phone that made them, and the house screen says so.

### 15.7 Bills: split and who owes who

- `bill.visibility = me`: private, counts fully towards that person's totals only.
- `bill.visibility = house`: split between **current** members. `splitModeRaw = "equal"`, or `"custom"` with `customSharesJSON` percentages (normalised over current members; one person at 100 covers it).
- "I paid this" (ticking the bill) creates a `billPayment` with `paidByUid = me` and `sharesJSON` fixed at that moment, so membership changes only affect later payments.
- Each other member owes `paidByUid` their share until it is in `repaidJSON` (either the payer or the debtor can tick it).
- "Who owes who" nets all unrepaid shares (bills and house `projectSpend`) pairwise.
- A shared bill is overdue only while the provider is unpaid (`nextDueDate` passed). Owing a share is shown neutrally, never red.
- Monthly total and "paid this month" use the viewer's share for shared bills.

### 15.8 iOS implementation

- `Sync/HouseStore.swift` — Firebase setup, Apple/Google sign-in, create/join/leave/remove/hand over, member people.
- `Sync/SyncEngine.swift` — listeners on `items` and `private/{uid}/items`; pushes local changes every 4 s and when the app leaves the foreground; Storage upload/download.
- `Sync/SyncCore.swift`, `Sync/SyncRecords.swift` (generated by `python3 tools/gen_sync_records.py`; edit the model list there, then regenerate) — the field mapping above.
- `Sync/BillSplit.swift`, `Sync/SharingViews.swift` (Just me / Everyone field, bill split fields, Who owes who card, House screen, Whose room field), `Sync/HouseContext.swift`.
- Change detection: each model has `syncId`, `visibilityRaw`, `createdBy`, `updatedBy`, `syncHash` (fingerprint of the last synced fields) and `syncScope`. A record whose fingerprint differs from `syncHash` is pushed. An incoming change is skipped for a record with an unpushed local edit (that edit is pushed next, so the last write to reach the server wins). Deletions are found by comparing with the IDs synced before; if the local store is completely empty the engine refuses to send deletions.
- Sync never runs on the temporary in-memory store used after a failed store open.
