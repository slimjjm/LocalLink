import SwiftUI

struct BookingDetailView: View {
    @StateObject var viewModel: BusinessBookingDetailViewModel
    @State private var showReschedule = false

    init(booking: Booking) {
        _viewModel = StateObject(wrappedValue: BusinessBookingDetailViewModel(booking: booking))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {

            Text("Booking Details")
                .font(.largeTitle.bold())
                .padding(.top)

            Group {
                HStack {
                    Text("Date:").font(.headline)
                    Spacer()
                    Text(viewModel.booking.startTime.formatted(date: .abbreviated, time: .omitted))
                }

                HStack {
                    Text("Time:").font(.headline)
                    Spacer()
                    Text(viewModel.booking.formattedTimeRange)
                }

                HStack {
                    Text("Service:").font(.headline)
                    Spacer()
                    Text(viewModel.booking.serviceName)
                }

                HStack {
                    Text("Status:").font(.headline)
                    Spacer()
                    Text(viewModel.booking.statusBadge)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.booking.statusColor.opacity(0.2))
                        .foregroundColor(viewModel.booking.statusColor)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)

            Spacer()

            // REQUESTED → Accept or Decline
            if viewModel.booking.status == "requested" {
                VStack(spacing: 12) {

                    Button("Accept Booking") {
                        viewModel.acceptBooking()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                    Button("Decline Booking") {
                        viewModel.declineBooking()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            // RESCHEDULE button (if not declined)
            if viewModel.booking.status != "declined" {
                Button {
                    showReschedule = true
                } label: {
                    Text("Reschedule Booking")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationDestination(isPresented: $showReschedule) {
            RescheduleDateSelectorView(booking: viewModel.booking)
        }
    }
}


