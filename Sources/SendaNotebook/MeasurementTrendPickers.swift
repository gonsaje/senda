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

struct MeasurementStrengthPicker: View {
    let exercises: [Exercise]
    let selectedID: String?
    let select: (String?) -> Void
    let cancel: () -> Void
    @State private var search = ""

    private var matches: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? exercises : exercises.filter { $0.displayName.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty { option("No comparison", id: nil) }
                ForEach(matches) { exercise in option(exercise.displayName, id: exercise.id) }
                if matches.isEmpty {
                    Text(exercises.isEmpty ? "Log a set to compare strength." : "No matching exercises.")
                        .foregroundStyle(NotebookStyle.quiet)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NotebookStyle.ivory)
            .foregroundStyle(NotebookStyle.ink)
            .searchable(text: $search, prompt: "Find a logged exercise")
            .navigationTitle("Compare strength")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", action: cancel) } }
        }
        .tint(NotebookStyle.clay)
    }

    private func option(_ name: String, id: String?) -> some View {
        Button { select(id) } label: {
            HStack {
                Text(name)
                Spacer(minLength: 8)
                if id == selectedID { Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay) }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(NotebookStyle.ivory)
        .accessibilityAddTraits(id == selectedID ? .isSelected : [])
        .accessibilityIdentifier("body-compare-\(id ?? "none")")
    }
}
