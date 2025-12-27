import SwiftUI

struct RescheduleDateSelectorView: View {

    var body: some View {
        VStack(spacing: 24) {
            Text("Reschedule Booking")
                .font(.largeTitle.bold())

            Text("Rescheduling coming soon")
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Reschedule")
    }
}

