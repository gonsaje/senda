import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

private enum TrainingDaySheet: String, Identifiable {
    case picker, exercises, reuse
    var id: String { rawValue }
}

private struct TrainingPendingSheet {
    let destination: TrainingDaySheet
    let day: TrainingDay
    let exerciseID: String?
    let rowIDs: [UUID]
}

private struct TrainingFocusedRowLayout: Equatable {
    let focusID: UUID
    let height: CGFloat
}

private enum TrainingFocusedRowPreference: PreferenceKey {
    static let defaultValue: TrainingFocusedRowLayout? = nil
    static func reduce(value: inout TrainingFocusedRowLayout?, nextValue: () -> TrainingFocusedRowLayout?) {
        value = nextValue() ?? value
    }
}

struct TrainingDayView: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    @State private var presentedSheet: TrainingDaySheet?
    @State private var pendingSheet: TrainingPendingSheet?
    @State private var planContext: TrainingMetadataContext?
    @State private var measuredFocusLayout: TrainingFocusedRowLayout?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    dayNavigation.id("day-header")
                    if let exercise = model.exercise {
                        exerciseNavigation(exercise)
                        TrainingReferenceBanners(model: model, beginNavigation: { pendingSheet = nil }, editPlan: {
                            pendingSheet = nil
                            planContext = TrainingMetadataContext(day: day, exerciseID: exercise.id, rowIDs: model.rows.map(\.id))
                        })
                        TrainingSetRows(model: model, beginInteraction: { pendingSheet = nil }).id("\(day.rawValue)/\(exercise.id)")
                        if model.focus == nil && model.errorMessage == nil && !model.canRetrySave {
                            TrainingNextWorkoutFeedback(model: model, day: day, exercise: exercise)
                        }
                    } else {
                        emptyWorkout
                    }
                }
                .padding(.horizontal, 24).padding(.top, 2).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .id("day-top")
            }
            .clipped()
            .accessibilityIdentifier("day-scroll")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let error = model.errorMessage ?? (model.canRetrySave ? model.saveStatus : nil) {
                        TrainingSaveError(model: model, message: error, retrySucceeded: presentPendingSheet)
                            .padding(.horizontal, 24).padding(.top, 8)
                            .padding(.bottom, model.focus == nil ? 12 : 0)
                    }
                    if let focus = model.focus {
                        TrainingInputDock(model: model, focus: focus, beginInteraction: { pendingSheet = nil }).id(focus.id)
                    }
                    else if model.errorMessage == nil, let label = model.undoLabel {
                        Button {
                            pendingSheet = nil
                            if model.undoChange() { TrainingAccessibility.announce("Change undone.") }
                        } label: {
                            Text("Undo last change").underline()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(NotebookStyle.ink)
                        .accessibilityValue(label)
                        .accessibilityIdentifier("undo-set-change")
                        .padding(.horizontal, 18).padding(.vertical, 5)
                        .background(NotebookStyle.olive.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24).padding(.bottom, 12)
                    }
                }.background(NotebookStyle.ivory).accessibilityElement(children: .contain).accessibilityIdentifier("day-controls")
            }
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .picker:
                    TrainingExercisePicker(model: model, close: { presentedSheet = nil })
                case .exercises:
                    TrainingDayExerciseList(model: model, day: day, close: { presentedSheet = nil },
                        add: { presentedSheet = .picker })
                case .reuse:
                    TrainingWorkoutReusePicker(model: model, close: { presentedSheet = nil })
                }
            }
            .sheet(item: $planContext) { context in
                TrainingPlanEditor(model: model, context: context, close: { planContext = nil })
            }
            .onPreferenceChange(TrainingFocusedRowPreference.self) { layout in
                measuredFocusLayout = layout
            }
            .task(id: measuredFocusLayout) {
                // Measure first, then let field anchors and the dock inset settle.
                // This also reveals a restored editor on its first layout.
                await Task.yield()
                guard !Task.isCancelled, let focus = model.focus,
                      measuredFocusLayout?.focusID == focus.id else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    scroll.scrollTo("\(focus.rowID)/\(focus.field.rawValue)", anchor: .center)
                }
            }
            .task(id: model.revealRowID) { if let id = model.revealRowID { await Task.yield(); scroll.scrollTo(id, anchor: .center) } }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let focus = model.focus { scroll.scrollTo("\(focus.rowID)/\(focus.field.rawValue)", anchor: .center) }
            }
            #endif
            .onChange(of: day) { _, _ in
                pendingSheet = nil
                presentedSheet = nil
                planContext = nil
                if model.revealRowID == nil { scroll.scrollTo("day-top", anchor: .top) }
            }
            .onChange(of: model.rows) { _, _ in reconcilePendingSheet() }
            .onChange(of: model.focus?.id) { _, _ in reconcilePendingSheet() }
            .onChange(of: model.canRetrySave) { _, _ in reconcilePendingSheet() }
            .onChange(of: model.errorMessage) { _, _ in reconcilePendingSheet() }
            .onChange(of: model.exercise?.id) { _, _ in pendingSheet = nil; planContext = nil }
            .onChange(of: model.section) { _, _ in pendingSheet = nil }
        }.background(NotebookStyle.ivory)
    }

    private func requestSheet(_ destination: TrainingDaySheet) {
        pendingSheet = nil
        if model.finishEditing() { presentedSheet = destination }
        else {
            pendingSheet = TrainingPendingSheet(destination: destination, day: day,
                exerciseID: model.exercise?.id, rowIDs: model.rows.map(\.id))
        }
    }
    private func presentPendingSheet() {
        guard let request = pendingSheet else { return }
        pendingSheet = nil
        guard model.section == .log, model.selectedDay == request.day, model.focus == nil,
              model.errorMessage == nil, !model.canRetrySave,
              model.exercise?.id == request.exerciseID, model.rows.map(\.id) == request.rowIDs else { return }
        presentedSheet = request.destination
    }
    private func reconcilePendingSheet() {
        guard let request = pendingSheet else { return }
        guard model.section == .log, model.selectedDay == request.day,
              model.exercise?.id == request.exerciseID, model.rows.map(\.id) == request.rowIDs else {
            pendingSheet = nil
            return
        }
        if model.errorMessage == nil, !model.canRetrySave {
            if model.focus == nil { presentPendingSheet() }
            else { pendingSheet = nil }
        }
    }

    private var emptyWorkout: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.indexedExercises(on: day).isEmpty { exerciseSelector }
            Button { requestSheet(.picker) } label: { WorkoutPrimaryActionLabel(title: "Add exercise") }
                .accessibilityIdentifier("add-exercise")
            if !model.reusableWorkouts.isEmpty {
                Button { requestSheet(.reuse) } label: {
                    Text("Use a previous workout")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(NotebookStyle.quiet)
                .accessibilityHint("Choose exercises from an earlier day without copying recorded sets")
                .accessibilityIdentifier("reuse-workout")
            }
        }.padding(.top, 12)
    }

    private var dayNavigation: some View {
        let stackDateControls = textSize.isAccessibilitySize
        let dateLayout = stackDateControls
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                weekButton
                Spacer(minLength: 8)
                todayControl
            }
            dateLayout {
                dayHeading.frame(maxWidth: .infinity, alignment: .leading)
                dateControls.fixedSize()
            }.padding(.bottom, 8)
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
        }
        .padding(.bottom, 4)
    }

    private var dayHeading: some View {
        VStack(alignment: .leading, spacing: 2) {
            weekdayTitle
            dateTitle(day == model.today ? "MMM d" : "MMM d, yyyy")
        }
    }

    @ViewBuilder private var todayControl: some View {
        if day == model.today {
            Text("Today").font(.callout).foregroundStyle(NotebookStyle.clay)
        } else {
            Button {
                pendingSheet = nil
                if model.openToday() { TrainingAccessibility.announce("Today, \(TrainingText.date(model.today, format: "MMM d, yyyy")).") }
            } label: {
                Text("Go to today")
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("Keep this day's unfinished input here and open today")
            .accessibilityIdentifier("go-to-today")
        }
    }

    @ViewBuilder private func exerciseNavigation(_ exercise: Exercise) -> some View {
        if textSize >= .xxxLarge {
            VStack(alignment: .leading, spacing: 0) {
                exerciseSelector
                HStack(spacing: 4) {
                    Spacer(minLength: 8)
                    progressButton(exercise)
                    unitToggle
                }
            }
        } else {
            HStack(spacing: 4) {
                exerciseSelector.frame(maxWidth: .infinity, alignment: .leading)
                progressButton(exercise)
                unitToggle
            }
        }
    }

    private var exerciseSelector: some View {
        TrainingExerciseMenu(model: model, day: day, addExercise: { requestSheet(.picker) },
            showAll: { requestSheet(.exercises) }, beginNavigation: { pendingSheet = nil })
    }
    private func progressButton(_ exercise: Exercise) -> some View {
        Button { pendingSheet = nil; model.openProgress(for: exercise.id) } label: {
            Image(systemName: "chart.xyaxis.line").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("View \(exercise.name) progress")
        .accessibilityIdentifier("exercise-progress")
    }
    private var weekButton: some View {
        Button { pendingSheet = nil; model.showWeek() } label: {
            Label("Week", systemImage: "chevron.left").font(.subheadline).fixedSize(horizontal: true, vertical: true).frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("back-to-week")
    }

    private var unitToggle: some View {
        Button {
            pendingSheet = nil
            model.changeUnit(model.unit.alternate)
        } label: {
            HStack(spacing: 5) {
                Text(model.unit.symbol).font(.subheadline.weight(.medium))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2.weight(.medium))
                    .accessibilityHidden(true)
            }
            .frame(minWidth: 50, minHeight: 44)
            .contentShape(Rectangle())
        }
        .fixedSize()
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("Weight unit")
        .accessibilityValue(model.unit == .pounds ? "Pounds" : "Kilograms")
        .accessibilityHint(model.unit == .pounds ? "Switch to kilograms" : "Switch to pounds")
        .accessibilityIdentifier("weight-unit-toggle")
    }

    private var dateControls: some View {
        HStack(spacing: 0) {
            Button { pendingSheet = nil; model.changeDay(-1) } label: {
                Image(systemName: "chevron.left").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled((try? day.adding(days: -1)) == nil)
            .accessibilityLabel("Previous day").accessibilityIdentifier("previous-day")
            Button { pendingSheet = nil; model.changeDay(1) } label: {
                Image(systemName: "chevron.right").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled((try? day.adding(days: 1)) == nil)
            .accessibilityLabel("Next day").accessibilityIdentifier("next-day")
        }.foregroundStyle(NotebookStyle.quiet)
    }

    private var weekdayTitle: some View {
        Text(TrainingText.date(day, format: "EEEE"))
            .font(NotebookTypography.heading(28, relativeTo: .largeTitle))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("day-title")
    }

    private func dateTitle(_ format: String = "MMM d, yyyy") -> some View {
        Text(TrainingText.date(day, format: format))
            .font(.caption).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityValue(format == "MMM d" ? TrainingText.date(day, format: "yyyy") : "")
            .accessibilityIdentifier("day-date")
    }
}

private struct TrainingSetDetailsRequest: Identifiable {
    let context: TrainingMetadataContext
    let row: TrainingRow
    let index: Int
    var id: UUID { row.id }
}

struct TrainingReferenceBanners: View {
    @Bindable var model: TrainingNotebookModel
    var beginNavigation: () -> Void = {}
    let editPlan: () -> Void
    @State private var expanded = false
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if textSize >= .xxxLarge {
                TrainingPlanSummary(model: model, edit: editPlan)
                if hasReferences { disclosure }
            } else {
                HStack(spacing: 12) {
                    TrainingPlanSummary(model: model, edit: editPlan).frame(maxWidth: .infinity, alignment: .leading)
                    if hasReferences { disclosure.fixedSize(horizontal: true, vertical: false) }
                }
            }
            if expanded { references }
        }
        .onChange(of: model.focus?.rowID) { _, rowID in if rowID != nil { expanded = false } }
    }
    private var hasReferences: Bool { model.lastReference != nil || model.personalBest != nil }
    private var disclosure: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 6) {
                Text(model.lastReference != nil ? (model.personalBest != nil ? "Previous / PR" : "Previous") : "PR")
                    .font(.caption.weight(.medium))
                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel(model.lastReference != nil ? "Previous workout top set\(model.personalBest != nil ? " and personal best" : "")" : "Personal best")
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .accessibilityIdentifier("toggle-entry-references")
    }
    private var references: some View {
        VStack(spacing: 0) {
            if let last = model.lastReference { banner("Previous workout · top set", last, id: "last-reference") }
            if let best = model.personalBest { banner("PR", best, id: "personal-best-reference") }
        }
    }
    private func banner(_ label: String, _ reference: TrainingPerformanceReference, id: String) -> some View {
        Button { beginNavigation(); model.openReference(reference) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TrainingText.set(reference.values, unit: model.unit)).font(.subheadline.monospacedDigit())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(TrainingText.date(reference.day, format: "MMM d, yyyy"))
                            .font(.caption).foregroundStyle(NotebookStyle.quiet)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(TrainingText.set(reference.values, unit: model.unit)).font(.subheadline.monospacedDigit())
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text(TrainingText.date(reference.day, format: "MMM d, yyyy"))
                            .font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize()
                    }
                }
            }.padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        }.accessibilityLabel("\(label), \(TrainingText.date(reference.day, format: "MMM d")), \(TrainingText.set(reference.values, unit: model.unit))")
            .accessibilityHint("View saved sets for this day").accessibilityIdentifier(id)
    }
}

struct TrainingSetRows: View {
    @Bindable var model: TrainingNotebookModel
    var beginInteraction: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .title2) private var numeralSize: CGFloat = 24
    @State private var highlightedRow: UUID?
    @State private var revealedRowID: UUID?
    @State private var detailsRequest: TrainingSetDetailsRequest?
    @State private var typeRequest: TrainingSetDetailsRequest?
    @State private var availableWidth: CGFloat = 345
    private var usesStackedRows: Bool { textSize >= .xxxLarge }
    private var usesCompactRows: Bool { !usesStackedRows && (availableWidth < 340 || textSize >= .xLarge) }
    private var usesLabeledValues: Bool { usesStackedRows || usesCompactRows }
    private var setActionsLayout: AnyLayout {
        usesStackedRows
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            columnHeadings
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            ForEach(Array(model.setEntries.enumerated()), id: \.element.id) { offset, entry in
                if let first = entry.rows.first {
                    entryView(entry, first: first, index: offset + 1)
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                }
            }
            // Preserve each action's identity when Larger Text changes the layout.
            setActionsLayout {
                newSetButton
                Spacer(minLength: usesStackedRows ? 0 : 8)
                repeatButton
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 14)
        }
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in availableWidth = width }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.rows.map(\.id))
        .onChange(of: model.focus?.id) { _, _ in revealedRowID = nil }
        .onChange(of: model.rows.map(\.id)) { _, _ in revealedRowID = nil }
        .sheet(item: $detailsRequest) { request in
            TrainingSetDetailsEditor(model: model, context: request.context, row: request.row, index: request.index,
                                     close: { detailsRequest = nil })
        }
        .sheet(item: $typeRequest) { request in
            TrainingSetTypePicker(model: model, context: request.context, row: request.row, index: request.index,
                                  close: { typeRequest = nil })
        }
        .task(id: highlightedRow) {
            guard highlightedRow != nil else { return }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) { highlightedRow = nil }
        }
    }

    @ViewBuilder private var columnHeadings: some View {
        if usesLabeledValues {
            Text("Sets").font(.headline).accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
        } else {
            HStack(spacing: 6) {
                independentColumnHeading(Text("Set")).frame(width: 24, alignment: .leading)
                independentColumnHeading(Text("Type")).frame(width: 100, alignment: .leading)
                independentColumnHeading(Text("Weight (\(model.unit.symbol))")).frame(maxWidth: .infinity, alignment: .trailing)
                independentColumnHeading(Text("Reps")).frame(width: 54, alignment: .trailing)
                Color.clear.frame(width: 44, height: 1)
            }.font(.footnote.weight(.medium)).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 6)
                .accessibilityElement(children: .contain)
        }
    }

    private func independentColumnHeading(_ title: Text) -> some View {
        title.accessibilityAddTraits(.isHeader)
    }

    private func entryView(_ entry: TrainingSetEntry, first: TrainingRow, index: Int) -> some View {
        SwipeableSetRow(id: entry.id, index: index, revealedRowID: $revealedRowID,
                        highlighted: entry.rows.contains { $0.id == highlightedRow },
                        effort: TrainingSetDetailsText.effort(first.repsInReserve),
                        includesDropStages: entry.rows.count > 1,
                        editEffort: { presentDetails(first, index: index) },
                        delete: { beginInteraction(); return model.deleteSet(first.id) }) {
            VStack(alignment: .leading, spacing: 0) {
                if entry.isDropSet {
                    setHeading(first, index: index)
                    ForEach(Array(entry.rows.enumerated()), id: \.element.id) { stageOffset, row in
                        dropStage(row, index: index, stage: stageOffset)
                    }
                    Button {
                        beginInteraction(); revealedRowID = nil
                        if model.addDropStage(to: first.id) {
                            TrainingAccessibility.announce("Drop added to set \(index). Enter its weight and reps.")
                        }
                    } label: {
                        Label("Add drop", systemImage: "plus").frame(minHeight: 44)
                    }
                    .font(.subheadline).foregroundStyle(NotebookStyle.clay)
                    .padding(.leading, usesLabeledValues ? 0 : 26)
                    .accessibilityLabel("Add drop to set \(index)")
                    .accessibilityHint("Add another weight and reps stage to this drop set")
                    .accessibilityIdentifier("row-\(index)-add-drop")
                } else {
                    ordinaryRow(first, index: index)
                        .id(first.id).background { focusMeasurement(first) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 6)))
    }

    @ViewBuilder private func setHeading(_ row: TrainingRow, index: Int) -> some View {
        if usesStackedRows {
            Text("Set \(index)").font(.subheadline.weight(.medium))
                .foregroundStyle(NotebookStyle.quiet).padding(.top, 10).accessibilityAddTraits(.isHeader)
                .accessibilityRespondsToUserInteraction(false)
            VStack(alignment: .leading, spacing: 4) {
                Text("Type").font(.caption).foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
                typeButton(row, index: index)
            }.padding(.top, 8).padding(.bottom, 4)
        } else if usesCompactRows {
            typeButton(row, index: index, includesSetNumber: true).padding(.top, 4)
        } else {
            HStack(spacing: 6) {
                Text("\(index)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: 24, alignment: .leading)
                    .accessibilityLabel("Set \(index)").accessibilityAddTraits(.isHeader)
                    .accessibilityRespondsToUserInteraction(false)
                typeButton(row, index: index).frame(width: 100)
                Spacer(minLength: 0)
            }.frame(minHeight: 56)
        }
    }

    @ViewBuilder private func ordinaryRow(_ row: TrainingRow, index: Int) -> some View {
        if usesLabeledValues {
            setHeading(row, index: index)
            labeledValues(row)
        } else {
            HStack(spacing: 6) {
                Text("\(index)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: 24, alignment: .leading)
                    .accessibilityLabel("Set \(index)").accessibilityAddTraits(.isHeader)
                    .accessibilityRespondsToUserInteraction(false)
                typeButton(row, index: index).frame(width: 100)
                cell(weightText(row), row: row, field: .weight).frame(maxWidth: .infinity)
                cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: 54)
            }
        }
        stateContext(row).padding(.leading, usesLabeledValues ? 0 : 26)
    }

    private func dropStage(_ row: TrainingRow, index: Int, stage: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if stage > 0 { Rectangle().fill(NotebookStyle.rule.opacity(0.65)).frame(height: 0.5) }
            if usesLabeledValues {
                stageLabel(row, index: index, stage: stage)
                labeledValues(row)
            } else {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 24, height: 1)
                    stageLabel(row, index: index, stage: stage).frame(width: 100, alignment: .leading)
                    cell(weightText(row), row: row, field: .weight).frame(maxWidth: .infinity)
                    cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: 54)
                }
            }
            stateContext(row).padding(.leading, usesLabeledValues ? 0 : 26)
        }
        .id(row.id).background { focusMeasurement(row) }
    }

    @ViewBuilder private func labeledValues(_ row: TrainingRow) -> some View {
        if usesStackedRows {
            stackedCell(row, field: .weight)
            stackedCell(row, field: .reps)
        } else {
            HStack(alignment: .top, spacing: 12) {
                stackedCell(row, field: .weight)
                stackedCell(row, field: .reps)
            }
        }
    }

    @ViewBuilder private func stageLabel(_ row: TrainingRow, index: Int, stage: Int) -> some View {
        if stage == 0 {
            Text("Start").font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet)
                .padding(.leading, 12).padding(.top, usesLabeledValues ? 8 : 0)
                .accessibilityIdentifier("row-\(index)-start")
        } else {
            Menu {
                Button(TrainingSetDetailsText.effort(row.repsInReserve)) { presentDetails(row, index: index) }
                    .accessibilityIdentifier("row-\(index)-drop-\(stage)-details")
                Button(role: .destructive) {
                    beginInteraction(); revealedRowID = nil
                    if model.deleteDropStage(row.id) { TrainingAccessibility.announce("Drop \(stage) removed from set \(index).") }
                } label: { Label("Remove drop", systemImage: "minus.circle") }
                    .accessibilityIdentifier("row-\(index)-drop-\(stage)-remove")
            } label: {
                HStack(spacing: 5) {
                    Text("Drop \(stage)").fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium)).accessibilityHidden(true)
                }.font(.subheadline.weight(.medium)).padding(.leading, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).foregroundStyle(NotebookStyle.clay)
            .accessibilityLabel("Set \(index), drop \(stage) actions")
            .accessibilityIdentifier("row-\(index)-drop-\(stage)-actions")
        }
    }

    @ViewBuilder private func focusMeasurement(_ row: TrainingRow) -> some View {
        if let focus = model.focus, focus.rowID == row.id {
            GeometryReader { geometry in
                Color.clear.preference(key: TrainingFocusedRowPreference.self,
                    value: TrainingFocusedRowLayout(focusID: focus.id, height: geometry.size.height))
            }
        }
    }

    private var newSetButton: some View {
        Button { beginInteraction(); model.newSet() } label: { WorkoutPrimaryActionLabel(title: "New set") }
        .accessibilityIdentifier("new-set")
    }
    @ViewBuilder private var repeatButton: some View {
        if model.canRepeat {
            Button {
                beginInteraction()
                if model.repeatLastSet() {
                    highlightedRow = model.rows.last?.id
                    TrainingAccessibility.announce("Set repeated and saved.")
                }
            } label: {
                Text("Repeat last set")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }.foregroundStyle(NotebookStyle.quiet).accessibilityIdentifier("repeat-set")
        }
    }
    private func weightText(_ row: TrainingRow) -> String {
        row.weight.isEmpty ? (model.exercise?.requiresWeight == false ? "BW" : "—") : row.weight
    }
    private func typeButton(_ row: TrainingRow, index: Int, includesSetNumber: Bool = false) -> some View {
        Button {
            beginInteraction(); revealedRowID = nil
            guard let day = model.selectedDay, let exercise = model.exercise else { return }
            typeRequest = TrainingSetDetailsRequest(
                context: TrainingMetadataContext(day: day, exerciseID: exercise.id, rowIDs: model.rows.map(\.id)),
                row: row, index: index)
        } label: {
            if includesSetNumber {
                HStack(spacing: 6) {
                    Text("Set \(index)").font(.subheadline.monospacedDigit())
                        .foregroundStyle(NotebookStyle.quiet).frame(width: 48, alignment: .leading)
                    typeButtonLabel(row)
                }.contentShape(Rectangle())
            } else {
                typeButtonLabel(row)
            }
        }.foregroundStyle(NotebookStyle.ink)
            .accessibilityLabel(includesSetNumber
                ? "Set \(index), \(TrainingSetTypeText.buttonTitle(row.kind))"
                : "\(TrainingSetTypeText.buttonTitle(row.kind)), set \(index) type")
            .accessibilityHint("Choose Warm-up, Working set, or Drop set. Changes save when selected.")
            .accessibilityIdentifier("row-\(index)-type")
    }
    private func typeButtonLabel(_ row: TrainingRow) -> some View {
        Text(TrainingSetTypeText.buttonTitle(row.kind))
            .font(.footnote.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 6).contentShape(Rectangle())
            .background(NotebookStyle.clay.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
    }
    private func stackedCell(_ row: TrainingRow, field: NumericField) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(field == .weight ? "Weight (\(model.unit.symbol))" : "Reps")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).accessibilityAddTraits(.isHeader).accessibilityRespondsToUserInteraction(false)
            cell(field == .weight ? weightText(row) : row.reps.isEmpty ? "—" : row.reps, row: row, field: field)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, usesCompactRows ? 2 : 4)
    }
    @ViewBuilder private func stateContext(_ row: TrainingRow) -> some View {
        let status = model.rowStatus(for: row)
        VStack(alignment: .leading, spacing: 3) {
            if status == .pendingCorrection, let saved = model.recordedValues(for: row) {
                Text("Last saved: \(TrainingText.set(saved, unit: model.unit))")
                    .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(rowIdentifier(row))-recorded-value")
            }
            if status != .empty, let hint = completionHint(row) {
                Text(hint).font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(rowIdentifier(row))-status")
            }
            if status == .pendingCorrection {
                Button("Restore saved values") {
                    beginInteraction()
                    if model.discardCorrection(row.id) { TrainingAccessibility.announce("Saved values restored.") }
                }.font(.subheadline).foregroundStyle(NotebookStyle.clay).frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Replace the incomplete input with this stage's last saved weight and reps")
                    .accessibilityIdentifier("\(rowIdentifier(row))-discard-edit")
            }
            if status == .empty, !isChildStage(row), let previous = model.previousRecordedSet(before: row.id) {
                Text("Last set: \(TrainingText.set(previous.values, unit: row.unit)) · \(TrainingText.date(previous.day, format: "MMM d"))")
                    .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Use last values") {
                    beginInteraction()
                    if model.prefillSet(row.id) { TrainingAccessibility.announce("Last values saved to \(positionLabel(row).lowercased()).") }
                }.font(.subheadline).foregroundStyle(NotebookStyle.clay).frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Save the last set's weight and reps here")
                    .accessibilityIdentifier("prefill-\(rowIdentifier(row))")
            }
            if let reserve = row.repsInReserve {
                Text(TrainingSetDetailsText.effort(reserve)).font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(positionLabel(row)), \(TrainingSetDetailsText.effort(reserve))")
                    .accessibilityIdentifier("\(rowIdentifier(row))-effort")
            }
        }.padding(.bottom, hasContext(row) ? 8 : 0)
    }
    private func hasContext(_ row: TrainingRow) -> Bool {
        let status = model.rowStatus(for: row)
        return row.repsInReserve != nil || status == .pendingCorrection ||
            (status != .empty && completionHint(row) != nil) ||
            (status == .empty && !isChildStage(row) && model.previousRecordedSet(before: row.id) != nil)
    }
    private func presentDetails(_ row: TrainingRow, index: Int) {
        beginInteraction(); revealedRowID = nil
        guard let day = model.selectedDay, let exercise = model.exercise else { return }
        detailsRequest = TrainingSetDetailsRequest(
            context: TrainingMetadataContext(day: day, exerciseID: exercise.id, rowIDs: model.rows.map(\.id)),
            row: row, index: index)
    }
    private func completionHint(_ row: TrainingRow) -> String? {
        var fields: [String] = []
        if row.parsedWeight == nil && (model.exercise?.requiresWeight != false || !row.weight.isEmpty) { fields.append("weight") }
        if NumericField.reps.parse(row.reps) == nil { fields.append("reps") }
        return fields.isEmpty ? nil : "Enter valid \(fields.joined(separator: " and "))."
    }
    private func isChildStage(_ row: TrainingRow) -> Bool {
        (model.setPosition(for: row.id)?.stageIndex ?? 1) > 1
    }
    private func rowIdentifier(_ row: TrainingRow) -> String {
        guard let position = model.setPosition(for: row.id) else { return "row-1" }
        let base = "row-\(position.setIndex)"
        return position.stageIndex > 1 ? "\(base)-drop-\(position.stageIndex - 1)" : base
    }
    private func positionLabel(_ row: TrainingRow) -> String {
        guard let position = model.setPosition(for: row.id) else { return "Set 1" }
        let base = "Set \(position.setIndex)"
        guard position.isDropSet else { return base }
        return "\(base), \(position.stageIndex == 1 ? "start" : "drop \(position.stageIndex - 1)")"
    }
    private func cell(_ text: String, row: TrainingRow, field: NumericField) -> some View {
        Button { beginInteraction(); model.selectInput(row.id, field: field) } label: {
            Text(text).font(.system(size: numeralSize).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: usesCompactRows ? 48 : 56, alignment: usesLabeledValues ? .leading : .trailing)
                .contentShape(Rectangle())
                .foregroundStyle(model.focus?.rowID == row.id && model.focus?.field == field ? NotebookStyle.clay : NotebookStyle.ink)
        }
        .accessibilityLabel("\(positionLabel(row)), \(text) \(field == .weight ? model.unit.symbol : "reps")")
        .accessibilityHint("Edit \(field == .weight ? "weight" : "reps")")
        .accessibilityIdentifier("\(rowIdentifier(row))-\(field.rawValue)")
        .id("\(row.id)/\(field.rawValue)")
    }
}

private struct WorkoutPrimaryActionLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        Label(title, systemImage: "plus")
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .frame(minHeight: 44)
            .foregroundStyle(NotebookStyle.ivory)
            .background(NotebookStyle.clay, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}
