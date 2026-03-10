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

            if member.id != nil {

                NavigationLink {

                    destinationView(staff: member)

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
    private func destinationView(staff: Staff) -> some View {

        switch mode {

        case .manualBooking:

            BusinessManualBookingView(
                businessId: businessId,
                staff: staff
            )

        case .blockTime:

            AddBlockTimeView(
                businessId: businessId,
                staffId: staff.id ?? ""
            )
        }
    }
}
