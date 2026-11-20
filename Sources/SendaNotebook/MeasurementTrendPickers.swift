import SwiftUI
import SendaDomain

struct MeasurementDatePicker: View {
    let today: TrainingDay
    let calendar: Calendar
    let cancel: () -> Void
    let apply: (ClosedRange<TrainingDay>) -> Void
    @State private var start: Date
    @State private var end: Date

    init(days: ClosedRange<TrainingDay>, today: TrainingDay, calendar: Calendar,
         cancel: @escaping () -> Void, apply: @escaping (ClosedRange<TrainingDay>) -> Void) {
        self.today = today
        self.calendar = calendar
        self.cancel = cancel
        self.apply = apply
        _start = State(initialValue: calendar.startOfDay(for: days.lowerBound.date(in: calendar)))
        _end = State(initialValue: calendar.startOfDay(for: days.upperBound.date(in: calendar)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("body-date-start")
                    Divider()
                    DatePicker("Through", selection: $end, in: start...today.date(in: calendar), displayedComponents: .date)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("body-date-end")
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(NotebookStyle.ivory)
            .foregroundStyle(NotebookStyle.ink)
            .navigationTitle("Custom dates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(TrainingDay(start, calendar: calendar)...TrainingDay(end, calendar: calendar)) }
                        .accessibilityIdentifier("body-dates-apply")
                }
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .tint(NotebookStyle.clay)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}
