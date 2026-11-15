import SwiftUI
// import RoomPlan - Commented out as RoomPlan may not be available in all environments

@available(iOS 17.0, *)
struct RoomScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var scannedResult: String? // Changed to String for stub implementation
    
    typealias UIViewControllerType = UIViewController
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = "Room Scanner\n(Not available in this environment)"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isPresented = false
            self.scannedResult = "Stub room data"
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@available(iOS 17.0, *)
struct RoomScannerResultView: View {
    let capturedRoom: String // Changed to String for stub
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Result")
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.62))
                        Spacer()
                        Text(capturedRoom)
                            .foregroundColor(.white)
                    }
                } header: {
                    Text("Room Details")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.1, green: 0.1, blue: 0.11))
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
