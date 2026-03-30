import SwiftUI

struct DurationPickerRow: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    private let minuteOptions = [0, 15, 30, 45]

    var totalMinutes: Int {
        (hours * 60) + minutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Service duration")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Hours", selection: $hours) {
                        ForEach(0..<13, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(minuteOptions, id: \.self) { minute in
                            Text("\(minute)m").tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Text(displayText(totalMinutes))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func displayText(_ totalMinutes: Int) -> String {
        guard totalMinutes > 0 else { return "Select a duration" }

        let h = totalMinutes / 60
        let m = totalMinutes % 60

        switch (h, m) {
        case (0, let m):
            return "\(m) min"
        case (let h, 0):
            return h == 1 ? "1 hour" : "\(h) hours"
        default:
            return h == 1 ? "1 hour \(m) min" : "\(h) hours \(m) min"
        }
    }
}
