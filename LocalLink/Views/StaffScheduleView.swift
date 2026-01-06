import SwiftUI

struct StaffScheduleView: View {

    // MARK: - Input
    let businessId: String

    // MARK: - State
    @StateObject private var viewModel = StaffScheduleViewModel()

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Date Picker
            DatePicker(
                "Date",
                selection: $viewModel.selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .onChange(of: viewModel.selectedDate) { _ in
                viewModel.load(businessId: businessId)
            }

            // MARK: - States
            if viewModel.isLoading {
                ProgressView("Loading schedule…")
                    .padding()
            }
            else if !viewModel.errorMessage.isEmpty {
                errorState
            }
            else if viewModel.staffSchedules.isEmpty {
                emptyState
            }
            else {
                scheduleList
            }
        }
        .navigationTitle("Staff Schedule")
        .onAppear {
            viewModel.load(businessId: businessId)
        }
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        List {
            ForEach(viewModel.staffSchedules) { staff in
                Section(header: staffHeader(staff)) {
                    ForEach(staff.blocks) { block in
                        blockRow(block)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Section Header (tap → edit availability)

    private func staffHeader(_ staff: StaffDaySchedule) -> some View {
        NavigationLink {
            StaffAvailabilityEditView(
                businessId: businessId,
                staffId: staff.id,              // ✅ FIX HERE
                staffName: staff.staffName
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {

                Text(staff.staffName)
                    .font(.headline)

                if let hours = staff.workingHours {
                    Text(hours)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No availability set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Block Row

    private func blockRow(_ block: ScheduleBlock) -> some View {
        HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {
                Text(block.timeLabel)
                    .font(.subheadline.weight(.semibold))

                Text(block.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(block.type == .booked ? "Booked" : "Free")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        block.type == .booked
                        ? Color.red.opacity(0.15)
                        : Color.green.opacity(0.15)
                    )
                )
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No schedule for this date")
                .font(.headline)

            Text("There are no staff or availability for the selected day.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Couldn’t load schedule")
                .font(.headline)

            Text(viewModel.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                viewModel.load(businessId: businessId)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
