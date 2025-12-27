import SwiftUI

struct CustomerBookingsView: View {

    @StateObject private var viewModel = CustomerBookingsViewModel()

    var body: some View {
        VStack {

            if viewModel.isLoading {
                ProgressView("Loading bookings…")
                    .padding()
            }

            else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            else if viewModel.bookings.isEmpty {
                ContentUnavailableView(
                    "No upcoming bookings",
                    systemImage: "calendar",
                    description: Text("When you book a service, it will appear here.")
                )
            }

            else {
                List(viewModel.bookings) { booking in
                    VStack(alignment: .leading, spacing: 6) {

                        Text(booking.serviceName)
                            .font(.headline)

                        Text(
                            "\(dateFormatter.string(from: booking.date)) • " +
                            "\(timeFormatter.string(from: booking.date)) – " +
                            "\(timeFormatter.string(from: booking.endDate))"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        Text("With \(booking.staffName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
            }

            NavigationLink {
                CustomerHomeView()
            } label: {
                Text("Browse services")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("My Bookings")
        .onAppear {
            viewModel.loadBookings()
        }
    }

    // MARK: - Formatters

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }
}

