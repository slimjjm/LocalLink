import SwiftUI

struct DurationPickerRow: View {
    
    @Binding var hours: Int
    @Binding var minutes: Int
    
    private let minuteOptions = [0, 15, 30, 45]
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Service duration")
                .font(.headline)
            
            HStack {
                
                VStack(alignment: .leading) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<12, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading) {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Minutes", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { minute in
                            Text("\(minute)m").tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}
