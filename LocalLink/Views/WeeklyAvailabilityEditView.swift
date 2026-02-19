import SwiftUI
import FirebaseFirestore

struct WeeklyAvailabilityEditView: View {

    let businessId: String
    let staff: Staff

    @Environment(\.dismiss) private var dismiss

    @State private var days: [StaffEditableDay] = DayKey.allCases.map {
        StaffEditableDay(
            key: $0,
            closed: false,
            openTime: Self.timeToDate("09:00"),
            closeTime: Self.timeToDate("17:00")
        )
    }

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var generatedUntil: Date?

    private let repo = StaffWeeklyAvailabilityRepository()
    private let calendar = Calendar.current
    private let db = Firestore.firestore()

    var body: some View {
        Form {

            Section("Staff") {
                Text(staff.name)
                    .font(.headline)
            }

            Section {
                HStack {
                    Text("Generated until")
                    Spacer()

                    if let generatedUntil {
                        Text(generatedUntil.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    } else if isLoading {
                        Text("Loading…")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not generated")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if isLoading {
                Section {
                    ProgressView("Loading weekly availability…")
                }
            } else {
                Section("Weekly availability") {
                    ForEach($days) { $day in
                        VStack(alignment: .leading, spacing: 8) {

                            HStack {
                                Text(day.key.displayName)
                                    .font(.headline)

                                Spacer()

                                Toggle("Closed", isOn: $day.closed)
                                    .labelsHidden()
                            }

                            if !day.closed {
                                HStack {
                                    DatePicker(
                                        "Open",
                                        selection: $day.openTime,
                                        displayedComponents: .hourAndMinute
                                    )

                                    DatePicker(
                                        "Close",
                                        selection: $day.closeTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                }

                                if day.closeTime <= day.openTime {
                                    Text("Close must be later than open")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    saveAndGenerate()
                } label: {
                    HStack {
                        if isSaving { ProgressView() }
                        Text(isSaving ? "Saving…" : "Save & regenerate availability")
                    }
                }
                .disabled(isLoading || isSaving)
            }
        }
        .navigationTitle("Weekly Availability")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    // MARK: - Load Weekly Template

    private func load() {
        guard let staffId = staff.id else {
            isLoading = false
            errorMessage = "Missing staff ID."
            return
        }

        repo.fetchWeek(businessId: businessId, staffId: staffId) { result in
            DispatchQueue.main.async {
                self.isLoading = false

                switch result {

                case .failure(let error):
                    self.errorMessage = error.localizedDescription

                case .success(let week):
                    for i in days.indices {
                        let key = days[i].key.rawValue
                        if let saved = week[key] {
                            days[i].closed = saved.closed
                            days[i].openTime = Self.timeToDate(saved.open)
                            days[i].closeTime = Self.timeToDate(saved.close)
                        }
                    }
                }

                Task { await refreshGeneratedUntil(staffId: staffId) }
            }
        }
    }

    // MARK: - Save + FULL REGENERATE (Correct architecture)

    private func saveAndGenerate() {
        guard let staffId = staff.id else { return }

        isSaving = true
        errorMessage = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")

        let week = Dictionary(uniqueKeysWithValues: days.map {
            (
                $0.key.rawValue,
                StaffDayAvailability(
                    open: formatter.string(from: $0.openTime),
                    close: formatter.string(from: $0.closeTime),
                    closed: $0.closed
                )
            )
        })

        repo.saveWeek(businessId: businessId, staffId: staffId, week: week) { result in
            switch result {

            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSaving = false
                }
                return

            case .success:
                break
            }

            // 🔥 Fire regeneration in background so UI never locks
            Task.detached {
                AvailabilityGenerator().regenerateNextDays(
                    businessId: businessId,
                    staffId: staffId,
                    numberOfDays: 60
                ) { _ in }
            }

            // Immediately unlock UI
            DispatchQueue.main.async {
                self.isSaving = false
                self.dismiss()
            }
        }
    }


    // MARK: - Generated Until Label

    private func refreshGeneratedUntil(staffId: String) async {
        do {
            let snap = try await db
                .collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("availability")
                .order(by: "date", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snap.documents.first,
                  let ts = doc.data()["date"] as? Timestamp
            else {
                await MainActor.run { self.generatedUntil = nil }
                return
            }

            await MainActor.run {
                self.generatedUntil = calendar.startOfDay(for: ts.dateValue())
            }

        } catch {
            // non-critical
        }
    }

    private static func timeToDate(_ hhmm: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_GB")
        return f.date(from: hhmm) ?? Date()
    }
}
