import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @Query private var rooms: [Room]
    @Query private var documents: [Document]
    @Query private var warranties: [Warranty]
    @Query private var maintenanceRecords: [Maintenance]
    @Query private var people: [Person]
    @Query private var projects: [Project]
    
    @State private var searchText = ""
    
    var searchResults: [SearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        let lowercasedSearch = searchText.lowercased()
        
        for asset in assets {
            if asset.name.lowercased().contains(lowercasedSearch) ||
               asset.category.lowercased().contains(lowercasedSearch) ||
               asset.manufacturer.lowercased().contains(lowercasedSearch) ||
               asset.model.lowercased().contains(lowercasedSearch) ||
               asset.serialNumber.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: asset.id,
                    title: asset.name,
                    subtitle: asset.category,
                    type: .asset,
                    icon: "cube.fill"
                ))
            }
        }
        
        for room in rooms {
            if room.name.lowercased().contains(lowercasedSearch) ||
               room.floor.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: room.id,
                    title: room.name,
                    subtitle: room.floor,
                    type: .room,
                    icon: "door.room.fill"
                ))
            }
        }
        
        for document in documents {
            if document.title.lowercased().contains(lowercasedSearch) ||
               document.ocrText.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: document.id,
                    title: document.title,
                    subtitle: document.type.rawValue,
                    type: .document,
                    icon: "doc.fill"
                ))
            }
        }
        
        for warranty in warranties {
            if warranty.provider.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: warranty.id,
                    title: warranty.provider,
                    subtitle: "Warranty",
                    type: .warranty,
                    icon: "shield.checkered"
                ))
            }
        }
        
        for maintenance in maintenanceRecords {
            if maintenance.task.lowercased().contains(lowercasedSearch) ||
               maintenance.notes.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: maintenance.id,
                    title: maintenance.task,
                    subtitle: "Maintenance",
                    type: .maintenance,
                    icon: "wrench.and.screwdriver.fill"
                ))
            }
        }
        
        for person in people {
            if person.name.lowercased().contains(lowercasedSearch) ||
               person.company.lowercased().contains(lowercasedSearch) ||
               person.role.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: person.id,
                    title: person.name,
                    subtitle: person.company.isEmpty ? person.role : person.company,
                    type: .person,
                    icon: "person.fill"
                ))
            }
        }
        
        for project in projects {
            if project.title.lowercased().contains(lowercasedSearch) ||
               project.projectDescription.lowercased().contains(lowercasedSearch) {
                results.append(SearchResult(
                    id: project.id,
                    title: project.title,
                    subtitle: project.status.rawValue,
                    type: .project,
                    icon: "hammer.fill"
                ))
            }
        }
        
        return results
    }
    
    var body: some View {
        ZStack {
            StarryBackground().ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Header
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
                    
                    Text("SEARCH")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 50)

                // Custom Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    TextField("Search everything...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .submitLabel(.search)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                )
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 12) {
                        if searchText.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
                                Text("Search your home")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Text("Search for assets, rooms, documents, warranties, maintenance, people, and projects.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.4, green: 0.37, blue: 0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 60)
                        } else if searchResults.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.55))
                                Text("No results found")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                Text("Try a different search term.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 0.4, green: 0.37, blue: 0.5))
                            }
                            .padding(.vertical, 60)
                        } else {
                            ForEach(searchResults) { result in
                                NavigationLink(destination: destinationView(for: result)) {
                                    SearchResultRow(result: result)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func destinationView(for result: SearchResult) -> some View {
        switch result.type {
        case .asset:
            if let asset = assets.first(where: { $0.id == result.id }) {
                AssetDetailView(asset: asset)
            }
        case .document:
            if let document = documents.first(where: { $0.id == result.id }) {
                DocumentDetailView(document: document)
            }
        case .warranty:
            if let warranty = warranties.first(where: { $0.id == result.id }) {
                WarrantyDetailView(warranty: warranty)
            }
        case .maintenance:
            if let record = maintenanceRecords.first(where: { $0.id == result.id }) {
                MaintenanceDetailView(maintenance: record)
            }
        case .person:
            if let person = people.first(where: { $0.id == result.id }) {
                PersonDetailView(person: person)
            }
        case .project:
            if let project = projects.first(where: { $0.id == result.id }) {
                ProjectDetailView(project: project)
            }
        case .room:
            RoomsListView()
        }
    }
}

struct SearchResult: Identifiable {
    let id: PersistentIdentifier
    let title: String
    let subtitle: String
    let type: SearchResultType
    let icon: String
}

enum SearchResultType {
    case asset
    case room
    case document
    case warranty
    case maintenance
    case person
    case project
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.5
                        )
                    )
                
                Image(systemName: result.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(result.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
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
    
    private var iconColor: Color {
        switch result.type {
        case .asset:       return Color(red: 0.55, green: 0.3, blue: 0.6)
        case .room:        return Color(red: 0.25, green: 0.45, blue: 0.75)
        case .document:    return Color(red: 0.2, green: 0.55, blue: 0.7)
        case .warranty:    return Color(red: 0.65, green: 0.4, blue: 0.35)
        case .maintenance: return Color(red: 0.3, green: 0.5, blue: 0.55)
        case .person:      return Color(red: 0.5, green: 0.35, blue: 0.65)
        case .project:     return Color(red: 0.4, green: 0.4, blue: 0.7)
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
