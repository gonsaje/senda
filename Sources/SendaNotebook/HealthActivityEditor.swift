import SwiftUI
import SendaLogger

struct HealthActivityEditor: View {
    let model: BodyMeasurementsModel
    let close: () -> Void
    @State private var steps = ""
    @State private var calories = ""
    @State private var date = Date.now
    @State private var id = UUID()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add activity").font(NotebookTypography.heading(31)).accessibilityAddTraits(.isHeader)
                Text("Enter only steps or active calories missing from Apple Health. These amounts add to your daily totals.")
                    .font(.callout).foregroundStyle(NotebookStyle.quiet)
                DatePicker("Date and time", selection: $date, in: ...Date.now)
                field("Steps", value: $steps, whole: true)
                field("Active calories (kcal)", value: $calories, whole: false)
                if let error { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            }
            .disabled(saving)
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button("Cancel", action: close).disabled(saving)
                Spacer()
                Button(saving ? "Saving…" : "Save to Apple Health") { Task { await save() } }
                    .fontWeight(.semibold).disabled(saving || (steps.isEmpty && calories.isEmpty))
            }
            .frame(minHeight: 44).padding(.horizontal, 24)
            .background(NotebookStyle.ivory)
        }
        .interactiveDismissDisabled(saving)
        .foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay)
        .background(NotebookStyle.ivory)
    }

    private func field(_ title: String, value: Binding<String>, whole: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            TextField("Optional", text: value)
                .accessibilityLabel(title)
                #if os(iOS)
                .keyboardType(whole ? .numberPad : .decimalPad)
                #endif
                .textFieldStyle(.roundedBorder).frame(minHeight: 44)
        }
    }

    private func save() async {
        guard !saving else { return }
        let stepCount = Int(steps)
        let energy = try? Double(calories, format: .number, lenient: false)
        guard steps.isEmpty || (stepCount ?? 0) > 0,
              calories.isEmpty || (energy ?? 0) > 0 else {
            error = "Enter a positive amount. Steps must be a whole number."
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await model.addActivity(DailyHealthActivity(steps: stepCount.map(Double.init), activeCalories: energy),
                                        date: date, id: id)
            close()
        } catch { self.error = error.localizedDescription }
    }
}
