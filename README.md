# Void Home OS

A premium native iOS application for home organization. Void Home OS becomes the organised memory of your home, understanding it as a collection of connected things: rooms, assets, systems, documents, maintenance, projects, and history.

## Vision

> A home has thousands of important details, but no memory. Void Home OS becomes the organised memory of the home.

This is not a notes app, file manager, or smart home controller. It is a system that understands the user's home as a collection of connected real-world objects.

## Brand Identity

**Void** represents:
- Minimal
- Calm
- Premium
- Organised
- Intentional

The aesthetic feels like Apple hardware design, Nothing's minimalism, architectural software, and premium home design.

## Features

### Core Modules

- **Home** - Central hub for your home information
- **Rooms** - Manage rooms with dimensions and assets
- **Assets** - Track physical objects (appliances, furniture, etc.)
- **Documents** - Store manuals, receipts, invoices linked to assets
- **Warranties** - Track warranty expiry with automatic alerts
- **Maintenance** - Log maintenance tasks and history
- **Materials** - Track home materials (coming soon)
- **Measurements** - Store room and space measurements (coming soon)
- **Electrical** - Manage electrical systems (coming soon)
- **Heating** - Track heating systems (coming soon)
- **Plumbing** - Manage plumbing information (coming soon)
- **Network** - Network configuration and documentation (coming soon)
- **People** - Contact directory for contractors and service providers
- **Timeline** - Home history showing all events
- **Projects** - Track renovations, decorating, extensions
- **Search** - Global search across all data

### Advanced Features

- **Document Scanning** - Scan documents using VisionKit (iOS 16.0+)
- **OCR Text Recognition** - Extract text from scanned documents using Vision framework
- **Receipt Extraction** - Automatically extract retailer, date, and total from receipts
- **Photo Picker** - Select documents from photo library with PhotosUI
- **Warranty Reminders** - Automatic notifications for warranty expiry
- **Maintenance Reminders** - Schedule reminders for maintenance tasks
- **Room Scanning** - Scan rooms with RoomPlan using LiDAR (iPhone Pro, iOS 17.0+)
- **Room Dimensions** - Automatically capture room dimensions from scans

### Data Model

Everything is a connected object using SwiftData:

- **Home** - Stores rooms, systems, assets, timeline
- **Rooms** - Name, floor, dimensions, assets inside
- **Assets** - Physical objects with manufacturer, model, serial number, purchase info
- **Documents** - Manuals, receipts, invoices linked to assets
- **Warranties** - Provider, dates, linked assets with expiry tracking
- **Maintenance** - Tasks, dates, costs, linked assets
- **People** - Contractors, installers, contact details
- **Projects** - Renovations with costs, documents, contractors, timeline

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Architecture

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Core Data replacement for data persistence
- **MVVM** - Model-View-ViewModel architecture
- **NavigationStack** - Modern navigation
- **Vision Framework** - OCR and text recognition
- **VisionKit** - Document scanning
- **RoomPlan** - Room scanning with LiDAR
- **PhotosUI** - Photo picker integration
- **UserNotifications** - Local notifications for reminders

## Project Structure

```
VoidHomeOS/
├── VoidHomeOS/
│   ├── VoidHomeOSApp.swift          # App entry point
│   ├── HomeScreen.swift             # Home screen with app icons
│   ├── Models/                      # SwiftData models
│   │   ├── Home.swift
│   │   ├── Room.swift
│   │   ├── Asset.swift
│   │   ├── Document.swift
│   │   ├── Warranty.swift
│   │   ├── Maintenance.swift
│   │   ├── Person.swift
│   │   └── Project.swift
│   ├── Views/                       # SwiftUI views
│   │   ├── RoomsListView.swift
│   │   ├── AssetsListView.swift
│   │   ├── DocumentsListView.swift
│   │   ├── WarrantiesListView.swift
│   │   ├── MaintenanceListView.swift
│   │   ├── PeopleListView.swift
│   │   ├── ProjectsListView.swift
│   │   ├── TimelineView.swift
│   │   └── SearchView.swift
│   ├── Services/                    # Service layer
│   │   ├── DocumentScannerService.swift
│   │   ├── OCRService.swift
│   │   ├── NotificationService.swift
│   │   └── RoomScannerService.swift
│   ├── Assets.xcassets/             # Images and icons
│   ├── LaunchScreen.storyboard      # App launch screen
│   └── Info.plist                   # App configuration
└── VoidHomeOS.xcodeproj/            # Xcode project
```

## Setup Instructions

1. **Open the Project**
   ```bash
   cd /Users/andrewblewett/CascadeProjects/VoidHomeOS
   open VoidHomeOS.xcodeproj
   ```

2. **Select Target Device**
   - Choose an iOS Simulator (iPhone 15 Pro recommended) or a physical device

3. **Build and Run**
   - Press `Cmd + R` or click the Run button in Xcode

4. **First Launch**
   - The app will automatically create a default "My Home" entry
   - Start by adding rooms, then assets within those rooms

## Design System

### Colors

- **Background**: `RGB(0.1, 0.1, 0.11)` - Deep charcoal
- **Surface**: `RGB(0.2, 0.2, 0.22)` - Soft grey
- **Text Primary**: White
- **Text Secondary**: `RGB(0.6, 0.6, 0.62)` - Medium grey
- **Text Tertiary**: `RGB(0.5, 0.5, 0.52)` - Light grey

### Typography

- **Header**: System 34pt Light
- **Title**: System 17pt Medium
- **Body**: System 15pt Regular
- **Caption**: System 13pt Regular
- **Small**: System 11pt Medium

### Components

- **App Icons**: 70x70 rounded rectangles with 18pt corner radius
- **List Cells**: Inset grouped style with dark backgrounds
- **Navigation**: Inline title display mode
- **Buttons**: System icons with standard spacing

## MVP Scope (Version 1.0)

✅ Home screen launcher
✅ Rooms module
✅ Assets module
✅ Documents module
✅ Warranties module
✅ Maintenance module
✅ People module
✅ Projects module
✅ Timeline module
✅ Global search
✅ Dark Mode support
✅ Accessibility support
✅ Document scanning with VisionKit
✅ OCR text recognition
✅ Receipt extraction
✅ Warranty expiry notifications
✅ Maintenance reminders
✅ RoomPlan integration for room scanning
✅ Photo picker integration

## Planned Features (Future Versions)

- Barcode/QR scanning
- Core Spotlight integration
- Photo attachment for assets
- Document file storage
- Export data functionality
- iCloud sync
- Shared home support
- Apple Watch companion app

## Success Criteria

The app should feel like:
> "Apple created a system for managing your home."

The user should open Void Home OS and think:
> "I finally know where everything about my home is."

## License

Proprietary - All rights reserved

## Contact

For questions or support, please contact the development team.
