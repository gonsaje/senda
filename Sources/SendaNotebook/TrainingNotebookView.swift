import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingNotebookView: View {
    @Bindable private var model: TrainingNotebookModel
    public init(model: TrainingNotebookModel) { self.model = model }
    public var body: some View {
        Group {
            if let day = model.selectedDay { TrainingDayView(model: model, day: day) }
            else { TrainingWeekView(model: model) }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay).buttonStyle(.plain)
    }
}

enum TrainingText {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    static func date(_ day: TrainingDay, format: String) -> String {
        let formatter = DateFormatter(); formatter.locale = .current; formatter.calendar = utc; formatter.timeZone = utc.timeZone
        formatter.dateFormat = format
        return formatter.string(from: day.date(in: utc))
    }
    static func set(_ values: SetValues, unit: WeightUnit) -> String { "\(unit.text(for: values.weight)) \(unit.symbol) × \(values.reps)" }
}

struct TrainingWeekView: View {
    @Bindable var model: TrainingNotebookModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TrainingWordmark()
                Text("Your week").font(NotebookTypography.heading(35))
                HStack {
                    Button { model.changeWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Previous week").accessibilityIdentifier("previous-week")
                    Spacer(minLength: 0)
                    if let last = model.weekDays.last {
                        Text("\(TrainingText.date(model.workspace.visibleWeek, format: "MMM d"))–\(TrainingText.date(last, format: String(model.workspace.visibleWeek.rawValue.prefix(7)) == String(last.rawValue.prefix(7)) ? "d" : "MMM d"))")
                            .font(.headline).accessibilityIdentifier("week-range")
                    }
                    Spacer(minLength: 0)
                    Button { model.changeWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Next week").accessibilityIdentifier("next-week")
                }.foregroundStyle(NotebookStyle.ink)
                VStack(spacing: 0) {
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    ForEach(model.weekDays, id: \.self) { day in
                        let summary = model.summary(for: day)
                        let categories = summary.muscleGroups.map(\.rawValue)
                        Button { model.openDay(day) } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(TrainingText.date(day, format: "EEE")).font(.subheadline.weight(.medium))
                                    Text(TrainingText.date(day, format: "d")).font(.subheadline.monospacedDigit())
                                }.frame(width: 38, alignment: .leading)
                                    .foregroundStyle(day == model.today ? NotebookStyle.clay : NotebookStyle.ink)
                                VStack(alignment: .leading, spacing: 4) {
                                    if summary.setCount == 0 {
                                        Text("No sets logged").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                                    } else { Text(categories.joined(separator: " · ")).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                                    if day == model.today { Text("Today").font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.clay) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                if summary.setCount > 0 { Text("\(summary.setCount) sets").font(.caption.monospacedDigit()).fixedSize() }
                            }
                            .padding(.vertical, 14).padding(.horizontal, 8).frame(minHeight: 64)
                            .background(day == model.today ? NotebookStyle.clay.opacity(0.06) : .clear)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(TrainingText.date(day, format: "EEEE, MMM d")), \(summary.setCount) sets, \(categories.joined(separator: ", "))")
                        .accessibilityIdentifier("day-\(day.rawValue)")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                    }
                }
                Text("\(model.trainingDayCount) training days · \(model.weekSetCount) sets")
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet).accessibilityIdentifier("week-summary")
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
            }
            .padding(.horizontal, 24).padding(.vertical, 24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(NotebookStyle.ivory).accessibilityIdentifier("week-view")
    }
}

struct TrainingSaveError: View {
    var model: TrainingNotebookModel
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
            Button("Try again") { model.flushRecovery() }.frame(minHeight: 44).accessibilityIdentifier("retry-save")
        }
    }
}
