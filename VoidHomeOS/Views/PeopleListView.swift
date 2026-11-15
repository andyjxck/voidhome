import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson = false
    @State private var searchText = ""
    
    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { person in
            person.name.localizedCaseInsensitiveContains(searchText) ||
            person.company.localizedCaseInsensitiveContains(searchText) ||
            person.role.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Unique starry background for PeopleListView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.9, blue: 0.8), Color(red: 0.95, green: 1.0, blue: 0.9)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                                    Text("Back").font(.system(size: 16))
                                }
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.bottom, 4)

                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("PEOPLE")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingAddPerson = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                    
                    // Search bar with glassmorphic styling
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                            .font(.system(size: 16))
                        
                        TextField("Search people", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 24)
                    
                    // People list with glassmorphic rows
                    VStack(spacing: 12) {
                        ForEach(filteredPeople) { person in
                            NavigationLink(destination: PersonDetailView(person: person)) {
                                PersonRow(person: person)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(person)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if filteredPeople.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.5))
                                
                                Text("No people yet")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                
                                Button(action: { showingAddPerson = true }) {
                                    Text("Add Person")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(red: 0.5, green: 0.35, blue: 0.65))
                                        )
                                }
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonView()
            }
        }
        .navigationBarHidden(true)
    }
    
    private func deletePeople(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredPeople[index])
            }
        }
    }
}

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person
    @State private var showingEditPerson = false
    
    var body: some View {
        ZStack {
            // Unique starry background for PersonDetailView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.95, blue: 0.85), Color(red: 0.9, green: 0.8, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack(alignment: .top) {
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
                            
                            Text("PERSON")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        Spacer()
                        Button(action: { showingEditPerson = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 50)
                    
                    // Person details with glassmorphic cards
                    VStack(spacing: 16) {
                        GlassDetailCard(label: "Name", value: person.name, icon: "person.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
                        
                        if !person.company.isEmpty {
                            GlassDetailCard(label: "Company", value: person.company, icon: "building.2.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                        }
                        
                        if !person.role.isEmpty {
                            GlassDetailCard(label: "Role", value: person.role, icon: "briefcase.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                        }
                        
                        if !person.phoneNumber.isEmpty {
                            GlassDetailCard(label: "Phone", value: person.phoneNumber, icon: "phone.fill", tint: Color(red: 0.3, green: 0.5, blue: 0.55))
                        }
                        
                        if !person.email.isEmpty {
                            GlassDetailCard(label: "Email", value: person.email, icon: "envelope.fill", tint: Color(red: 0.2, green: 0.55, blue: 0.7))
                        }
                        
                        if !person.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NOTES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .tracking(2)
                                
                                Text(person.notes)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.02))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .sheet(isPresented: $showingEditPerson) {
                EditPersonView(person: person)
            }
        }
        .navigationBarHidden(true)
    }
}

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var company = ""
    @State private var role = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var notes = ""
    
    var body: some View {
        ZStack {
            // Unique starry background for AddPersonView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.9, blue: 0.8), Color(red: 0.95, green: 1.0, blue: 0.9)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("ADD PERSON")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $name, icon: "person.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
                            GlassTextField(title: "Company", text: $company, icon: "building.2.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            GlassTextField(title: "Role", text: $role, icon: "briefcase.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Phone Number", text: $phoneNumber, icon: "phone.fill", tint: Color(red: 0.3, green: 0.5, blue: 0.55), keyboardType: .phonePad)
                            GlassTextField(title: "Email", text: $email, icon: "envelope.fill", tint: Color(red: 0.2, green: 0.55, blue: 0.7), keyboardType: .emailAddress, autocapitalization: .none)
                            GlassTextField(title: "Notes", text: $notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            savePerson()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .disabled(name.isEmpty)
                        .foregroundColor(name.isEmpty ? .white.opacity(0.3) : Color(red: 0.5, green: 0.35, blue: 0.65))
                    }
                }
            }
        }
    }
    
    private func savePerson() {
        let person = Person(name: name, company: company, role: role, phoneNumber: phoneNumber, email: email, notes: notes)
        modelContext.insert(person)
    }
}

struct EditPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person
    
    var body: some View {
        ZStack {
            // Unique starry background for EditPersonView
            StarryBackground(
                stars: (0..<120).map { _ in
                    Star(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 1...3),
                        opacity: Double.random(in: 0.15...0.6),
                        color: [Color(red: 1.0, green: 0.95, blue: 0.85), Color(red: 0.9, green: 0.8, blue: 1.0)].randomElement()!
                    )
                }
            )
            .ignoresSafeArea()
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VOID")
                                .font(.system(size: 44, weight: .ultraLight, design: .default))
                                .foregroundColor(.white)
                                .tracking(6)
                                .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 0)
                            
                            Text("EDIT PERSON")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.65))
                                .tracking(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // Form fields with glassmorphic styling
                        VStack(spacing: 16) {
                            GlassTextField(title: "Name", text: $person.name, icon: "person.fill", tint: Color(red: 0.5, green: 0.35, blue: 0.65))
                            GlassTextField(title: "Company", text: $person.company, icon: "building.2.fill", tint: Color(red: 0.25, green: 0.45, blue: 0.75))
                            GlassTextField(title: "Role", text: $person.role, icon: "briefcase.fill", tint: Color(red: 0.55, green: 0.3, blue: 0.6))
                            GlassTextField(title: "Phone Number", text: $person.phoneNumber, icon: "phone.fill", tint: Color(red: 0.3, green: 0.5, blue: 0.55), keyboardType: .phonePad)
                            GlassTextField(title: "Email", text: $person.email, icon: "envelope.fill", tint: Color(red: 0.2, green: 0.55, blue: 0.7), keyboardType: .emailAddress, autocapitalization: .none)
                            GlassTextField(title: "Notes", text: $person.notes, icon: "note.text", tint: Color(red: 0.65, green: 0.4, blue: 0.35), isMultiline: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { dismiss() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.65))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PeopleListView()
    }
}
