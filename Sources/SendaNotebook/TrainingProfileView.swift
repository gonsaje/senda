import SwiftUI
import SendaDomain
import SendaLogger

private enum ProfileSheet: String, Identifiable {
    case details, settings
    var id: String { rawValue }
}
struct TrainingProfileView: View {
    @Bindable var model: TrainingNotebookModel
    @State private var sheet: ProfileSheet?
    private var unit: WeightUnit { model.workspace.preferredUnit }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Text("Profile").font(NotebookTypography.heading(37))
                    Spacer()
                    Button { sheet = .settings } label: { Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44) }
                        .accessibilityLabel("Settings").accessibilityIdentifier("profile-settings")
                }
                Button { sheet = .details } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.profile.details.name.isEmpty ? "Your details" : model.profile.details.name).font(.body.weight(.semibold))
                            Text(model.profile.details.email.isEmpty ? "Account details" : model.profile.details.email)
                                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.caption)
                    }.frame(minHeight: 52).contentShape(Rectangle())
                }
                .disabled(model.profile.openingError != nil)
                .accessibilityElement(children: .combine).accessibilityIdentifier("profile-details")
                if let error = model.profile.openingError {
                    Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                    Button("Try profile again") { model.profile.reload() }.frame(minHeight: 44)
                }
                BigThreeBreakdown(progress: model.bigThreeProgress, unit: unit)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal records").font(NotebookTypography.heading(27))
                    Text("Heaviest weight, then reps.").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    if model.personalRecords.isEmpty {
                        Text("Your PRs will appear as you log sets.").foregroundStyle(NotebookStyle.quiet).padding(.vertical, 16)
                    } else {
                        ForEach(model.personalRecords) { record in
                            recordRow(record)
                        }
                    }
                }
                if let error = model.errorMessage { ProfileActionError(model: model, message: error) }
            }
            .padding(24).padding(.bottom, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("profile-scroll")
        .sheet(item: $sheet) { destination in
            switch destination {
            case .details: ProfileDetailsView(profile: model.profile, close: { sheet = nil })
            case .settings: TrainingSettingsView(model: model, close: { sheet = nil })
            }
        }
    }
    private func recordRow(_ record: ExercisePersonalRecord) -> some View {
        let exercise = model.exercise(record.exerciseID)
        let values = record.reference.values
        let value = values.weight == 0 && !exercise.requiresWeight ? "BW × \(values.reps)" : "\(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)"
        let date = TrainingText.date(TrainingDay(record.reference.recordedAt, calendar: model.calendar), format: "MMM d, yyyy")
        return Button { model.openPersonalRecord(record) } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name).font(.body.weight(.medium))
                        Text(date).font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(value).font(.body.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(NotebookStyle.quiet)
                }.frame(minHeight: 64).padding(.vertical, 4)
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            }.contentShape(Rectangle())
        }
        .accessibilityLabel("\(exercise.name), \(value), \(date)")
        .accessibilityHint("Open the recorded set").accessibilityIdentifier("profile-pr-\(record.exerciseID)")
    }
}

struct BigThreeBreakdown: View {
    let progress: BigThreeProgress
    let unit: WeightUnit
    private var totalLabel: String {
        progress.totalWeight.map { "Big 3 total, \(unit.text(for: $0)) \(unit.symbol)" } ?? "Big 3 total incomplete, \(progress.records.count) of 3 lifts recorded"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Big 3 total").font(NotebookTypography.heading(27))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(progress.totalWeight.map { unit.text(for: $0) } ?? "—").font(.system(size: 48, weight: .medium).monospacedDigit()).minimumScaleFactor(0.6).lineLimit(1)
                if progress.totalWeight != nil { Text(unit.symbol).font(.title3).foregroundStyle(NotebookStyle.quiet) }
            }
            .accessibilityElement(children: .ignore).accessibilityLabel(totalLabel).accessibilityIdentifier("big-three-total")
            Text(progress.totalWeight == nil ? "\(progress.records.count) of 3 lifts recorded" : "Your heaviest logged sets, added together.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            GeometryReader { geometry in
                if let total = progress.totalWeight, total > 0 {
                    HStack(spacing: 0) {
                        ForEach(progress.records) { record in
                            color(record.exerciseID).frame(width: geometry.size.width * CGFloat(record.reference.values.weight) / CGFloat(total))
                        }
                    }.clipShape(Capsule())
                } else { Capsule().fill(NotebookStyle.rule) }
            }.frame(height: 10).accessibilityHidden(true)
            ForEach(BigThreeProgress.exerciseIDs, id: \.self) { id in
                let record = progress.records.first { $0.exerciseID == id }
                HStack(spacing: 10) {
                    Circle().fill(color(id)).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(id == "bench" ? "Bench" : id == "deadlift" ? "Deadlift" : "Squat")
                    Spacer(minLength: 8)
                    Text(record.map { "\(unit.text(for: $0.reference.values.weight)) \(unit.symbol) × \($0.reference.values.reps)" } ?? "—")
                        .monospacedDigit().foregroundStyle(record == nil ? NotebookStyle.quiet : NotebookStyle.ink)
                }.font(.body).accessibilityElement(children: .combine)
            }
        }
    }
    private func color(_ id: String) -> Color { id == "bench" ? NotebookStyle.clay : id == "deadlift" ? NotebookStyle.olive : NotebookStyle.ink }
}
