import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [Home]
    @Query private var allAssets: [Asset]
    @Query private var allProjects: [Project]
    @Query private var allMaintenance: [Maintenance]
    @Query private var allWarranties: [Warranty]
    @Query private var allDocuments: [Document]

    var events: [TimelineEvent] {
        var result: [TimelineEvent] = []

        for project in allProjects {
            if let startDate = project.startDate {
                result.append(TimelineEvent(
                    id: UUID(),
                    date: startDate,
                    title: project.title,
                    subtitle: "Project (\(project.status.rawValue))",
                    type: .project,
                    icon: "hammer.fill"
                ))
            }
        }

        for asset in allAssets {
            if let purchaseDate = asset.purchaseDate {
                result.append(TimelineEvent(
                    id: UUID(),
                    date: purchaseDate,
                    title: "Purchased \(asset.name)",
                    subtitle: asset.category.isEmpty ? "Asset" : asset.category,
                    type: .asset,
                    icon: "cube.fill"
                ))
            }
        }

        for maintenance in allMaintenance {
            let subtitle = maintenance.asset?.name ?? "Maintenance Record"
            result.append(TimelineEvent(
                id: UUID(),
                date: maintenance.date,
                title: maintenance.task,
                subtitle: subtitle,
                type: .maintenance,
                icon: "wrench.and.screwdriver.fill"
            ))
        }

        for warranty in allWarranties {
            let subtitle = warranty.asset?.name ?? warranty.provider
            result.append(TimelineEvent(
                id: UUID(),
                date: warranty.startDate,
                title: "Warranty (\(warranty.provider))",
                subtitle: subtitle,
                type: .warranty,
                icon: "shield.checkered"
            ))
        }

        for document in allDocuments {
            result.append(TimelineEvent(
                id: UUID(),
                date: document.createdAt,
                title: "Added \(document.title)",
                subtitle: "Document (\(document.type.rawValue))",
                type: .asset,
                icon: "doc.fill"
            ))
        }

        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 4)

                        Text("VOID")
                            .font(.system(size: 44, weight: .ultraLight, design: .default))
                            .foregroundColor(.white)
                            .tracking(6)
                            .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                        Text("TIMELINE")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                            .tracking(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)

                    if events.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
                            Text("No history yet")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            Text("As you add assets, maintenance, and projects, your home's history will appear here.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.4, green: 0.37, blue: 0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(events) { event in
                                TimelineEventRow(event: event)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct TimelineEvent: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let subtitle: String
    let type: EventType
    let icon: String
}

enum EventType {
    case project
    case asset
    case maintenance
    case warranty
}

struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [iconTint.opacity(0.3), iconTint.opacity(0.1), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.5
                        )
                    )
                Image(systemName: event.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Text(event.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                Text(event.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.45, green: 0.4, blue: 0.55))
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
                )
        )
    }

    private var iconTint: Color {
        switch event.type {
        case .project:     return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .asset:       return Color(red: 0.3, green: 0.65, blue: 0.5)
        case .maintenance: return Color(red: 0.85, green: 0.55, blue: 0.25)
        case .warranty:    return Color(red: 0.55, green: 0.35, blue: 0.75)
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
