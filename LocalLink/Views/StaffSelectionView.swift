import SwiftUI

enum StaffSelectionMode {
    case manualBooking
    case blockTime
}

struct StaffSelectionView: View {

    let businessId: String
    let staff: [Staff]
    let mode: StaffSelectionMode

    var body: some View {

        List(staff) { member in

            if let staffId = member.id {

                NavigationLink {

                    destinationView(staffId: staffId)

                } label: {

                    HStack {

                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)

                        Text(member.name)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Select staff")
    }

    @ViewBuilder
    private func destinationView(staffId: String) -> some View {

        switch mode {

        case .manualBooking:

            BusinessManualBookingView(
                businessId: businessId,
                staffId: staffId
            )

        case .blockTime:

            AddBlockTimeView(
                businessId: businessId,
                staffId: staffId
            )
        }
    }
}
