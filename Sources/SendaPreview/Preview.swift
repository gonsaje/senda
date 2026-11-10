#if os(macOS)
import AppKit
import SwiftUI
import SendaDomain
import SendaLogger
import SendaPersistence
@_spi(Preview) import SendaNotebook

/// Renders the real SwiftUI view on macOS; these are not iOS simulator screenshots.
@main @MainActor
struct SendaPreview {
    private static var liveWindow: NSWindow?
    static func main() throws {
        if CommandLine.arguments.contains("--live") {
            try openLivePreview()
            return
        }
        let learnOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--learn-only"
        let autosaveOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--autosave-only"
        let setTypesOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--set-types-only"
        let navigationOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--navigation-only"
        let uxOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--ux-review-only"
        let firstPassOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--first-pass-only"
        let dayHeaderOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--day-header-only"
        let weekOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--week-only"
        let dockOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--dock-only"
        let profileOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--profile-only"
        let trendsOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--trends-only"
        guard CommandLine.arguments.count == 2 || learnOnly || autosaveOnly || setTypesOnly || uxOnly || navigationOnly || firstPassOnly || weekOnly || dayHeaderOnly || trendsOnly || profileOnly || dockOnly else {
            print("Usage: swift run senda-preview [--learn-only | --autosave-only | --set-types-only | --ux-review-only | --navigation-only | --first-pass-only | --week-only | --day-header-only | --trends-only | --profile-only | --dock-only] /absolute/output/directory")
            return
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[learnOnly || autosaveOnly || setTypesOnly || uxOnly || navigationOnly || firstPassOnly || weekOnly || dayHeaderOnly || trendsOnly || profileOnly || dockOnly ? 2 : 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        if dockOnly {
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: SampleJournal.makeWeek(relativeTo: Date())), isSample: true)
            for section in TrainingSection.allCases {
                guard model.selectSection(section) else { throw CocoaError(.coderInvalidValue) }
                let name = section.rawValue.lowercased()
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-dock-\(name).png"))
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-dock-\(name)-compact.png"), width: 320, height: 568)
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-dock-\(name)-accessibility.png"), width: 320, height: 568, textSize: .accessibility5)
            }
            print("Rendered all four bottom-bar selections at regular, compact and Largest Text sizes to \(directory.path).")
            return
        }
        if profileOnly {
            try renderProfileRefinementStates(to: directory)
            try renderBackupStates(to: directory, date: Date())
            print("Rendered Profile, details, units, backup and restore review states to \(directory.path).")
            return
        }
        if trendsOnly {
            try renderTrendsStates(to: directory, date: Date())
            print("Rendered Trends comparison, records, compact, Larger Text and empty states to \(directory.path).")
            return
        }
        if dayHeaderOnly {
            try renderDayHeaderStates(to: directory)
            print("Rendered day headers at standard, compact and Larger Text sizes to \(directory.path).")
            return
        }
        if weekOnly {
            let date = Date()
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: SampleJournal.makeWeek(relativeTo: date)), isSample: true, now: { date })
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week.png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-compact.png"), width: 320, height: 568)
            try renderWeekBoundaryStates(to: directory)
            print("Rendered week masthead, compact, Larger Text and calendar-boundary states to \(directory.path).")
            return
        }
        if firstPassOnly {
            try renderUXReviewStates(to: directory)
            try renderTrendsStates(to: directory, date: Date())
            try renderFirstPassHistoryStates(to: directory)
            print("Rendered first-pass workout, Trends and history states to \(directory.path).")
            return
        }
        if navigationOnly {
            let date = Date()
            try renderPickerStates(to: directory, date: date)
            try renderTrendsStates(to: directory, date: date)
            try renderProfileCraftStates(to: directory, date: date)
            try renderProgressStates(to: directory, date: date)
            try renderBackupStates(to: directory, date: date)
            print("Rendered picker, Trends and Profile states to \(directory.path).")
            return
        }
        if uxOnly {
            try renderUXReviewStates(to: directory)
            print("Rendered workout UX review states to \(directory.path).")
            return
        }
        if setTypesOnly {
            try renderSetTypeStates(to: directory)
            print("Rendered set type states to \(directory.path).")
            return
        }
        if autosaveOnly {
            try renderAutomaticSavingStates(to: directory)
            print("Rendered automatic saving states to \(directory.path).")
            return
        }
        if learnOnly {
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true)
            _ = model.selectSection(.learn)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn.png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-compact.png"), width: 320, height: 568)
            try renderLearnVisualStates(to: directory)
            print("Rendered Learn visual states to \(directory.path).")
            return
        }
        let date = Date()
        try renderPickerStates(to: directory, date: date)
        try renderUXReviewStates(to: directory)
        try renderSetTypeStates(to: directory)
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: SampleJournal.makeWeek(relativeTo: date)), isSample: true, now: { date })
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-compact.png"), width: 320, height: 568)
        guard model.changeWeek(-1) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-away.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-away-compact.png"), width: 320, height: 568)
        guard model.showCurrentWeek() else { throw CocoaError(.coderInvalidValue) }
        try renderWeekBoundaryStates(to: directory)
        _ = model.openDay(model.today)
        for id in ["cable-row", "lat-pulldown", "overhead-press", "lateral-raise", "biceps-curl", "triceps-extension", "push-up"] {
            _ = model.addExercise(id)
        }
        _ = model.selectExercise("bench")
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-day.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-draft.png"))
        try render(TrainingDayExerciseList(model: model, day: model.today, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-day-exercises.png"))
        try render(TrainingDayExerciseList(model: model, day: model.today, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-day-exercises-compact.png"), width: 320, height: 568)
        try render(TrainingExercisePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-picker.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-compact.png"), width: 320, height: 568)
        _ = model.repeatLastSet()
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-exception.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-recorded.png"))
        if let row = model.rows.dropFirst(2).first {
            _ = model.selectInput(row.id, field: .weight)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-dial.png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-dial-compact.png"), width: 320, height: 568)
        }
        _ = model.finishEditing()
        _ = model.selectSection(.profile)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-compact.png"), width: 320, height: 568)
        _ = model.selectSection(.learn)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-compact.png"), width: 320, height: 568)
        model.learningExerciseID = "bench"
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-form-guide.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-form-guide-compact.png"), width: 320, height: 568)
        let empty = try TrainingNotebookModel(repository: MemoryJournalRepository())
        _ = empty.selectSection(.profile)
        try render(TrainingNotebookView(model: empty), to: directory.appendingPathComponent("senda-profile-empty.png"))
        try renderPremiumStates(to: directory, date: date)
        try renderDailyLoggingStates(to: directory, date: date)
        try renderBackupStates(to: directory, date: date)
        try renderProgressStates(to: directory, date: date)
        try renderTrendsStates(to: directory, date: date)
        try renderProfileCraftStates(to: directory, date: date)
        try renderTrainingPlanStates(to: directory, date: date)
        try renderLearnVisualStates(to: directory)
        try renderAutomaticSavingStates(to: directory)
        print("Rendered actual SwiftUI screens and premium logging states to \(directory.path).")
    }

    private static func logPreviewSet(_ model: TrainingNotebookModel, rowID: UUID, weight: String, reps: String) throws {
        guard model.selectInput(rowID, field: .weight), let weightFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput(weight, focus: weightFocus)
        guard model.selectInput(rowID, field: .reps), let repsFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput(reps, focus: repsFocus)
        guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
    }

    private static func renderUXReviewStates(to directory: URL) throws {
        let working = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true)
        guard working.openToday(), working.addExercise("bench"),
              working.setPlan(ExercisePlan(workingSets: 4, minimumReps: 8, maximumReps: 12), for: "bench") else { throw CocoaError(.coderInvalidValue) }
        for (index, reps) in ["10", "9", "8", "8"].enumerated() {
            if index > 0, !working.newSet() { throw CocoaError(.coderInvalidValue) }
            guard let row = working.rows.last else { throw CocoaError(.coderInvalidValue) }
            try logPreviewSet(working, rowID: row.id, weight: "135", reps: reps)
        }
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-working.png"))
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-working-full.png"), height: 1250)
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-working-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-working-compact-full.png"), width: 320, height: 1450)
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-working-accessibility.png"), width: 320, height: 1800, textSize: .accessibility3)
        let store = AutosavePreviewRepository()
        let drop = try TrainingNotebookModel(repository: store, isSample: true)
        guard drop.openToday(), drop.addExercise("bench"), let first = drop.rows.first,
              drop.setPlan(ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12), for: "bench") else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(drop, rowID: first.id, weight: "135", reps: "10")
        guard drop.newSet(), let start = drop.rows.last, drop.setKind(.dropSet, for: start.id) else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(drop, rowID: start.id, weight: "135", reps: "8")
        for (weight, reps) in [("105", "8"), ("75", "10")] {
            guard drop.addDropStage(to: start.id), let stage = drop.focus?.rowID else { throw CocoaError(.coderInvalidValue) }
            try logPreviewSet(drop, rowID: stage, weight: weight, reps: reps)
        }
        guard drop.setEntries.count == 2, drop.summary(for: drop.today).setCount == 2 else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop.png"), height: 1350)
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-compact.png"), width: 320, height: 1650)
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-accessibility.png"), width: 320, height: 2250, textSize: .accessibility3)
        guard let last = drop.rows.last, drop.selectInput(last.id, field: .reps) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-editing.png"))
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-editing-compact.png"), width: 320, height: 568)
        guard drop.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        drop.progressExerciseID = "bench"
        try render(TrainingProgressView(model: drop, initialSessionDay: drop.today, close: {}),
                   to: directory.appendingPathComponent("senda-ux-drop-history.png"), height: 1250)
        try render(TrainingProgressView(model: drop, initialSessionDay: drop.today, close: {}),
                   to: directory.appendingPathComponent("senda-ux-drop-history-compact.png"), width: 320, height: 1550)
        guard drop.repeatLastSet(), drop.setEntries.count == 3, drop.undoChange(), drop.setEntries.count == 2 else { throw CocoaError(.coderInvalidValue) }
        guard drop.deleteSet(start.id), drop.setEntries.count == 1, drop.undoChange(), drop.setEntries.count == 2 else { throw CocoaError(.coderInvalidValue) }
        store.reject = true
        guard !drop.addDropStage(to: start.id) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-failed-phone.png"))
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-failed-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-failed.png"), height: 1450)
        store.reject = false
        guard drop.retrySave(), let blank = drop.focus?.rowID else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(drop, rowID: blank, weight: "55", reps: "12")
        try render(TrainingNotebookView(model: drop), to: directory.appendingPathComponent("senda-ux-drop-retried.png"), height: 1450)
        _ = working.selectSection(.learn); working.learningExerciseID = "bench"
        try render(TrainingNotebookView(model: working), to: directory.appendingPathComponent("senda-ux-learn.png"))
    }

    private static func renderFirstPassHistoryStates(to directory: URL) throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true)
        let oldDay = try model.today.adding(days: -200)
        guard model.openDay(oldDay), model.addExercise("bench"), let first = model.rows.first else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(model, rowID: first.id, weight: "135", reps: "10")
        guard model.newSet(), let second = model.rows.last else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(model, rowID: second.id, weight: "115", reps: "12")
        guard let record = model.personalRecords.first, model.openToday(), model.addExercise("squat"),
              let current = model.rows.first else { throw CocoaError(.coderInvalidValue) }
        try logPreviewSet(model, rowID: current.id, weight: "95", reps: "8")
        guard model.openProgress(for: "bench") else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-history-all-dates.png"), width: 320, height: 900)
        guard model.openPersonalRecord(record), model.selectedDay == model.today, model.exercise?.id == "squat" else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-history-pr-compact.png"), width: 320, height: 568)
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-history-pr-accessibility.png"), width: 320, height: 1250, textSize: .accessibility3)
        guard model.editRecordedSession(for: "bench", on: oldDay, setID: record.reference.setID) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-history-edit-return-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-history-edit-return.png"))
        guard model.returnToWorkoutFromHistory(), model.selectedDay == model.today, model.exercise?.id == "squat" else { throw CocoaError(.coderInvalidValue) }
    }

    private static func renderPickerStates(to directory: URL, date: Date) throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
        let yesterday = try model.today.adding(days: -1)
        guard model.openDay(yesterday) else { throw CocoaError(.coderInvalidValue) }
        for (id, weight) in [("bench", "135"), ("cable-row", "90")] {
            guard model.addExercise(id), let row = model.rows.first else { throw CocoaError(.coderInvalidValue) }
            try logPreviewSet(model, rowID: row.id, weight: weight, reps: "10")
        }
        guard model.openToday(), model.addExercise("squat") else { throw CocoaError(.coderInvalidValue) }
        let picker = TrainingExercisePicker(model: model, close: {})
        try render(picker, to: directory.appendingPathComponent("senda-picker-refined.png"))
        try render(picker, to: directory.appendingPathComponent("senda-picker-refined-compact.png"), width: 320, height: 568)
        try render(picker, to: directory.appendingPathComponent("senda-picker-refined-accessibility.png"), width: 320, height: 568, textSize: .accessibility3)
        try render(picker, to: directory.appendingPathComponent("senda-picker-refined-accessibility-full.png"), width: 320, height: 1500, textSize: .accessibility3)
        let filtered = TrainingExercisePicker(model: model, search: "", group: .back, equipment: .cable, close: {})
        try render(filtered, to: directory.appendingPathComponent("senda-picker-filtered.png"), width: 320, height: 568)
        let filters = TrainingExercisePicker(model: model, search: "", group: .back, equipment: .cable, showsFilters: true, close: {})
        try render(filters, to: directory.appendingPathComponent("senda-picker-filters.png"), width: 320, height: 568)
        try render(filters, to: directory.appendingPathComponent("senda-picker-filters-accessibility.png"), width: 320, height: 1500, textSize: .accessibility3)
        let empty = TrainingExercisePicker(model: model, search: "Incline", group: .back, equipment: .cable, close: {})
        try render(empty, to: directory.appendingPathComponent("senda-picker-no-matches.png"), width: 320, height: 568)
        let selected = TrainingExercisePicker(model: model, search: "", selectedIDs: ["cable-row", "bench"], close: {})
        try render(selected, to: directory.appendingPathComponent("senda-picker-multiple.png"), width: 320, height: 568)
        try render(selected, to: directory.appendingPathComponent("senda-picker-multiple-accessibility.png"), width: 320, height: 1500, textSize: .accessibility3)
        try render(TrainingWorkoutReusePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-picker-reuse-compact.png"), width: 320, height: 568)
        guard model.selectSection(.learn) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-hierarchy-compact.png"), width: 320, height: 568)
    }

    private static func renderSetTypeStates(to directory: URL) throws {
        let store = AutosavePreviewRepository()
        let model = try TrainingNotebookModel(repository: store, isSample: true)
        guard model.openToday(), model.addExercise("bench"),
              model.setPlan(ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12), for: "bench") else {
            throw CocoaError(.coderInvalidValue)
        }
        let examples: [(TrainingSetKind, String, String)] = [(.working, "135", "10"), (.warmup, "45", "12"), (.dropSet, "95", "15")]
        for (index, example) in examples.enumerated() {
            if index > 0, !model.newSet() { throw CocoaError(.coderInvalidValue) }
            guard let row = model.rows.last, model.setKind(example.0, for: row.id),
                  model.selectInput(row.id, field: .weight), let weight = model.focus else { throw CocoaError(.coderInvalidValue) }
            model.typeInput(example.1, focus: weight)
            guard model.selectInput(row.id, field: .reps), let reps = model.focus else { throw CocoaError(.coderInvalidValue) }
            model.typeInput(example.2, focus: reps)
            guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
            if index == 0 {
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-type-default.png"))
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-type-default-compact.png"), width: 320, height: 1000)
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-type-default-accessibility.png"), width: 320, height: 1600, textSize: .accessibility3)
            }
        }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-types.png"), height: 1550)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-types-compact.png"), width: 320, height: 2450)
        guard let row = model.rows.first else { throw CocoaError(.coderInvalidValue) }
        let picker = TrainingSetTypePicker(model: model, day: model.today, exerciseID: "bench", rowID: row.id, close: {})
        try render(picker, to: directory.appendingPathComponent("senda-set-type-picker.png"), height: 900)
        try render(picker, to: directory.appendingPathComponent("senda-set-type-picker-compact.png"), width: 320, height: 1050)
        try render(picker, to: directory.appendingPathComponent("senda-set-type-picker-accessibility.png"), width: 320, height: 1600, textSize: .accessibility3)
        store.reject = true
        guard !model.setKind(.warmup, for: row.id), model.rows.first?.kind == .working else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-type-failed.png"), height: 1750)
        store.reject = false
        guard model.retrySave(), model.rows.first?.kind == .warmup else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-set-type-retried.png"), height: 1550)
    }

    private static func renderAutomaticSavingStates(to directory: URL) throws {
        let store = AutosavePreviewRepository()
        let model = try TrainingNotebookModel(repository: store, isSample: true)
        guard model.openToday(), model.addExercise("bench"), let row = model.rows.first,
              model.setPlan(ExercisePlan(workingSets: 3, minimumReps: 8, maximumReps: 12), for: "bench"),
              model.selectInput(row.id, field: .weight), let weight = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput("135", focus: weight)
        guard model.selectInput(row.id, field: .reps), let reps = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput("10", focus: reps)
        guard model.summary(for: model.today).setCount == 1,
              try store.loadSnapshot().journal.batches.flatMap(\.sets).count == 1 else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-editing.png"), height: 1100)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-editing-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-editing-phone.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-editing-accessibility.png"), width: 320, height: 1550, textSize: .accessibility3)
        model.typeInput("", focus: reps)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-needs-value.png"), height: 1200)
        model.typeInput("12", focus: reps)
        store.reject = true
        model.typeInput("11", focus: reps)
        guard model.errorMessage != nil, model.rows.first?.reps == "11" else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-failed.png"), height: 1200)
        store.reject = false
        guard model.retrySave(), model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-saved.png"), height: 1100)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-autosave-saved-compact.png"), width: 320, height: 1100)
    }

    @MainActor private final class AutosavePreviewRepository: JournalRepository {
        private let memory = MemoryJournalRepository()
        var reject = false
        func loadSnapshot() throws -> JournalSnapshot { try memory.loadSnapshot() }
        func saveSnapshot(_ snapshot: JournalSnapshot) throws {
            if reject { throw CocoaError(.fileWriteNoPermission) }
            try memory.saveSnapshot(snapshot)
        }
    }

    private static func renderLearnVisualStates(to directory: URL) throws {
        let custom = Exercise(id: "custom-test", name: "Travel press", shortName: "Travel", startingWeight: 0)
        let repository = try MemoryJournalRepository(snapshot: JournalSnapshot(customExercises: [custom]))
        let model = try TrainingNotebookModel(repository: repository, isSample: true)
        _ = model.selectSection(.learn)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-accessibility.png"), width: 320, height: 568, textSize: .accessibility3)
        for (name, query) in [("search", "Bench"), ("empty", "zzzz-no-match"), ("custom-results", "press")] {
            model.learningQuery = query
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-\(name).png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-\(name)-compact.png"), width: 320, height: 568)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-learn-\(name)-accessibility.png"), width: 320, height: 1100, textSize: .accessibility3)
        }
        if let frame = ExerciseFormVisual.guide(for: "bench")?.frames.first {
            try render(ExerciseFormPositionView(frame: frame, close: {}), to: directory.appendingPathComponent("senda-learn-position.png"))
            try render(ExerciseFormPositionView(frame: frame, close: {}), to: directory.appendingPathComponent("senda-learn-position-accessibility.png"), width: 320, height: 1100, textSize: .accessibility3)
        }
        for id in ["bench", "squat", "deadlift", "pull-up", "lateral-raise", "hip-thrust", "leg-extension"] {
            guard let exercise = Exercise.catalog.first(where: { $0.id == id }) else { throw CocoaError(.coderInvalidValue) }
            let detail = ScrollView { ExerciseLearningDetail(exercise: exercise).padding(24) }
                .background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255))
            try render(detail, to: directory.appendingPathComponent("senda-learn-\(id)-full.png"), height: 2300)
            if id == "bench" {
                try render(detail, to: directory.appendingPathComponent("senda-learn-bench-compact-full.png"), width: 320, height: 2500)
                try render(detail, to: directory.appendingPathComponent("senda-learn-bench-accessibility.png"), width: 320, height: 3300, textSize: .accessibility3)
            }
        }
        try render(ScrollView { ExerciseLearningDetail(exercise: custom).padding(24) }
            .background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)),
            to: directory.appendingPathComponent("senda-learn-custom.png"), width: 320, height: 568)
    }

    private static func renderDayHeaderStates(to directory: URL) throws {
        let today = try TrainingDay("2026-11-10")
        let date = today.date(in: Calendar(identifier: .gregorian))
        for (name, rawDay) in [("today", "2026-11-10"), ("past", "2026-11-09"), ("future", "2026-11-11")] {
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
            guard model.openDay(try TrainingDay(rawDay)) else { throw CocoaError(.coderInvalidValue) }
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-day-header-\(name).png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-day-header-\(name)-compact.png"), width: 320, height: 568)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-day-header-\(name)-accessibility.png"), width: 320, height: 900, textSize: .accessibility3)
        }
    }

    private static func renderWeekBoundaryStates(to directory: URL) throws {
        for (name, rawDay) in [("split-month", "2026-11-30"), ("split-year", "2026-12-28")] {
            let day = try TrainingDay(rawDay)
            let date = day.date(in: Calendar(identifier: .gregorian))
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-\(name).png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-\(name)-compact.png"), width: 320, height: 568)
        }
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-accessibility-compact.png"), width: 320, height: 568, textSize: .accessibility3)
    }

    private static func renderPremiumStates(to directory: URL, date: Date) throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
        guard model.openToday(), model.addExercise("bench"), let row = model.rows.first,
              model.selectInput(row.id, field: .weight), let weightFocus = model.focus else {
            throw CocoaError(.coderInvalidValue)
        }
        model.typeInput("135", focus: weightFocus)
        guard model.selectInput(row.id, field: .reps), let repsFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput("10", focus: repsFocus)
        guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-recorded-set.png"))
        guard model.selectInput(row.id, field: .weight), let correctionFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput("", focus: correctionFocus)
        guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-pending-correction.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-pending-correction-compact.png"), width: 320, height: 568)
        guard model.showWeek() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-week-unfinished.png"))
        guard model.openToday(), model.discardCorrection(row.id), model.newSet(), let newFocus = model.focus else {
            throw CocoaError(.coderInvalidValue)
        }
        model.typeInput("145", focus: newFocus)
        guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-unfinished-set.png"))
        guard let unfinished = model.rows.last, model.selectInput(unfinished.id, field: .weight) else {
            throw CocoaError(.coderInvalidValue)
        }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-editor-accessibility.png"), textSize: .accessibility3)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-editor-accessibility-compact.png"), width: 320, height: 568, textSize: .accessibility3)
        if let largeFocus = model.focus {
            guard model.setInputWeight(200_000, focus: largeFocus) else { throw CocoaError(.coderInvalidValue) }
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-editor-accessibility-largest.png"), width: 320, height: 568, textSize: .accessibility5)
        }
        guard model.openDay(try model.today.adding(days: -1)) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-historical-day.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-historical-day-compact.png"), width: 320, height: 568)
    }

    private static func renderDailyLoggingStates(to directory: URL, date: Date) throws {
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
        let previousDay = try model.today.adding(days: -1)
        guard model.openDay(previousDay) else { throw CocoaError(.coderInvalidValue) }
        for (id, weight, reps) in [("bench", "135", "10"), ("cable-row", "90", "8")] {
            guard model.addExercise(id), let row = model.rows.first,
                  model.selectInput(row.id, field: .weight), let weightFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
            model.typeInput(weight, focus: weightFocus)
            guard model.selectInput(row.id, field: .reps), let repsFocus = model.focus else { throw CocoaError(.coderInvalidValue) }
            model.typeInput(reps, focus: repsFocus)
            guard model.finishEditing() else { throw CocoaError(.coderInvalidValue) }
        }
        guard model.openToday() else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-reuse-entry.png"))
        try render(TrainingWorkoutReusePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-workout-reuse.png"))
        try render(TrainingWorkoutReusePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-workout-reuse-compact.png"), width: 320, height: 568)
        guard model.reuseWorkout(from: previousDay) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingExercisePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-exercise-picker-recent.png"))
        try render(TrainingExercisePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-exercise-picker-recent-compact.png"), width: 320, height: 568)
        try render(TrainingExercisePicker(model: model, close: {}), to: directory.appendingPathComponent("senda-exercise-picker-accessibility.png"), width: 320, height: 568, textSize: .accessibility3)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-next-set-values.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-next-set-values-compact.png"), width: 320, height: 568)
        guard let row = model.rows.first, model.prefillSet(row.id) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-prefilled-draft.png"))
        guard model.openDay(previousDay), model.removeExercise("bench") else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingDayExerciseList(model: model, day: previousDay, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-hidden-exercises.png"))
        try render(TrainingDayExerciseList(model: model, day: previousDay, close: {}, add: {}),
                   to: directory.appendingPathComponent("senda-hidden-exercises-compact.png"), width: 320, height: 568)
    }

    private static func renderBackupStates(to directory: URL, date: Date) throws {
        let profile = MemoryProfileRepository()
        try profile.save(ProfileDetails(name: "Jae"))
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: SampleJournal.makeWeek(relativeTo: date)),
                                              isSample: true, now: { date }, profileRepository: profile)
        guard model.openToday(), model.addExercise("bench"), let row = model.rows.last,
              model.selectInput(row.id, field: .weight), let focus = model.focus else { throw CocoaError(.coderInvalidValue) }
        model.typeInput("31.", focus: focus)
        guard model.selectSection(.profile) else { throw CocoaError(.coderInvalidValue) }
        let archive = try NotebookBackupCodec.decode(model.backupData())
        try render(TrainingSettingsView(model: model, close: {}), to: directory.appendingPathComponent("senda-settings-backup.png"))
        try render(TrainingSettingsView(model: model, close: {}), to: directory.appendingPathComponent("senda-settings-backup-compact.png"), width: 320, height: 568)
        try render(TrainingSettingsView(model: model, destination: .backup, close: {}), to: directory.appendingPathComponent("senda-backup-direct-compact.png"), width: 320, height: 568)
        try render(TrainingSettingsView(model: model, destination: .backup, close: {}), to: directory.appendingPathComponent("senda-backup-direct-accessibility.png"), width: 320, height: 1300, textSize: .accessibility3)
        try render(ProfileDetailsView(profile: model.profile, close: {}), to: directory.appendingPathComponent("senda-profile-details.png"))
        try render(ProfileDetailsView(profile: model.profile, close: {}), to: directory.appendingPathComponent("senda-profile-details-compact.png"), width: 320, height: 568)
        try render(ProfileDetailsView(profile: model.profile, close: {}), to: directory.appendingPathComponent("senda-profile-details-accessibility.png"), width: 320, height: 1300, textSize: .accessibility3)
        try render(ScrollView { NotebookRestorePreview(archive: archive).padding(24) }.background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)),
                   to: directory.appendingPathComponent("senda-backup-review.png"))
        try render(ScrollView { NotebookRestorePreview(archive: archive).padding(24) }.background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)),
                   to: directory.appendingPathComponent("senda-backup-review-compact.png"), width: 320, height: 568)
        try render(ScrollView { NotebookRestorePreview(archive: archive).padding(24) }.background(Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)),
                   to: directory.appendingPathComponent("senda-backup-review-accessibility.png"), width: 320, height: 1800, textSize: .accessibility3)
    }

    private static func renderProgressStates(to directory: URL, date: Date) throws {
        let today = TrainingDay(date)
        var journal = Journal()
        for (offset, load, reps) in [(77, 9500, 10), (63, 10500, 10), (42, 11500, 8), (21, 12500, 8), (7, 13500, 6), (0, 13500, 8)] {
            let day = try today.adding(days: -offset)
            _ = try journal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: load, reps: reps), SetValues(weight: load, reps: max(1, reps - 2))]), at: day.date())
            _ = try journal.record(DraftBatch(exerciseID: "push-up", sets: [SetValues(weight: 0, reps: reps + 10)]), at: day.date())
        }
        let oneDay = try today.adding(days: -2)
        _ = try journal.record(DraftBatch(exerciseID: "squat", sets: [SetValues(weight: 18500, reps: 5)]), at: oneDay.date())
        for (offset, load, reps) in [(14, 0, 8), (7, 2500, 5), (0, 0, 10)] {
            _ = try journal.record(DraftBatch(exerciseID: "pull-up", sets: [SetValues(weight: load, reps: reps)]), at: today.adding(days: -offset).date())
        }
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: journal), isSample: true, now: { date })
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-exercises.png"))
        model.progressExerciseID = "bench"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-bench.png"))
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-bench-compact.png"), width: 320, height: 568)
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-bench-full.png"), height: 2300)
        model.progressRange = .eightWeeks
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-eight-weeks.png"))
        model.progressRange = .twelveWeeks; model.progressExerciseID = "push-up"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-bodyweight.png"), height: 1600)
        model.progressExerciseID = "pull-up"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-added-weight.png"), height: 1600)
        model.progressExerciseID = "squat"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-one-day.png"), height: 1500)
        model.progressExerciseID = "deadlift"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-empty.png"), width: 320, height: 568)
        model.progressExerciseID = "bench"
        try render(TrainingProgressView(model: model, close: {}), to: directory.appendingPathComponent("senda-progress-accessibility-compact.png"), width: 320, height: 568, textSize: .accessibility3)
    }

    private static func renderTrendsStates(to directory: URL, date: Date) throws {
        let today = TrainingDay(date)
        // Sparse weeks, two kinds of improvements, a decrease, a tie, mixed
        // bodyweight loads, and a nonzero kilogram delta below display precision.
        let histories: [(String, [(Int, Int, Int)])] = [
            ("bench", [(77, 9500, 10), (63, 10500, 10), (42, 11500, 8), (21, 12500, 8), (7, 13500, 6), (0, 13500, 8)]),
            ("deadlift", [(14, 20500, 5), (7, 22500, 5), (0, 23500, 5)]),
            ("push-up", [(14, 0, 10), (7, 0, 12), (0, 0, 14)]),
            ("pull-up", [(14, 0, 5), (7, 2500, 5), (0, 0, 5)]),
            ("cable-row", [(14, 8000, 10), (7, 9000, 10), (5, 9000, 10), (0, 9000, 10)]),
            ("overhead-press", [(14, 9500, 8), (7, 10500, 8), (0, 11500, 6)]),
            ("biceps-curl", [(8, 2500, 8), (1, 2501, 8)])
        ]
        var journal = Journal()
        var bodyweightJournal = Journal()
        for (id, sessions) in histories {
            for (offset, weight, reps) in sessions {
                let recordedAt = try today.adding(days: -offset).date()
                var sets = [SetValues(weight: weight, reps: reps)]
                if id == "bench" { sets.append(SetValues(weight: weight, reps: max(1, reps - 2))) }
                let batch = DraftBatch(exerciseID: id, sets: sets)
                _ = try journal.record(batch, at: recordedAt)
                if id == "push-up" || id == "pull-up" {
                    _ = try bodyweightJournal.record(batch, at: recordedAt)
                }
            }
        }
        let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: journal),
            isSample: true, now: { date })
        guard model.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-trends.png"))
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-trends-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-trends-accessibility-compact.png"), width: 320, height: 568, textSize: .accessibility3)
        try render(TrainingTrendsView(model: model), to: directory.appendingPathComponent("senda-trends-full.png"), height: 2200)
        try render(TrainingTrendsView(model: model), to: directory.appendingPathComponent("senda-trends-full-compact.png"), width: 320, height: 2600)
        model.progressRange = .eightWeeks
        try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-trends-eight-weeks.png"))
        model.progressRange = .twelveWeeks
        guard model.setPreferredUnit(.kilograms) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingTrendsView(model: model), to: directory.appendingPathComponent("senda-trends-kilograms-full.png"), height: 2300)

        let bodyweight = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: bodyweightJournal),
            isSample: true, now: { date })
        guard bodyweight.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingTrendsView(model: bodyweight), to: directory.appendingPathComponent("senda-trends-bodyweight-full.png"), height: 1700)
        try render(TrainingTrendsView(model: bodyweight, showsAllTimeRecords: true), to: directory.appendingPathComponent("senda-records-bodyweight.png"), width: 320, height: 1900)

        let empty = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
        guard empty.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: empty), to: directory.appendingPathComponent("senda-trends-empty-compact.png"), width: 320, height: 568)

        var oneDayJournal = Journal()
        _ = try oneDayJournal.record(DraftBatch(exerciseID: "squat", sets: [
            SetValues(weight: 18500, reps: 5), SetValues(weight: 17500, reps: 8)
        ]), at: today.date())
        let oneDay = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: oneDayJournal),
            isSample: true, now: { date })
        guard oneDay.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: oneDay), to: directory.appendingPathComponent("senda-trends-one-day-compact.png"), width: 320, height: 568)
        try render(TrainingTrendsView(model: oneDay), to: directory.appendingPathComponent("senda-trends-one-day-full.png"), height: 1200)
        try render(TrainingTrendsView(model: oneDay), to: directory.appendingPathComponent("senda-trends-accessibility-full.png"), width: 320, height: 1400, textSize: .accessibility3)

        var comparisonJournal = Journal()
        for (offset, reps) in [(7, 6), (0, 8)] {
            _ = try comparisonJournal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13500, reps: reps)]),
                at: today.adding(days: -offset).date())
        }
        let comparison = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: comparisonJournal),
            isSample: true, now: { date })
        guard comparison.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingTrendsView(model: comparison),
            to: directory.appendingPathComponent("senda-trends-comparison-accessibility-full.png"),
            width: 320, height: 1600, textSize: .accessibility3)

        var oldJournal = Journal()
        _ = try oldJournal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13500, reps: 8)]),
            at: today.adding(days: -100).date())
        let oldHistory = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: oldJournal),
            isSample: true, now: { date })
        guard oldHistory.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingNotebookView(model: oldHistory), to: directory.appendingPathComponent("senda-trends-old-history-compact.png"), width: 320, height: 568)
        try render(TrainingTrendsView(model: bodyweight, showsAllTimeRecords: false, strengthExerciseID: "push-up"),
            to: directory.appendingPathComponent("senda-strength-bodyweight-reps.png"), height: 1300)
        try render(TrainingTrendsView(model: bodyweight, showsAllTimeRecords: false, strengthExerciseID: "pull-up"),
            to: directory.appendingPathComponent("senda-strength-added-weight.png"), height: 1300)
        var fallbackJournal = Journal()
        _ = try fallbackJournal.record(DraftBatch(exerciseID: "bench", sets: [SetValues(weight: 13500, reps: 8)]), at: today.adding(days: -77).date())
        _ = try fallbackJournal.record(DraftBatch(exerciseID: "deadlift", sets: [SetValues(weight: 22500, reps: 5)]), at: today.date())
        let fallback = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: fallbackJournal), isSample: true, now: { date })
        fallback.progressRange = .eightWeeks
        try render(TrainingTrendsView(model: fallback, showsAllTimeRecords: false, strengthExerciseID: "bench"),
            to: directory.appendingPathComponent("senda-strength-range-fallback.png"), width: 320, height: 1200)
        let longExercise = Exercise(id: "custom-strength-long", name: "Single-arm alternating dumbbell overhead press", shortName: "Single-arm alternating dumbbell overhead press", startingWeight: 2000)
        var longJournal = Journal()
        for (offset, weight) in [(7, 2000), (0, 2500)] {
            _ = try longJournal.record(DraftBatch(exerciseID: longExercise.id, sets: [SetValues(weight: weight, reps: 8)]), at: today.adding(days: -offset).date())
        }
        let longRepository = try MemoryJournalRepository(snapshot: JournalSnapshot(journal: longJournal, customExercises: [longExercise]))
        let longModel = try TrainingNotebookModel(repository: longRepository, isSample: true, now: { date })
        try render(TrainingTrendsView(model: longModel), to: directory.appendingPathComponent("senda-strength-long-name.png"), width: 320, height: 1300)
        try render(TrainingTrendsView(model: longModel), to: directory.appendingPathComponent("senda-strength-long-name-accessibility.png"), width: 320, height: 1800, textSize: .accessibility3)

    }

    private static func renderProfileRefinementStates(to directory: URL) throws {
        for (state, name) in [("empty", ""), ("named", "Jae"), ("long-name", String(repeating: "Alexandra ", count: 7) + "Alexandria")] {
            let profile = MemoryProfileRepository()
            try profile.save(ProfileDetails(name: name))
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, profileRepository: profile)
            guard model.selectSection(.profile) else { throw CocoaError(.coderInvalidValue) }
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(state).png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(state)-compact.png"), width: 320, height: 568)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(state)-accessibility.png"), width: 320, height: 1300, textSize: .accessibility3)
            if state == "named" {
                guard model.setPreferredUnit(.kilograms) else { throw CocoaError(.coderInvalidValue) }
                try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-kilograms.png"))
                try render(TrainingSettingsView(model: model, close: {}), to: directory.appendingPathComponent("senda-profile-units.png"))
                try render(TrainingSettingsView(model: model, close: {}), to: directory.appendingPathComponent("senda-profile-units-compact.png"), width: 320, height: 568)
                try render(TrainingSettingsView(model: model, close: {}), to: directory.appendingPathComponent("senda-profile-units-accessibility.png"), width: 320, height: 1300, textSize: .accessibility3)
            }
            if state == "long-name" {
                try render(ProfileDetailsView(profile: model.profile, close: {}), to: directory.appendingPathComponent("senda-profile-details-long-name.png"), width: 320, height: 568)
            }
        }
    }

    private static func renderProfileCraftStates(to directory: URL, date: Date) throws {
        for (name, loads) in [("complete", [13500, 22500, 18500]), ("zero", [0, 0, 0])] {
            var journal = Journal()
            for (id, load) in zip(["bench", "deadlift", "squat"], loads) {
                _ = try journal.record(DraftBatch(exerciseID: id, sets: [SetValues(weight: load, reps: 5)]), at: date)
            }
            let model = try TrainingNotebookModel(repository: MemoryJournalRepository(journal: journal), isSample: true, now: { date })
            guard model.selectSection(.profile) else { throw CocoaError(.coderInvalidValue) }
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(name).png"))
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(name)-compact.png"), width: 320, height: 568)
            try render(TrainingNotebookView(model: model), to: directory.appendingPathComponent("senda-profile-\(name)-accessibility.png"), width: 320, height: 1300, textSize: .accessibility3)
            guard model.selectSection(.trends) else { throw CocoaError(.coderInvalidValue) }
            try render(TrainingTrendsView(model: model, showsAllTimeRecords: true), to: directory.appendingPathComponent("senda-records-\(name).png"), width: 320, height: 2200)
            if name == "complete" {
                try render(TrainingTrendsView(model: model, showsAllTimeRecords: true), to: directory.appendingPathComponent("senda-records-accessibility.png"), width: 320, height: 3800, textSize: .accessibility3)
            }
        }
        let empty = try TrainingNotebookModel(repository: MemoryJournalRepository(), isSample: true, now: { date })
        try render(TrainingProgressView(model: empty, close: {}), to: directory.appendingPathComponent("senda-progress-no-records.png"), width: 320, height: 568)
    }

    private static func renderTrainingPlanStates(to directory: URL, date: Date) throws {
        let ready = try trainingPlanModel(date: date)
        try render(TrainingNotebookView(model: ready), to: directory.appendingPathComponent("senda-plan-day.png"))
        try render(TrainingNotebookView(model: ready), to: directory.appendingPathComponent("senda-plan-day-compact.png"), width: 320, height: 568)
        try render(TrainingNotebookView(model: ready), to: directory.appendingPathComponent("senda-plan-day-full.png"), height: 1400)
        try render(TrainingNotebookView(model: ready), to: directory.appendingPathComponent("senda-plan-day-accessibility-full.png"), width: 320, height: 2000, textSize: .accessibility3)

        try render(TrainingPlanEditor(model: ready, day: ready.today, exerciseID: "bench", close: {}),
                   to: directory.appendingPathComponent("senda-plan-editor.png"))
        try render(TrainingPlanEditor(model: ready, day: ready.today, exerciseID: "bench", close: {}),
                   to: directory.appendingPathComponent("senda-plan-editor-compact.png"), width: 320, height: 568)
        try render(TrainingPlanEditor(model: ready, day: ready.today, exerciseID: "bench", close: {}),
                   to: directory.appendingPathComponent("senda-plan-editor-accessibility.png"), width: 320, height: 1200, textSize: .accessibility3)
        guard let working = ready.rows.first(where: { $0.kind == .working }) else { throw CocoaError(.coderInvalidValue) }
        try render(TrainingSetDetailsEditor(model: ready, day: ready.today, exerciseID: "bench", rowID: working.id, close: {}),
                   to: directory.appendingPathComponent("senda-set-details-editor.png"))
        try render(TrainingSetDetailsEditor(model: ready, day: ready.today, exerciseID: "bench", rowID: working.id, close: {}),
                   to: directory.appendingPathComponent("senda-set-details-editor-compact.png"), width: 320, height: 568)
        try render(TrainingSetDetailsEditor(model: ready, day: ready.today, exerciseID: "bench", rowID: working.id, close: {}),
                   to: directory.appendingPathComponent("senda-set-details-editor-accessibility.png"), width: 320, height: 1400, textSize: .accessibility3)

        let buildReps = try trainingPlanModel(date: date, latestReps: [10, 9], latestReserve: 3)
        try render(TrainingNotebookView(model: buildReps), to: directory.appendingPathComponent("senda-next-build-reps.png"), height: 1400)
        let missingEffort = try trainingPlanModel(date: date, latestReserve: nil)
        try render(TrainingNotebookView(model: missingEffort), to: directory.appendingPathComponent("senda-next-missing-effort.png"), height: 1400)
        let unknownType = try trainingPlanModel(date: date, unknownKind: true)
        try render(TrainingNotebookView(model: unknownType), to: directory.appendingPathComponent("senda-next-unknown-type.png"), height: 1400)
        let incomplete = try trainingPlanModel(date: date, latestReps: [10])
        try render(TrainingNotebookView(model: incomplete), to: directory.appendingPathComponent("senda-next-incomplete.png"), height: 1400)
        let bodyweight = try trainingPlanModel(date: date, exerciseID: "push-up")
        try render(TrainingNotebookView(model: bodyweight), to: directory.appendingPathComponent("senda-next-bodyweight.png"), height: 1400)
        let noPlan = try trainingPlanModel(date: date, includePlan: false)
        try render(TrainingPlanEditor(model: noPlan, day: noPlan.today, exerciseID: "bench", close: {}),
                   to: directory.appendingPathComponent("senda-plan-editor-new-compact.png"), width: 320, height: 568)
    }

    /// Seed performed values and their saved day links independently of the plan targets.
    private static func trainingPlanModel(date: Date, exerciseID: String = "bench", latestReps: [Int] = [12, 12],
                                          latestReserve: Int? = 2, unknownKind: Bool = false,
                                          includePlan: Bool = true) throws -> TrainingNotebookModel {
        let calendar = Calendar.current
        let today = TrainingDay(date, calendar: calendar)
        let previous = try today.adding(days: -7)
        let plan = ExercisePlan(workingSets: 2, minimumReps: 8, maximumReps: 12)
        let bodyweight = exerciseID == "push-up"
        var journal = Journal()
        var days: [String: DayWorkout] = [:]
        for day in [previous, today] {
            let reps = day == today ? latestReps : [12, 12]
            let values = [SetValues(weight: bodyweight ? 0 : 4500, reps: 10)] +
                reps.map { SetValues(weight: bodyweight ? 0 : 13500, reps: $0) }
            let batch = try journal.record(DraftBatch(exerciseID: exerciseID, sets: values), at: day.date(in: calendar))
            let rows = batch.sets.enumerated().map { position, performed in
                var row = TrainingRow(set: performed, unit: .pounds)
                row.kind = unknownKind ? nil : position == 0 ? .warmup : .working
                row.repsInReserve = position == 0 ? nil : day == today ? latestReserve : 2
                return row
            }
            days[day.rawValue] = DayWorkout(exerciseIDs: [exerciseID], selectedExerciseID: exerciseID,
                rows: [exerciseID: rows], unit: .pounds, exercisePlans: includePlan ? [exerciseID: plan] : nil)
        }
        let workspace = TrainingWorkspace(visibleWeek: try today.week()[0], selectedDay: today, days: days)
        let snapshot = try JournalSnapshot(journal: journal, training: workspace).validated()
        return try TrainingNotebookModel(repository: MemoryJournalRepository(snapshot: snapshot), isSample: true,
                                         calendar: calendar, now: { date })
    }

    private static func openLivePreview() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("senda-weekly-live-preview/journal.json")
        let repository = FileJournalRepository(url: url)
        if !FileManager.default.fileExists(atPath: url.path) {
            try repository.save(SampleJournal.makeWeek())
        }
        let profileURL = url.deletingLastPathComponent().appendingPathComponent("profile.json")
        let session = TrainingSession(repository: repository, isSample: true,
            profileRepository: FileProfileRepository(url: profileURL),
            restoreStore: FileNotebookRestoreStore(journalURL: url, profileURL: profileURL))
        let host = NSHostingView(rootView: TrainingSessionView(session: session)
            .environment(\.colorScheme, .light)
            .frame(minWidth: 320, minHeight: 568))
        let height = max(640, min(820, (NSScreen.main?.visibleFrame.height ?? 890) - 70))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 393, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Senda — Live preview"
        window.contentMinSize = NSSize(width: 320, height: 568)
        window.contentView = host
        window.isReleasedWhenClosed = false
        liveWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        FileHandle.standardOutput.write(Data("Senda live preview visible: \(window.isVisible)\n".utf8))
        NSApp.run()
    }

    private static func render<Content: View>(_ content: Content, to url: URL, width: CGFloat = 393, height: CGFloat = 820, textSize: DynamicTypeSize = .large) throws {
        let view = content
            .environment(\.dynamicTypeSize, textSize)
            .frame(width: width, height: height)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
        // ImageRenderer omits platform-backed ScrollView/TextField content. Host the
        // real view in an off-screen window so those controls are captured, too.
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: width, height: height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        // Let the 0.2-second focus scroll settle before capturing the view.
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
#else
@main struct SendaPreview {
    static func main() { print("Run this preview renderer on macOS.") }
}
#endif
