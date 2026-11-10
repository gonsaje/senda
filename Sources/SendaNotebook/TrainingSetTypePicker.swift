import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingSetTypePicker: View {
    @Bindable var model: TrainingNotebookModel
    let context: TrainingMetadataContext
    let rowID: UUID
    let index: Int
    let close: () -> Void
    @State private var pending: TrainingSetKind?
    @State private var beganEditing = false
    @Environment(\.dynamicTypeSize) private var textSize

    public init(model: TrainingNotebookModel, day: TrainingDay, exerciseID: String, rowID: UUID, close: @escaping () -> Void) {
        let rows = model.workspace.days[day.rawValue]?.rows[exerciseID] ?? []
        self.model = model
        context = TrainingMetadataContext(day: day, exerciseID: exerciseID, rowIDs: rows.map(\.id))
        self.rowID = rowID
        index = (TrainingSetEntry.grouping(rows).firstIndex(where: { $0.rows.contains { $0.id == rowID } }) ?? 0) + 1
        self.close = close
    }

    init(model: TrainingNotebookModel, context: TrainingMetadataContext, row: TrainingRow, index: Int, close: @escaping () -> Void) {
        self.model = model; self.context = context; rowID = row.id; self.index = index; self.close = close
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set \(index) type").font(NotebookTypography.heading(32)).accessibilityAddTraits(.isHeader)
                    Text(model.exercise(context.exerciseID).name).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }.fixedSize(horizontal: false, vertical: true)
                if (model.setPosition(for: rowID)?.stageCount ?? 1) > 1 {
                    Text("Choosing another type splits these stages into individual sets.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("drop-set-split-notice")
                }
                VStack(spacing: 0) {
                    ForEach(TrainingSetTypeText.choices, id: \.self) { kind in
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
                        option(kind)
                    }
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Text("Close").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("close-set-type")
            }
            .padding(.horizontal, 24).padding(.vertical, 4)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory)
            .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true) }
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay).buttonStyle(.plain)
        .accessibilityIdentifier("set-type-picker")
        .onAppear(perform: beginEditing)
        .onChange(of: model.workspace) { _, _ in reconcile() }
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }

    private var currentKind: TrainingSetKind? {
        TrainingSetTypeText.selectedChoice(for: model.rows.first(where: { $0.id == rowID })?.kind)
    }
    private func option(_ kind: TrainingSetKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { choose(kind) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(TrainingSetTypeText.title(kind)).font(.body.weight(currentKind == kind ? .semibold : .regular))
                        if !textSize.isAccessibilitySize {
                            Text(TrainingSetTypeText.definition(kind)).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if currentKind == kind {
                        Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 14).contentShape(Rectangle())
            }
            .accessibilityAddTraits(currentKind == kind ? .isSelected : [])
            .accessibilityHint("Save this type for set \(index)")
            .accessibilityIdentifier("set-type-\(TrainingSetTypeText.identifier(kind))")
            if textSize.isAccessibilitySize {
                Text(TrainingSetTypeText.definition(kind)).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 14)
            }
        }
    }
    private func beginEditing() {
        guard !beganEditing else { return }
        guard context.matches(model), model.rows.contains(where: { $0.id == rowID }) else { close(); return }
        beganEditing = true
        _ = model.beginMetadataEditing()
    }
    private func choose(_ kind: TrainingSetKind) {
        guard context.matches(model), model.rows.contains(where: { $0.id == rowID }) else { dismiss(); return }
        cancelPending()
        if currentKind == kind { close(); return }
        pending = kind
        if model.setKind(kind, for: rowID) { completePending() }
        else if !model.canRetrySave { pending = nil }
    }
    private func completePending() {
        guard let pending, context.matches(model), !model.canRetrySave, model.errorMessage == nil,
              model.rows.first(where: { $0.id == rowID })?.kind == pending else { return }
        self.pending = nil
        close()
        TrainingAccessibility.announce("Set \(index) type saved as \(TrainingSetTypeText.title(pending)).")
    }
    private func reconcile() {
        if context.matches(model) { completePending() } else { dismiss() }
    }
    private func cancelPending() {
        guard pending != nil else { return }
        pending = nil
        _ = model.cancelPendingAction()
    }
    private func dismiss() { cancelPending(); close() }
}

enum TrainingSetTypeText {
    static let choices: [TrainingSetKind] = [.warmup, .working, .dropSet]
    static func selectedChoice(for kind: TrainingSetKind?) -> TrainingSetKind? {
        kind == .regular ? .working : kind
    }
    static func title(_ kind: TrainingSetKind?) -> String {
        switch kind {
        case .regular, .working: "Working set"
        case .warmup: "Warm-up"
        case .dropSet: "Drop set"
        case nil: "Not set"
        }
    }
    static func buttonTitle(_ kind: TrainingSetKind?) -> String { kind == nil ? "Choose type" : title(kind) }
    static func definition(_ kind: TrainingSetKind) -> String {
        switch kind {
        case .regular, .working: "A set toward your planned working-set target."
        case .warmup: "A preparation set. Does not count toward your working-set target."
        case .dropSet: "Reduce the weight with little rest. Log your starting weight and reps, then add each drop below it. The stages count as one drop set and do not count toward your working-set target."
        }
    }
    static func identifier(_ kind: TrainingSetKind) -> String {
        switch kind {
        case .regular: "regular"
        case .warmup: "warmup"
        case .working: "working"
        case .dropSet: "drop"
        }
    }
}
