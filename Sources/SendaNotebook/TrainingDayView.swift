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
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Button { model.showWeek() } label: { Label("Week", systemImage: "chevron.left").frame(minHeight: 44) }
                            .accessibilityIdentifier("back-to-week")
                        Spacer(); TrainingWordmark()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TrainingText.date(day, format: "EEEE, MMM d")).font(.system(size: 33, design: .serif).italic())
                            .accessibilityIdentifier("day-title")
                        if day == model.today { Text("Today").font(.system(size: 20, design: .serif).italic()).foregroundStyle(NotebookStyle.clay) }
                    }
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
                            .accessibilityLabel("Add exercise").accessibilityIdentifier("add-exercise")
                    }
                    if let exercise = model.exercise {
                        Text(exercise.name).font(.system(size: 43, design: .serif).italic()).lineLimit(2).minimumScaleFactor(0.7)
                            .accessibilityIdentifier("entry-exercise")
                        if model.lastReference != nil || model.personalBest != nil { TrainingReferenceBanners(model: model) }
                        TrainingSetRows(model: model)
                        HStack(spacing: 8) {
                            Circle().fill(NotebookStyle.quiet).frame(width: 6, height: 6)
                            Text(model.saveStatus).font(.caption).foregroundStyle(NotebookStyle.quiet)
                        }.accessibilityElement(children: .combine).accessibilityIdentifier("save-status")
                    } else {
                        Button { if model.finishEditing() { picking = true } } label: { Label("Add exercise", systemImage: "plus").frame(minHeight: 52) }
                            .foregroundStyle(NotebookStyle.clay).accessibilityIdentifier("empty-add-exercise")
                    }
                    if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
                }
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
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
                        .background(NotebookStyle.clay.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24).padding(.bottom, 12)
                    }
                }.background(NotebookStyle.ivory).accessibilityElement(children: .contain).accessibilityIdentifier("day-controls")
            }
            .sheet(isPresented: $picking) { TrainingExercisePicker(model: model, close: { picking = false }) }
            .task(id: model.focus?.id) {
                if let row = model.focus?.rowID { await Task.yield(); withAnimation { scroll.scrollTo(row, anchor: .center) } }
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
        VStack(spacing: 8) {
            if let last = model.lastReference { banner("Last", last, id: "last-reference") }
            if let best = model.personalBest { banner("PR", best, id: "personal-best-reference") }
        }
    }
    private func banner(_ label: String, _ reference: TrainingPerformanceReference, id: String) -> some View {
        Button { model.openReference(reference) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.clay).frame(width: 30, alignment: .leading)
                Text(TrainingText.set(reference.values, unit: model.unit)).font(.system(size: 15).monospacedDigit())
                Spacer(minLength: 0)
                Text(TrainingText.date(reference.day, format: "MMM d")).font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize()
            }.padding(.horizontal, 12).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 44)
                .background(NotebookStyle.clay.opacity(0.055))
                .overlay(alignment: .leading) { Rectangle().fill(NotebookStyle.clay).frame(width: 2) }
        }.accessibilityLabel("\(label), \(TrainingText.date(reference.day, format: "MMM d")), \(TrainingText.set(reference.values, unit: model.unit))")
            .accessibilityHint("Open this training day").accessibilityIdentifier(id)
    }
}

struct TrainingSetRows: View {
    @Bindable var model: TrainingNotebookModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Set").frame(width: 24, alignment: .leading)
                HStack(spacing: 5) {
                    Text("Weight").lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 0) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Button { model.changeUnit(unit) } label: {
                                Text(unit.symbol).font(.caption.weight(unit == model.unit ? .semibold : .regular))
                                    .foregroundStyle(unit == model.unit ? NotebookStyle.ivory : NotebookStyle.quiet)
                                    .frame(width: 30, height: 30)
                                    .background(unit == model.unit ? NotebookStyle.clay : .clear, in: RoundedRectangle(cornerRadius: 4))
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }.accessibilityLabel("Weight in \(unit.symbol)").accessibilityIdentifier("day-unit-\(unit.symbol)")
                        }
                    }.padding(2).overlay { RoundedRectangle(cornerRadius: 5).stroke(NotebookStyle.rule, lineWidth: 0.5) }
                }.frame(maxWidth: .infinity)
                Text("Reps").frame(width: 66)
                Color.clear.frame(width: 44, height: 1)
            }.font(.caption.weight(.medium)).foregroundStyle(NotebookStyle.quiet).padding(.bottom, 6)
            Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    Text("\(index + 1)").font(.subheadline.monospacedDigit()).frame(width: 24, alignment: .leading)
                    cell(row.weight.isEmpty ? (model.exercise?.requiresWeight == false ? "BW" : "—") : row.weight, row: row, field: .weight)
                        .frame(maxWidth: .infinity)
                    cell(row.reps.isEmpty ? "—" : row.reps, row: row, field: .reps).frame(width: 66)
                    Button { model.deleteSet(row.id) } label: { Image(systemName: "minus").font(.system(size: 18, weight: .light)).frame(width: 44, height: 44) }
                        .accessibilityLabel("Delete set \(index + 1)").accessibilityIdentifier("delete-row-\(index + 1)")
                }.frame(minHeight: 56).id(row.id)
                Rectangle().fill(NotebookStyle.rule).frame(height: 1)
            }
            HStack {
                Button { model.newSet() } label: { Label("New set", systemImage: "plus").frame(minHeight: 48) }
                    .accessibilityIdentifier("new-set")
                Spacer(minLength: 8)
                if model.canRepeat { Button("Repeat last set") { model.repeatLastSet() }.frame(minHeight: 48).accessibilityIdentifier("repeat-set") }
            }.font(.subheadline).foregroundStyle(NotebookStyle.clay).padding(.top, 5)
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
