import SwiftUI
import FirebaseFirestore

struct AddServiceView: View {
    
    @Environment(\.dismiss) var dismiss
    
    let businessId: String
    
    // MARK: - Form fields
    
    @State private var name = ""
    @State private var details = ""
    @State private var price = ""
    
    // Duration (improved defaults)
    @State private var durationHours = 1
    @State private var durationMinutesPart = 0
    
    @State private var isSaving = false
    @State private var errorMessage = ""
    
    var body: some View {
        
        Form {
            
            // MARK: - SERVICE INFO
            
            Section("Service Info") {
                
                TextField("Name", text: $name)
                
                TextField("Details", text: $details, axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("Price (£)", text: $price)
                    .keyboardType(.decimalPad)
            }
            
            // MARK: - DURATION
            
            Section("Duration") {
                
                // 🔥 Quick presets (big UX win)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        presetButton("30m", 0, 30)
                        presetButton("1h", 1, 0)
                        presetButton("2h", 2, 0)
                        presetButton("3h", 3, 0)
                        presetButton("4h", 4, 0)
                        presetButton("7h", 7, 0)
                    }
                }
                
                // Wheel picker
                DurationPickerRow(
                    hours: $durationHours,
                    minutes: $durationMinutesPart
                )
                
                // Live display
                Text("\(durationHours)h \(durationMinutesPart)m total")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - ERROR
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            // MARK: - SAVE BUTTON
            
            Button {
                saveService()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save Service")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(
                name.trimmingCharacters(in: .whitespaces).isEmpty ||
                price.trimmingCharacters(in: .whitespaces).isEmpty ||
                totalDurationMinutes == 0 ||
                isSaving
            )
        }
        .navigationTitle("Add Service")
    }
    
    // MARK: - PRESET BUTTON
    
    private func presetButton(_ title: String, _ h: Int, _ m: Int) -> some View {
        Button {
            durationHours = h
            durationMinutesPart = m
        } label: {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
        }
    }
    
    // MARK: - COMPUTED DURATION
    
    private var totalDurationMinutes: Int {
        (durationHours * 60) + durationMinutesPart
    }
    
    // MARK: - SAVE FUNCTION
    
    private func saveService() {
        
        guard let priceValue = Double(price) else {
            errorMessage = "Enter a valid price."
            return
        }
        
        guard totalDurationMinutes > 0 else {
            errorMessage = "Please select a valid duration."
            return
        }
        
        isSaving = true
        errorMessage = ""
        
        let db = Firestore.firestore()
        
        let data: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "details": details.trimmingCharacters(in: .whitespacesAndNewlines),
            "price": priceValue,
            "durationMinutes": totalDurationMinutes,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .addDocument(data: data) { error in
                
                isSaving = false
                
                if let error = error {
                    errorMessage = "Failed: \(error.localizedDescription)"
                } else {
                    dismiss()
                }
            }
    }
}
