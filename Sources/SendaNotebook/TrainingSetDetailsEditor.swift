import SwiftUI
import SendaDomain
import SendaLogger

private struct TrainingSetDetailsSelection: Equatable {
    var reserve: Int?
}

public struct TrainingSetDetailsEditor: View {
    @Bindable var model: TrainingNotebookModel
    let context: TrainingMetadataContext
    let rowID: UUID
    let index: Int
    let close: () -> Void
    @State private var selection: TrainingSetDetailsSelection
    @State private var pending: TrainingSetDetailsSelection?
    @State private var beganEditing = false

    public init(model: TrainingNotebookModel, day: TrainingDay, exerciseID: String, rowID: UUID, close: @escaping () -> Void) {
        let rows = model.workspace.days[day.rawValue]?.rows[exerciseID] ?? []
        let context = TrainingMetadataContext(day: day, exerciseID: exerciseID, rowIDs: rows.map(\.id))
        self.model = model; self.context = context; self.rowID = rowID; self.close = close
        index = (TrainingSetEntry.grouping(rows).firstIndex(where: { $0.rows.contains { $0.id == rowID } }) ?? 0) + 1
        let row = rows.first(where: { $0.id == rowID })
        _selection = State(initialValue: TrainingSetDetailsSelection(reserve: row?.repsInReserve))
    }

    init(model: TrainingNotebookModel, context: TrainingMetadataContext, row: TrainingRow, index: Int, close: @escaping () -> Void) {
        self.model = model; self.context = context; rowID = row.id; self.index = index; self.close = close
        _selection = State(initialValue: TrainingSetDetailsSelection(reserve: row.repsInReserve))
    }

    private var setContext: String {
        let base = "Set \(index)"
        guard let position = model.setPosition(for: rowID), position.isDropSet else { return base }
        return "\(base) · \(position.stageIndex == 1 ? "Start" : "Drop \(position.stageIndex - 1)")"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Button(action: cancel) {
                        Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("cancel-set-details")
                    Spacer(minLength: 12)
                    Button(action: save) {
                        Text("Save").font(.body.weight(.medium)).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .disabled(pending != nil).accessibilityIdentifier("save-set-details")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(setContext) reps left").font(NotebookTypography.heading(32)).accessibilityAddTraits(.isHeader)
                    Text(model.exercise(context.exerciseID).name).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }.fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reps left").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("How many more reps could you have done? This is optional; leaving it blank means unknown.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                    Menu {
                        reserveOption(nil)
                        ForEach(0...5, id: \.self) { reserveOption($0) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(TrainingSetDetailsText.reserve(selection.reserve))
                                .font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.down").font(.caption).accessibilityHidden(true)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.foregroundStyle(NotebookStyle.clay).accessibilityLabel("Reps left")
                        .accessibilityValue(TrainingSetDetailsText.reserve(selection.reserve))
                        .accessibilityIdentifier("set-reps-left")
                    detailsRule
                }
                if let error = model.errorMessage {
                    if pending != nil && context.matches(model) {
                        TrainingSaveError(model: model, message: error, retrySucceeded: completePending)
                    } else {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("save-error-message")
                    }
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .accessibilityIdentifier("set-details-editor")
        .onAppear(perform: beginEditing)
        .onChange(of: selection) { _, _ in cancelPending() }
        .onChange(of: model.workspace) { _, _ in reconcile() }
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }

    private var detailsRule: some View { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true) }
    private func beginEditing() {
        guard !beganEditing else { return }
        guard context.matches(model), model.rows.contains(where: { $0.id == rowID }) else { close(); return }
        beganEditing = true
        _ = model.beginMetadataEditing()
    }
    private func reserveOption(_ value: Int?) -> some View {
        Button { selection.reserve = value } label: {
            if selection.reserve == value { Label(TrainingSetDetailsText.reserve(value), systemImage: "checkmark") }
            else { Text(TrainingSetDetailsText.reserve(value)) }
        }
        .accessibilityLabel(TrainingSetDetailsText.reserve(value))
        .accessibilityAddTraits(selection.reserve == value ? .isSelected : [])
        .accessibilityIdentifier("set-reserve-\(value.map(String.init) ?? "unknown")")
    }
    private func save() {
        guard context.matches(model), model.rows.contains(where: { $0.id == rowID }) else { cancel(); return }
        cancelPending(); pending = selection
        if model.setRepsInReserve(selection.reserve, for: rowID) { completePending() }
        else if !model.canRetrySave { pending = nil }
    }
    private func completePending() {
        guard let pending, context.matches(model), !model.canRetrySave, model.errorMessage == nil,
              let row = model.rows.first(where: { $0.id == rowID }),
              row.repsInReserve == pending.reserve else { return }
        self.pending = nil; close(); TrainingAccessibility.announce("\(setContext) reps left saved.")
    }
    private func reconcile() {
        if context.matches(model) { completePending() } else { cancel() }
    }
    private func cancelPending() {
        guard pending != nil else { return }
        pending = nil; _ = model.cancelPendingAction()
    }
    private func cancel() { cancelPending(); close() }
}

enum TrainingSetDetailsText {
    static func kind(_ kind: TrainingSetKind?) -> String { TrainingSetTypeText.title(kind) }
    static func reserve(_ reserve: Int?) -> String {
        guard let reserve else { return "Not set" }
        return reserve == 5 ? "5+ reps left" : "\(reserve) \(reserve == 1 ? "rep" : "reps") left"
    }
    static func effort(_ reserve: Int?) -> String {
        reserve.map(Self.reserve) ?? "Reps left"
    }
}
