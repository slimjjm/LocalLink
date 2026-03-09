import SwiftUI

struct CustomerServiceListView: View {

    let businessId: String
    @StateObject private var viewModel = ServiceListViewModel()

    var body: some View {

        Group {

            // MARK: Loading
            if viewModel.isLoading {

                VStack(spacing: 16) {

                    ProgressView()
                        .tint(AppColors.primary)

                    Text("Loading services…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }

            // MARK: Error
            else if let error = viewModel.errorMessage {

                VStack(spacing: 14) {

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.error)

                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.error)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // MARK: Empty
            else if viewModel.services.isEmpty {

                ContentUnavailableView(
                    "No services yet",
                    systemImage: "scissors",
                    description: Text(
                        "This business hasn’t added any services yet."
                    )
                )
            }

            // MARK: Services
            else {

                ScrollView {

                    VStack(spacing: 16) {

                        ForEach(viewModel.services) { service in

                            NavigationLink {

                                nextStepView(service)

                            } label: {

                                HStack(spacing: 14) {

                                    // MARK: Icon Bubble

                                    ZStack {

                                        Circle()
                                            .fill(AppColors.primary.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: iconForService(service.name))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(AppColors.primary)
                                    }

                                    // MARK: Service Text

                                    VStack(alignment: .leading, spacing: 6) {

                                        Text(service.name)
                                            .font(.headline.weight(.semibold))
                                            .foregroundColor(AppColors.charcoal)

                                        Text(
                                            "£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins"
                                        )
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColors.primary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(AppColors.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(
                                    color: .black.opacity(0.05),
                                    radius: 4,
                                    y: 2
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(AppColors.background)
        .navigationTitle("Choose a service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            viewModel.loadServices(
                for: businessId,
                activeOnly: false
            )
        }
    }

    // MARK: Booking Routing

    @ViewBuilder
    private func nextStepView(_ service: BusinessService) -> some View {

        if service.locationType == "mobile" {

            AddressCaptureView(
                businessId: businessId,
                service: service
            )

        } else {

            BookingDateSelectorView(
                businessId: businessId,
                service: service,
                customerAddress: nil
            )
        }
    }

    // MARK: Icon Selection

    private func iconForService(_ name: String) -> String {

        let lower = name.lowercased()

        if lower.contains("hair") || lower.contains("cut") {
            return "scissors"
        }

        if lower.contains("beard") {
            return "person.crop.circle"
        }

        if lower.contains("dog") || lower.contains("pet") {
            return "pawprint"
        }

        if lower.contains("clean") {
            return "sparkles"
        }

        if lower.contains("garden") {
            return "leaf.fill"
        }

        if lower.contains("electric") {
            return "bolt.fill"
        }

        if lower.contains("massage") {
            return "hands.sparkles"
        }

        return "wrench.and.screwdriver.fill"
    }
}
