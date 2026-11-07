import SwiftUI
import SendaDomain
import SendaLogger

public struct NotebookView: View {
    @Bindable private var model: LoggerModel
    public init(model: LoggerModel) { self.model = model }

    public var body: some View {
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                recentLifts.padding(.top, 18)
                priorLine.padding(.top, 8)
                entry.padding(.top, 12)
                if let comparison = model.comparison {
                    ComparisonView(comparison: comparison).padding(.top, 24)
                }
                if model.editor == nil {
                    if let error = model.errorMessage {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay).padding(.top, 18)
                    }
                    if let error = model.recoveryErrorMessage {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay).padding(.top, 18)
                        Button("Try again") { model.flushRecovery() }.frame(minHeight: 44)
                            .accessibilityIdentifier("retry-recovery")
                    }
                }
            }
            .padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 30)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: NotebookContentHeight.self, value: geometry.size.height)
            })
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .accessibilityIdentifier("notebook-scroll")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if model.showsNumberEditor { NumericDock(model: model) }
                else if model.draft != nil { recordDock }
                else { loggedDock }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("entry-controls")
        }
        .sheet(isPresented: Binding(get: { model.editor != nil }, set: { if !$0 { model.cancelSetEdits() } })) {
            SetEditorView(model: model)
        }
        .tint(NotebookStyle.clay).buttonStyle(.plain)
        .onPreferenceChange(NotebookContentHeight.self) { _ in
            if model.showsNumberEditor, let index = model.selectedSetIndex {
                scroll.scrollTo("set-row-\(index)", anchor: .center)
            }
        }
        .task(id: model.showsNumberEditor ? model.selectedSetIndex : nil) {
            await Task.yield()
            if model.showsNumberEditor, let index = model.selectedSetIndex {
                withAnimation { scroll.scrollTo("set-row-\(index)", anchor: .center) }
            }
        }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("senda").font(.system(size: 27, weight: .medium, design: .serif).italic()).foregroundStyle(NotebookStyle.clay)
            if model.isSample { Text("Sample").font(.caption).foregroundStyle(NotebookStyle.quiet) }
            Spacer(minLength: 8)
            Text((model.recorded?.recordedAt ?? model.today).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
        }
    }
    private var recentLifts: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 27) {
                ForEach(model.recentExercises) { exercise in
                    Button { model.selectExercise(exercise.id) } label: {
                        VStack(spacing: 4) {
                            Text(exercise.shortName).font(.body.weight(exercise.id == model.selectedExerciseID ? .semibold : .regular))
                                .foregroundStyle(exercise.id == model.selectedExerciseID ? NotebookStyle.ink : NotebookStyle.quiet)
                            Rectangle().fill(exercise.id == model.selectedExerciseID ? NotebookStyle.clay : .clear).frame(height: 2)
                        }.frame(minHeight: 44)
                    }
                    .accessibilityLabel(exercise.name)
                    .accessibilityAddTraits(exercise.id == model.selectedExerciseID ? .isSelected : [])
                    .accessibilityIdentifier("lift-\(exercise.id)")
                }
            }
        }.scrollIndicators(.hidden)
    }
    @ViewBuilder private var priorLine: some View {
        if let previous = model.priorReference, let top = previous.topSet {
            Button { model.beginEditingSets(batchID: previous.id) } label: {
                Text("\(EntryText.date(previous.recordedAt)) · \(EntryText.set(top.values))")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 36, alignment: .leading)
            }
            .accessibilityLabel("\(EntryText.date(previous.recordedAt)) · \(EntryText.set(top.values))")
            .accessibilityHint("Edit this previous entry")
            .accessibilityIdentifier("prior-performed-reference")
        }
    }
    private var entry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.exercise.name).font(.system(size: 43, weight: .regular, design: .serif).italic())
                .lineLimit(1).minimumScaleFactor(0.7).accessibilityIdentifier("entry-exercise")
            if model.exerciseHistory.personalBest != nil { LiftReferencesView(model: model) }
            SetRowsView(model: model)
        }
    }
    private var recordDock: some View {
        RecordButton(title: "Record \(model.recordSetCount) \(model.recordSetCount == 1 ? "set" : "sets")") { model.record() }
            .accessibilityIdentifier("record-batch")
            .padding(.horizontal, 26).padding(.vertical, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity).background(NotebookStyle.ivory)
    }
    private var loggedDock: some View {
        VStack(spacing: 8) {
            Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            HStack {
                Button("Undo") { model.undo() }.font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("undo-batch")
                Spacer()
            }
            RecordButton(title: "New entry") { model.anotherBatch() }.accessibilityIdentifier("another-batch")
        }
        .padding(.horizontal, 26).padding(.bottom, 12)
        .frame(maxWidth: 560).frame(maxWidth: .infinity).background(NotebookStyle.ivory)
    }
}

private struct NotebookContentHeight: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
