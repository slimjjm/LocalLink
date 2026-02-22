import SwiftUI

struct BusinessBookingCalendarView: View {

    let businessId: String
    let staffId: String

    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current

    private var days: [Date] {

        guard let monthInterval =
            calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek =
            calendar.dateInterval(of: .weekOfMonth,
                                  for: monthInterval.start),
              let lastWeek =
            calendar.dateInterval(of: .weekOfMonth,
                                  for: monthInterval.end - 1)
        else { return [] }

        let start = firstWeek.start
        let end = lastWeek.end

        var days: [Date] = []
        var date = start

        while date < end {
            days.append(date)
            date = calendar.date(byAdding: .day,
                                 value: 1,
                                 to: date)!
        }

        return days
    }

    var body: some View {

        VStack {

            HStack {

                Button {
                    currentMonth =
                        calendar.date(byAdding: .month,
                                      value: -1,
                                      to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    currentMonth =
                        calendar.date(byAdding: .month,
                                      value: 1,
                                      to: currentMonth)!
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: 7
                )
            ) {

                ForEach(days, id: \.self) { date in

                    let isCurrentMonth =
                        calendar.isDate(
                            date,
                            equalTo: currentMonth,
                            toGranularity: .month
                        )

                    Text("\(calendar.component(.day, from: date))")
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            Circle()
                                .fill(
                                    selectedDate == date
                                    ? Color.orange.opacity(0.3)
                                    : Color.clear
                                )
                        )
                        .foregroundColor(
                            isCurrentMonth
                            ? .primary
                            : .gray
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                }
            }
            .padding()

            Spacer()

            if let selectedDate {

                NavigationLink(
                    "Block whole day",
                    destination:
                        AddBlockTimeView(
                            businessId: businessId,
                            staffId: staffId
                        )
                )
                .padding()
            }
        }
        .navigationTitle("Calendar")
    }

    private var monthTitle: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
}
