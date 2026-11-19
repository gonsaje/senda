import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

private enum TrainingDaySheet: Hashable, Identifiable {
    case catalog(String), exercises, library, saveTemplate, history(String)
    var id: Self { self }
}

private enum TrainingDayDestination {
    case addExercise, sheet(TrainingDaySheet)
}

private struct TrainingPendingNavigation {
    let destination: TrainingDayDestination
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
    @State private var weightEntry = TrainingWeightEntrySettings()
    @State private var showingSearch = false
    @State private var searchAfterDismissal: TrainingDay?
    @State private var pendingNavigation: TrainingPendingNavigation?
    @State private var planContext: TrainingMetadataContext?
    @State private var stripScrolledPast = false
    @State private var measuredFocusLayout: TrainingFocusedRowLayout?
    @State private var showsFirstSetConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    private var firstSetConfirmation: some View {
        Label("First set saved", systemImage: "checkmark")
            .font(.footnote.weight(.medium))
            .foregroundStyle(NotebookStyle.olive)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(NotebookStyle.ivory, in: Capsule())
            .overlay { Capsule().strokeBorder(NotebookStyle.rule, lineWidth: 1) }
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("First set saved")
            .accessibilityIdentifier("first-set-saved")
    }

    var body: some View {
        let hasExercises = model.exercise != nil || !model.indexedExercises(on: day).isEmpty
        let isFirstWorkout = !hasExercises && model.isFirstWorkout
        return ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if hasExercises {
                        dayNavigation.id("day-header")
                            .onGeometryChange(for: Bool.self) {
                                $0.frame(in: .scrollView(axis: .vertical)).maxY < 0
                            } action: { stripScrolledPast = $0 }
                        // An unpinned anchor restores the first sets even when the tab strip is pinned.
                        Color.clear.frame(height: 0).id("active-exercise")
                            .accessibilityHidden(true)
                    } else {
                        emptyDayNavigation(isFirstWorkout: isFirstWorkout).id("day-header")
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            if showingSearch {
                                TrainingExercisePicker(inline: model, close: { showingSearch = false },
                                    browse: { query in open(.sheet(.catalog(query))) })
                            } else if let exercise = model.exercise {
                                exerciseControls(exercise)
                                if let last = model.lastReference {
                                    TrainingLastTimeRow(
                                        summary: ProgressFormatting.set(last.values, exercise: exercise, unit: model.unit),
                                        day: last.day,
                                        showSet: { pendingNavigation = nil; model.openReference(last) },
                                        showHistory: { open(.sheet(.history(exercise.id))) })
                                }
                                TrainingSetRows(model: model, records: model.workoutPersonalRecords,
                                                beginInteraction: { pendingNavigation = nil }).id("\(day.rawValue)/\(exercise.id)")
                                if let best = model.personalBest {
                                    TrainingPersonalBest(model: model, best: best, beginNavigation: { pendingNavigation = nil })
                                }
                                if model.focus == nil && model.errorMessage == nil && !model.canRetrySave {
                                    TrainingNextWorkoutFeedback(model: model, day: day, exercise: exercise)
                                }
                            } else {
                                TrainingEmptyWorkout(isFirstWorkout: isFirstWorkout, unit: model.unit,
                                    addExercise: hasExercises ? nil : { open(.addExercise) },
                                    chooseTemplate: { open(.sheet(.library)) })
                            }
                        }
                        .padding(.top, 8)
                    } header: {
                        if hasExercises {
                            workoutExercises(scroll)
                                .background(NotebookStyle.ivory)
                        }
                    }
                }
                .padding(.horizontal, hasExercises ? 24 : 20).padding(.top, 2).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .id("day-top")
            }
            .clipped()
            .accessibilityIdentifier("day-scroll")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let error = model.errorMessage ?? (model.canRetrySave ? model.saveStatus : nil) {
                        TrainingSaveError(model: model, message: error, retrySucceeded: presentPendingNavigation)
                            .padding(.horizontal, 24).padding(.top, 8)
                            .padding(.bottom, model.focus == nil ? 12 : 0)
                    }
                    if let focus = model.focus {
                        TrainingInputDock(model: model, focus: focus, weightEntry: $weightEntry, beginInteraction: {
                            pendingNavigation = nil
                        }).id(focus.id)
                    }
                    else if model.errorMessage == nil, let label = model.undoLabel {
                        Button {
                            pendingNavigation = nil
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
                }
                .frame(maxWidth: .infinity)
                .background(NotebookStyle.ivory)
                .overlay(alignment: .top) {
                    if showsFirstSetConfirmation && model.errorMessage == nil && !model.canRetrySave {
                        // Keep confirmation above the controls without resizing the viewport.
                        firstSetConfirmation
                            .padding(.bottom, 3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(height: 0, alignment: .bottom)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("day-controls")
            }
            .sheet(item: $presentedSheet, onDismiss: {
                if searchAfterDismissal == day && model.selectedDay == day && model.section == .log {
                    showingSearch = true
                }
                searchAfterDismissal = nil
            }) { destination in
                switch destination {
                case .catalog(let query):
                    TrainingExercisePicker(model: model, initialSearch: query, close: { presentedSheet = nil })
                case .exercises:
                    TrainingDayExerciseList(model: model, day: day, close: { presentedSheet = nil },
                        add: { searchAfterDismissal = day; presentedSheet = nil })
                case .library:
                    TrainingWorkoutLibrary(model: model, close: { presentedSheet = nil })
                case .saveTemplate:
                    TrainingWorkoutTemplateEditor(model: model, template: nil, isEditing: false, copiesCurrentDay: true,
                        close: { presentedSheet = nil }, saved: { _ in presentedSheet = nil })
                case .history(let exerciseID):
                    TrainingWorkoutExerciseHistory(model: model, exercise: model.exercise(exerciseID), before: day,
                        close: { presentedSheet = nil })
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
                    scroll.scrollTo("\(focus.rowID)/\(focus.field.rawValue)", anchor: textSize.isAccessibilitySize ? .bottom : .center)
                }
            }
            .task(id: model.revealRowID) { if let id = model.revealRowID { await Task.yield(); scroll.scrollTo(id, anchor: .center) } }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let focus = model.focus { scroll.scrollTo("\(focus.rowID)/\(focus.field.rawValue)", anchor: textSize.isAccessibilitySize ? .bottom : .center) }
            }
            #endif
            .onChange(of: model.hasSavedFirstSet) { _, hasSaved in
                guard hasSaved else { return }
                showsFirstSetConfirmation = true
                TrainingAccessibility.announce("First set saved.")
            }
            .task(id: showsFirstSetConfirmation) {
                guard showsFirstSetConfirmation else { return }
                do { try await Task.sleep(for: .seconds(4)) }
                catch { return }
                showsFirstSetConfirmation = false
            }
            .onChange(of: day) { _, _ in
                weightEntry = TrainingWeightEntrySettings()
                showsFirstSetConfirmation = false
                showingSearch = false
                searchAfterDismissal = nil
                pendingNavigation = nil
                presentedSheet = nil
                planContext = nil
                if model.revealRowID == nil { scroll.scrollTo("day-top", anchor: .top) }
            }
            .onChange(of: showingSearch) { _, isOpen in
                if !isOpen && presentedSheet == nil && model.section == .log && model.selectedDay == day {
                    scroll.scrollTo(hasExercises ? "active-exercise" : "day-header", anchor: .top)
                }
            }
            .onChange(of: model.rows) { _, _ in reconcilePendingNavigation() }
            .onChange(of: model.focus?.id) { _, _ in reconcilePendingNavigation() }
            .onChange(of: model.canRetrySave) { _, _ in reconcilePendingNavigation() }
            .onChange(of: model.errorMessage) { _, _ in reconcilePendingNavigation() }
            .onChange(of: model.exercise?.id) { _, _ in
                pendingNavigation = nil
                planContext = nil
            }
            .onChange(of: model.section) { _, _ in
                pendingNavigation = nil
                showingSearch = false
                searchAfterDismissal = nil
            }
        }.background(NotebookStyle.ivory)
    }

    private func open(_ destination: TrainingDayDestination) {
        pendingNavigation = nil
        if model.finishEditing() { present(destination) }
        else {
            pendingNavigation = TrainingPendingNavigation(destination: destination, day: day,
                exerciseID: model.exercise?.id, rowIDs: model.rows.map(\.id))
        }
    }
    private func presentPendingNavigation() {
        guard let request = pendingNavigation else { return }
        pendingNavigation = nil
        guard model.section == .log, model.selectedDay == request.day, model.focus == nil,
              model.errorMessage == nil, !model.canRetrySave,
              model.exercise?.id == request.exerciseID, model.rows.map(\.id) == request.rowIDs else { return }
        present(request.destination)
    }

    private func present(_ destination: TrainingDayDestination) {
        switch destination {
        case .addExercise:
            showingSearch = true
        case .sheet(let sheet):
            showingSearch = false
            presentedSheet = sheet
        }
    }
    private func reconcilePendingNavigation() {
        guard let request = pendingNavigation else { return }
        guard model.section == .log, model.selectedDay == request.day,
              model.exercise?.id == request.exerciseID, model.rows.map(\.id) == request.rowIDs else {
            pendingNavigation = nil
            return
        }
        if model.errorMessage == nil, !model.canRetrySave {
            if model.focus == nil { presentPendingNavigation() }
            else { pendingNavigation = nil }
        }
    }

    private func emptyDayNavigation(isFirstWorkout: Bool) -> some View {
        let dateLayout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 4))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                weekButton
                if day != model.today && !textSize.isAccessibilitySize { todayControl }
                Spacer(minLength: 8)
                TrainingWordmark(width: 103)
            }
            Text(isFirstWorkout ? "Your first workout" : "Add a workout")
                .font(NotebookTypography.heading(34, relativeTo: .title2))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("day-title")
            dateLayout {
                dateTitle(fullDateFormat, font: .subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                dateControls
            }
            if day != model.today && textSize.isAccessibilitySize { todayControl }
        }
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

    private var fullDateFormat: String {
        day.rawValue.prefix(4) == model.today.rawValue.prefix(4) ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy"
    }

    private var dayHeading: some View {
        VStack(alignment: .leading, spacing: 2) {
            TrainingDateStamp(day: day, isToday: day == model.today, isHeading: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(TrainingText.date(day, format: "EEEE"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("day-title")
            dateTitle(day == model.today ? "MMMM" : "MMMM yyyy", font: .subheadline)
        }
    }

    @ViewBuilder private var todayControl: some View {
        if day == model.today {
            Text("Today").font(.callout).foregroundStyle(NotebookStyle.clay)
        } else {
            Button {
                pendingNavigation = nil
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

    @ViewBuilder private func workoutExercises(_ scroll: ScrollViewProxy) -> some View {
        if model.tabs.isEmpty {
            HStack {
                Text("Exercises").font(NotebookTypography.heading(17, relativeTo: .headline)).accessibilityAddTraits(.isHeader)
                Spacer()
                if !model.indexedExercises(on: day).isEmpty { workoutOptions }
                addExerciseButton
            }
        } else {
            TrainingWorkoutExerciseList(exercises: model.tabs, selectedID: model.exercise?.id, select: { id in
                if id == model.exercise?.id {
                    if showingSearch { showingSearch = false }
                    return true
                }
                pendingNavigation = nil
                guard model.selectExercise(id) else { return false }
                showingSearch = false
                if stripScrolledPast { scroll.scrollTo("active-exercise", anchor: .top) }
                return true
            }, add: { addExerciseButton })
        }
    }
    private var addExerciseButton: some View {
        Button { open(.addExercise) } label: {
            Image(systemName: "plus").font(.body.weight(.medium))
                .frame(width: 44, height: 46).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .disabled(showingSearch)
        .accessibilityLabel("Add exercise")
        .accessibilityIdentifier("add-exercise")
    }

    private func exerciseControls(_ exercise: Exercise) -> some View {
        let layout = textSize >= .xxxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            TrainingPlanSummary(model: model) {
                pendingNavigation = nil
                planContext = TrainingMetadataContext(day: day, exerciseID: exercise.id, rowIDs: model.rows.map(\.id))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                progressButton(exercise)
                unitToggle
                workoutOptions
            }
        }
    }

    private var workoutOptions: some View {
        TrainingWorkoutOptions(model: model, day: day, showAll: { open(.sheet(.exercises)) },
            chooseWorkout: { open(.sheet(.library)) }, saveTemplate: { open(.sheet(.saveTemplate)) },
            beginNavigation: { pendingNavigation = nil })
    }
    private func progressButton(_ exercise: Exercise) -> some View {
        Button { pendingNavigation = nil; model.openProgress(for: exercise.id) } label: {
            Image(systemName: "chart.xyaxis.line").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("View \(exercise.displayName) progress")
        .accessibilityIdentifier("exercise-progress")
    }
    private var weekButton: some View {
        Button { pendingNavigation = nil; model.showWeek() } label: {
            Label("Week", systemImage: "chevron.left").font(.subheadline).fixedSize(horizontal: true, vertical: true).frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("back-to-week")
    }

    private var unitToggle: some View {
        Button {
            pendingNavigation = nil
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
            Button { pendingNavigation = nil; model.changeDay(-1) } label: {
                Image(systemName: "chevron.left").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled((try? day.adding(days: -1)) == nil)
            .accessibilityLabel("Previous day").accessibilityIdentifier("previous-day")
            Button { pendingNavigation = nil; model.changeDay(1) } label: {
                Image(systemName: "chevron.right").padding(8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .disabled((try? day.adding(days: 1)) == nil)
            .accessibilityLabel("Next day").accessibilityIdentifier("next-day")
        }.foregroundStyle(NotebookStyle.quiet)
    }

    private func dateTitle(_ format: String, font: Font) -> some View {
        Text(TrainingText.date(day, format: format))
            .font(font).foregroundStyle(NotebookStyle.quiet)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(TrainingText.date(day, format: fullDateFormat))
            .accessibilityValue(fullDateFormat.contains("y") ? "" : TrainingText.date(day, format: "yyyy"))
            .accessibilityIdentifier("day-date")
    }
}

private struct TrainingSetDetailsRequest: Identifiable {
    let context: TrainingMetadataContext
    let row: TrainingRow
    let index: Int
    var id: UUID { row.id }
}

private struct TrainingLastTimeRow: View {
    let summary: String
    let day: TrainingDay
    let showSet: () -> Void
    let showHistory: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        layout {
            Button(action: showSet) {
                Text("Last time · \(Text(summary).fontWeight(.semibold).foregroundColor(NotebookStyle.ink))")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityValue("Top set on \(TrainingText.date(day, format: "MMM d, yyyy"))")
            .accessibilityHint("View this recorded top set").accessibilityIdentifier("last-reference")
            Button(action: showHistory) {
                HStack(spacing: 4) {
                    Text("History")
                    Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true)
                }.font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
            .foregroundStyle(NotebookStyle.clay)
            .accessibilityHint("Read all earlier sets for this exercise")
            .accessibilityIdentifier("exercise-history")
        }
        .overlay(alignment: .top) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
    }
}

private struct TrainingPersonalBest: View {
    @Bindable var model: TrainingNotebookModel
    let best: TrainingPerformanceReference
    let beginNavigation: () -> Void
    @State private var expanded = false
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            disclosure
            if expanded { banner("PR", best, id: "personal-best-reference") }
        }
        .onChange(of: model.focus?.rowID) { _, rowID in if rowID != nil { expanded = false } }
        .onChange(of: model.exercise?.id) { _, _ in expanded = false }
    }
    private var disclosure: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: 6) {
                Text("Personal best")
                    .font(.caption.weight(.medium))
                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("Personal best")
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        .accessibilityIdentifier("toggle-entry-references")
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
    private enum Ledger {
        static let numberWidth: CGFloat = 24
        static let typeWidth: CGFloat = 104
        static let repsWidth: CGFloat = 50
        static let columnSpacing: CGFloat = 4
        static let valueInset: CGFloat = 4
        static let minimumWidth: CGFloat = 324
    }

    @Bindable var model: TrainingNotebookModel
    let records: [UUID: TrainingWorkoutRecord]
    var beginInteraction: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title2) private var numeralSize: CGFloat = 24
    @State private var highlightedRow: UUID?
    @State private var pendingRecord: TrainingPerformanceReference?
    @State private var celebratedRows: Set<UUID> = []
    @State private var revealedRowID: UUID?
    @State private var detailsRequest: TrainingSetDetailsRequest?
    @State private var typeRequest: TrainingSetDetailsRequest?
    @State private var availableWidth: CGFloat = 345
    private var usesStackedRows: Bool { textSize >= .xxxLarge }
    private var usesCompactRows: Bool { !usesStackedRows && (availableWidth < Ledger.minimumWidth || textSize >= .xLarge) }
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
        .onChange(of: RecordUpdate(records: records, write: model.latestWorkoutSetWrite), recordChanged)
        .onChange(of: scenePhase) { _, phase in if phase != .active { pendingRecord = nil } }
        .onDisappear { pendingRecord = nil }
        .task(id: pendingRecord, celebrateRecord)
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
            Text("Sets").font(NotebookTypography.heading(17, relativeTo: .headline)).accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
        } else {
            HStack(spacing: SwipeableSetRowMetrics.menuSpacing) {
                HStack(spacing: Ledger.columnSpacing) {
                    independentColumnHeading(Text("Set")).frame(width: Ledger.numberWidth, alignment: .leading)
                    independentColumnHeading(Text("Type")).frame(width: Ledger.typeWidth, alignment: .leading)
                    independentColumnHeading(Text("Weight (\(model.unit.symbol))"))
                        .padding(.trailing, Ledger.valueInset)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    independentColumnHeading(Text("Reps"))
                        .padding(.trailing, Ledger.valueInset)
                        .frame(width: Ledger.repsWidth, alignment: .trailing)
                }
                Color.clear.frame(width: SwipeableSetRowMetrics.menuWidth, height: 1)
            }.font(.footnote.weight(.medium)).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 6)
                .accessibilityElement(children: .contain)
        }
    }

    private func independentColumnHeading(_ title: Text) -> some View {
        title.accessibilityAddTraits(.isHeader)
    }

    private func entryView(_ entry: TrainingSetEntry, first: TrainingRow, index: Int) -> some View {
        let previous = model.rowStatus(for: first) == .empty ? model.previousRecordedSet(before: first.id) : nil
        return SwipeableSetRow(id: entry.id, index: index, revealedRowID: $revealedRowID,
                        highlighted: entry.rows.contains { $0.id == highlightedRow },
                        effort: TrainingSetDetailsText.effort(first.repsInReserve),
                        includesDropStages: entry.rows.count > 1,
                        editEffort: { presentDetails(first, index: index) },
                        previousValues: previous.map { TrainingText.set($0.values, unit: first.unit) },
                        useLastValues: {
                            beginInteraction()
                            if model.prefillSet(first.id) {
                                TrainingAccessibility.announce("Last values saved to \(positionLabel(first).lowercased()).")
                            }
                        },
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
                    .padding(.leading, usesLabeledValues ? 0 : Ledger.numberWidth + Ledger.columnSpacing)
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
            HStack(spacing: Ledger.columnSpacing) {
                Text("\(index)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: Ledger.numberWidth, alignment: .leading)
                    .accessibilityLabel("Set \(index)").accessibilityAddTraits(.isHeader)
                    .accessibilityRespondsToUserInteraction(false)
                typeButton(row, index: index).frame(width: Ledger.typeWidth)
                Spacer(minLength: 0)
            }.frame(minHeight: SwipeableSetRowMetrics.rowHeight)
        }
    }

    @ViewBuilder private func ordinaryRow(_ row: TrainingRow, index: Int) -> some View {
        if usesLabeledValues {
            setHeading(row, index: index)
            labeledValues(row)
        } else {
            HStack(spacing: Ledger.columnSpacing) {
                Text("\(index)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .frame(width: Ledger.numberWidth, alignment: .leading)
                    .accessibilityLabel("Set \(index)").accessibilityAddTraits(.isHeader)
                    .accessibilityRespondsToUserInteraction(false)
                typeButton(row, index: index).frame(width: Ledger.typeWidth)
                cell(weightText(row), row: row, field: .weight).frame(maxWidth: .infinity)
                cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: Ledger.repsWidth)
            }
        }
        stateContext(row).padding(.leading, usesLabeledValues ? 0 : Ledger.numberWidth + Ledger.columnSpacing)
    }

    private func dropStage(_ row: TrainingRow, index: Int, stage: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if stage > 0 { Rectangle().fill(NotebookStyle.rule.opacity(0.65)).frame(height: 0.5) }
            if usesLabeledValues {
                stageLabel(row, index: index, stage: stage)
                labeledValues(row)
            } else {
                HStack(spacing: Ledger.columnSpacing) {
                    Color.clear.frame(width: Ledger.numberWidth, height: 1)
                    stageLabel(row, index: index, stage: stage).frame(width: Ledger.typeWidth, alignment: .leading)
                    cell(weightText(row), row: row, field: .weight).frame(maxWidth: .infinity)
                    cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: Ledger.repsWidth)
                }
            }
            stateContext(row).padding(.leading, usesLabeledValues ? 0 : Ledger.numberWidth + Ledger.columnSpacing)
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
    private var repeatButton: some View {
        let canRepeat = model.canRepeat
        return Button {
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
        }
        .foregroundStyle(colorScheme == .dark ? NotebookStyle.clay : NotebookStyle.quiet)
        .opacity(canRepeat ? 1 : 0)
        .disabled(!canRepeat)
        .accessibilityHidden(!canRepeat)
        .accessibilityIdentifier("repeat-set")
    }
    private func weightText(_ row: TrainingRow) -> String {
        row.weight.isEmpty ? (model.exercise?.equipmentType == .bodyweight ? "BW" : "—") : row.weight
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
        let title = row.kind == nil && !usesLabeledValues ? "Choose" : TrainingSetTypeText.buttonTitle(row.kind)
        return HStack(spacing: 5) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(row.kind == nil ? NotebookStyle.quiet : NotebookStyle.ink)
                .fixedSize(horizontal: !usesLabeledValues, vertical: true)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .imageScale(.small)
                .foregroundStyle(NotebookStyle.quiet)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(NotebookStyle.typeFill, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
    private func stackedCell(_ row: TrainingRow, field: NumericField) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(field == .weight ? "Weight (\(model.unit.symbol))" : "Reps")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet).accessibilityAddTraits(.isHeader).accessibilityRespondsToUserInteraction(false)
            cell(field == .weight ? weightText(row) : row.reps.isEmpty ? "—" : row.reps, row: row, field: field)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, usesCompactRows ? 2 : 4)
    }

    private struct RecordUpdate: Equatable {
        let records: [UUID: TrainingWorkoutRecord]
        let write: TrainingPerformanceReference?
    }

    private func recordChanged(_ before: RecordUpdate, _ after: RecordUpdate) {
        guard before.write != after.write else { return }
        guard let write = after.write, write.day == model.selectedDay, write.exerciseID == model.exercise?.id,
              after.records[write.rowID]?.values == write.values, !celebratedRows.contains(write.rowID),
              before.records[write.rowID] == nil || pendingRecord?.rowID == write.rowID else {
            pendingRecord = nil
            return
        }
        pendingRecord = write
    }

    private func celebrateRecord() async {
        guard let write = pendingRecord else { return }
        // Each valid digit autosaves. Let a multi-digit entry settle before announcing its result.
        do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
        guard !Task.isCancelled, scenePhase == .active, model.section == .log, !model.canRetrySave,
              model.selectedDay == write.day, let exercise = model.exercise, exercise.id == write.exerciseID,
              let row = model.rows.first(where: { $0.id == write.rowID }),
              model.workoutPersonalRecords[row.id]?.values == write.values,
              row.pendingCorrection != true, row.parsed(for: exercise) == write.values else { return }
        celebratedRows.insert(row.id)
        let result = ProgressFormatting.set(write.values, exercise: exercise, unit: row.unit)
        TrainingAccessibility.announce("Personal record for \(exercise.displayName), \(result).")
    }

    private func recordMark(_ record: TrainingWorkoutRecord, row: TrainingRow, exercise: Exercise) -> some View {
        let previous = ProgressFormatting.set(record.previousValues, exercise: exercise, unit: row.unit)
        let result = ProgressFormatting.set(record.values, exercise: exercise, unit: row.unit)
        let title = Text("Personal record").fontWeight(.semibold).foregroundColor(NotebookStyle.clay)
        let crown = Image(systemName: "crown.fill").foregroundStyle(NotebookStyle.clay)
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Group {
                if reduceMotion { crown }
                else { crown.symbolEffect(.pulse, options: .nonRepeating, value: celebratedRows.contains(row.id)) }
            }.accessibilityHidden(true)
            Text("\(title) · was \(previous)")
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Personal record for \(exercise.displayName), \(positionLabel(row))")
        .accessibilityValue("\(result), previously \(previous)")
        .accessibilityIdentifier("\(rowIdentifier(row))-pr")
    }

    @ViewBuilder private func stateContext(_ row: TrainingRow) -> some View {
        let status = model.focus?.rowID == row.id ? nil : model.rowStatus(for: row)
        let hint = status.flatMap { $0 == .empty ? nil : completionHint(row) }
        VStack(alignment: .leading, spacing: 3) {
            if let record = records[row.id], let exercise = model.exercise,
               row.pendingCorrection != true, row.parsed(for: exercise) == record.values {
                recordMark(record, row: row, exercise: exercise)
            }
            if status == .pendingCorrection, let saved = model.recordedValues(for: row) {
                Text("Last saved: \(TrainingText.set(saved, unit: model.unit))")
                    .font(.caption.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(rowIdentifier(row))-recorded-value")
            }
            if let hint {
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
            if let reserve = row.repsInReserve {
                Text(TrainingSetDetailsText.effort(reserve)).font(.caption).foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(positionLabel(row)), \(TrainingSetDetailsText.effort(reserve))")
                    .accessibilityIdentifier("\(rowIdentifier(row))-effort")
            }
        }.padding(.bottom, row.repsInReserve != nil || status == .pendingCorrection || hint != nil ? 8 : 0)
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
        let isFocused = model.focus?.rowID == row.id && model.focus?.field == field
        return Button { beginInteraction(); model.selectInput(row.id, field: field) } label: {
            Text(text).font(.system(size: numeralSize).monospacedDigit())
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, usesLabeledValues ? 0 : Ledger.valueInset)
                .frame(maxWidth: .infinity, minHeight: usesCompactRows ? 48 : SwipeableSetRowMetrics.rowHeight,
                       alignment: usesLabeledValues ? .leading : .trailing)
                .contentShape(Rectangle())
                .foregroundStyle(isFocused ? NotebookStyle.clay : NotebookStyle.ink)
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
            .foregroundStyle(NotebookStyle.onPrimary)
            .background(NotebookStyle.primaryFill, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}
