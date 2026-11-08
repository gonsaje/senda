import SwiftUI
import SendaDomain
import SendaLogger
#if canImport(UIKit)
import UIKit
#endif

struct TrainingDayView: View {
    @Bindable var model: TrainingNotebookModel
    let day: TrainingDay
    @State private var picking = false
    @State private var tabPosition: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button { model.showWeek() } label: { Label("Week", systemImage: "chevron.left").frame(minHeight: 44) }
                            .accessibilityIdentifier("back-to-week")
                        Spacer(minLength: 12)
                        Text(TrainingText.date(day, format: "MMM d, yyyy"))
                            .font(.caption).foregroundStyle(NotebookStyle.quiet).lineLimit(1)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(TrainingText.date(day, format: "EEEE"))
                            .font(NotebookTypography.heading(28, relativeTo: .title2))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(TrainingText.date(day, format: "EEEE, MMM d"))
                            .accessibilityIdentifier("day-title")
                        if day == model.today { Text("Today").font(.callout).foregroundStyle(NotebookStyle.clay).fixedSize() }
                        Spacer(minLength: 0)
                    }.padding(.bottom, 2)
                    HStack(spacing: 10) {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 24) {
                                ForEach(model.tabs) { exercise in
                                    Button { model.selectExercise(exercise.id) } label: {
                                        VStack(spacing: 5) {
                                            Text(exercise.name).font(.body.weight(model.exercise?.id == exercise.id ? .semibold : .regular))
                                                .lineLimit(1).frame(maxWidth: 180)
                                            Rectangle().fill(model.exercise?.id == exercise.id ? NotebookStyle.clay : .clear).frame(height: 2)
                                        }.frame(minHeight: 44)
                                    }.foregroundStyle(model.exercise?.id == exercise.id ? NotebookStyle.clay : NotebookStyle.ink)
                                        .accessibilityIdentifier("exercise-\(exercise.id)")
                                        .contextMenu { Button("Remove from day", role: .destructive) { model.removeExercise(exercise.id) } }
                                        .id(exercise.id)
                                }
                            }.scrollTargetLayout()
                        }.scrollIndicators(.hidden).scrollPosition(id: $tabPosition, anchor: .center)
                        Button { if model.finishEditing() { picking = true } } label: { Image(systemName: "plus").font(.title2).frame(width: 44, height: 44) }
                            .foregroundStyle(NotebookStyle.clay)
                            .accessibilityLabel("Add exercise").accessibilityIdentifier("add-exercise")
                    }
                    if let exercise = model.exercise {
                        Text(exercise.name).font(NotebookTypography.heading(36, italic: true)).lineLimit(2).minimumScaleFactor(0.7)
                            .padding(.top, 4)
                            .accessibilityIdentifier("entry-exercise")
                        if model.lastReference != nil || model.personalBest != nil { TrainingReferenceBanners(model: model) }
                        TrainingSetRows(model: model).id("\(day.rawValue)/\(exercise.id)")
                        TrainingSaveStatus(model: model).id("\(day.rawValue)/\(exercise.id)")
                    } else {
                        Button { if model.finishEditing() { picking = true } } label: { Label("Add exercise", systemImage: "plus").frame(minHeight: 52) }
                            .foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("empty-add-exercise")
                    }
                    if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                }
                .padding(.horizontal, 24).padding(.top, 2).padding(.bottom, 28)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
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
            .sheet(isPresented: $picking) { TrainingExercisePicker(model: model, close: { picking = false }) }
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
            .onChange(of: model.exercise?.id) { _, id in tabPosition = id }
            .onAppear { tabPosition = model.exercise?.id }
        }.background(NotebookStyle.ivory)
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
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Set").frame(width: 20, alignment: .leading)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text("Weight")
                        unitSwitch
                    }.fixedSize(horizontal: true, vertical: false)
                    VStack(spacing: 2) {
                        Text("Weight")
                        unitSwitch
                    }
                }.frame(maxWidth: .infinity)
                Text("Reps").frame(width: 60)
                Color.clear.frame(width: 44, height: 1)
            }.font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 6)
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text("\(index + 1)").font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet).frame(width: 20, alignment: .leading)
                        cell(row.weight.isEmpty ? (model.exercise?.requiresWeight == false ? "BW" : "—") : row.weight, row: row, field: .weight)
                            .frame(maxWidth: .infinity)
                        cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: 60)
                        Button { model.deleteSet(row.id) } label: { Image(systemName: "minus").font(.system(size: 18, weight: .light)).foregroundStyle(NotebookStyle.quiet).frame(width: 44, height: 44) }
                            .accessibilityLabel("Delete set \(index + 1)").accessibilityIdentifier("delete-row-\(index + 1)")
                    }.frame(minHeight: 60)
                        .background(highlightedRow == row.id ? NotebookStyle.olive.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
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
        .task(id: highlightedRow) {
            guard highlightedRow != nil else { return }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) { highlightedRow = nil }
        }
    }
    private var unitSwitch: some View {
        HStack(spacing: 0) {
            ForEach(WeightUnit.allCases, id: \.self) { unit in
                Button { model.changeUnit(unit) } label: {
                    Text(unit.symbol).font(.caption.weight(unit == model.unit ? .semibold : .regular))
                        .foregroundStyle(unit == model.unit ? NotebookStyle.ink : NotebookStyle.quiet)
                        .frame(width: 30, height: 30)
                        .background(unit == model.unit ? NotebookStyle.ivory : .clear, in: RoundedRectangle(cornerRadius: 4))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Weight in \(unit.symbol)").accessibilityIdentifier("day-unit-\(unit.symbol)")
            }
        }.padding(2).background(NotebookStyle.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
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
