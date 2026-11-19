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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(model.exercise(context.exerciseID).displayName) · Set \(index)")
                        .font(.subheadline)
                        .foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 12)
                    if wouldSplitStages {
                        Text("Choosing another type splits these stages into individual sets.")
                            .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("drop-set-split-notice")
                    }
                    VStack(spacing: 2) {
                        ForEach(TrainingSetTypeText.choices, id: \.self) { kind in
                            option(kind)
                        }
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("set-type-picker")
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay)
        .buttonStyle(.plain)
        #if os(iOS)
        .presentationBackground(NotebookStyle.ivory)
        .presentationDragIndicator(.visible)
        .presentationDetents(detents)
        #endif
        .onAppear(perform: beginEditing)
        .onChange(of: model.workspace) { _, _ in reconcile() }
        .onChange(of: model.canRetrySave) { _, _ in completePending() }
        .onChange(of: model.errorMessage) { _, _ in completePending() }
        .onDisappear { cancelPending() }
    }

    private var wouldSplitStages: Bool { (model.setPosition(for: rowID)?.stageCount ?? 1) > 1 }

    #if os(iOS)
    private var detents: Set<PresentationDetent> {
        if textSize >= .xxLarge || model.errorMessage != nil { return [.large] }
        let standardHeight: CGFloat = textSize == .xLarge ? 356 : 316
        return [.height(standardHeight + (wouldSplitStages ? 58 : 0)), .large]
    }
    #endif

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Set type")
                .font(NotebookTypography.heading(27, relativeTo: .title2))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(NotebookStyle.typeFill, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("close-set-type")
        }
        .padding(.leading, 28)
        .padding(.trailing, 16)
        .padding(.top, 17)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
    }

    private var currentKind: TrainingSetKind? {
        TrainingSetTypeText.selectedChoice(for: model.rows.first(where: { $0.id == rowID })?.kind)
    }

    private func option(_ kind: TrainingSetKind) -> some View {
        let isSelected = currentKind == kind
        return Button { choose(kind) } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(TrainingSetTypeText.title(kind))
                        .font(.body.weight(isSelected ? .semibold : .medium))
                    Text(TrainingSetTypeText.definition(kind))
                        .font(.subheadline)
                        .foregroundStyle(NotebookStyle.quiet)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NotebookStyle.clay)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(isSelected ? NotebookStyle.dockSelectionFill : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(TrainingSetTypeText.title(kind))
        .accessibilityHint(TrainingSetTypeText.accessibilityDetail(kind))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("set-type-\(TrainingSetTypeText.identifier(kind))")
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
        case .warmup: "Prepare for your working sets."
        case .regular, .working: "Counts toward your set target."
        case .dropSet: "Lower the weight within the same set."
        }
    }
    static func accessibilityDetail(_ kind: TrainingSetKind) -> String {
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
