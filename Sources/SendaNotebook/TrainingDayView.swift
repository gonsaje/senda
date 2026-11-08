import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

private enum TrainingDaySheet: String, Identifiable {
    case picker, exercises
    var id: String { rawValue }
}

struct TrainingDayView: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    @State private var presentedSheet: TrainingDaySheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        weekButton
                        Spacer(minLength: 12)
                        if day == model.today { Text("Today").font(.callout).foregroundStyle(NotebookStyle.clay).fixedSize() }
                    }
                    dateNavigation.padding(.bottom, 2).id("day-header")
                    TrainingExerciseTabs(model: model, day: day,
                        add: { if model.finishEditing() { presentedSheet = .picker } },
                        showAll: { if model.finishEditing() { presentedSheet = .exercises } })
                    if let exercise = model.exercise {
                        HStack(alignment: .center, spacing: 12) {
                            Text(exercise.name).font(NotebookTypography.heading(36, italic: true)).lineLimit(2).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("entry-exercise")
                            if exercise.requiresWeight { unitMenu }
                        }.padding(.top, 4)
                        if model.lastReference != nil || model.personalBest != nil { TrainingReferenceBanners(model: model) }
                        TrainingSetRows(model: model).id("\(day.rawValue)/\(exercise.id)")
                        TrainingSaveStatus(model: model).id("\(day.rawValue)/\(exercise.id)")
                    } else {
                        Button { if model.finishEditing() { presentedSheet = .picker } } label: { Label("Add exercise", systemImage: "plus").frame(minHeight: 52) }
                            .foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("empty-add-exercise")
                    }
                    if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                }
                .padding(.horizontal, 24).padding(.top, 2).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
                .id("day-top")
            }
            .accessibilityIdentifier("day-scroll")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let focus = model.focus { TrainingInputDock(model: model, focus: focus).id(focus.id) }
                    else if let label = model.undoLabel {
                        HStack {
                            Text(label).font(.subheadline)
                            Spacer()
                            Button("Undo") { model.undoChange() }.underline().frame(minHeight: 44).accessibilityIdentifier("undo-set-change")
                        }
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
                }
            }
            .task(id: model.focus?.id) {
                if let row = model.focus?.rowID {
                    await Task.yield()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { scroll.scrollTo(row, anchor: .center) }
                }
            }
            .task(id: model.revealRowID) { if let id = model.revealRowID { await Task.yield(); scroll.scrollTo(id, anchor: .center) } }
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                if let row = model.focus?.rowID { scroll.scrollTo(row, anchor: .center) }
            }
            #endif
            .onChange(of: day) { _, _ in
                presentedSheet = nil
                if model.revealRowID == nil { scroll.scrollTo("day-top", anchor: .top) }
            }
        }.background(NotebookStyle.ivory)
    }

    private var weekButton: some View {
        Button { model.showWeek() } label: { Label("Week", systemImage: "chevron.left").frame(minHeight: 44) }
            .accessibilityIdentifier("back-to-week")
    }

    private var unitMenu: some View {
        Menu {
            ForEach(WeightUnit.allCases, id: \.self) { unit in
                Button { model.changeUnit(unit) } label: {
                    if unit == model.unit {
                        Label(unit == .pounds ? "Pounds (lb)" : "Kilograms (kg)", systemImage: "checkmark")
                    } else { Text(unit == .pounds ? "Pounds (lb)" : "Kilograms (kg)") }
                }.accessibilityIdentifier("day-unit-\(unit.symbol)")
            }
        } label: {
            HStack(spacing: 5) {
                Text(model.unit.symbol).font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium))
            }.frame(minWidth: 50, minHeight: 44).contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .foregroundStyle(NotebookStyle.quiet)
        .accessibilityLabel("Weight unit, \(model.unit.symbol)")
        .accessibilityIdentifier("weight-unit-menu")
    }

    private var dateNavigation: some View {
        HStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    weekdayTitle.fixedSize()
                    dateTitle().fixedSize()
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    weekdayTitle.fixedSize()
                    dateTitle("MMM d").fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    weekdayTitle
                    dateTitle()
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                Button { model.changeDay(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled((try? day.adding(days: -1)) == nil)
                .accessibilityLabel("Previous day").accessibilityIdentifier("previous-day")
                Button { model.changeDay(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled((try? day.adding(days: 1)) == nil)
                .accessibilityLabel("Next day").accessibilityIdentifier("next-day")
            }
        }
    }

    private var weekdayTitle: some View {
        Text(TrainingText.date(day, format: "EEEE"))
            .font(NotebookTypography.heading(28, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(TrainingText.date(day, format: "EEEE, MMM d"))
            .accessibilityIdentifier("day-title")
    }

    private func dateTitle(_ format: String = "MMM d, yyyy") -> some View {
        Text(TrainingText.date(day, format: format))
            .font(.caption).foregroundStyle(NotebookStyle.quiet)
            .accessibilityLabel(TrainingText.date(day, format: "MMM d, yyyy"))
            .accessibilityIdentifier("day-date")
    }
}

struct TrainingReferenceBanners: View {
    @Bindable var model: TrainingNotebookModel
    var body: some View {
        VStack(spacing: 6) {
            if let last = model.lastReference { banner("Last", last, id: "last-reference") }
            if let best = model.personalBest { banner("PR", best, id: "personal-best-reference") }
        }
    }
    private func banner(_ label: String, _ reference: TrainingPerformanceReference, id: String) -> some View {
        Button { model.openReference(reference) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet).frame(width: 30, alignment: .leading)
                Text(TrainingText.set(reference.values, unit: model.unit)).font(.system(size: 15).monospacedDigit())
                Spacer(minLength: 0)
                Text(TrainingText.date(reference.day, format: "MMM d")).font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize()
            }.padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, minHeight: 44)
                .background(NotebookStyle.olive.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
        }.accessibilityLabel("\(label), \(TrainingText.date(reference.day, format: "MMM d")), \(TrainingText.set(reference.values, unit: model.unit))")
            .accessibilityHint("Open this training day").accessibilityIdentifier(id)
    }
}

struct TrainingSetRows: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightedRow: UUID?
    @State private var revealedRowID: UUID?
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Set").frame(width: 20, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity)
                Text("Reps").frame(width: 60)
                Color.clear.frame(width: 44, height: 1)
            }.font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 6)
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 0) {
                    SwipeableSetRow(id: row.id, index: index + 1, revealedRowID: $revealedRowID,
                                    highlighted: highlightedRow == row.id, delete: { model.deleteSet(row.id) }) {
                        HStack(spacing: 6) {
                            Text("\(index + 1)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet).frame(width: 20, alignment: .leading)
                            cell(row.weight.isEmpty ? (model.exercise?.requiresWeight == false ? "BW" : "—") : row.weight, row: row, field: .weight)
                                .frame(maxWidth: .infinity)
                            cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: 60)
                        }
                    }
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                }.id(row.id)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: 6)))
            }
            HStack {
                Button { model.newSet() } label: { Label("New set", systemImage: "plus").frame(minHeight: 48) }
                    .accessibilityIdentifier("new-set")
                Spacer(minLength: 8)
                if model.canRepeat {
                    Button("Repeat last set") {
                        if model.repeatLastSet() { highlightedRow = model.rows.last?.id }
                    }.frame(minHeight: 48).accessibilityIdentifier("repeat-set")
                }
            }.font(.subheadline).foregroundStyle(NotebookStyle.clay).padding(.top, 5)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.rows.map(\.id))
        .onChange(of: model.focus?.id) { _, _ in revealedRowID = nil }
        .onChange(of: model.rows.map(\.id)) { _, _ in revealedRowID = nil }
        .task(id: highlightedRow) {
            guard highlightedRow != nil else { return }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) { highlightedRow = nil }
        }
    }
    private func cell(_ text: String, row: TrainingRow, field: NumericField) -> some View {
        let index = (model.rows.firstIndex { $0.id == row.id } ?? 0) + 1
        return Button { model.selectInput(row.id, field: field) } label: {
            Text(text).font(.system(size: 24).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(model.focus?.rowID == row.id && model.focus?.field == field ? NotebookStyle.clay : NotebookStyle.ink)
        }
        .accessibilityLabel("Set \(index), \(text) \(field == .weight ? model.unit.symbol : "reps")")
        .accessibilityIdentifier("row-\(index)-\(field.rawValue)")
    }
}

private struct TrainingSaveStatus: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var receipt: UUID?
    private var showSaved: Bool { receipt != nil && model.focus == nil && model.errorMessage == nil }
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: showSaved ? "checkmark" : "circle.fill")
                .font(.system(size: showSaved ? 9 : 5, weight: .medium))
                .foregroundStyle(showSaved ? NotebookStyle.olive : NotebookStyle.quiet)
                .frame(width: 10).accessibilityHidden(true)
            Text(showSaved ? "Saved" : model.saveStatus).font(.caption).foregroundStyle(NotebookStyle.quiet)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier("save-status")
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showSaved)
        .onChange(of: model.journal) { _, _ in
            if model.errorMessage == nil { receipt = UUID() }
        }
        .task(id: receipt) {
            guard receipt != nil else { return }
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            receipt = nil
        }
    }
}
