import SwiftUI
import SendaDomain
import SendaLogger

/// The recorded entry occupies exactly the draft's journal position.
public struct NotebookView: View {
    @Bindable private var model: LoggerModel
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: LoggerModel) { self.model = model }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                recentLifts.padding(.top, 25)
                priorLine.padding(.top, 17)
                journalLine.padding(.top, 40)
                if let comparison = model.comparison {
                    ComparisonView(comparison: comparison).padding(.top, 30)
                }
                if let error = model.errorMessage, model.editor == nil {
                    Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                        .padding(.top, 20).accessibilityLabel("Could not save. \(error)")
                }
            }
            .padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.draft != nil {
                NumericDock(model: model)
            } else {
                recordedDock
            }
        }
        .sheet(isPresented: Binding(get: { model.editor != nil }, set: {
            if !$0 { model.cancelSetEdits() }
        })) {
            SetEditorView(model: model)
        }
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Training").font(.system(size: 31, weight: .regular, design: .serif))
                Text(model.today.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 4) {
                Text("senda").font(.system(size: 25, weight: .medium, design: .serif).italic())
                    .foregroundStyle(NotebookStyle.clay)
                if model.isSample {
                    Text("SAMPLE JOURNAL").font(.system(size: 9, weight: .medium)).tracking(1)
                        .foregroundStyle(NotebookStyle.quiet)
                }
            }
        }
    }

    private var recentLifts: some View {
        HStack(spacing: 27) {
            ForEach(model.recentExercises) { exercise in
                Button { model.selectExercise(exercise.id) } label: {
                    VStack(spacing: 3) {
                        Text(exercise.shortName).font(.body.weight(exercise.id == model.selectedExerciseID ? .semibold : .regular))
                            .foregroundStyle(exercise.id == model.selectedExerciseID ? NotebookStyle.ink : NotebookStyle.quiet)
                        Rectangle().fill(exercise.id == model.selectedExerciseID ? NotebookStyle.clay : .clear)
                            .frame(height: 2)
                    }.frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(exercise.name)
                .accessibilityAddTraits(exercise.id == model.selectedExerciseID ? .isSelected : [])
                .accessibilityHint("Last performed " + (model.journal.entries(for: exercise.id).last.map { EntryText.date($0.recordedAt) } ?? "never"))
                .accessibilityIdentifier("lift-\(exercise.id)")
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent lifts")
    }

    private var priorLine: some View {
        Group {
            if let previous = model.priorReference {
                Text("Last · \(EntryText.date(previous.recordedAt))  \(EntryText.summary(previous.values))")
            } else {
                Text("No earlier entry for \(model.exercise.name)")
            }
        }
        .font(.system(.caption, design: .monospaced)).foregroundStyle(NotebookStyle.quiet)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("prior-performed-reference")
    }

    private var journalLine: some View {
        HStack(alignment: .top, spacing: 17) {
            VStack(spacing: 5) {
                Text((model.recorded?.recordedAt ?? model.today).formatted(.dateTime.day())).font(.system(.caption, design: .monospaced))
                Rectangle().fill(NotebookStyle.clay.opacity(0.28)).frame(width: 1).frame(minHeight: 180)
            }.foregroundStyle(NotebookStyle.clay).frame(width: 23)

            VStack(alignment: .leading, spacing: 0) {
                Text(model.draft != nil ? "DRAFT · NOT RECORDED" : "RECORDED")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.6)
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("entry-status")
                Text(model.exercise.name)
                    .font(.system(size: typeSize.isAccessibilitySize ? 49 : 59, weight: .regular, design: .serif).italic())
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .padding(.top, 15).padding(.bottom, 15)

                if hasRepExceptions {
                    exceptionSentence
                } else {
                    uniformSentence
                }
                Rectangle().fill(NotebookStyle.rule).frame(height: 1).padding(.top, 17)
                if model.draft != nil {
                    Button("One set different?") { model.beginEditingSets() }
                        .font(.subheadline).foregroundStyle(NotebookStyle.clay)
                        .frame(minHeight: 44).padding(.top, 5)
                        .accessibilityIdentifier("draft-edit-sets")
                } else {
                    Text("\(model.values.count) individual sets")
                        .font(.caption).foregroundStyle(NotebookStyle.quiet).padding(.top, 16)
                }
            }
        }
    }

    private var hasRepExceptions: Bool {
        guard let first = model.values.first else { return false }
        return model.values.contains { $0.reps != first.reps }
    }

    private var uniformSentence: some View {
        HStack(alignment: .top, spacing: 5) {
            field(.weight, text: weightText)
            multiplication
            field(.reps, text: String(model.values.first?.reps ?? 0))
            multiplication
            field(.sets, text: String(model.values.count))
        }
    }

    private var exceptionSentence: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 7) {
                field(.weight, text: weightText)
                multiplication
                Button { model.beginEditingSets() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.values.map { String($0.reps) }.joined(separator: ","))
                            .font(.system(size: 31, weight: .regular).monospacedDigit())
                            .lineLimit(2).minimumScaleFactor(0.6)
                        Text("reps by set").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                }.buttonStyle(.plain)
                .accessibilityLabel("Edit ordered sets, " + model.values.map { String($0.reps) }.joined(separator: ", "))
            }
            if model.draft != nil {
                Button { model.selectField(.sets) } label: {
                    Text("\(model.values.count) sets")
                        .underline(model.selectedField == .sets, color: NotebookStyle.clay)
                        .frame(minHeight: 44)
                }
                .font(.caption).foregroundStyle(NotebookStyle.clay)
                .accessibilityLabel("Number of sets, \(model.values.count). Edit batch size")
                .accessibilityIdentifier("sentence-sets")
            } else {
                Text("\(model.values.count) sets").font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    private var weightText: String {
        guard let first = model.values.first else { return "0" }
        return model.values.allSatisfy { $0.weight == first.weight } ? NumericField.weight.text(first.weight) : "var."
    }

    private var multiplication: some View {
        Text("×").font(.system(size: 24, weight: .light)).foregroundStyle(NotebookStyle.quiet)
            .padding(.top, 13).accessibilityHidden(true)
    }

    private func field(_ field: NumericField, text: String) -> some View {
        Group {
            if model.draft != nil {
                Button { model.selectField(field) } label: { fieldLabel(field, text: text) }
                    .buttonStyle(.plain)
            } else {
                fieldLabel(field, text: text)
            }
        }
        .accessibilityLabel("\(field.title), \(text) \(field.label)")
        .accessibilityHint(model.draft != nil ? "Edit in the bottom number control" : "Recorded value")
        .accessibilityIdentifier("sentence-\(field.rawValue)")
    }

    private func fieldLabel(_ field: NumericField, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text).font(.system(size: 45, weight: .regular).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.5)
            Rectangle().fill(model.draft != nil && model.selectedField == field ? NotebookStyle.clay : .clear)
                .frame(height: 2)
            Text(field.label).font(.caption).foregroundStyle(NotebookStyle.quiet)
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }

    private var recordedDock: some View {
        VStack(spacing: 10) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            HStack {
                Text(model.isSample ? "Recorded · sample" : "Saved on this iPhone")
                    .font(.caption).foregroundStyle(NotebookStyle.quiet)
                Spacer()
                Button("Undo") { model.undo() }.accessibilityIdentifier("undo-batch")
                Button("Edit sets") { model.beginEditingSets() }.padding(.leading, 12)
                    .accessibilityIdentifier("recorded-edit-sets")
            }.font(.subheadline).frame(minHeight: 44)
            RecordButton(title: "Another batch") { model.anotherBatch() }
                .accessibilityIdentifier("another-batch")
        }
        .padding(.horizontal, 26).padding(.bottom, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
    }
}
