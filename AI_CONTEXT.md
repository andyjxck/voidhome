# VoidHomeOS — Full Project Rundown for AI Assistants

## 1. What This App Is

**VoidHomeOS** (branded "Void Home OS") is a premium, native iOS app for organizing the memory of a home. It treats a home as a connected graph of real-world objects: rooms, assets, documents, warranties, maintenance records, people, and projects. It is *not* a notes app, file manager, or smart-home controller — it is a structured home inventory + history system.

**Vision statement:** "A home has thousands of important details, but no memory. Void Home OS becomes the organised memory of the home."

**Target feel:** "Apple created a system for managing your home." Minimal, calm, premium, intentional — inspired by Apple hardware design and Nothing's minimalism.

## 2. Platform & Toolchain

- iOS 17.0+ (some features gated at iOS 16.0 via `@available`)
- Xcode 15.0+, Swift 5.0+
- Pure Apple frameworks — no third-party dependencies:
  - **SwiftUI** — declarative UI
  - **SwiftData** — persistence (Core Data replacement)
  - **NavigationStack** — navigation
  - **VisionKit** (`VNDocumentCameraViewController`) — document scanning
  - **Vision** (`VNRecognizeTextRequest`) — OCR
  - **PhotosUI** — photo picker
  - **UserNotifications** — local reminders
  - **RoomPlan** — referenced in README but currently **stubbed out** (import commented out in `RoomScannerService.swift`)
- Force-dark UI: `.preferredColorScheme(.dark)` at the app root.

## 3. Project Structure

```
VoidHomeOS/
├── README.md
├── .clineignore
├── VoidHomeOS.xcodeproj/
└── VoidHomeOS/
    ├── VoidHomeOSApp.swift          # @main entry, ModelContainer setup, notif auth
    ├── Info.plist                   # Camera / Photo Library / Documents usage strings
    ├── LaunchScreen.storyboard
    ├── Assets.xcassets/
    ├── Models/                      # 8 SwiftData @Model classes
    │   ├── Home.swift
    │   ├── Room.swift
    │   ├── Asset.swift
    │   ├── Document.swift
    │   ├── Warranty.swift
    │   ├── Maintenance.swift
    │   ├── Person.swift
    │   └── Project.swift
    ├── Views/                       # SwiftUI screens (12 files)
    │   ├── HomeScreen.swift         # Launcher grid + HomeDetailView + PlaceholderView
    │   ├── RoomsListView.swift      # Floorplan + list modes (616 lines, largest view)
    │   ├── AssetsListView.swift
    │   ├── DocumentsListView.swift
    │   ├── WarrantiesListView.swift
    │   ├── MaintenanceListView.swift
    │   ├── PeopleListView.swift
    │   ├── ProjectsListView.swift   # 903 lines — projects + contractors
    │   ├── TimelineView.swift
    │   ├── SearchView.swift         # Global cross-entity search
    │   └── SharedViews.swift        # Canonical glass components (610 lines)
    ├── Services/
    │   ├── DocumentScannerService.swift   # VisionKit wrapper
    │   ├── OCRService.swift               # Vision OCR + receipt parsing
    │   ├── NotificationService.swift      # UNUserNotificationCenter singleton
    │   └── RoomScannerService.swift       # STUB — RoomPlan not wired in
    ├── ViewModels/                  # Empty — MVVM in name only; logic lives in views
    └── Resources/                   # Empty
```

Total: ~6,260 lines of Swift across 23 source files.

## 4. App Entry Point

`VoidHomeOSApp.swift`:
- Builds a `ModelContainer` with the schema of all 8 models (`isStoredInMemoryOnly: false`).
- On launch, requests notification authorization via `NotificationService.shared.requestAuthorization()` in a `Task`.
- Root scene: `HomeScreen()` injected with the model container, forced to dark color scheme.
- Fatal-asserts if the container can't be created (will crash on schema mismatch — no migration handling beyond default-value fields).

## 5. Data Model (SwiftData)

All models use `@Model final class`. Relationships use `@Relationship(deleteRule:)`.

### Home
- `name`, `address`, `createdAt`
- Cascade relationships to `rooms: [Room]`, `assets: [Asset]`, `projects: [Project]`
- A single default "My Home" is auto-created on first launch if none exists.

### Room
- `name`, `floorNumber: Int` (0 = Ground, 1 = 1st Floor, -1 = Basement), `width`/`height: Double` (meters, defaults 3.0×4.0), `rotation: Double` (degrees), `xPosition`/`yPosition: Double` (normalized 0–1 for floorplan placement)
- Legacy string fields `floor` and `dimensions` kept populated for migration safety
- Computed: `floorDisplay`, `dimensionsDisplay` ("3.0m x 4.0m")
- `home: Home?` (nullify on delete), `assets: [Asset]` (cascade)

### Asset
- `name`, `category`, `manufacturer`, `model`, `serialNumber`, `purchaseDate: Date?`, `purchasePrice: Double`, `location`, `notes`, `createdAt`
- `home: Home?` and `room: Room?` (both nullify)
- Cascade to `documents: [Document]`, `warranties: [Warranty]`, `maintenanceRecords: [Maintenance]`

### Document
- `title`, `type: DocumentType`, `fileURL: String`, `ocrText: String`, `createdAt`
- `asset: Asset?` (nullify)
- `DocumentType` enum: `manual`, `receipt`, `invoice`, `certificate`, `guarantee`, `other`

### Warranty
- `provider`, `startDate`, `expiryDate`, `notes`, `createdAt`
- `asset: Asset?` (nullify)
- Computed: `isExpired: Bool`, `daysUntilExpiry: Int?`

### Maintenance
- `task`, `date`, `cost: Double`, `notes`, `createdAt`
- `asset: Asset?` (nullify)

### Person
- `name`, `company`, `role`, `phoneNumber`, `email`, `notes`, `createdAt`
- No inverse relationship declared (referenced by `Project.contractors` via cascade)

### Project
- `title`, `projectDescription`, `startDate: Date?`, `endDate: Date?`, `budget: Double`, `actualCost: Double`, `status: ProjectStatus`, `notes`, `createdAt`
- `home: Home?` (nullify), `contractors: [Person]` (cascade)
- `ProjectStatus` enum: `planned`, `inProgress`, `completed`, `onHold`

**Note:** `Person` has no inverse back-reference, and `Project.contractors` uses `.cascade` — deleting a project will delete its contractors, which may be unexpected if a person is shared across projects. Worth flagging.

## 6. Services

### NotificationService (singleton)
- `requestAuthorization()` — async, requests `.alert/.sound/.badge`
- `scheduleWarrantyExpiryReminder(for:)` — fires on the expiry date itself (not N days before — note this is a potential bug vs. the README's "expiry alerts" intent)
- `scheduleMaintenanceReminder(for:daysBefore:)` — defaults to 7 days before `maintenance.date`
- `scheduleCustomReminder(title:body:date:)`
- `cancelNotification(withIdentifier:)`, `cancelAllNotifications()`
- Identifiers: `"warranty-\(id)"`, `"maintenance-\(id)"`, or UUID for custom

### OCRService
- `recognizeText(from:) async -> String` — uses `VNRecognizeTextRequest`, `.accurate`, `en-US`, language correction on. **Bug:** the completion handler builds `recognizedText` as a local constant that is never returned — the function always returns `""`. The async wrapper does not actually bridge the callback result.
- `extractReceiptInfo(from:) -> ReceiptInfo` — regex-based: first non-price/non-"Total" line ≥4 chars becomes `retailer`; matches `\d{1,2}[/-]\d{1,2}[/-]\d{2,4}` for date; matches `\$?\d+\.\d{2}` for total (prefers lines containing "total", else largest price)
- `ReceiptInfo { retailer, date: Date?, total: Double }`
- Uses a custom `DateFormatter.then { }` helper for inline configuration

### DocumentScannerService
- `DocumentScannerView: UIViewControllerRepresentable` wrapping `VNDocumentCameraViewController`
- Bindings: `isPresented`, `scannedImages: [UIImage]`
- Coordinator handles success (collects all pages), cancel, and error

### RoomScannerService
- **Currently a stub.** `RoomPlan` import is commented out. `RoomScannerView` shows a label "Room Scanner (Not available in this environment)" and after 1s sets `scannedResult = "Stub room data"`. `RoomScannerResultView` displays the string. README/feature list overstate this — it is not functional.

## 7. UI / Design System

### Aesthetic
"Cosmic / glassmorphic" — deep midnight gradient backgrounds with subtle purple radial glows, a sparse starfield, and frosted-glass cards/icons with thin gradient strokes and soft shadows. Heavy use of `LinearGradient`/`RadialGradient`, `RoundedRectangle(cornerRadius: 22, style: .continuous)`, white-on-near-black text, and letter-spaced uppercase labels.

### Color tokens (from README, used inline as `Color(red:green:blue:)`)
- Background: `RGB(0.1, 0.1, 0.11)` — deep charcoal
- Surface: `RGB(0.2, 0.2, 0.22)`
- Text primary: white
- Text secondary: `RGB(0.6, 0.6, 0.62)`
- Text tertiary: `RGB(0.5, 0.5, 0.52)`
- Accent palette: muted purples/blues/teals per module (each app icon has its own tint)

### Typography (system font)
- Header: 34pt Light (home screen uses 44pt UltraLight with tracking 6)
- Title: 17pt Medium
- Body: 15pt Regular
- Caption: 13pt Regular
- Small/labels: 11pt Medium/Semibold, uppercase, tracking 1.5–3

### Reusable components (defined twice — see "Known issues")
- `StarryBackground` — gradient + Canvas-drawn 80 stars with `drawingGroup()` GPU flattening. All shared components live in `SharedViews.swift` (the orphaned `SharedComponents.swift` duplicate was removed during the Step 1 consolidation).
- `GlassAppIcon<Destination: View>` — 76×76 rounded-square icon with tinted glass layers, glossy top highlight, press-scale animation via `GlassAppButtonStyle`
- `GlassStatCard`, `GlassDetailCard`, `GlassTextField` (supports multiline via `TextEditor`), `PersonRow`, `AssetRow`
- `VisualOrbMetric` — circular "orb" metric with gradient ring (defined in `HomeScreen.swift`)
- `PlaceholderView` — "Coming Soon" screen for unimplemented modules

### Navigation
- `NavigationStack` at the root
- `HomeScreen` hides the nav bar; module views use `.inline` title display + custom back buttons calling `@Environment(\.dismiss)`
- App icons are `NavigationLink`s into each module

## 8. Screens / Modules

### HomeScreen (launcher)
- 4-column `LazyVGrid` of `GlassAppIcon`s: Home, Rooms, Assets, Documents, Warranties, Maintenance, People, Projects, Timeline, Search
- "VOID" wordmark + home name header
- Auto-creates default "My Home" on first appear

### HomeDetailView
- Immersive cosmic orb visual, home name/address, three `VisualOrbMetric`s (rooms/assets/projects counts), glass details card

### RoomsListView (616 lines — most complex)
- Toggle between **Floorplan mode** (rooms positioned via `xPosition`/`yPosition` on a canvas, filtered by `currentFloor`) and **List mode**
- Floor selector derived from existing rooms
- Add-room sheet, room detail/edit

### AssetsListView, DocumentsListView, WarrantiesListView, MaintenanceListView, PeopleListView, ProjectsListView
- Standard pattern: `@Query` the entity, list of glass rows, add/edit sheets, detail views
- Documents integrates the scanner + OCR flow
- Warranties surfaces `isExpired` / `daysUntilExpiry` and schedules notifications
- Projects (903 lines) is the largest — manages projects plus their `contractors: [Person]`

### TimelineView
- Aggregates `createdAt`/date events across the home's assets, maintenance, projects, warranties into a chronological feed. Empty state handled.

### SearchView
- Single search field; queries all 7 entity types via `@Query` and `lowercased().contains(...)`, returns `SearchResult` array with `id/title/subtitle/type/icon`. (Note: searches in-memory `@Query` results, not Spotlight — fine for current scale.)

## 9. Permissions (Info.plist)
- `NSCameraUsageDescription` — for document scanning & asset photos
- `NSPhotoLibraryUsageDescription` — for photo picker
- `NSDocumentsFolderUsageDescription` — for document storage

## 10. MVP Scope (per README — all marked ✅)
Home launcher; Rooms; Assets; Documents; Warranties; Maintenance; People; Projects; Timeline; Global search; Dark mode; Accessibility; VisionKit scanning; OCR; Receipt extraction; Warranty notifications; Maintenance reminders; RoomPlan room scanning (⚠️ actually stubbed); Photo picker.

## 11. Planned / Not Yet Implemented
- Barcode/QR scanning
- Core Spotlight integration
- Photo attachments for assets
- Document file storage (currently `fileURL: String`, no real file management shown)
- Data export
- iCloud sync
- Shared home support
- Apple Watch companion
- "Coming Soon" modules listed in README: Materials, Measurements, Electrical, Heating, Plumbing, Network

## 12. Known Issues & Gotchas (important for any AI working on this)

1. **~~Duplicate type declarations.~~ RESOLVED.** The orphaned `SharedComponents.swift` duplicate was removed during the Step 1 consolidation. `SharedViews.swift` is now the single canonical source for all shared glass components.
2. **OCRService always returns `""`.** `recognizeText(from:)` builds `recognizedText` inside a Vision completion handler but never captures it back to the async return. Needs a continuation/`withCheckedThrowingContinuation` bridge.
3. **RoomPlan is stubbed.** `RoomScannerService.swift` has the import commented out and returns hardcoded "Stub room data". Any feature work claiming RoomPlan/LiDAR scanning is not real yet.
4. **Warranty reminder timing.** `scheduleWarrantyExpiryReminder` triggers on the expiry date itself, not N days before. If "expiring soon" alerts are wanted, schedule earlier.
5. **`Project.contractors` uses `.cascade`.** Deleting a project deletes its `Person` contractors. If a person can belong to multiple projects, this is data loss. Consider `.nullify` or a join model.
6. **`Person` has no inverse relationship** to Project, so SwiftData won't auto-maintain back-references.
7. **No ViewModels exist** despite "MVVM" in the README — all logic is inline in views. The `ViewModels/` directory is empty.
8. **No migration plan** beyond default-valued properties on `Room`. Schema changes will likely fatal-error at launch.
9. **No tests, no CI config, no lint config** in the repo.
10. **`autocapitalization`** is deprecated in newer iOS SDKs; may produce warnings.
11. **`fileURL: String`** for documents — no evidence of actual file persistence/sandbox management in the scanned code; verify how scanned images are stored before assuming durability.

## 13. Build & Run

```bash
cd /Users/andrewblewett/CascadeProjects/VoidHomeOS
open VoidHomeOS.xcodeproj
```
- Select an iOS 17+ simulator (iPhone 15 Pro recommended for RoomPlan, though that feature is stubbed) or a physical device.
- Cmd+R to build and run.
- First launch auto-creates "My Home"; start by adding rooms, then assets within rooms.

## 14. Conventions to Follow When Editing

- Use system fonts via `.font(.system(size:weight:design:))` — no custom fonts.
- Use `Color(red:green:blue:)` literals matching the existing muted palette; do not introduce bright/saturated colors.
- Glass cards: `RoundedRectangle(cornerRadius: 18–22, style: .continuous)` with `Color.white.opacity(0.03–0.04)` fill + thin gradient stroke + soft shadow.
- Uppercase, letter-spaced labels for section headers and field titles.
- Every module view wraps its body in `ZStack { StarryBackground().ignoresSafeArea(); ... }` and provides a custom "Back" chevron button using `@Environment(\.dismiss)`.
- Persist data via `@Environment(\.modelContext)` + `@Query`; insert/delete with `modelContext.insert` / `modelContext.delete`.
- Keep iOS 17.0 as the deployment target; gate older APIs with `@available`.

## 15. License
Proprietary — all rights reserved (per README).
