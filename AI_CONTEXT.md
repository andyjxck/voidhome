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

- iOS 17.0 deployment target, Swift, no third-party dependencies.
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
    ├── Models/                 # SwiftData @Model classes (see section 6)
    │   Asset, Bill (+BillPayment), Document, Door, Floor, Home,
    │   HomeTask (+TaskChecklistItem, TaskCompletion), Maintenance,
    │   MaintenancePlan (+ProjectPhoto), Person, Project, Room (+FloorplanGeometry), RoomPart, Warranty
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
- Assigning jobs to a person only works on this phone; nothing syncs.
- No tests, no ViewModels (logic lives in views and `TodoFeed`).
- Compiler warnings: missing `AccentColor` asset, deprecated `contentEdgeInsets` in `RoomScannerService`, and a retroactive `Identifiable` conformance on `URL` in `DocumentsListView`.
- Not built: barcode scanning, Spotlight, export, iCloud sync, shared homes, Watch app.

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
