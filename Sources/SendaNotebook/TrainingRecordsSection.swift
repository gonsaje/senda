import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingRecordsSection: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.dynamicTypeSize) private var textSize

    private var unit: WeightUnit { model.workspace.preferredUnit }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            BigThreeBreakdown(progress: model.bigThreeProgress, unit: unit)
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal records")
                    .font(NotebookTypography.heading(20, relativeTo: .title3))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Heaviest weight, then reps.")
                    .font(.subheadline)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if model.personalRecords.isEmpty {
                    Text("Your PRs will appear as you log sets.")
                        .foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 16)
                } else {
                    ForEach(model.personalRecords) { record in
                        recordRow(record)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training-records")
    }

    private func recordRow(_ record: ExercisePersonalRecord) -> some View {
        let exercise = model.exercise(record.exerciseID)
        let values = record.reference.values
        let value = ProgressFormatting.set(values, exercise: exercise, unit: unit)
        let date = TrainingText.date(TrainingDay(record.reference.recordedAt, calendar: model.calendar), format: "MMM d, yyyy")
        return Button { model.openPersonalRecord(record) } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name).font(.body.weight(.medium))
                        Group {
                            if textSize >= .xxxLarge {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(value).font(.body.monospacedDigit())
                                    Text(date).font(.caption).foregroundStyle(NotebookStyle.quiet)
                                }
                            } else {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(value).font(.body.monospacedDigit())
                                        Text(date).font(.caption).foregroundStyle(NotebookStyle.quiet)
                                    }.fixedSize(horizontal: true, vertical: true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(value).font(.body.monospacedDigit())
                                        Text(date).font(.caption).foregroundStyle(NotebookStyle.quiet)
                                    }
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(NotebookStyle.quiet)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 64)
                .padding(.vertical, 8)
                Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(exercise.name), \(value), \(date)")
        .accessibilityHint("Open the recorded set")
        .accessibilityIdentifier("records-pr-\(record.exerciseID)")
    }
}

struct BigThreeBreakdown: View {
    let progress: BigThreeProgress
    let unit: WeightUnit
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .largeTitle) private var totalSize: CGFloat = 48

    private var totalLabel: String {
        progress.totalWeight.map { "Big 3 total, \(unit.text(for: $0)) \(unit.symbol)" } ?? "Big 3 total incomplete, \(progress.records.count) of 3 lifts recorded"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Big 3 total")
                .font(NotebookTypography.heading(20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if let total = progress.totalWeight {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        totalValue(total).fixedSize(horizontal: true, vertical: true)
                        Text(unit.symbol).font(.title3).foregroundStyle(NotebookStyle.quiet)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        totalValue(total)
                        Text(unit.symbol).font(.title3).foregroundStyle(NotebookStyle.quiet)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(totalLabel)
                .accessibilityIdentifier("big-three-total")
                Text("Your heaviest logged sets, added together.")
                    .font(.subheadline)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if total > 0 {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(progress.records) { record in
                                color(record.exerciseID).frame(width: geometry.size.width * CGFloat(record.reference.values.weight) / CGFloat(total))
                            }
                        }.clipShape(Capsule())
                    }
                    .frame(height: 10)
                    .accessibilityHidden(true)
                }
            } else {
                Text("\(progress.records.count) of 3 lifts recorded")
                    .font(.subheadline)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(totalLabel)
                    .accessibilityIdentifier("big-three-total")
            }
            ForEach(BigThreeProgress.exerciseIDs, id: \.self) { id in
                let record = progress.records.first { $0.exerciseID == id }
                Group {
                    if textSize >= .xxxLarge {
                        VStack(alignment: .leading, spacing: 5) {
                            liftLabel(id)
                            liftValue(record)
                        }
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                liftLabel(id)
                                Spacer(minLength: 8)
                                liftValue(record).fixedSize(horizontal: true, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                liftLabel(id)
                                liftValue(record)
                            }
                        }
                    }
                }
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func totalValue(_ total: Int) -> some View {
        Text(unit.text(for: total))
            .font(.system(size: totalSize, weight: .medium).monospacedDigit())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func liftLabel(_ id: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color(id)).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(id == "bench" ? "Bench" : id == "deadlift" ? "Deadlift" : "Squat")
        }
    }

    private func liftValue(_ record: ExercisePersonalRecord?) -> some View {
        Text(record.map { "\(unit.text(for: $0.reference.values.weight)) \(unit.symbol) × \($0.reference.values.reps)" } ?? "Not recorded")
            .monospacedDigit()
            .foregroundStyle(record == nil ? NotebookStyle.quiet : NotebookStyle.ink)
    }

    private func color(_ id: String) -> Color {
        id == "bench" ? NotebookStyle.clay : id == "deadlift" ? NotebookStyle.olive : NotebookStyle.ink
    }
}
