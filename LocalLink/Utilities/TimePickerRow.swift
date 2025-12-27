import SwiftUI

struct TimePickerRow: View {

    let title: String
    @Binding var time: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromString(time) },
                    set: { time = stringFromDate($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private func dateFromString(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: string) ?? Date()
    }

    private func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
