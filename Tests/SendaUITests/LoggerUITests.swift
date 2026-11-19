import CoreImage
import XCTest

final class LoggerUITests: XCTestCase {
    @MainActor
    func testBodyMeasurementsCanBeLoggedAndFoundInTrendsAfterRelaunch() {
        let app = launch()
        tap("dock-trends", in: app)
        tap("trends-body-measurements", in: app)
        XCTAssertTrue(app.staticTexts["No body weight readings"].exists)
        tap("body-measurements-add", in: app)

        for (metric, value) in [("weight", "180.25"), ("waist", "32.5"), ("bodyFat", "23.4")] {
            let field = app.textFields["body-measurement-input-\(metric)"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(value)
        }
        tap("body-measurements-save", in: app)
        let weight = app.buttons["body-measurement-manual-row"].firstMatch
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        XCTAssertTrue(weight.label.contains("180.25 lb"))
        attach("Body weight history", app)

        tap("body-measurements-metric", in: app)
        tap("body-measurements-metric-waist", in: app)
        XCTAssertTrue(app.buttons["body-measurement-manual-row"].firstMatch.label.contains("32.5 in"))

        app.terminate()
        app.launch()
        tap("dock-trends", in: app)
        tap("trends-body-measurements", in: app)
        tap("body-measurements-metric", in: app)
        tap("body-measurements-metric-bodyFat", in: app)
        let fat = app.buttons["body-measurement-manual-row"].firstMatch
        XCTAssertTrue(fat.label.contains("23.4%"))
        XCTAssertTrue(fat.label.contains("Manual"))
    }

    @MainActor
    func testMyExercisesFindsMissingDetailsAndEquipmentFreeRepsSurviveRelaunch() {
        let app = launch()
        let day = openDay(0, in: app)
        let name = "Porch practice squat"
        openExerciseCatalog(in: app)
        tap("picker-more", in: app)
        tap("create-exercise", in: app)
        let nameField = app.textFields["custom-name"]
        nameField.tap()
        nameField.typeText(name)
        tap("save-custom-exercise", in: app)
        let selected = selectedExercise(in: app)
        XCTAssertEqual(selected.label, name)
        let id = String(selected.identifier.dropFirst("exercise-".count))

        openLibraryExercises(in: app)
        let query = app.textFields["learn-search"]
        query.tap(); query.typeText(name + "\n")
        app.buttons["learn-gym-filters"].tap()
        tap("gym-filter-menu", in: app)
        app.buttons["gym-filter-option-Home gym"].tap()
        tap("gym-gear-none", in: app)
        tap("gym-filter-apply", in: app)
        let row = app.buttons["learn-exercise-\(id)"]
        XCTAssertFalse(row.exists)
        tap("learn-my-exercises", in: app)
        tap("learn-needs-details", in: app)
        tap("learn-exercise-\(id)", in: app)
        tap("custom-setup-gym-home", in: app)
        let checklist = app.scrollViews["custom-setup-scroll"]
        for _ in 0..<6 where !app.buttons["custom-setup-gear-none"].exists { checklist.swipeUp() }
        tap("custom-setup-gear-none", in: app)
        tap("custom-setup-save", in: app)
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
        tap("learn-all-exercises", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(query.value as? String, name)

        tap("dock-log", in: app)
        if !app.buttons["row-1-reps"].exists { tap(day, in: app) }
        tap("row-1-reps", in: app); replace("10", in: app); tap("input-done", in: app)
        XCTAssertTrue(reveal("repeat-set", in: app).isEnabled)
        app.terminate(); app.launch()
        if !app.buttons["row-1-reps"].exists { tap(day, in: app) }
        XCTAssertEqual(selectedExercise(in: app).label, name)
        XCTAssertTrue(app.buttons["row-1-reps"].label.contains("10 reps"))
        tap("repeat-set", in: app)
        XCTAssertTrue(app.buttons["row-2-reps"].label.contains("10 reps"))
    }

    @MainActor
    func testSavedSetupsSwitchBrowseAllAndOpenAnAvailableAlternative() {
        let app = launch()
        openLibraryExercises(in: app)
        let query = app.textFields["learn-search"]
        query.tap(); query.typeText("Flat dumbbell press\n")
        app.buttons["learn-gym-filters"].tap()
        tap("gym-filter-menu", in: app)
        app.buttons["gym-filter-option-Home gym"].tap()
        let gear = app.textFields["gym-gear-search"]
        tap("gym-gear-search", in: app); gear.typeText("dumbbell\n")
        tap("gym-gear-Dumbbells", in: app)
        tap("gym-filter-apply", in: app)
        let reason = app.staticTexts["exercise-unavailable-reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        XCTAssertTrue(reason.label.localizedCaseInsensitiveContains("bench"))
        let alternative = "learn-exercise-dumbbell-floor-press"
        tap(alternative, in: app)
        XCTAssertTrue(element("form-guide-dumbbell-floor-press", in: app).exists)
        tap("back-to-learn", in: app)
        app.buttons["learn-gym-filters"].tap()
        tap("gym-setup-actions", in: app)
        app.buttons["gym-setup-new"].tap()
        let dialog = app.alerts.firstMatch
        dialog.textFields.firstMatch.tap()
        dialog.textFields.firstMatch.typeText("Travel")
        dialog.buttons["gym-setup-confirm-name"].firstMatch.tap()
        tap("gym-gear-none", in: app)
        tap("gym-filter-apply", in: app)
        tap("gym-setup-browse-all", in: app)
        XCTAssertTrue(app.buttons["learn-exercise-dumbbell-bench"].waitForExistence(timeout: 5))
        tap("gym-setup-switch-Home gym", in: app)
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        XCTAssertTrue(reason.label.localizedCaseInsensitiveContains("bench"))
        attach("Available alternative and saved gym setups", app)
        tap("gym-setup-switch-Travel", in: app)
        XCTAssertFalse(app.buttons[alternative].exists)
        app.terminate(); app.launch()
        openLibraryExercises(in: app)
        app.buttons["learn-gym-filters"].tap()
        XCTAssertTrue(app.buttons["gym-gear-none"].isSelected)
        tap("gym-filter-cancel", in: app)
        tap("gym-setup-switch-Home gym", in: app)
        app.buttons["learn-gym-filters"].tap()
        tap("gym-gear-search", in: app); gear.typeText("dumbbell\n")
        XCTAssertTrue(app.buttons["gym-gear-Dumbbells"].isSelected)
    }

    @MainActor
    func testExerciseSearchOpensInlineAndKeepsDraftWhenCancelled() {
        let app = launch()
        _ = openDay(0, in: app)
        tap("add-exercise", in: app)
        let panel = app.scrollViews["day-scroll"].descendants(matching: .any)["workout-inline-search"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3), "Search should open within the workout.")
        let search = panel.textFields["picker-search"]
        search.tap(); search.typeText("Bench\n")
        panel.buttons["picker-bench"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 3))
        let bench = app.buttons["exercise-bench"]
        XCTAssertTrue(bench.isSelected)
        add("Squat", id: "squat", in: app)
        bench.tap()
        tap("row-1-weight", in: app); replace("31.", in: app)
        tap("add-exercise", in: app)
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        let strip = element("workout-exercises", in: app)
        XCTAssertLessThanOrEqual(strip.frame.maxY, search.frame.minY)
        XCTAssertTrue(bench.isSelected)
        search.tap(); search.typeText("Cable\n")
        XCTAssertTrue(panel.buttons["picker-cable-row"].waitForExistence(timeout: 3))
        XCTAssertFalse(panel.buttons["picker-bench"].exists)
        attach("Inline cable search below the exercise tabs", app)
        panel.buttons["close-exercise-picker"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 3))
        XCTAssertTrue(bench.isSelected)
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
    }

    @MainActor
    func testWorkoutExerciseGridShowsEveryMovementAndAdd() {
        let app = launch()
        _ = openDay(0, in: app)
        tap("choose-workout", in: app)
        tap("workout-template-dumbbell-basics", in: app)
        tap("apply-workout-template", in: app)
        let add = element("add-exercise", in: app)
        let first = app.buttons["exercise-goblet-squat"]
        let last = app.buttons["exercise-dumbbell-romanian-deadlift"]
        XCTAssertTrue(first.isSelected)
        for id in ["goblet-squat", "dumbbell-bench", "one-arm-dumbbell-row", "dumbbell-romanian-deadlift"] {
            let movement = app.buttons["exercise-\(id)"]
            XCTAssertTrue(movement.isHittable)
            XCTAssertGreaterThanOrEqual(movement.frame.height, 44 - 0.01)
            XCTAssertGreaterThanOrEqual(movement.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(movement.frame.maxX, app.frame.maxX)
        }
        XCTAssertGreaterThan(last.frame.midY, first.frame.midY)
        XCTAssertTrue(add.isHittable)
        XCTAssertGreaterThanOrEqual(add.frame.width, 44 - 0.01)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44 - 0.01)
        attach("Workout with all four movements visible", app)
        last.tap()
        XCTAssertTrue(last.isSelected)
        add.tap()
        XCTAssertTrue(element("workout-inline-search", in: app).exists)
        tap("close-exercise-picker", in: app)
        XCTAssertTrue(last.isSelected)
        XCTAssertFalse(app.buttons["day-workout-library"].exists)
        tap("workout-options", in: app)
        tap("day-save-template", in: app)
        let editor = app.scrollViews["workout-template-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertTrue(editor.staticTexts["Goblet squat"].exists)
        tap("cancel-workout-template", in: app)
        XCTAssertTrue(last.isSelected)
    }

    @MainActor
    func testLargestTextKeepsLongExerciseTabAndPinnedAddReachable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { diagnostics(app) }
        _ = openDay(0, in: app)
        tap("choose-workout", in: app)
        tap("workout-template-dumbbell-basics", in: app)
        tap("apply-workout-template", in: app)

        let addButton = reveal("add-exercise", in: app)
        let pinnedFrame = addButton.frame
        let strip = element("workout-exercises", in: app)
        let longTab = app.buttons["exercise-dumbbell-romanian-deadlift"]
        func fitsInStrip(_ tab: XCUIElement) -> Bool {
            tab.exists && tab.isHittable && tab.frame.minX >= strip.frame.minX - 1 &&
                tab.frame.maxX <= strip.frame.maxX + 1
        }
        XCTAssertFalse(fitsInStrip(longTab))
        for _ in 0..<5 {
            strip.swipeLeft()
            if fitsInStrip(longTab) { break }
        }
        XCTAssertTrue(fitsInStrip(longTab))
        XCTAssertEqual(addButton.frame.midY, pinnedFrame.midY, accuracy: 1)
        longTab.tap()
        XCTAssertTrue(longTab.isSelected)
        XCTAssertEqual(longTab.label, "Dumbbell Romanian deadlift")
        XCTAssertTrue(fitsInStrip(longTab))
        XCTAssertGreaterThan(longTab.frame.height, 60, "The long name should wrap at the largest text size.")
        XCTAssertEqual(addButton.frame.midX, pinnedFrame.midX, accuracy: 1)
        XCTAssertEqual(addButton.frame.midY, pinnedFrame.midY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(addButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(addButton.frame.height, 44)
        XCTAssertTrue(addButton.isHittable)
        let visibleTab = reveal("exercise-dumbbell-romanian-deadlift", in: app)
        let dock = element("app-dock", in: app)
        XCTAssertGreaterThanOrEqual(visibleTab.frame.minY, app.scrollViews["day-scroll"].frame.minY - 1)
        XCTAssertLessThanOrEqual(visibleTab.frame.maxY, dock.frame.minY + 1)
        attach("Largest text workout tabs with Dumbbell Romanian deadlift selected", app)

        add("Face pull", id: "face-pull", in: app)
        let addedTab = app.buttons["exercise-face-pull"]
        XCTAssertTrue(addedTab.isSelected)
        attach("Largest text workout immediately after adding Face pull", app)
        XCTAssertTrue(fitsInStrip(addedTab),
                      "Added tab \(addedTab.frame), hittable \(addedTab.isHittable), strip \(strip.frame), Add \(addButton.frame)")
    }

    @MainActor
    func testInlineSearchOffersRecentlyLoggedExerciseOnAnotherDay() {
        let app = launch()
        _ = openDay(0, in: app)
        add("Face pull", id: "face-pull", in: app)
        enter(weight: "35", reps: "8", in: app); tap("input-done", in: app)
        tap("next-day", in: app)
        tap("add-exercise", in: app)
        let panel = element("workout-inline-search", in: app)
        let recent = panel.buttons["picker-face-pull"]
        XCTAssertTrue(recent.waitForExistence(timeout: 3))
        recent.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["exercise-face-pull"].isSelected)
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("—"))
    }

    @MainActor
    func testCompletedRepsContinueIntoNextSetWithoutDismissingKeyboard() throws {
        let preview = launch(extra: ["--sample-data"])
        _ = openDay(0, in: preview)
        attach("Workout overview", preview)
        preview.terminate()

        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        let dock = element("app-dock", in: app)
        let keyboard = app.keyboards.firstMatch
        tap("row-1-weight", in: app)
        attach("Weight adjustment", app)
        replace("135", in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertTrue(dock.waitForNonExistence(timeout: 3))
        attach("Typing weight with the tab bar hidden", app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "weight-dial").firstMatch.exists)
        tap("input-use-dial", in: app)
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCTAssertTrue(dock.waitForExistence(timeout: 3))
        XCTAssertTrue(element("weight-dial", in: app).exists)
        XCTAssertEqual(element("set-input", in: app).value as? String, "135")
        attach("Weight ruler with the tab bar restored", app)
        replace("135", in: app)
        tap("input-next", in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertTrue(dock.waitForNonExistence(timeout: 3))
        let next = element("input-next-set", in: app)
        XCTAssertFalse(next.isEnabled)
        replace("0", in: app)
        XCTAssertFalse(next.isEnabled)
        replace("10", in: app)
        XCTAssertTrue(next.isEnabled)
        XCTAssertGreaterThanOrEqual(next.frame.height, 44 - 0.01)
        attach("Typing reps with the tab bar hidden", app)
        next.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        XCTAssertTrue(dock.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("input-set-context", in: app).label.contains("Set 2"))
        XCTAssertTrue(element("input-field-label", in: app).label.contains("Weight"))
        XCTAssertEqual(element("set-input", in: app).value as? String, "")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        XCTAssertTrue(element("row-2-type", in: app).label.contains("Working set"))
        attach("Next set keeps typing focus", app)
        replace("145", in: app); tap("input-next", in: app); replace("8", in: app)
        tap("input-done", in: app)
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCTAssertTrue(dock.waitForExistence(timeout: 3))
        tap("row-1-reps", in: app)
        XCTAssertFalse(app.buttons["input-next-set"].exists)
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        XCTAssertTrue(element("week-summary", in: app).label.contains("2 sets"))
    }

    @MainActor
    func testNextFocusesRepsWithoutAnotherTapAndDoneDismissesKeyboard() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        tap("row-1-weight", in: app)
        replace("135", in: app)
        tap("input-next", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let reps = element("set-input", in: app)
        XCTAssertTrue(reps.label.contains("reps"))
        reps.typeText("10")
        XCTAssertEqual(reps.value as? String, "10")
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        attach("Next focuses reps without another field tap", app)
        tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(reps.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["input-done"].exists)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))

        let addExercise = element("add-exercise", in: app)
        XCTAssertTrue(addExercise.isHittable)
        XCTAssertGreaterThanOrEqual(addExercise.frame.width, 44 - 0.01)
        XCTAssertGreaterThanOrEqual(addExercise.frame.height, 44 - 0.01)
        attach("Add exercise is visible after logging the first lift", app)
        addExercise.tap()
        let search = element("picker-search", in: app)
        search.tap(); search.typeText("Cable row\n")
        tap("picker-cable-row", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Cable row")
        let bench = app.buttons["exercise-bench"]
        let cableRow = app.buttons["exercise-cable-row"]
        XCTAssertTrue(bench.waitForExistence(timeout: 3), "Bench should be visible without opening a menu")
        XCTAssertTrue(bench.isHittable)
        XCTAssertTrue(cableRow.isHittable)
        XCTAssertTrue(cableRow.isSelected)
        XCTAssertFalse(bench.isSelected)
        attach("Movements visible after adding a second exercise", app)
        bench.tap()
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(bench.isSelected)
        XCTAssertFalse(cableRow.isSelected)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
    }

    @MainActor
    func testSwitchingExercisesFromTheNumberEditorKeepsDraftsWithTheirLift() {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        add("Cable row", id: "cable-row", in: app)
        tap("exercise-bench", in: app)

        let keyboard = app.keyboards.firstMatch
        let editor = app.textFields["set-input"]
        tap("row-1-weight", in: app)
        replace("31.", in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let next = app.buttons["input-next-exercise"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(next.label.contains("Cable row"))
        XCTAssertLessThanOrEqual(next.frame.maxY, editor.frame.minY)
        attach("Next exercise above the open weight editor", app)
        next.tap()

        XCTAssertEqual(selectedExercise(in: app).label, "Cable row")
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCTAssertFalse(element("row-1-weight", in: app).label.contains("31."))

        tap("row-1-reps", in: app)
        replace("7", in: app)
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let previous = app.buttons["input-previous-exercise"]
        XCTAssertTrue(previous.waitForExistence(timeout: 3))
        XCTAssertTrue(previous.isHittable)
        XCTAssertTrue(previous.label.contains("Bench"))
        XCTAssertLessThanOrEqual(previous.frame.maxY, editor.frame.minY)
        attach("Previous exercise above the open reps editor", app)
        previous.tap()

        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        tap("row-1-weight", in: app)
        XCTAssertEqual(editor.value as? String, "31.")
    }

    @MainActor
    func testPickerSearchReturnDismissesKeyboardAndKeepsResults() throws {
        let app = launch()
        _ = openDay(0, in: app)
        XCTAssertFalse(selectedExercise(in: app).exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Add exercise")).count, 1)
        XCTAssertFalse(app.buttons["reuse-workout"].exists)
        tap("add-exercise", in: app)
        let search = element("picker-search", in: app)
        search.tap(); search.typeText("Cable")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        search.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(search.value as? String, "Cable")
        XCTAssertTrue(element("picker-cable-row", in: app).exists)
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        attach("Search Return keeps the query and results", app)
        tap("picker-cable-row", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Cable row")
    }

    @MainActor
    func testOpeningFiltersDismissesSearchKeyboardAndKeepsSelectedFilters() throws {
        let app = launch()
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        tap("picker-show-results", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Cable")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        element("picker-filter-toggle", in: app).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("group-Back", in: app).isSelected)
        XCTAssertTrue(element("equipment-Cable", in: app).isSelected)
        tap("picker-show-results", in: app)
        XCTAssertEqual(element("exercise-search", in: app).value as? String, "Cable")
        XCTAssertTrue(element("remove-group-filter", in: app).exists)
        XCTAssertTrue(element("remove-equipment-filter", in: app).exists)
        let row = element("picker-cable-row", in: app)
        XCTAssertTrue(row.label.contains(", Back, Cable"))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        attach("Filter choices and spoken row context survive keyboard dismissal", app)
    }

    @MainActor
    func testHomeDumbbellsAllowFloorPressAndAddingABenchInLearnUnlocksBenchPress() {
        let app = launch()
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-filter-toggle", in: app)
        tap("picker-gym-equipment", in: app)
        app.buttons["gym-filter-menu"].tap()
        app.buttons["gym-filter-option-Home gym"].tap()
        attach("Home gym equipment checklist on compact iPhone", app)
        let gearSearch = app.textFields["gym-gear-search"]
        gearSearch.tap()
        gearSearch.typeText("dumbbell\n")
        let dumbbells = app.buttons["gym-gear-Dumbbells"]
        dumbbells.tap()
        XCTAssertTrue(dumbbells.isSelected)
        attach("Home gym with dumbbells selected", app)
        app.buttons["gym-filter-apply"].tap()

        let search = app.textFields["exercise-search"]
        search.tap()
        search.typeText("DB floor press\n")
        XCTAssertTrue(app.buttons["picker-dumbbell-floor-press"].waitForExistence(timeout: 5))
        app.buttons["picker-clear-search"].tap()
        search.tap()
        search.typeText("Flat dumbbell press\n")
        XCTAssertTrue(element("exercise-picker-empty", in: app).exists)
        XCTAssertFalse(app.buttons["picker-dumbbell-bench"].exists)
        let reason = app.staticTexts["exercise-unavailable-reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        XCTAssertTrue(reason.label.localizedCaseInsensitiveContains("bench"))
        tap("picker-dumbbell-floor-press", in: app)
        XCTAssertEqual(selectedExercise(in: app).identifier, "exercise-dumbbell-floor-press")

        app.terminate()
        app.launch()
        openLibraryExercises(in: app)
        let learnSearch = app.textFields["learn-search"]
        learnSearch.tap()
        learnSearch.typeText("Flat dumbbell press\n")
        XCTAssertTrue(element("learn-empty-state", in: app).exists)
        app.buttons["learn-gym-filters"].tap()
        gearSearch.tap()
        gearSearch.typeText("flat bench\n")
        app.buttons["gym-gear-Flat bench"].tap()
        app.buttons["gym-filter-apply"].tap()
        XCTAssertEqual(learnSearch.value as? String, "Flat dumbbell press")
        XCTAssertTrue(app.buttons["learn-exercise-dumbbell-bench"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargestTextNoEquipmentExcludesPullUpsAndClearingRestoresLearnAlias() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openLibraryExercises(in: app)
        let search = app.textFields["learn-search"]
        search.tap()
        search.typeText("Dead hang pull up\n")
        let pullUp = app.buttons["learn-exercise-pull-up"]
        XCTAssertTrue(pullUp.waitForExistence(timeout: 5))
        app.buttons["learn-gym-filters"].tap()
        let apply = app.buttons["gym-filter-apply"]
        XCTAssertEqual(apply.label, "Show 1 exercise")
        reveal("gym-gear-none", in: app)
        let noEquipment = app.buttons["gym-gear-none"]
        XCTAssertGreaterThanOrEqual(noEquipment.frame.height, 44 - 0.01)
        noEquipment.tap()
        XCTAssertTrue(noEquipment.isSelected)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "gym-gear-none").count, 1)
        XCTAssertGreaterThanOrEqual(noEquipment.frame.minY, app.buttons["gym-filter-cancel"].frame.maxY)
        XCTAssertLessThanOrEqual(noEquipment.frame.maxY, apply.frame.minY)
        attach("No equipment at the largest text size", app)
        XCTAssertEqual(apply.label, "Show 0 exercises")
        XCTAssertTrue(app.frame.contains(apply.frame))
        apply.tap()
        XCTAssertTrue(element("learn-empty-state", in: app).exists)
        XCTAssertFalse(pullUp.exists)
        app.buttons["learn-gym-filters"].tap()
        app.buttons["gym-filter-clear"].tap()
        app.buttons["gym-filter-cancel"].tap()
        XCTAssertTrue(element("learn-empty-state", in: app).exists)
        tap("learn-clear-gym-filters", in: app)
        XCTAssertEqual(search.value as? String, "Dead hang pull up")
        XCTAssertTrue(pullUp.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCustomGymAndRequiredGearPersistAndMatchAcrossLearnAndAddExercise() {
        let app = launch()
        let name = "Porch dumbbell drill"
        let day = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-more", in: app)
        tap("create-exercise", in: app)
        let nameField = app.textFields["custom-name"]
        nameField.tap()
        nameField.typeText(name)
        tap("custom-setup-open", in: app)
        tap("custom-setup-gym-home", in: app)
        tap("custom-setup-gym-commercial", in: app)
        let gear = app.textFields["custom-setup-gear-search"]
        tap("custom-setup-gear-search", in: app)
        gear.typeText("dumbbell\n")
        let dumbbells = app.buttons["custom-setup-gear-Dumbbells"]
        dumbbells.tap()
        XCTAssertTrue(dumbbells.isSelected)
        attach("Required dumbbells on a custom exercise", app)
        app.buttons["custom-setup-save"].tap()
        app.buttons["save-custom-exercise"].tap()
        let selected = selectedExercise(in: app)
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertEqual(selected.label, name)
        let id = String(selected.identifier.dropFirst("exercise-".count))

        app.terminate()
        app.launch()
        openLibraryExercises(in: app)
        let search = app.textFields["learn-search"]
        search.tap()
        search.typeText(name + "\n")
        let row = app.buttons["learn-exercise-\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["learn-gym-filters"].tap()
        app.buttons["gym-filter-menu"].tap()
        app.buttons["gym-filter-option-Home gym"].tap()
        tap("gym-gear-none", in: app)
        let apply = app.buttons["gym-filter-apply"]
        XCTAssertEqual(apply.label, "Show 0 exercises")
        let gearSearch = app.textFields["gym-gear-search"]
        gearSearch.tap()
        gearSearch.typeText("dumbbell\n")
        app.buttons["gym-gear-Dumbbells"].tap()
        XCTAssertEqual(apply.label, "Show 1 exercise")
        apply.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        tap("edit-custom-setup", in: app)
        XCTAssertTrue(app.buttons["custom-setup-gym-home"].isSelected)
        XCTAssertTrue(app.buttons["custom-setup-gym-commercial"].isSelected)
        tap("custom-setup-gym-home", in: app)
        app.buttons["custom-setup-cancel"].tap()
        tap("edit-custom-setup", in: app)
        XCTAssertTrue(app.buttons["custom-setup-gym-home"].isSelected)
        tap("custom-setup-gym-home", in: app)
        app.buttons["custom-setup-save"].tap()
        app.buttons["back-to-learn"].tap()
        XCTAssertTrue(element("learn-empty-state", in: app).exists)
        XCTAssertEqual(search.value as? String, name)
        app.buttons["learn-gym-filters"].tap()
        app.buttons["gym-filter-menu"].tap()
        app.buttons["gym-filter-option-Commercial gym"].tap()
        XCTAssertEqual(apply.label, "Show 1 exercise")
        apply.tap()

        tap("dock-log", in: app)
        if !app.buttons["add-exercise"].exists { tap(day, in: app) }
        openExerciseCatalog(in: app)
        let pickerSearch = app.textFields["exercise-search"]
        pickerSearch.tap()
        pickerSearch.typeText(name + "\n")
        XCTAssertTrue(app.buttons["picker-\(id)"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTaggingAnExistingCustomExerciseAsEquipmentFreeAtLargestText() {
        let app = launch()
        let name = "Quiet floor drill"
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-more", in: app)
        tap("create-exercise", in: app)
        let field = app.textFields["custom-name"]
        field.tap()
        field.typeText(name)
        app.buttons["save-custom-exercise"].tap()
        let selected = selectedExercise(in: app)
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        let id = String(selected.identifier.dropFirst("exercise-".count))

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openLibraryExercises(in: app)
        let search = app.textFields["learn-search"]
        search.tap()
        search.typeText(name + "\n")
        app.buttons["learn-gym-filters"].tap()
        tap("gym-gear-none", in: app)
        let apply = app.buttons["gym-filter-apply"]
        XCTAssertEqual(apply.label, "Show 0 exercises")
        apply.tap()
        tap("learn-clear-gym-filters", in: app)
        let row = app.buttons["learn-exercise-\(id)"]
        row.tap()
        tap("edit-custom-setup", in: app)
        let none = app.buttons["custom-setup-gear-none"]
        let checklist = app.scrollViews["custom-setup-scroll"]
        for _ in 0..<12 where !none.exists { checklist.swipeUp(velocity: .slow) }
        tap("custom-setup-gear-none", in: app)
        XCTAssertTrue(none.isSelected)
        XCTAssertGreaterThanOrEqual(none.frame.height, 44)
        let save = app.buttons["custom-setup-save"]
        XCTAssertTrue(app.frame.contains(save.frame))
        attach("No equipment required on a custom exercise at Largest Text", app)
        save.tap()
        app.buttons["back-to-learn"].tap()
        app.buttons["learn-gym-filters"].tap()
        tap("gym-gear-none", in: app)
        XCTAssertEqual(apply.label, "Show 1 exercise")
        apply.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargestTextFilteredMultiplePickerPreservesStateAcrossKeyboardDismissal() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { diagnostics(app) }
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app); tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app)
        XCTAssertTrue(element("group-Back", in: app).isSelected)
        tap("equipment-Cable", in: app)
        XCTAssertTrue(element("equipment-Cable", in: app).isSelected)
        tap("picker-show-results", in: app)
        tap("picker-more", in: app); tap("picker-select-multiple", in: app)
        let search = reveal("exercise-search", in: app)
        search.tap(); search.typeText("Cable")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let cancel = element("close-exercise-picker", in: app)
        let footer = element("picker-add-selected", in: app)
        let scroll = app.scrollViews["exercise-picker-scroll"]
        let row = app.buttons["picker-cable-row"]
        XCTAssertEqual(footer.label, "Select exercises to add")
        XCTAssertFalse(footer.isEnabled)
        attach("Largest Text filtered multiple picker with keyboard and no selection", app)
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(app.frame.contains(cancel.frame))
        XCTAssertTrue(app.frame.contains(footer.frame))
        XCTAssertLessThanOrEqual(cancel.frame.maxY, footer.frame.minY)
        XCTAssertLessThanOrEqual(footer.frame.maxY, keyboard.frame.minY)
        search.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
        XCTAssertEqual(search.value as? String, "Cable")
        XCTAssertTrue(element("remove-group-filter", in: app).exists)
        XCTAssertTrue(element("remove-equipment-filter", in: app).exists)
        XCTAssertEqual(footer.label, "Select exercises to add")
        XCTAssertFalse(footer.isEnabled)

        // Reveal the full row between the pinned controls after submitting search.
        for _ in 0..<20 {
            let top = max(scroll.frame.minY, cancel.frame.maxY)
            let bottom = min(scroll.frame.maxY, footer.frame.minY, app.frame.maxY)
            let available = bottom - top
            guard available > 2 else { break }
            var upward = true
            var distance = min(90, available - 2)
            if row.exists {
                let frame = row.frame
                if row.isHittable && frame.minY >= top && frame.maxY <= bottom { break }
                guard frame.height <= available else { break }
                // A short remaining gap still needs enough travel to begin a scroll.
                if frame.maxY > bottom { distance = min(distance, max(30, frame.maxY - bottom)) }
                else if frame.minY < top {
                    upward = false
                    distance = min(distance, max(30, top - frame.minY))
                } else { break }
            }
            let startY = upward ? top + distance + 1 : top + 1
            let endY = upward ? top + 1 : top + distance + 1
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: scroll.frame.midX - app.frame.minX, dy: startY - app.frame.minY))
                .press(forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(dx: scroll.frame.midX - app.frame.minX, dy: endY - app.frame.minY)),
                    withVelocity: .slow, thenHoldForDuration: 0.25)
        }

        attach("Largest Text complete result above the selection footer after Search Return", app)
        XCTAssertFalse(keyboard.exists)
        XCTAssertTrue(row.exists)
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(app.frame.contains(cancel.frame))
        XCTAssertTrue(app.frame.contains(footer.frame))
        XCTAssertLessThanOrEqual(cancel.frame.maxY, footer.frame.minY)
        let visibleTop = max(scroll.frame.minY, cancel.frame.maxY)
        let visibleBottom = min(scroll.frame.maxY, footer.frame.minY, app.frame.maxY)
        XCTAssertGreaterThanOrEqual(row.frame.minY, visibleTop,
            "Result begins behind the pinned header: row \(row.frame), Cancel \(cancel.frame)")
        XCTAssertLessThanOrEqual(row.frame.maxY, visibleBottom,
            "Result ends behind the footer: row \(row.frame), footer \(footer.frame)")
        XCTAssertGreaterThanOrEqual(row.frame.minX, max(app.frame.minX, scroll.frame.minX))
        XCTAssertLessThanOrEqual(row.frame.maxX, min(app.frame.maxX, scroll.frame.maxX))
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(row.label.contains(", Back, Cable"))
        XCTAssertFalse(row.isSelected)
        row.tap()
        XCTAssertTrue(row.isSelected)
        XCTAssertTrue(row.label.contains(", selected 1"))
        XCTAssertFalse(keyboard.exists)
        XCTAssertEqual(footer.label, "Add 1 exercise")
        XCTAssertTrue(footer.isEnabled)
        attach("Largest Text selected exercise and order badge above the Add footer", app)
        XCTAssertTrue(footer.isHittable)
        XCTAssertTrue(app.frame.contains(footer.frame))
        XCTAssertGreaterThanOrEqual(row.frame.minY, max(scroll.frame.minY, cancel.frame.maxY))
        XCTAssertLessThanOrEqual(row.frame.maxY, min(scroll.frame.maxY, footer.frame.minY))
        footer.tap()
        XCTAssertEqual(selectedExercise(in: app).label, "Cable row")
        XCTAssertTrue(scroll.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testCustomExerciseBackAndPickerCancelDismissKeyboardWithoutChangingWorkout() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        let date = element("day-date", in: app).label
        tap("add-exercise", in: app)
        let inline = element("picker-search", in: app)
        inline.tap(); inline.typeText("Cancelled row\n")
        tap("browse-all-exercises", in: app)
        let search = element("exercise-search", in: app)
        XCTAssertEqual(search.value as? String, "Cancelled row")
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        element("picker-more", in: app).tap(); tap("create-exercise", in: app)
        let name = element("custom-name", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        name.typeText(" draft")
        element("custom-back", in: app).tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(element("exercise-search", in: app).value as? String, "Cancelled row")
        search.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        element("close-exercise-picker", in: app).tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(element("day-date", in: app).label, date)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        openExerciseCatalog(in: app)
        let reopenedSearch = element("exercise-search", in: app)
        reopenedSearch.tap(); reopenedSearch.typeText("Cancelled row")
        XCTAssertTrue(element("exercise-picker-empty", in: app).exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "picker-custom-", "Cancelled row")).firstMatch.exists)
        attach("Abandoned custom exercise leaves the workout and library unchanged", app)
    }

    @MainActor
    func testNumberStepperAccessibilityValuesFollowWeightAndRepsChanges() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        tap("row-1-weight", in: app)
        // Coordinate conversion can report an exact 44pt frame as 43.99999999999994.
        for id in ["input-increase", "input-decrease", "input-next", "input-done"] {
            let control = element(id, in: app)
            XCTAssertGreaterThanOrEqual(control.frame.width + 0.000_001, 44, "Narrow touch target: \(id)")
            XCTAssertGreaterThanOrEqual(control.frame.height + 0.000_001, 44, "Short touch target: \(id)")
        }
        XCTAssertEqual(element("input-increase", in: app).value as? String, "Not entered")
        replace("50", in: app)
        for id in ["input-increase", "input-decrease"] {
            XCTAssertEqual(element(id, in: app).value as? String, "50 pounds")
        }
        tap("input-increase", in: app)
        for id in ["input-increase", "input-decrease"] {
            XCTAssertEqual(element(id, in: app).value as? String, "52.5 pounds")
        }
        tap("input-decrease", in: app)
        XCTAssertEqual(element("input-decrease", in: app).value as? String, "50 pounds")
        tap("input-next", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        element("set-input", in: app).typeText("8")
        tap("input-increase", in: app)
        for id in ["input-increase", "input-decrease"] {
            XCTAssertEqual(element(id, in: app).value as? String, "9 reps")
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Increasing reps should keep the keyboard open")
        tap("input-decrease", in: app)
        XCTAssertEqual(element("input-decrease", in: app).value as? String, "8 reps")
        XCTAssertEqual(element("set-input", in: app).value as? String, "8")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Decreasing reps should keep the keyboard open")
        attach("Number controls expose their current value to VoiceOver", app)
        tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    @MainActor
    func testRepsLeftMenuExposesTheSelectedOption() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("row-1-details", in: app)
        tap("set-reps-left", in: app); tap("set-reserve-2", in: app)
        tap("save-set-details", in: app)
        tap("row-1-details", in: app)
        XCTAssertEqual(element("set-reps-left", in: app).value as? String, "2 reps left")
        tap("set-reps-left", in: app)
        XCTAssertTrue(element("set-reserve-2", in: app).isSelected)
        XCTAssertFalse(element("set-reserve-unknown", in: app).isSelected)
        attach("Saved reps left remains selected in the menu", app)
    }

    @MainActor
    func testProfileFocusedUnitsAndNameSubmit() throws {
        continueAfterFailure = false
        let app = launch()
        tap("dock-profile", in: app)
        attach("Profile overview", app)
        tap("profile-settings", in: app)
        tap("profile-weight-units", in: app)
        attach("Profile weight units", app)
        XCTAssertFalse(app.buttons["export-backup"].exists)
        XCTAssertFalse(app.buttons["restore-import"].exists)
        XCTAssertTrue(element("preference-lb", in: app).isSelected)
        tap("preference-kg", in: app)
        XCTAssertTrue(element("preference-kg", in: app).isSelected)
        tap("close-settings", in: app)
        XCTAssertTrue(element("profile-weight-units", in: app).label.contains("Kilograms"))
        tap("profile-details", in: app)
        attach("Profile name form", app)
        let name = element("profile-name", in: app)
        name.tap(); name.typeText("Jae\n")
        XCTAssertTrue(app.scrollViews["profile-details-scroll"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        tap("profile-details", in: app)
        let reopenedName = element("profile-name", in: app)
        reopenedName.tap(); reopenedName.typeText(" changed")
        attach("Profile name while typing", app)
        XCTAssertTrue(element("profile-save", in: app).isHittable)
        tap("profile-cancel", in: app)
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        XCTAssertFalse(element("profile-details", in: app).label.contains("changed"))
    }

    @MainActor
    func testStrengthGoalCompletesFromLoggedSetAndPersists() throws {
        continueAfterFailure = false
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "8", in: app)
        tap("input-done", in: app)
        tap("dock-profile", in: app)
        tap("add-strength-goal", in: app)
        tap("strength-goal-exercise", in: app)
        tap("strength-goal-exercise-bench", in: app)
        let weight = element("strength-goal-weight", in: app)
        weight.tap(); weight.typeText("145")
        let reps = element("strength-goal-reps", in: app)
        reps.tap(); reps.typeText("8")
        tap("save-strength-goal", in: app)
        let goal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "strength-goal-")).firstMatch
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertTrue(goal.label.contains("145 lb"))
        XCTAssertTrue(goal.label.contains("135 lb"))
        let goalID = goal.identifier
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "completed-strength-goals").firstMatch.exists)
        attach("Active strength goal", app)
        tap("dock-log", in: app)
        tap("row-1-weight", in: app); replace("145", in: app); tap("input-done", in: app)
        tap("dock-profile", in: app)
        XCTAssertTrue(element("completed-strength-goals", in: app).exists)
        XCTAssertTrue(element(goalID, in: app).label.contains("145 lb"))
        app.terminate(); app.launch()
        tap("dock-profile", in: app)
        XCTAssertTrue(element("completed-strength-goals", in: app).exists)
        XCTAssertTrue(element(goalID, in: app).exists)
        attach("Completed strength goal", app)
    }

    @MainActor
    func testLargestTextProfileDestinationsAndNameActionsStayReachable() throws {
        continueAfterFailure = false
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-profile", in: app)
        attach("Larger Text Profile", app)
        tap("profile-settings", in: app)
        tap("profile-details", in: app)
        let name = reveal("profile-name", in: app)
        name.tap(); name.typeText("Alexandra")
        for id in ["profile-save", "profile-cancel"] {
            let action = element(id, in: app)
            XCTAssertTrue(action.isHittable)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44 - 0.01)
        }
        attach("Larger Text name editing", app)
        tap("profile-cancel", in: app)
        tap("profile-weight-units", in: app)
        tap("preference-kg", in: app)
        XCTAssertTrue(element("preference-kg", in: app).isSelected)
        XCTAssertTrue(element("close-settings", in: app).isHittable)
        attach("Larger Text weight units", app)
        tap("close-settings", in: app)
        tap("profile-backup", in: app)
        let done = element("close-settings", in: app)
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(app.frame.contains(done.frame))
        attach("Larger Text backup header", app)
        let restore = element("restore-import", in: app)
        let scroll = app.scrollViews["settings-scroll"]
        // This large-text sheet has several screens of backup explanations.
        // Use page-sized drags rather than the shared helper's 90-point steps.
        for _ in 0..<16 {
            if restore.isHittable && restore.frame.minY >= scroll.frame.minY &&
                restore.frame.maxY <= scroll.frame.maxY - 36 { break }
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05,
                    thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                    withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertTrue(restore.isHittable)
        XCTAssertGreaterThanOrEqual(restore.frame.minY, scroll.frame.minY)
        XCTAssertLessThanOrEqual(restore.frame.maxY, scroll.frame.maxY - 36)
        attach("Larger Text restore action", app)
        tap("close-settings", in: app)
        XCTAssertTrue(element("profile-details", in: app).exists)
    }

    @MainActor
    func testInvalidProfileNameKeepsRawTextAndExposesSaveError() throws {
        let app = launch()
        tap("dock-profile", in: app); tap("profile-settings", in: app); tap("profile-details", in: app)
        let name = element("profile-name", in: app)
        let invalidName = String(repeating: "J", count: 81)
        name.tap(); name.typeText(invalidName)
        tap("profile-save", in: app)
        XCTAssertTrue(element("profile-save-error", in: app).label.contains("80"))
        XCTAssertEqual(name.value as? String, invalidName)
        XCTAssertTrue(app.scrollViews["profile-details-scroll"].exists)
        tap("profile-save", in: app)
        XCTAssertTrue(element("profile-save-error", in: app).exists)
        XCTAssertEqual(name.value as? String, invalidName)
        attach("Invalid name remains available to correct beside its error", app)
    }

    @MainActor
    func testExercisePickerPassesAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app)
        _ = element("exercise-search", in: app)
        attach("Exercise picker accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testExerciseFiltersPassAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        _ = openDay(0, in: app)
        openExerciseCatalog(in: app); tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        attach("Selected exercise filters accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testTwoSetsPassAccessibilityAudit() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("repeat-set", in: app)
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("10 reps"))
        attach("Two saved sets accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testEmptyWorkoutPassesAccessibilityAudit() throws {
        let app = launch()
        _ = openDay(0, in: app)
        attach("Empty workout accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testBlankSetPassesAccessibilityAudit() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        attach("Blank set accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testLargestTextWorkoutHeaderKeepsDatesAndArrowsReadable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let todayRow = reveal(todayRowID(), in: app)
        XCTAssertTrue(todayRow.label.contains("Add workout"))
        XCTAssertGreaterThanOrEqual(todayRow.frame.height, 44 - 0.01)
        attach("Today’s first workout row at the largest text size", app)
        todayRow.tap()
        let goToToday = app.buttons["go-to-today"]
        XCTAssertFalse(goToToday.exists)

        let title = element("day-title", in: app)
        let date = element("day-date", in: app)
        let previous = element("previous-day", in: app)
        let next = element("next-day", in: app)
        let scroll = app.scrollViews["day-scroll"]
        func assertHeader() {
            for item in [title, date, previous, next] {
                XCTAssertTrue(scroll.frame.contains(item.frame), "\(item.identifier) extends beyond the workout")
                XCTAssertTrue(item.isHittable, "\(item.identifier) is obscured")
            }
            XCTAssertLessThanOrEqual(title.frame.maxY, date.frame.minY)
            XCTAssertLessThanOrEqual(date.frame.maxY, previous.frame.minY)
            for arrow in [previous, next] {
                XCTAssertGreaterThanOrEqual(arrow.frame.width, 44)
                XCTAssertGreaterThanOrEqual(arrow.frame.height, 44)
            }
        }

        assertHeader()
        XCTAssertFalse(selectedExercise(in: app).exists)
        let addExercise = element("add-exercise", in: app)
        XCTAssertLessThanOrEqual(max(previous.frame.maxY, next.frame.maxY), addExercise.frame.minY)
        XCTAssertTrue(addExercise.isHittable)
        XCTAssertGreaterThanOrEqual(addExercise.frame.height, 44 - 0.01)
        attach("Today's workout header at the largest text size", app)
        let today = date.label
        for (arrow, day) in [(previous, "Past"), (next, "Future")] {
            arrow.tap()
            XCTAssertNotEqual(date.label, today)
            XCTAssertFalse(app.staticTexts["\(day) training day"].exists)
            assertHeader()
            attach("\(day) workout header at the largest text size", app)
            XCTAssertTrue(goToToday.isHittable)
            goToToday.tap()
            XCTAssertEqual(date.label, today)
        }
    }

    @MainActor
    func testPopulatedWorkoutPassesAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let confirmation = app.descendants(matching: .any).matching(identifier: "first-set-saved").firstMatch
        if confirmation.exists {
            XCTAssertLessThanOrEqual(confirmation.frame.maxY, element("app-dock", in: app).frame.minY)
            XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        }
        attach("Populated workout accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testProfilePassesAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        tap("dock-profile", in: app)
        assertProfileDestinations(in: app)
        attach("Profile accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testBackupSettingsPassAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        tap("dock-profile", in: app); tap("profile-settings", in: app); tap("profile-backup", in: app)
        _ = element("export-backup", in: app)
        attach("Backup settings accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testSettingsAddsSampleWorkoutsWithoutChangingLoggedDays() {
        let app = launch()
        tap("previous-week", in: app)
        let loggedDay = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "81", reps: "9", in: app)
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        let originalLabel = element(loggedDay, in: app).label

        tap("dock-profile", in: app)
        element("profile-settings", in: app).tap()
        let addSamples = element("add-sample-workouts", in: app)
        addSamples.tap()
        let result = element("sample-workouts-status", in: app)
        XCTAssertTrue(result.label.hasPrefix("Added "), result.label)
        attach("Sample workouts added in Settings", app)
        addSamples.tap()
        XCTAssertEqual(result.label, "No more sample workouts to add.")
        tap("close-profile-settings", in: app)
        tap("dock-log", in: app)

        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(element(loggedDay, in: app).label, originalLabel)
        XCTAssertTrue(days.allElementsBoundByIndex.contains {
            $0.identifier != loggedDay && $0.label.contains("6 sets")
        })
        attach("Sample training on previously empty dates", app)
        tap(loggedDay, in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("81 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("9 reps"))
        XCTAssertFalse(app.buttons["row-2-weight"].exists)
    }

    @MainActor
    func testForcedSampleLaunchKeepsExistingSampleFlow() {
        let app = launch(extra: ["--sample-data"])
        XCTAssertFalse(app.buttons["try-demo"].exists)
        XCTAssertFalse(app.buttons["exit-demo"].exists)
        tap("dock-trends", in: app)
        XCTAssertTrue(element("trends-strength-chart", in: app).exists)
    }

    @MainActor
    func testColdLaunchOpensNotebookAndResumeKeepsWorkout() {
        let app = launch(extra: ["--sample-data"])
        let intro = app.descendants(matching: .any).matching(identifier: "senda-launch-intro").firstMatch
        XCTAssertTrue(intro.waitForNonExistence(timeout: 5))
        tap(todayRowID(), in: app)

        let day = element("day-date", in: app).label
        let history = app.buttons["exercise-history"]
        XCTAssertTrue(history.isHittable)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 3) || app.state == .runningBackgroundSuspended)
        app.activate()

        XCTAssertFalse(intro.exists)
        XCTAssertEqual(element("day-date", in: app).label, day)
        XCTAssertTrue(history.isHittable)
        history.tap()
        XCTAssertTrue(app.scrollViews["workout-exercise-history"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWeekAndActiveWorkoutFollowPhoneAppearance() async throws {
        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        defer { device.appearance = originalAppearance }
        device.appearance = .light

        let app = launch(extra: ["--sample-data"])
        let ivory = [247, 243, 235]
        let espresso = [37, 31, 26]
        let context = CIContext()
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))

        func expectPaper(_ expected: [Int], capture title: String? = nil,
                         file: StaticString = #filePath, line: UInt = #line) async throws {
            let deadline = ContinuousClock.now + .seconds(5)
            var actual = [Int]()
            repeat {
                let shot = app.screenshot()
                let image = CIImage(cgImage: try XCTUnwrap(shot.image.cgImage))
                // The outer margin at mid-height contains only the page background on these screens.
                let sample = CGRect(x: 3, y: floor(image.extent.midY), width: 1, height: 1)
                var pixel = [UInt8](repeating: 0, count: 4)
                context.render(image, toBitmap: &pixel, rowBytes: 4, bounds: sample, format: .RGBA8, colorSpace: sRGB)
                actual = pixel.prefix(3).map(Int.init)
                if zip(actual, expected).allSatisfy({ abs($0.0 - $0.1) <= 2 }) {
                    if let title {
                        let attachment = XCTAttachment(screenshot: shot)
                        attachment.name = title
                        attachment.lifetime = .keepAlways
                        self.add(attachment)
                    }
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            } while ContinuousClock.now < deadline
            XCTFail("Expected page RGB \(expected), found \(actual)", file: file, line: line)
        }

        try await expectPaper(ivory, capture: "Week · Light")
        device.appearance = .dark
        try await expectPaper(espresso, capture: "Week · Brown")
        tap("dock-library", in: app)
        XCTAssertTrue(element("library-workouts", in: app).isHittable)
        try await expectPaper(ivory)
        tap("dock-log", in: app)
        XCTAssertTrue(element("week-summary", in: app).exists)
        try await expectPaper(espresso)

        tap(todayRowID(), in: app)
        XCTAssertTrue(app.buttons["last-reference"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("row-1-weight", in: app).exists)
        try await expectPaper(espresso, capture: "Active workout · Brown")
        device.appearance = .light
        try await expectPaper(ivory, capture: "Active workout · Light")
    }

    @MainActor
    func testWeekOverviewKeepsSevenDaysAboveDock() {
        var emptyRowHeight: CGFloat?
        for (arguments, state) in [([String](), "Empty"), (["--sample-data"], "Sample")] {
            let app = launch(extra: arguments)
            let dock = element("app-dock", in: app)
            let week = app.scrollViews["week-view"]
            let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
            XCTAssertEqual(days.count, 7, state)
            let rowHeight = days.firstMatch.frame.height
            XCTAssertGreaterThan(rowHeight, 54, state)
            XCTAssertLessThanOrEqual(rowHeight, 72.5, state)
            if let emptyRowHeight {
                XCTAssertEqual(rowHeight, emptyRowHeight, accuracy: 0.5, state)
            } else {
                emptyRowHeight = rowHeight
            }
            if arguments.contains("--sample-data") {
                let labels = days.allElementsBoundByIndex.map(\.label)
                XCTAssertTrue(labels.contains { $0.contains("Chest") })
                XCTAssertFalse(labels.contains { $0.contains("Bench") })
            }
            for day in days.allElementsBoundByIndex {
                XCTAssertTrue(day.isHittable, "\(state): \(day.identifier)")
                XCTAssertEqual(day.frame.height, rowHeight, accuracy: 0.5, "\(state): \(day.identifier)")
                XCTAssertTrue(week.frame.contains(day.frame), "\(state): \(day.identifier) extends past the week")
                XCTAssertLessThanOrEqual(day.frame.maxY, dock.frame.minY, "\(state): \(day.identifier) overlaps the dock")
            }
            XCTAssertTrue(element("week-muscles", in: app).isHittable)
            XCTAssertTrue(app.buttons[todayRowID()].isHittable)
            attach("\(state) week overview above the dock", app)
            app.terminate()
        }
    }

    @MainActor
    func testMonthCalendarMarksWorkoutDaysAndOpensSelectedWeek() throws {
        let app = launch(extra: ["--sample-data"])
        let todayControl = element("today-week", in: app)
        let calendarControl = element("week-calendar", in: app)
        XCTAssertEqual(calendarControl.frame.midY, todayControl.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(calendarControl.frame.width, 44 - 0.01)
        XCTAssertGreaterThanOrEqual(calendarControl.frame.height, 44 - 0.01)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = String(todayRowID().dropFirst("day-".count))
        let today = try XCTUnwrap(formatter.date(from: todayKey))
        let currentMonth = try XCTUnwrap(calendar.dateInterval(of: .month, for: today))
        let futureDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 10, to: currentMonth.end))
        let futureKey = formatter.string(from: futureDay)

        func assertWeek(containing date: Date, file: StaticString = #filePath, line: UInt = #line) throws {
            let week = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: date), file: file, line: line)
            let expected = try (0..<7).map { offset in
                let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: week.start), file: file, line: line)
                return "day-" + formatter.string(from: day)
            }
            let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
            XCTAssertTrue(app.scrollViews["week-view"].exists, file: file, line: line)
            XCTAssertEqual(days.allElementsBoundByIndex.map(\.identifier), expected, file: file, line: line)
            XCTAssertFalse(app.buttons["back-to-week"].exists, file: file, line: line)
        }

        calendarControl.tap()
        let monthTitle = element("calendar-month-title", in: app)
        let initialTitle = monthTitle.label
        let loggedDay = element("calendar-day-\(todayKey)", in: app)
        XCTAssertEqual(loggedDay.value as? String, "Workout logged")
        attach("Month calendar with logged workout dots", app)
        loggedDay.tap()
        XCTAssertTrue(monthTitle.waitForNonExistence(timeout: 3))
        try assertWeek(containing: today)

        calendarControl.tap()
        tap("calendar-next-month", in: app)
        XCTAssertNotEqual(monthTitle.label, initialTitle)
        let blankDay = element("calendar-day-\(futureKey)", in: app)
        XCTAssertEqual(blankDay.value as? String, "No workout logged")
        blankDay.tap()
        XCTAssertTrue(monthTitle.waitForNonExistence(timeout: 3))
        try assertWeek(containing: futureDay)

        calendarControl.tap()
        XCTAssertTrue(element("calendar-day-\(futureKey)", in: app).exists)
        tap("calendar-previous-month", in: app)
        XCTAssertEqual(monthTitle.label, initialTitle)
        tap("calendar-close", in: app)
        XCTAssertTrue(monthTitle.waitForNonExistence(timeout: 3))
        try assertWeek(containing: futureDay)
    }

    @MainActor
    func testWeekMuscleHeatmapShowsLoggedSetsAndUpdatesAcrossWeeks() {
        let app = launch(extra: ["--sample-data"])
        let todayID = todayRowID()
        let summary = element("week-summary", in: app).label
        XCTAssertTrue(app.buttons[todayID].isHittable)
        tap("week-muscles", in: app)
        let sheet = element("week-muscles-sheet", in: app)
        let chest = element("week-muscle-region-chest", in: app)
        let count = chest.label + " " + String(describing: chest.value ?? "")
        // The sample week includes Monday's bench workout if today is later than Monday.
        XCTAssertNotNil(count.range(of: #"\b(?:4|8) sets\b"#, options: .regularExpression), count)
        tap("week-muscle-region-chest", in: app)
        XCTAssertTrue(element("week-muscle-lift-bench", in: app).exists)
        let volume = element("week-muscle-volume", in: app).label
        XCTAssertTrue(["4 sets across 1 day", "8 sets across 2 days"].contains(volume), volume)
        attach("Chest sets in the weekly muscle heatmap", app)
        tap("close-week-muscles", in: app)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons[todayID].isHittable)
        XCTAssertEqual(element("week-summary", in: app).label, summary)
        tap("next-week", in: app)
        XCTAssertFalse(app.buttons[todayID].exists)
        tap("week-muscles", in: app)
        XCTAssertTrue(element("week-muscle-empty", in: app).exists)
        XCTAssertFalse(chest.exists)
        tap("close-week-muscles", in: app)
        XCTAssertFalse(app.buttons[todayID].exists)

        tap("today-week", in: app)
        tap("previous-week", in: app)
        attach("Populated week overview", app)
        tap("week-muscles", in: app)
        XCTAssertTrue(element("week-muscle-region-chest", in: app).exists)
        XCTAssertTrue(element("week-muscle-region-upperBack", in: app).exists)
        attach("Populated weekly muscle heatmap", app)
    }

    @MainActor
    func testWeeklyMuscleTargetPersistsAndShowsLoggedVolume() {
        let app = launch()
        tap("dock-profile", in: app)
        tap("add-weekly-muscle-target", in: app)
        tap("weekly-muscle-target-muscle", in: app)
        tap("weekly-muscle-target-option-chest", in: app)
        let minimum = element("weekly-muscle-target-minimum", in: app)
        minimum.tap(); minimum.typeText("8")
        let maximum = element("weekly-muscle-target-maximum", in: app)
        maximum.tap(); maximum.typeText("12")
        tap("save-weekly-muscle-target", in: app)
        XCTAssertTrue(element("weekly-muscle-target-chest", in: app).label.contains("8–12"))
        attach("Weekly set targets in Profile", app)

        app.terminate(); app.launch()
        tap("week-muscles", in: app)
        XCTAssertEqual(element("week-muscle-volume", in: app).label, "0 sets across 0 days")
        XCTAssertTrue(element("week-muscle-target", in: app).label.contains("8–12 sets"))
        tap("close-week-muscles", in: app)

        tap(todayRowID(), in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "8", in: app)
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        tap("week-muscles", in: app)
        XCTAssertEqual(element("week-muscle-volume", in: app).label, "1 set across 1 day")
        XCTAssertTrue(element("week-muscle-target", in: app).label.contains("8–12 sets"))
        attach("Muscle detail with logged volume and a weekly target", app)
        tap("close-week-muscles", in: app)

        tap("dock-profile", in: app)
        tap("weekly-muscle-target-chest", in: app)
        tap("remove-weekly-muscle-target", in: app)
        tap("confirm-remove-weekly-muscle-target", in: app)
        XCTAssertFalse(app.buttons["weekly-muscle-target-chest"].exists)
        tap("dock-log", in: app)
        tap("week-muscles", in: app)
        XCTAssertEqual(element("week-muscle-volume", in: app).label, "1 set across 1 day")
        XCTAssertFalse(app.staticTexts["week-muscle-target"].exists)
    }

    @MainActor
    func testEmptyDaysOfferAddWorkoutAndFirstSetConfirmsSave() {
        let app = launch()
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        XCTAssertEqual(days.count, 7)
        for row in days.allElementsBoundByIndex {
            XCTAssertTrue(row.label.contains("Add workout"), row.label)
        }
        XCTAssertFalse(app.buttons["try-demo"].exists)
        tap("dock-profile", in: app)
        XCTAssertFalse(app.buttons["profile-try-demo"].exists)
        tap("dock-log", in: app)

        let day = todayRowID()
        attach("Week with the first workout and library entrances", app)
        tap(day, in: app)
        XCTAssertFalse(app.buttons["go-to-today"].exists)
        add("Bench", id: "bench", in: app)

        let confirmation = app.descendants(matching: .any).matching(identifier: "first-set-saved").firstMatch
        tap("row-1-weight", in: app)
        replace("135", in: app)
        tap("input-next", in: app)
        XCTAssertFalse(confirmation.exists)

        let row = element("set-row-1", in: app)
        let reps = element("row-1-reps", in: app)
        let blankRowHeight = row.frame.height
        let blankRepsFrame = reps.frame
        replace("0000000000", in: app)
        XCTAssertEqual(row.frame.height, blankRowHeight, accuracy: 1)
        XCTAssertEqual(reps.frame.midY, blankRepsFrame.midY, accuracy: 2)
        replace("8", in: app)
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        XCTAssertEqual(row.frame.height, blankRowHeight, accuracy: 1)
        XCTAssertEqual(reps.frame.midY, blankRepsFrame.midY, accuracy: 2)
        XCTAssertTrue(confirmation.label.contains("First set saved"))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(element("set-input", in: app).label.contains("reps"))
        XCTAssertLessThanOrEqual(confirmation.frame.maxY, element("input-set-context", in: app).frame.minY)
        attach("First set saved while editing reps", app)
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertEqual(reps.frame.midY, blankRepsFrame.midY, accuracy: 2)

        element("input-next-set", in: app).tap()
        replace("145", in: app)
        tap("input-next", in: app)
        replace("8", in: app)
        XCTAssertFalse(confirmation.exists)
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("8 reps"))
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        let loggedDay = element(day, in: app)
        XCTAssertFalse(loggedDay.label.contains("Add workout"))
        XCTAssertTrue(loggedDay.label.contains("2 sets"))
        XCTAssertTrue(element("week-summary", in: app).label.contains("2 sets"))
    }

    @MainActor
    func testAutomaticEntryAndHeaderUnitsUpdateTheWeek() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Record ")).firstMatch.exists)
        enter(weight: "135", reps: "10", in: app)
        XCTAssertTrue(element("set-input", in: app).exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        XCTAssertFalse(element("row-1-weight", in: app).label.contains("Recorded"))
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        tap("row-1-reps", in: app)
        tap("input-done", in: app)
        changeUnit("kg", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("61.23 kg"))
        changeUnit("lb", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("1 set"))
        XCTAssertTrue(element("week-summary", in: app).label.contains("1 set"))
        XCTAssertTrue(element(day, in: app).label.contains("Chest"))
        XCTAssertFalse(element(day, in: app).label.contains("Bench"))
        attach("Trained body parts reflected in week", app)
        tap(day, in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        let originalDate = element("day-date", in: app).label
        let originalHeaderY = element("back-to-week", in: app).frame.minY
        tap("next-day", in: app)
        XCTAssertNotEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("back-to-week", in: app).frame.minY, originalHeaderY, accuracy: 1)
        XCTAssertFalse(selectedExercise(in: app).exists)
        XCTAssertTrue(element("back-to-week", in: app).exists)
        tap("previous-day", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("back-to-week", in: app).frame.minY, originalHeaderY, accuracy: 1)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        attach("Adjacent day navigation", app)
    }

    @MainActor
    func testWeekSwipesNavigateWithoutOpeningDaysAndKeepVerticalScrolling() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"])
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        let originalDay = days.element(boundBy: 0).identifier
        let todayControl = element("today-week", in: app)
        XCTAssertTrue(todayControl.isSelected)
        let previousControl = element("previous-week", in: app)
        let nextControl = element("next-week", in: app)
        XCTAssertLessThan(todayControl.frame.midY, previousControl.frame.midY)
        XCTAssertEqual(previousControl.frame.midY, nextControl.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(todayControl.frame.width, 44)
        XCTAssertLessThan(previousControl.frame.minX, nextControl.frame.minX)
        XCTAssertTrue(element("week-month", in: app).exists)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = formatter.timeZone
        let date = try XCTUnwrap(formatter.date(from: String(originalDay.dropFirst(4))))
        let previous = "day-" + formatter.string(from: try XCTUnwrap(calendar.date(byAdding: .day, value: -7, to: date)))
        let next = "day-" + formatter.string(from: try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: date)))
        func swipe(_ id: String, left: Bool) {
            let row = element(id, in: app)
            row.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.5))
                .press(forDuration: 0.05,
                    thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.5)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertTrue(app.scrollViews["week-view"].exists)
            XCTAssertFalse(app.buttons["back-to-week"].exists)
        }
        swipe(originalDay, left: false)
        XCTAssertFalse(todayControl.isSelected)
        XCTAssertEqual(days.element(boundBy: 0).identifier, previous)
        swipe(previous, left: true)
        XCTAssertTrue(todayControl.isSelected)
        XCTAssertEqual(days.element(boundBy: 0).identifier, originalDay)
        swipe(originalDay, left: true)
        XCTAssertEqual(days.element(boundBy: 0).identifier, next)
        swipe(next, left: false)
        XCTAssertEqual(days.element(boundBy: 0).identifier, originalDay)
        let week = app.scrollViews["week-view"]
        let firstY = element(originalDay, in: app).frame.minY
        let verticalStart = week.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        verticalStart.press(forDuration: 0.05,
            thenDragTo: verticalStart.withOffset(CGVector(dx: 3, dy: -90)),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(days.element(boundBy: 0).identifier, originalDay)
        XCTAssertLessThan(element(originalDay, in: app).frame.minY, firstY)
        XCTAssertFalse(app.buttons["back-to-week"].exists)
        tap("previous-week", in: app)
        XCTAssertEqual(days.element(boundBy: 0).identifier, previous)
        tap("next-week", in: app)
        XCTAssertEqual(days.element(boundBy: 0).identifier, originalDay)
        tap("next-week", in: app)
        XCTAssertFalse(todayControl.isSelected)
        tap("today-week", in: app)
        XCTAssertTrue(todayControl.isSelected)
        XCTAssertEqual(days.element(boundBy: 0).identifier, originalDay)
        XCTAssertFalse(app.buttons["back-to-week"].exists)
        tap(originalDay, in: app)
        XCTAssertTrue(element("day-title", in: app).exists)
        attach("Swipe weeks and open a day", app)
    }

    @MainActor
    func testBodyweightRepeatDeleteAndUndo() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Push", id: "push-up", in: app)
        tap("row-1-reps", in: app)
        replace("12", in: app)
        tap("input-done", in: app)
        changeUnit("kg", in: app)
        tap("row-1-weight", in: app); replace("10", in: app); tap("input-done", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("10 kg"))
        changeUnit("lb", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("22.05 lb"))
        let repeatSet = reveal("repeat-set", in: app)
        XCTAssertGreaterThanOrEqual(repeatSet.frame.height, 44 - 0.01)
        repeatSet.tap()
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("12 reps"))
        XCTAssertGreaterThanOrEqual(element("undo-set-change", in: app).frame.height, 44)
        tap("undo-set-change", in: app)
        XCTAssertFalse(app.buttons["row-2-reps"].exists)
        tap("set-1-actions", in: app)
        XCTAssertTrue(element("delete-row-1", in: app).exists)
        tap("row-1-details", in: app)
        tap("cancel-set-details", in: app)
        XCTAssertFalse(app.buttons["delete-row-1"].exists)
        let firstRow = element("set-row-1", in: app)
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).press(forDuration: 0.05,
            thenDragTo: firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(element("row-1-reps", in: app).exists)
        attach("Short swipe reveals red delete action", app)
        tap("delete-row-1", in: app)
        XCTAssertFalse(app.buttons["row-1-reps"].exists)
        tap("undo-set-change", in: app)
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("12 reps"))
        tap("repeat-set", in: app)
        let secondRow = element("set-row-2", in: app)
        secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).press(forDuration: 0.05,
            thenDragTo: secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertFalse(app.buttons["row-2-reps"].exists)
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("12 reps"))
        tap("undo-set-change", in: app)
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("12 reps"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("2 sets"))
    }

    @MainActor
    func testPartialNumbersSurviveReopeningWithoutProgress() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "31.", reps: "8", in: app)
        tap("next-day", in: app)
        XCTAssertFalse(selectedExercise(in: app).exists)
        tap("previous-day", in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(selectedExercise(in: app).label.contains("Bench"))
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("0 sets"))
    }

    @MainActor
    func testIncompleteCorrectionKeepsSavedHistoryAndCanBeRestoredAfterRelaunch() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertFalse(element("row-1-weight", in: app).label.contains("Recorded"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        tap("row-1-weight", in: app); replace("135.", in: app); tap("input-done", in: app)
        XCTAssertTrue(element("row-1-status", in: app).label.contains("Enter valid weight."))
        let savedValue = element("row-1-recorded-value", in: app)
        XCTAssertTrue(savedValue.label.contains("Last saved: 135 lb"))
        tap("dock-trends", in: app); tap("trends-records-toggle", in: app)
        XCTAssertTrue(element("records-pr-bench", in: app).label.contains("135 lb"))
        tap("dock-log", in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135. lb"))
        XCTAssertTrue(element("row-1-discard-edit", in: app).exists)
        XCTAssertTrue(element("row-1-discard-edit", in: app).label.contains("Restore saved values"))
        tap("row-1-discard-edit", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertFalse(element("row-1-weight", in: app).label.contains("Recorded"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        XCTAssertFalse(app.buttons["row-1-discard-edit"].exists)
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("1 set"))
        attach("Saved history preserved while a correction needs values", app)
    }

    @MainActor
    func testHistoricalDraftCanResumeAfterGoingToToday() throws {
        let app = launch()
        let mondayID = openDay(0, in: app)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = formatter.timeZone
        let monday = try XCTUnwrap(formatter.date(from: String(mondayID.dropFirst(4))))
        let pastID = "day-" + formatter.string(from: try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: monday)))
        tap("previous-day", in: app)
        let pastDate = element("day-date", in: app).label
        add("Bench", id: "bench", in: app)
        enter(weight: "31.", reps: "8", in: app); tap("input-done", in: app)
        XCTAssertTrue(element("row-1-status", in: app).label.contains("Enter valid weight."))
        tap("go-to-today", in: app)
        XCTAssertNotEqual(element("day-date", in: app).label, pastDate)
        XCTAssertFalse(selectedExercise(in: app).exists)
        tap("back-to-week", in: app); tap("previous-week", in: app)
        XCTAssertTrue(element(pastID, in: app).label.contains("1 set needs values"))
        XCTAssertTrue(element(pastID, in: app).label.contains("0 sets"))
        tap(pastID, in: app)
        XCTAssertEqual(element("day-date", in: app).label, pastDate)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("31."))
        XCTAssertTrue(element("row-1-status", in: app).label.contains("Enter valid weight."))
        attach("Historical unfinished input stays on its original day", app)
    }

    @MainActor
    func testLeavingRowSavesAndRowsStayIndividuallyEditable() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("new-set", in: app)
        replace("145", in: app); tap("input-next", in: app); replace("8", in: app)
        tap("row-1-reps", in: app)
        replace("9", in: app); tap("input-done", in: app)
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("8 reps"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("2 sets"))
        tap(day, in: app)
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("9 reps"))
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("145 lb"))
    }

    @MainActor
    func testWorkoutMarksTheRecordBreakingSetAndKeepsTheCrownOnReturn() {
        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        defer { device.appearance = originalAppearance }
        device.appearance = .light

        let app = launch()
        let today = todayRowID()
        tap(today, in: app)
        tap("previous-day", in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "8", in: app)
        tap("input-done", in: app)
        let crown = app.descendants(matching: .any).matching(identifier: "row-1-pr").firstMatch
        XCTAssertFalse(crown.exists, "A first set establishes the baseline.")

        tap("go-to-today", in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "145", reps: "8", in: app)
        tap("input-done", in: app)
        XCTAssertTrue(crown.waitForExistence(timeout: 3))
        XCTAssertTrue(crown.label.localizedCaseInsensitiveContains("Personal record"))
        XCTAssertTrue(element("last-reference", in: app).label.contains("135 lb"))
        attach("Workout personal record - Light", app)

        tap("repeat-set", in: app)
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("145 lb"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-2-pr").firstMatch.exists,
                       "Repeating the exact performance keeps the crown on the set that earned it.")
        tap("back-to-week", in: app)
        device.appearance = .dark
        tap(today, in: app)
        XCTAssertTrue(crown.waitForExistence(timeout: 3))
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("8 reps"))
        attach("Workout personal record - Espresso", app)
    }

    @MainActor
    func testLastAndPrOpenReadOnlyHistoryBeforeExplicitEditing() throws {
        let app = launch()
        defer { diagnostics(app) }
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        _ = openDay(1, in: app)
        add("Bench", id: "bench", in: app)
        XCTAssertTrue(element("last-reference", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        enter(weight: "200", reps: "5", in: app)
        tap("toggle-entry-references", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        tap("input-done", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        XCTAssertTrue(element("last-reference", in: app).label.contains("135 lb"))
        let originalDate = element("day-date", in: app).label
        tap("last-reference", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        tap("progress-close", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        tap("last-reference", in: app)
        tap("progress-edit-workout", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        tap("row-1-weight", in: app); replace("140", in: app); tap("input-done", in: app)
        tap("history-return-workout", in: app)
        XCTAssertTrue(element("last-reference", in: app).label.contains("140 lb"))
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        attach("Expandable Last and PR history", app)
    }

    @MainActor
    func testWorkoutHistoryShowsEarlierSetsAndReturnsToDraft() {
        let app = launch()
        defer { diagnostics(app) }
        tap("previous-week", in: app)
        let earlier = openDay(6, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("repeat-set", in: app)
        tap("row-2-reps", in: app); replace("8", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        tap("today-week", in: app)
        let today = element(todayRowID(), in: app)
        XCTAssertTrue(today.label.contains("Add workout"))
        attach("Week with today’s date stamp", app)
        today.tap()
        add("Bench", id: "bench", in: app)
        tap("row-1-weight", in: app); replace("31.", in: app); tap("input-done", in: app)
        let day = element("day-date", in: app).label
        let lastTime = app.buttons["last-reference"]
        XCTAssertEqual(lastTime.label, "Last time · 135 lb × 10")
        let firstSet = element("row-1-weight", in: app)
        XCTAssertLessThanOrEqual(lastTime.frame.maxY, firstSet.frame.minY)
        XCTAssertGreaterThanOrEqual(app.buttons["toggle-entry-references"].frame.minY, firstSet.frame.maxY)
        XCTAssertTrue(app.buttons["exercise-history"].isHittable)
        attach("Active Bench workout with prior top set and History", app)
        tap("exercise-history", in: app)
        XCTAssertTrue(app.scrollViews["workout-exercise-history"].exists)
        XCTAssertTrue(element("exercise-history-day-" + String(earlier.dropFirst(4)), in: app).exists)
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "exercise-history-set-"))
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("10 reps"))
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("8 reps"))
        XCTAssertFalse(app.buttons["progress-edit-workout"].exists)
        attach("Read-only exercise history", app)
        tap("close-exercise-history", in: app)
        XCTAssertEqual(element("day-date", in: app).label, day)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
    }

    @MainActor
    func testGroupedPickerSearchAndCustomExerciseRecover() throws {
        let app = launch()
        let day = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        tap("picker-show-results", in: app)
        XCTAssertTrue(element("picker-cable-row", in: app).exists)
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        tap("remove-group-filter", in: app)
        XCTAssertFalse(app.buttons["remove-group-filter"].exists)
        XCTAssertTrue(element("remove-equipment-filter", in: app).exists)
        XCTAssertTrue(element("picker-cable-row", in: app).exists)
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        tap("remove-equipment-filter", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Bench\n")
        XCTAssertTrue(element("picker-bench", in: app).exists)
        tap("picker-bench", in: app)
        openExerciseCatalog(in: app)
        tap("picker-more", in: app); tap("create-exercise", in: app)
        let name = element("custom-name", in: app)
        name.tap(); name.typeText("Travel row")
        tap("custom-group", in: app)
        app.buttons["Back"].firstMatch.tap()
        tap("custom-equipment", in: app)
        app.buttons["Cable"].firstMatch.tap()
        tap("save-custom-exercise", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Travel row")
        enter(weight: "50", reps: "8", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        app.terminate(); app.launch()
        tap(day, in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Travel row")
        openExerciseCatalog(in: app)
        tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        tap("picker-show-results", in: app)
        search.tap(); search.typeText("Travel row\n")
        let custom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "picker-custom-", "Travel row")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        XCTAssertTrue(custom.label.contains("added"))
        attach("Grouped local exercise picker", app)
        let customID = String(custom.identifier.dropFirst("picker-".count))
        tap("close-exercise-picker", in: app)
        XCTAssertTrue(element("add-exercise", in: app).isHittable)
        let customMovement = element("exercise-\(customID)", in: app)
        XCTAssertTrue(customMovement.isSelected)
        XCTAssertGreaterThanOrEqual(customMovement.frame.height, 44 - 0.01)
        XCTAssertTrue(element("exercise-bench", in: app).isHittable)
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-bench", in: app).label.contains("No sets yet"))
        XCTAssertTrue(element("day-exercise-\(customID)", in: app).label.contains("1 set"))
        attach("Day exercise index and actual set counts", app)
        tap("day-exercise-bench", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        tap("all-exercises", in: app)
        tap("day-exercise-\(customID)", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("50 lb"))
        tap("all-exercises", in: app)
        tap("day-list-add-exercise", in: app)
        _ = element("picker-search", in: app)
        tap("close-exercise-picker", in: app)
        app.terminate(); app.launch()
        XCTAssertEqual(selectedExercise(in: app).label, "Travel row")
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("8 reps"))
    }

    @MainActor
    func testRoundedUnitFocusDoesNotChangeStoredPounds() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "1", reps: "10", in: app); tap("input-done", in: app)
        changeUnit("kg", in: app)
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "0.45")
        tap("input-done", in: app)
        changeUnit("lb", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains(", 1 lb"))
    }

    @MainActor
    func testNextSetReusesBlankRowAndLastValuesSaveImmediately() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("new-set", in: app); tap("new-set", in: app)
        XCTAssertTrue(element("row-2-weight", in: app).exists)
        XCTAssertFalse(app.buttons["row-3-weight"].exists)
        tap("input-done", in: app)
        tap("set-2-actions", in: app)
        tap("prefill-row-2", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "135")
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("10 reps"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-2-status").firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("10 reps"))
        tap("row-2-weight", in: app)
        tap("input-done", in: app)
        XCTAssertFalse(element("row-2-weight", in: app).label.contains("Recorded"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-2-status").firstMatch.exists)
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("2 sets"))
        attach("One blank next row and saved last values", app)
    }

    @MainActor
    func testPickerFiltersAndOrderedMultipleExerciseAddition() throws {
        let app = launch()
        let day = openDay(0, in: app)
        openExerciseCatalog(in: app)
        tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        tap("picker-show-results", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Bench")
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        tap("picker-filter-toggle", in: app)
        tap("clear-exercise-filters", in: app)
        tap("picker-show-results", in: app)
        XCTAssertEqual(element("exercise-search", in: app).value as? String, "Bench")
        XCTAssertTrue(element("picker-bench", in: app).exists)
        tap("picker-more", in: app); tap("picker-select-multiple", in: app)
        tap("picker-dumbbell-bench", in: app); tap("picker-bench", in: app)
        XCTAssertTrue(element("picker-dumbbell-bench", in: app).isSelected)
        XCTAssertTrue(element("picker-dumbbell-bench", in: app).label.contains("selected 1"))
        XCTAssertTrue(element("picker-bench", in: app).label.contains("selected 2"))
        tap("picker-filter-toggle", in: app); tap("equipment-Barbell", in: app)
        tap("picker-show-results", in: app)
        XCTAssertFalse(app.buttons["picker-dumbbell-bench"].exists)
        XCTAssertTrue(element("picker-bench", in: app).isSelected)
        XCTAssertTrue(element("picker-bench", in: app).label.contains("selected 2"))
        XCTAssertTrue(element("picker-add-selected", in: app).label.contains("2"))
        tap("remove-equipment-filter", in: app)
        XCTAssertTrue(element("picker-dumbbell-bench", in: app).label.contains("selected 1"))
        XCTAssertTrue(element("picker-bench", in: app).label.contains("selected 2"))
        tap("picker-clear-search", in: app)
        XCTAssertFalse(app.buttons["picker-clear-search"].exists)
        XCTAssertTrue(element("picker-dumbbell-bench", in: app).isSelected)
        XCTAssertTrue(element("picker-add-selected", in: app).label.contains("2"))
        tap("picker-add-selected", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Dumbbell bench")
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-bench", in: app).label.contains("No sets yet"))
        XCTAssertTrue(element("day-exercise-dumbbell-bench", in: app).label.contains("No sets yet"))
        tap("close-day-exercises", in: app); tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("0 sets"))
        attach("Consistent filters and multiple exercise setup without records", app)
    }

    @MainActor
    func testPreviousWorkoutStructureDoesNotCopyRecordsOrOverwriteDrafts() throws {
        let app = launch()
        let source = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        add("Deadlift", id: "deadlift", in: app)
        enter(weight: "225", reps: "5", in: app); tap("input-done", in: app)
        tap("next-day", in: app)
        tap("choose-workout", in: app)
        tap("workout-library-tab-recent", in: app)
        tap("reuse-workout-" + source, in: app)
        for result in ["135 lb × 10", "225 lb × 5"] {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", result)).firstMatch.exists, result)
        }
        attach("Recent workout with its saved sets", app)
        tap("apply-recent-workout", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("—"))
        tap("row-1-weight", in: app); replace("95", in: app); tap("input-done", in: app)
        openExerciseCatalog(in: app); tap("picker-more", in: app); tap("reuse-workout", in: app)
        tap("reuse-workout-" + source, in: app)
        tap("apply-recent-workout", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("95 lb"))
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-deadlift", in: app).label.contains("No sets yet"))
        tap("close-day-exercises", in: app); tap("back-to-week", in: app)
        XCTAssertTrue(element("week-summary", in: app).label.contains("2 sets"))
        attach("Previous exercise structure preserves destination draft and history", app)
    }

    @MainActor
    func testHiddenRecordedExercisesRemainInTheFullDayList() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        add("Deadlift", id: "deadlift", in: app)
        enter(weight: "225", reps: "5", in: app); tap("input-done", in: app)
        for id in ["deadlift", "bench"] {
            tap("hide-exercise-menu", in: app)
            tap("hide-exercise-" + id, in: app)
            XCTAssertTrue(app.buttons["exercise-" + id].waitForNonExistence(timeout: 3))
        }
        XCTAssertTrue(reveal("workout-options", in: app).isHittable)
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-deadlift", in: app).label.localizedCaseInsensitiveContains("hidden"))
        tap("day-exercise-deadlift", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("225 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("2 sets"))
        attach("Hidden movements retain discoverable recorded sets", app)
    }

    @MainActor
    func testWeightDialPreservesTypedPrecisionAndSettlesInBothDirections() throws {
        let app = launch()
        tap(todayRowID(), in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "8", in: app)
        tap("input-done", in: app)
        tap("row-1-weight", in: app)
        replace("127.25", in: app)
        tap("input-use-dial", in: app)
        let dial = element("weight-dial", in: app)
        func pounds() throws -> Double {
            let value = try XCTUnwrap(dial.value as? String)
            return try XCTUnwrap(Double(value.components(separatedBy: " ").first ?? ""))
        }
        func drag(by distance: CGFloat, speed: CGFloat = 160, hold: TimeInterval = 0.35) {
            let from = dial.coordinate(withNormalizedOffset: CGVector(dx: distance < 0 ? 0.75 : 0.25, dy: 0.4))
            from.press(forDuration: 0.08, thenDragTo: from.withOffset(CGVector(dx: distance, dy: 0)),
                       withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: hold)
        }
        XCTAssertEqual(try pounds(), 127.25)
        attach("Weight dial before turning", app)
        drag(by: -96)
        let heavier = try pounds()
        XCTAssertEqual(heavier, 135, "A slow 96-point turn from 127.25 lb should settle three increments higher.")
        XCTAssertEqual(heavier.truncatingRemainder(dividingBy: 2.5), 0)
        try XCTContext.runActivity(named: "Turn below and across a single click") { _ in
            drag(by: -17, speed: 600, hold: 0)
            XCTAssertEqual(try pounds(), 135, "Releasing short of the click must keep the saved weight.")
            drag(by: -23, speed: 120, hold: 0)
            XCTAssertEqual(try pounds(), 137.5, "Crossing one click should advance one weight increment.")
            drag(by: 23)
            XCTAssertEqual(try pounds(), 135)
        }
        drag(by: 40)
        let lighter = try pounds()
        XCTAssertLessThan(lighter, heavier)
        drag(by: -73, speed: 600, hold: 0)
        let settled = try pounds()
        XCTAssertGreaterThan(settled, lighter)
        XCTAssertLessThanOrEqual(settled - lighter, 7.5, "A fast 73-point turn should land within three 2.5 lb increments.")
        XCTAssertEqual(settled.truncatingRemainder(dividingBy: 2.5), 0)
        attach("Weight dial after settling", app)
        tap("input-done", in: app)
        app.terminate()
        app.launch()
        tap("row-1-weight", in: app)
        XCTAssertEqual(try pounds(), settled)
    }


    @MainActor
    func testFastDecimalTypingAndFingerDial() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        for row in 1...3 {
            tap("row-\(row)-weight", in: app)
            XCTAssertTrue(element("weight-dial", in: app).exists)
            XCTAssertFalse(app.keyboards.firstMatch.exists)
            XCTAssertFalse(app.buttons["input-mode"].exists)
            for value in ["152.5", "127.25", "135", "152.5"] {
                replace(value, in: app)
                XCTAssertEqual(element("set-input", in: app).value as? String, value)
                XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "weight-dial").firstMatch.exists)
            }
            tap("input-next", in: app); replace("10", in: app); tap("input-done", in: app)
            if row < 3 { tap("new-set", in: app) }
        }
        tap("row-3-weight", in: app)
        replace("152.5", in: app)
        tap("input-increase", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let dial = element("weight-dial", in: app)
        let beforeDrag = try XCTUnwrap(dial.value as? String)
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)).press(forDuration: 0.1,
            thenDragTo: dial.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)))
        XCTAssertNotEqual(dial.value as? String, beforeDrag)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("input-done", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("152.5 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("3 sets"))
    }

    @MainActor
    func testLargeTextKeepsEditingActionsReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("next-week", in: app); tap("today-week", in: app)
        XCTAssertTrue(element("week-month", in: app).exists)
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        let newSet = reveal("new-set", in: app)
        XCTAssertGreaterThanOrEqual(newSet.frame.height, 44 - 0.01)
        newSet.tap()
        XCTAssertTrue(element("input-done", in: app).isHittable)
        XCTAssertTrue(element("input-next", in: app).isHittable)
        XCTAssertGreaterThanOrEqual(element("input-next", in: app).frame.width, 44)
        XCTAssertGreaterThanOrEqual(element("input-done", in: app).frame.width, 44)
        XCTAssertTrue(element("input-field-label", in: app).label.contains("Weight"))
        XCTAssertTrue(element("input-field-label", in: app).label.contains("lb"))
        replace("135", in: app); tap("input-next", in: app)
        XCTAssertTrue(element("input-field-label", in: app).label.contains("Reps"))
        replace("10", in: app)
        let nextSet = element("input-next-set", in: app)
        XCTAssertTrue(nextSet.isHittable)
        // Screen-coordinate conversion can introduce floating-point roundoff.
        XCTAssertGreaterThanOrEqual(nextSet.frame.height, 44 - 0.01)
        attach("Large text automatic entry", app)
        tap("input-done", in: app)
        changeUnit("kg", in: app)
        XCTAssertEqual(element("weight-unit-toggle", in: app).value as? String, "Kilograms")
        let originalDate = element("day-date", in: app).label
        tap("next-day", in: app)
        XCTAssertNotEqual(element("day-date", in: app).label, originalDate)
        tap("previous-day", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        attach("Large text day navigation", app)
        add("Cable row", id: "cable-row", in: app)
        for id in ["exercise-bench", "exercise-cable-row"] {
            let movement = reveal(id, in: app)
            let workout = app.scrollViews["day-scroll"]
            XCTAssertTrue(movement.isHittable)
            XCTAssertGreaterThanOrEqual(movement.frame.height, 44 - 0.01)
            XCTAssertGreaterThanOrEqual(movement.frame.minX, workout.frame.minX)
            XCTAssertLessThanOrEqual(movement.frame.maxX, workout.frame.maxX)
        }
        attach("Movement list fits at the largest text size", app)
        tap("all-exercises", in: app)
        _ = element("day-exercises-title", in: app)
        attach("All exercises at large text size", app)
        tap("close-day-exercises", in: app)
        tap("row-1-weight", in: app)
        replace("45", in: app)
        let previous = app.buttons["input-previous-exercise"]
        XCTAssertTrue(previous.isHittable)
        XCTAssertGreaterThanOrEqual(previous.frame.height, 44 - 0.01)
        XCTAssertTrue(element("input-done", in: app).isHittable)
        attach("Exercise switching with the keyboard at the largest text size", app)
        previous.tap()
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
    }

    @MainActor
    func testLearnFindsExercisesByDisplayedMuscleAndCommonName() {
        let app = launch()
        openLibraryExercises(in: app)
        let search = element("learn-search", in: app)
        search.tap()
        search.typeText("hamstrings\n")
        let result = app.buttons["learn-exercise-romanian-deadlift"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.localizedCaseInsensitiveContains("hamstrings"))
        attach("Learn results for hamstrings", app)
        tap("learn-search-clear", in: app)
        search.tap()
        search.typeText("pull up\n")
        XCTAssertTrue(app.buttons["learn-exercise-pull-up"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLearnSearchClearAndBackPreserveResults() throws {
        let app = launch()
        openLibraryExercises(in: app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("back-to-learn", in: app)
        XCTAssertEqual(search.value as? String, "Bench")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("learn-search-clear", in: app)
        XCTAssertEqual(search.value as? String, "")
        search.tap(); search.typeText("zzzz-no-match\n")
        XCTAssertTrue(element("learn-empty-state", in: app).exists)
        attach("Learn no matches", app)
        tap("learn-empty-clear", in: app)
        XCTAssertEqual(search.value as? String, "")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("learn-exercise-hip-thrust", in: app)
        let title = element("form-guide-hip-thrust", in: app)
        XCTAssertTrue(app.frame.contains(title.frame))
        XCTAssertGreaterThanOrEqual(title.frame.minY, element("learn-navigation", in: app).frame.maxY - 1)
        tap("back-to-learn", in: app)
        XCTAssertTrue(element("learn-exercise-hip-thrust", in: app).isHittable)
    }

    @MainActor
    func testLearnGuideBackRestoresFilteredListAndReselectClearsSearch() throws {
        let app = launch()
        openLibraryExercises(in: app)
        let search = element("learn-search", in: app)
        let landingY = search.frame.minY
        search.tap()
        search.typeText("Barbell\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))

        let list = app.scrollViews["learn-scroll"]
        func visibleExercise() throws -> XCUIElement {
            let visibleArea = list.frame.intersection(app.frame)
                .intersection(CGRect(x: 0, y: 0, width: app.frame.width, height: app.buttons["dock-library"].frame.minY))
            let exerciseButtons = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "learn-exercise-"))
            return try XCTUnwrap(exerciseButtons.allElementsBoundByIndex.first {
                visibleArea.contains($0.frame) && $0.isHittable
            })
        }
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -145)),
            withVelocity: .slow, thenHoldForDuration: 0.25)
        let exercise = try visibleExercise()
        let guideID = "form-guide-" + exercise.identifier.dropFirst("learn-exercise-".count)
        let exerciseY = exercise.frame.minY
        exercise.tap()
        XCTAssertTrue(element(guideID, in: app).exists)
        tap("back-to-learn", in: app)
        XCTAssertTrue(exercise.isHittable)
        XCTAssertEqual(exercise.frame.minY, exerciseY, accuracy: 2)

        list.swipeDown()
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.value as? String, "Barbell")
        let next = try visibleExercise()
        let nextGuideID = "form-guide-" + next.identifier.dropFirst("learn-exercise-".count)
        next.tap()
        XCTAssertTrue(element(nextGuideID, in: app).exists)
        tap("dock-library", in: app)
        XCTAssertTrue(element("library-workouts", in: app).isSelected)
        tap("library-exercises", in: app)
        XCTAssertTrue(search.isHittable)
        XCTAssertEqual(search.value as? String, "")
        XCTAssertEqual(search.frame.minY, landingY, accuracy: 2)
        XCTAssertFalse(app.buttons["back-to-learn"].exists)
    }

    @MainActor
    func testLargestTextLearnSearchAndIllustrationsStayReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openLibraryExercises(in: app)
        let search = reveal("learn-search", in: app)
        search.tap(); search.typeText("Bench\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        attach("Larger Text Learn results", app)
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("form-position-bench-1", in: app)
        let done = element("close-form-position", in: app)
        XCTAssertTrue(done.isHittable)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44 - 0.01)
        attach("Larger Text enlarged form", app)
        done.tap()
        tap("back-to-learn", in: app)
        XCTAssertEqual(element("learn-search", in: app).value as? String, "Bench")
        tap("learn-search-clear", in: app)
        XCTAssertEqual(element("learn-search", in: app).value as? String, "")
    }

    @MainActor
    func testLearnFormPositionsOpenAndDismiss() throws {
        let app = launch()
        openLibraryExercises(in: app)
        attach("Learn library", app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("exercise-muscles-bench", in: app).exists)
        attach("Learn exercise guide", app)
        tap("form-position-bench-1", in: app)
        XCTAssertTrue(element("form-position-detail", in: app).exists)
        attach("Learn enlarged form", app)
        tap("close-form-position", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "close-form-position")
            .firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
    }

    @MainActor
    func testDockKeepsUnfinishedSetsAndProfileDetailsRecover() throws {
        let app = launch()
        attach("Standard bottom bar", app)
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "31.", reps: "8", in: app)
        tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        tap("dock-profile", in: app)
        assertProfileDestinations(in: app)
        tap("profile-settings", in: app)
        tap("profile-details", in: app)
        let name = element("profile-name", in: app)
        name.tap(); name.typeText("Jae")
        XCTAssertFalse(app.textFields["profile-email"].exists)
        tap("profile-save", in: app)
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        tap("profile-weight-units", in: app)
        tap("preference-kg", in: app)
        tap("close-settings", in: app)
        tap("close-profile-settings", in: app)
        openLibraryExercises(in: app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        XCTAssertTrue(element("form-source", in: app).exists)
        tap("dock-profile", in: app); tap("dock-library", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("dock-log", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
        tap("input-done", in: app)
        app.terminate(); app.launch()
        tap("dock-profile", in: app)
        assertProfileDestinations(in: app)
        tap("profile-settings", in: app)
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        tap("profile-weight-units", in: app)
        XCTAssertTrue(element("preference-kg", in: app).isSelected)
        attach("Local profile and unit setting", app)
    }

    @MainActor
    func testPrivacyAndSupportAreReachableFromSettings() {
        let app = launch()
        tap("dock-profile", in: app)
        tap("profile-settings", in: app)
        XCTAssertTrue(reveal("profile-privacy-policy", in: app).isHittable)
        XCTAssertTrue(reveal("profile-contact-support", in: app).isHittable)
    }

    @MainActor
    func testBackupSettingsExposeExportAndValidatedRestoreActions() throws {
        let app = launch()
        tap("dock-profile", in: app)
        tap("profile-settings", in: app)
        XCTAssertTrue(element("profile-storage-explanation", in: app).exists)
        tap("profile-weight-units", in: app)
        XCTAssertTrue(element("preference-lb", in: app).exists)
        tap("close-settings", in: app)
        tap("profile-backup", in: app)
        XCTAssertTrue(app.staticTexts["Workout recovery"].exists)
        XCTAssertTrue(app.buttons["choose-backup-folder"].isHittable)
        attach("Workout recovery with automatic backup setup", app)
        XCTAssertFalse(app.buttons["preference-lb"].exists)
        for id in ["restore-import", "restore-pre-restore-backup", "export-backup", "export-csv", "export-pre-restore-backup"] {
            reveal(id, in: app)
            XCTAssertTrue(element(id, in: app).isHittable)
        }
        tap("restore-pre-restore-backup", in: app)
        reveal("backup-status", in: app)
        XCTAssertTrue(element("backup-status", in: app).label.contains("no pre-restore copy"))
        tap("close-settings", in: app)
        attach("Workout recovery settings", app)
    }

    @MainActor
    func testExerciseProgressShowsSavedSetsAndReturnsToCurrentWorkout() throws {
        let app = launch()
        defer { diagnostics(app) }
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        let originalDate = element("day-date", in: app).label
        tap("exercise-progress", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        XCTAssertTrue(element("progress-range-3m", in: app).isSelected)
        tap("progress-range-1m", in: app)
        XCTAssertTrue(element("progress-range-1m", in: app).isSelected)
        let sessionID = "progress-session-" + String(day.dropFirst(4))
        for _ in 0..<10 {
            if app.buttons[sessionID].exists { break }
            app.scrollViews["progress-scroll"].swipeUp()
        }
        tap(sessionID, in: app)
        let set = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress-recorded-set-")).firstMatch
        XCTAssertTrue(set.exists && set.label.contains("135 lb"))
        tap("progress-back", in: app)
        tap("progress-return-workout", in: app)
        XCTAssertFalse(app.scrollViews["progress-scroll"].exists)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        attach("Exercise progress preserves current workout", app)
    }

    @MainActor
    func testPlanningReflectsTypedSetBeforeDone() throws {
        let app = launch()
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app)
        XCTAssertTrue(element("set-input", in: app).exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        tap("edit-exercise-plan", in: app)
        XCTAssertTrue(app.scrollViews["exercise-plan-editor"].exists)
        tap("save-exercise-plan", in: app)
        XCTAssertTrue(element("working-set-completion", in: app).label.contains("1 of 3"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        tap("input-done", in: app)
        XCTAssertTrue(element("working-set-completion", in: app).label.contains("1 of 3"))
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertFalse(element("row-1-weight", in: app).label.contains("Recorded"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-status").firstMatch.exists)
        attach("Plan targets reflect sets saved during input", app)
    }

    @MainActor
    func testSetTypeSheetKeepsWorkoutVisibleAndAllThreeChoicesWithinReach() throws {
        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        defer { device.appearance = originalAppearance }
        device.appearance = .light

        let app = launch(extra: ["--sample-data"])
        tap(todayRowID(), in: app)
        let exercise = selectedExercise(in: app).label
        tap("row-1-type", in: app)
        if !element("set-type-working", in: app).isSelected {
            tap("set-type-working", in: app)
            tap("row-1-type", in: app)
        }

        let sheet = app.scrollViews["set-type-picker"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(sheet.frame.minY, app.frame.height * 0.30,
                             "The compact sheet should leave the top of the workout visible.")
        XCTAssertTrue(app.staticTexts["Set type"].isHittable)
        let context = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", exercise, "Set 1")
        ).firstMatch
        XCTAssertTrue(context.isHittable)
        for id in ["warmup", "working", "drop"] {
            let option = element("set-type-\(id)", in: app)
            XCTAssertTrue(option.isHittable)
            XCTAssertGreaterThanOrEqual(option.frame.height, 44)
        }
        XCTAssertTrue(element("set-type-working", in: app).isSelected)
        attach("Compact set type picker - Light", app)

        device.appearance = .dark
        tap("set-type-warmup", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Warm-up"))
        tap("row-1-type", in: app)
        XCTAssertTrue(element("set-type-warmup", in: app).isSelected)
        attach("Compact set type picker - Espresso", app)
        tap("set-type-working", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Working set"))
        attach("Workout set type controls - Espresso", app)
    }

    @MainActor
    func testSeparateSetTypeColumnSavesChoicesBeforeDone() throws {
        let app = launch()
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Working set"))
        let type = element("row-1-type", in: app)
        XCTAssertEqual(type.elementType, .button)
        XCTAssertGreaterThanOrEqual(type.frame.height, 44)
        XCTAssertGreaterThanOrEqual(type.frame.width, 44)
        tap("edit-exercise-plan", in: app); tap("save-exercise-plan", in: app)
        enter(weight: "135", reps: "10", in: app)
        XCTAssertTrue(element("set-input", in: app).exists)
        tap("row-1-type", in: app)
        for id in ["working", "warmup", "drop"] {
            XCTAssertTrue(element("set-type-\(id)", in: app).exists)
        }
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "set-type-regular").firstMatch.exists)
        XCTAssertTrue(element("set-type-working", in: app).isSelected)
        XCTAssertFalse(app.buttons["save-set-type"].exists)
        tap("set-type-warmup", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Warm-up"))
        XCTAssertTrue(element("working-set-completion", in: app).label.contains("0 of 3"))
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Warm-up"))
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        for (id, title, count) in [("working", "Working set", 1), ("drop", "Drop set", 0), ("working", "Working set", 1)] {
            tap("row-1-type", in: app); tap("set-type-\(id)", in: app)
            XCTAssertTrue(element("row-1-type", in: app).label.contains(title))
            XCTAssertTrue(element("working-set-completion", in: app).label.contains("\(count) of 3"))
        }
        tap("new-set", in: app)
        XCTAssertTrue(element("row-2-type", in: app).label.contains("Working set"))
        attach("Separate type buttons save without Done", app)
    }

    @MainActor
    func testDropSetStagesSaveRepeatRemoveAndDeleteAsOneSet() throws {
        let app = launch()
        let day = openDay(0, in: app); add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("row-1-type", in: app); tap("set-type-drop", in: app)
        tap("row-1-add-drop", in: app)
        XCTAssertTrue(element("input-set-context", in: app).label.contains("Set 1 · Drop 1"))
        replace("95", in: app); tap("input-next", in: app); replace("8", in: app)
        XCTAssertTrue(element("row-1-drop-1-weight", in: app).label.contains("95 lb"))
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-1-drop-1-reps", in: app).label.contains("8 reps"))
        XCTAssertTrue(element("input-set-context", in: app).label.contains("Set 1 · Drop 1"))
        tap("row-1-add-drop", in: app)
        replace("65", in: app); tap("input-next", in: app); replace("6", in: app)
        tap("input-done", in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "set-row-2").firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(element("row-1-drop-2-weight", in: app).label.contains("65 lb"))
        XCTAssertTrue(element("row-1-drop-2-reps", in: app).label.contains("6 reps"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("1 set"))
        tap(day, in: app)
        tap("row-1-drop-1-actions", in: app); tap("row-1-drop-1-remove", in: app)
        XCTAssertTrue(element("row-1-drop-1-weight", in: app).label.contains("65 lb"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-1-drop-2-weight").firstMatch.exists)
        tap("repeat-set", in: app)
        XCTAssertTrue(element("row-2-type", in: app).label.contains("Drop set"))
        XCTAssertTrue(element("row-2-drop-1-weight", in: app).label.contains("65 lb"))
        tap("set-2-actions", in: app); tap("delete-row-2", in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "set-row-2").firstMatch.exists)
        tap("undo-set-change", in: app)
        XCTAssertTrue(element("row-2-drop-1-weight", in: app).label.contains("65 lb"))
        tap("row-1-type", in: app)
        XCTAssertTrue(element("drop-set-split-notice", in: app).exists)
        tap("set-type-working", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Working set"))
        XCTAssertTrue(element("row-2-weight", in: app).label.contains("65 lb"))
        attach("One drop set with editable stages and whole-set actions", app)
    }

    @MainActor
    func testLoggingPrioritizesSetValuesAndKeepsOptionalEffortInActions() throws {
        let app = launch()
        defer { diagnostics(app) }
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        XCTAssertGreaterThanOrEqual(reveal("edit-exercise-plan", in: app).frame.height, 44)
        let weight = reveal("row-1-weight", in: app)
        let reps = element("row-1-reps", in: app)
        XCTAssertEqual(weight.frame.midY, reps.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(weight.frame.height, 44)
        XCTAssertGreaterThanOrEqual(reps.frame.height, 44)
        XCTAssertFalse(app.buttons["row-1-details"].exists)
        tap("set-1-actions", in: app)
        XCTAssertTrue(element("row-1-details", in: app).exists)
        tap("row-1-details", in: app)
        XCTAssertTrue(element("set-reps-left", in: app).exists)
        tap("cancel-set-details", in: app)
        XCTAssertTrue(element("exercise-bench", in: app).isSelected)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        attach("Compact logging and contextual effort actions", app)
    }

    @MainActor
    func testLargeTextKeepsSetTypeAndEffortSeparate() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        app.scrollViews["day-scroll"].swipeUp()
        let type = reveal("row-1-type", in: app)
        XCTAssertGreaterThanOrEqual(type.frame.height, 44)
        XCTAssertGreaterThanOrEqual(type.frame.width, 44)
        type.tap()
        let close = element("close-set-type", in: app)
        let closePosition = close.frame.midY
        app.scrollViews["set-type-picker"].swipeUp()
        XCTAssertTrue(close.isHittable)
        XCTAssertEqual(close.frame.midY, closePosition, accuracy: 1,
                       "Close stays in reach when larger text requires scrolling.")
        attach("Set type picker - Larger Text", app)
        tap("set-type-drop", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Drop set"))
        tap("row-1-details", in: app)
        XCTAssertTrue(element("set-reps-left", in: app).exists)
        XCTAssertFalse(app.buttons["set-type-drop"].exists)
        tap("cancel-set-details", in: app)
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Drop set"))
        attach("Larger Text type control and optional effort", app)
    }

    @MainActor
    func testWarmupAndRepsLeftPreserveRecordedValuesAndRepeatedEffortStaysUnknown() throws {
        let app = launch()
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        tap("edit-exercise-plan", in: app); tap("save-exercise-plan", in: app)
        enter(weight: "45", reps: "10", in: app); tap("input-done", in: app)
        tap("row-1-type", in: app)
        tap("set-type-warmup", in: app)
        tap("row-1-details", in: app)
        tap("set-reps-left", in: app); tap("set-reserve-4", in: app)
        tap("save-set-details", in: app)
        XCTAssertTrue(element("working-set-completion", in: app).label.contains("0 of 3"))
        XCTAssertTrue(element("row-1-type", in: app).label.contains("Warm-up"))
        XCTAssertTrue(element("row-1-effort", in: app).label.contains("4 reps left"))
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("45 lb"))
        tap("repeat-set", in: app)
        XCTAssertTrue(element("row-2-type", in: app).label.contains("Warm-up"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "row-2-effort").firstMatch.exists)
        attach("Warm-ups are distinct and repeated effort is unknown", app)
    }

    @MainActor
    func testTrendsStrengthChartSwitchesExercisesWithinTheWindow() throws {
        continueAfterFailure = false
        let app = launch(extra: ["--sample-data"])
        // The weekly sample varies by weekday; create the second lift explicitly.
        _ = openDay(0, in: app)
        add("Overhead press", id: "overhead-press", in: app)
        enter(weight: "65", reps: "8", in: app)
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        tap("dock-trends", in: app)
        attach("Strength Trends overview", app)
        let picker = element("trends-strength-picker", in: app)
        XCTAssertEqual(picker.value as? String, "Bench")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Bench"))
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("145 lb"))
        tap("trends-strength-previous-day", in: app)
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("135 lb"))
        tap("trends-strength-next-day", in: app)
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("145 lb"))
        element("trends-strength-chart", in: app)
            .coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.45)).tap()
        XCTAssertFalse(element("trends-strength-latest", in: app).label.contains("145 lb"))
        picker.tap()
        tap("trends-strength-exercise-overhead-press", in: app)
        XCTAssertEqual(picker.value as? String, "Overhead press")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Overhead press"))
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("65 lb"))
        attach("Strength Trends selected exercise", app)
        tap("trends-range-1m", in: app)
        XCTAssertEqual(picker.value as? String, "Overhead press")
        XCTAssertTrue(element("trends-range-1m", in: app).isSelected)
        tap("trends-range-3m", in: app)
        picker.tap(); tap("trends-strength-exercise-bench", in: app)
        tap("trends-strength-history", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        XCTAssertTrue(element("progress-chart", in: app).label.contains("Bench"))
        tap("progress-close", in: app)
        XCTAssertEqual(element("trends-strength-picker", in: app).value as? String, "Bench")
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
    }

    @MainActor
    func testLargestTextStrengthChartControlsStayReachable() throws {
        continueAfterFailure = false
        let app = launch(extra: ["--sample-data", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-trends", in: app)
        let picker = reveal("trends-strength-picker", in: app)
        XCTAssertGreaterThanOrEqual(picker.frame.height, 44 - 0.01)
        picker.tap(); tap("trends-strength-exercise-bench", in: app)
        XCTAssertEqual(picker.value as? String, "Bench")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Bench"))
        attach("Larger Text strength progress", app)
        let history = reveal("trends-strength-history", in: app)
        XCTAssertTrue(history.isHittable)
        XCTAssertGreaterThanOrEqual(history.frame.height, 44 - 0.01)
        attach("Larger Text strength values and history", app)
        history.tap()
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        tap("progress-close", in: app)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
    }

    @MainActor
    func testTrendsShowsRecordedActivityAndPreservesWorkout() throws {
        let app = launch()
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        let originalDate = element("day-date", in: app).label
        tap("dock-trends", in: app)
        XCTAssertTrue(element("dock-trends", in: app).isSelected)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        XCTAssertTrue(element("trends-range-3m", in: app).isSelected)
        for range in ["1m", "3m", "6m", "1y"] {
            let identifier = "trends-range-\(range)"
            tap(identifier, in: app)
            XCTAssertTrue(element(identifier, in: app).isSelected)
        }
        XCTAssertTrue(element("trends-period-summary", in: app).exists)
        tap("trends-exercise-bench", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        XCTAssertTrue(element("progress-range-1y", in: app).isSelected)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        XCTAssertTrue(element("trends-range-1y", in: app).isSelected)
        tap("dock-log", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        attach("Trends preserves the current workout", app)
    }

    @MainActor
    func testEmptyTrendsHasActionWithoutFakeCharts() throws {
        let app = launch()
        tap("dock-trends", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "trends-period-summary").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "trends-records-toggle").firstMatch.exists)
        XCTAssertFalse(app.buttons["trends-history"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "trends-strength-chart").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "trends-strength-picker").firstMatch.exists)
        tap("trends-empty-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
        XCTAssertTrue(element("dock-log", in: app).isSelected)
    }

    @MainActor
    func testTrendsHistoryCatalogFindsRecordedExercise() throws {
        let app = launch()
        _ = openDay(0, in: app); add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("dock-trends", in: app); tap("trends-history", in: app)
        let search = element("progress-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("progress-exercise-bench", in: app)
        XCTAssertTrue(element("progress-chart", in: app).exists)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        tap("dock-log", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
    }

    @MainActor
    func testTrendsAllTimeRecordsOpenTheRecordedSet() throws {
        let app = launch()
        defer { diagnostics(app) }
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        add("Deadlift", id: "deadlift", in: app)
        enter(weight: "225", reps: "5", in: app); tap("input-done", in: app)
        add("Squat", id: "squat", in: app)
        enter(weight: "185", reps: "8", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("185 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("8 reps"))
        tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        tap("dock-trends", in: app); tap("trends-records-toggle", in: app)
        XCTAssertTrue(element("big-three-total", in: app).label.contains("545 lb"))
        XCTAssertTrue(element("records-pr-bench", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("records-pr-deadlift", in: app).label.contains("225 lb"))
        attach("Big 3 breakdown and actual PRs", app)
        tap("records-pr-bench", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        tap("dock-log", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Squat")
        tap("dock-trends", in: app)
        tap("trends-records-toggle", in: app)
        tap("records-pr-bench", in: app)
        tap("progress-edit-workout", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        tap("row-1-weight", in: app); replace("145", in: app); tap("input-done", in: app)
        tap("history-return-workout", in: app)
        XCTAssertEqual(selectedExercise(in: app).label, "Squat")
        tap("dock-trends", in: app)
        tap("trends-records-toggle", in: app)
        XCTAssertTrue(element("big-three-total", in: app).label.contains("555 lb"))
        XCTAssertTrue(element("records-pr-bench", in: app).label.contains("145 lb"))
        tap("dock-profile", in: app)
        assertProfileDestinations(in: app)
    }

    @MainActor
    func testLargestTextTrendsKeepsHistoryAndRecordsReachable() throws {
        let preview = launch(extra: ["--sample-data"])
        tap("dock-trends", in: preview)
        attach("Trends overview", preview)
        preview.terminate()
        let app = launch(extra: ["--sample-data", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-trends", in: app)
        for id in ["trends-history", "trends-records-toggle"] {
            let action = element(id, in: app)
            XCTAssertTrue(action.isHittable)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44 - 0.01)
        }
        attach("Larger Text Trends overview", app)
        tap("trends-records-toggle", in: app)
        XCTAssertEqual(element("trends-records-toggle", in: app).value as? String, "Expanded")
        XCTAssertTrue(element("big-three-total", in: app).exists)
        attach("Larger Text all-time records", app)
        tap("trends-records-toggle", in: app)
        tap("trends-history", in: app)
        XCTAssertTrue(element("progress-search", in: app).exists)
        tap("progress-exercise-bench", in: app)
        XCTAssertTrue(reveal("progress-range-3m", in: app).isSelected)
        attach("Larger Text exercise history range", app)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
    }

    @MainActor
    func testLibraryLearnHasReadOnlyGuidesAndMuscleMaps() {
        let app = launch()
        tap("dock-library", in: app)
        tap("library-learn", in: app)
        XCTAssertTrue(app.buttons["library-learn"].isSelected)
        attach("Library Learn", app)
        for topic in ["form", "muscles"] {
            tap("learn-topic-" + topic, in: app)
            let search = app.textFields["guide-search"]
            search.tap()
            search.typeText("Bench\n")
            tap("guide-exercise-bench", in: app)
            let detailID = topic == "form" ? "form-guide-bench" : "exercise-muscles-bench"
            XCTAssertTrue(element(detailID, in: app).exists)
            XCTAssertFalse(app.buttons["library-edit-exercise"].exists)
            XCTAssertFalse(app.buttons["library-delete-exercise"].exists)
            tap("back-to-guides", in: app)
            XCTAssertEqual(search.value as? String, "Bench")
            tap("back-to-learn-topics", in: app)
        }
        tap("library-exercises", in: app)
        let search = app.textFields["learn-search"]
        search.tap()
        search.typeText("Bench\n")
        tap("learn-exercise-bench", in: app)
        XCTAssertFalse(app.buttons["library-edit-exercise"].exists)
        XCTAssertFalse(app.buttons["library-delete-exercise"].exists)
    }

    @MainActor
    func testDeletingCustomExerciseKeepsItsLoggedSetsAfterRelaunch() {
        let app = launch()
        openLibraryExercises(in: app)
        tap("library-add-exercise", in: app)
        let name = app.textFields["library-exercise-name"]
        name.tap()
        name.typeText("Garage")
        tap("library-save-exercise", in: app)
        tap("library-edit-exercise", in: app)
        name.tap()
        name.typeText(" press")
        tap("library-save-exercise", in: app)
        let title = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'form-guide-custom-'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        XCTAssertEqual(title.label, "Garage press")
        let id = String(title.identifier.dropFirst("form-guide-".count))
        attach("Custom exercise actions", app)
        tap("dock-log", in: app)
        let dayID = openDay(0, in: app)
        add("Garage press", id: id, in: app)
        enter(weight: "45", reps: "8", in: app)
        tap("input-done", in: app)
        tap("dock-library", in: app)
        tap("library-delete-exercise", in: app)
        let confirmation = app.buttons.matching(identifier: "confirm-delete-library-exercise").firstMatch
        if confirmation.exists { confirmation.tap() } else { app.sheets.buttons["Delete exercise"].tap() }
        XCTAssertTrue(app.buttons["library-edit-exercise"].waitForNonExistence(timeout: 4))
        XCTAssertFalse(app.buttons["learn-exercise-" + id].exists)

        app.terminate()
        app.launch()
        if app.buttons[dayID].exists { tap(dayID, in: app) }
        XCTAssertEqual(selectedExercise(in: app).label, "Garage press")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("45 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("8 reps"))
        tap("next-day", in: app)
        tap("add-exercise", in: app)
        let search = app.textFields["picker-search"]
        search.tap()
        search.typeText("Garage press\n")
        XCTAssertFalse(app.buttons["picker-" + id].exists)
    }

    @MainActor
    func testStarterCopyCanBeEditedAndDeletedIndependently() {
        let app = launch()
        tap("dock-library", in: app)
        tap("workout-template-push", in: app)
        XCTAssertFalse(app.buttons["edit-workout-template"].exists)
        XCTAssertFalse(app.buttons["delete-workout-template"].exists)
        tap("copy-workout-template", in: app)
        let name = app.textFields["workout-template-name"]
        name.tap()
        name.typeText(" at home")
        tap("save-workout-template", in: app)
        let personal = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Push at home'")).firstMatch
        XCTAssertTrue(personal.waitForExistence(timeout: 4))
        personal.tap()
        tap("edit-workout-template", in: app)
        name.tap()
        name.typeText(" A")
        tap("save-workout-template", in: app)
        XCTAssertTrue(app.staticTexts["Push at home A"].waitForExistence(timeout: 4))
        tap("delete-workout-template", in: app)
        let confirmation = app.buttons.matching(identifier: "confirm-delete-workout-template").firstMatch
        if confirmation.exists { confirmation.tap() } else { app.sheets.buttons["Delete template"].tap() }
        XCTAssertTrue(personal.waitForNonExistence(timeout: 5))
        tap("workout-library-tab-starters", in: app)
        XCTAssertTrue(app.buttons["workout-template-push"].exists)
    }

    @MainActor
    func testLibraryDockOpensTemplatesAndRetainsExerciseGuide() {
        let app = launch()
        XCTAssertFalse(app.buttons["dock-learn"].exists)
        tap("dock-library", in: app)
        XCTAssertTrue(app.buttons["dock-library"].isSelected)
        XCTAssertTrue(element("library-workouts", in: app).isSelected)
        XCTAssertTrue(app.buttons["workout-template-push"].exists)
        XCTAssertFalse(app.textFields["learn-search"].exists)

        tap("library-exercises", in: app)
        XCTAssertTrue(element("library-exercises", in: app).isSelected)
        XCTAssertFalse(app.buttons["workout-template-push"].exists)
        let search = reveal("learn-search", in: app)
        search.tap(); search.typeText("Bench\n")
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)

        tap("dock-profile", in: app)
        tap("dock-library", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("back-to-learn", in: app)
        XCTAssertEqual(search.value as? String, "Bench")

        tap("library-workouts", in: app)
        XCTAssertTrue(app.buttons["workout-template-push"].exists)
        XCTAssertFalse(app.textFields["learn-search"].exists)
    }

    @MainActor
    func testAdjacentDockPagesKeepTheDockInPlace() {
        let app = launch()
        let ids = ["dock-log", "dock-trends", "dock-library", "dock-profile"]
        let pages = ["week-view", "trends-scroll", "workout-library", "profile-scroll"]
        let dock = element("app-dock", in: app)
        let originalDock = dock.frame
        let originalButtons = ids.map { element($0, in: app).frame }

        for index in [1, 2, 3, 2, 1, 0] {
            tap(ids[index], in: app)
            XCTAssertTrue(element(ids[index], in: app).isSelected)
            XCTAssertTrue(app.scrollViews[pages[index]].exists)
            for other in pages.indices where other != index {
                XCTAssertFalse(app.scrollViews[pages[other]].exists)
            }
            XCTAssertEqual(dock.frame, originalDock)
            for (id, frame) in zip(ids, originalButtons) {
                XCTAssertEqual(element(id, in: app).frame, frame)
            }
        }
    }

    @MainActor
    func testReselectingDockTabsReturnsToLandingViews() {
        let app = launch(extra: ["--sample-data"])
        tap("previous-week", in: app)
        let day = openDay(0, in: app)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
        XCTAssertFalse(app.buttons["back-to-week"].exists)
        XCTAssertTrue(element(day, in: app).isHittable)

        tap("dock-trends", in: app)
        tap("trends-range-1m", in: app)
        let records = element("trends-records-toggle", in: app)
        records.tap()
        XCTAssertEqual(records.value as? String, "Expanded")
        tap("dock-trends", in: app)
        XCTAssertEqual(records.value as? String, "Collapsed")
        XCTAssertTrue(element("trends-range-1m", in: app).isSelected)
        app.terminate()

        let largeText = launch(extra: ["--sample-data", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-profile", in: largeText)
        let settings = element("profile-settings", in: largeText)
        let landingY = settings.frame.minY
        largeText.scrollViews["profile-scroll"].swipeUp()
        XCTAssertTrue(!settings.isHittable || settings.frame.minY < landingY - 10,
            "The Profile must be scrolled before reselection")
        tap("dock-profile", in: largeText)
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(settings.frame.minY, landingY, accuracy: 2)
    }

    @MainActor
    func testLargeTextDockKeepsProfileAndLearningReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        continueAfterFailure = false
        attach("Largest Text bottom bar", app)
        let dock = element("app-dock", in: app)
        // Includes the bottom safe area; leave the page room to remain useful.
        XCTAssertLessThanOrEqual(dock.frame.height, 120)
        let tabs = [("dock-log", "Log"), ("dock-trends", "Trends"), ("dock-library", "Library"), ("dock-profile", "Profile")]
        var tabFrames: [CGRect] = []
        for (id, title) in tabs {
            let tab = element(id, in: app)
            XCTAssertTrue(tab.isHittable)
            XCTAssertEqual(tab.label, title)
            XCTAssertGreaterThanOrEqual(tab.frame.width, 44 - 0.01)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44 - 0.01)
            XCTAssertTrue(dock.frame.contains(tab.frame))
            XCTAssertFalse(tabFrames.contains { !$0.intersection(tab.frame).isEmpty })
            tabFrames.append(tab.frame)
        }
        XCTAssertEqual(tabFrames[0].midY, tabFrames[1].midY, accuracy: 1)
        XCTAssertEqual(tabFrames[2].midY, tabFrames[3].midY, accuracy: 1)
        XCTAssertLessThanOrEqual(tabFrames[0].maxY, tabFrames[2].minY + 0.01)
        XCTAssertTrue(element("dock-log", in: app).isSelected)
        tap("dock-trends", in: app)
        XCTAssertTrue(element("dock-trends", in: app).isSelected)
        XCTAssertTrue(element("trends-empty-log", in: app).exists)
        element("dock-profile", in: app).press(forDuration: 3)
        tap("dock-profile", in: app)
        XCTAssertTrue(element("dock-profile", in: app).isSelected)
        attach("Profile Largest Text bottom bar", app)
        assertProfileDestinations(in: app)
        tap("profile-settings", in: app)
        tap("profile-weight-units", in: app); tap("preference-kg", in: app); tap("close-settings", in: app)
        tap("close-profile-settings", in: app)
        openLibraryExercises(in: app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
        attach("Large text Log Trends Library Profile dock", app)
    }

    @MainActor
    func testFirstWorkoutAndLibraryPreviewBeforeApplyingPushToToday() {
        let app = launch()
        let today = todayRowID()
        tap(today, in: app)
        XCTAssertEqual(element("day-title", in: app).label, "Your first workout")
        XCTAssertTrue(element("first-workout-example", in: app).label.contains("135 lb"))
        XCTAssertTrue(app.buttons["add-exercise"].isHittable)
        XCTAssertTrue(app.buttons["choose-workout"].isHittable)
        attach("Your first workout", app)

        tap("choose-workout", in: app)
        tap("workout-library-tab-personal", in: app)
        tap("workout-library-tab-recent", in: app)
        XCTAssertTrue(app.staticTexts["No recent workouts"].exists)
        tap("close-workout-library", in: app)
        tap("back-to-week", in: app)
        XCTAssertFalse(app.buttons["week-workout-library"].exists)
        tap("dock-library", in: app)
        XCTAssertTrue(app.buttons["workout-template-push"].isHittable)
        attach("Workout library starters", app)
        tap("workout-template-push", in: app)
        attach("Push template preview", app)
        tap("back-to-workout-library", in: app)
        tap("dock-log", in: app)
        XCTAssertTrue(element(today, in: app).label.contains("Add workout"))
        tap("previous-week", in: app)
        tap("dock-library", in: app)
        tap("workout-template-push", in: app)
        tap("apply-workout-template", in: app)
        XCTAssertTrue(app.buttons["dock-log"].isSelected)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertFalse(app.descendants(matching: .any)["first-workout-example"].exists)
        for id in ["bench", "overhead-press", "lateral-raise", "triceps-extension"] {
            XCTAssertTrue(app.buttons["exercise-" + id].isHittable, id)
        }
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("—"))
        attach("Push workout before logging", app)
        tap("back-to-week", in: app)
        let planned = element(today, in: app)
        XCTAssertTrue(planned.label.contains("4 exercises planned"))
        XCTAssertTrue(planned.label.contains("0 sets"))
    }

    @MainActor
    func testSaveActiveWorkoutAsTemplateAndApplyFromLibraryToSelectedDay() {
        let app = launch()
        tap("previous-week", in: app)
        _ = openDay(0, in: app)
        tap("choose-workout", in: app)
        tap("workout-template-push", in: app)
        tap("apply-workout-template", in: app)
        XCTAssertFalse(app.buttons["day-workout-library"].exists)
        tap("workout-options", in: app)
        tap("day-save-template", in: app)
        let name = element("workout-template-name", in: app)
        name.tap()
        name.typeText("Push at home")
        tap("save-workout-template", in: app)
        tap("next-day", in: app)
        add("Cable row", id: "cable-row", in: app)
        let date = element("day-date", in: app).label
        tap("dock-library", in: app)
        tap("workout-library-tab-personal", in: app)
        let stored = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Push at home")).firstMatch
        XCTAssertTrue(stored.waitForExistence(timeout: 5))
        stored.tap()
        let benchPlan = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Bench", "3 working sets · 6–10 reps")
        XCTAssertTrue(app.descendants(matching: .any).matching(benchPlan).firstMatch.exists)
        tap("apply-workout-template", in: app)
        XCTAssertTrue(app.buttons["dock-log"].isSelected)
        XCTAssertEqual(element("day-date", in: app).label, date)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(app.buttons["exercise-cable-row"].exists)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("—"))
    }

    @MainActor
    func testWeekIdentifiesPreparedWorkoutBeforeFirstSet() {
        let app = launch()
        let dayID = openDay(0, in: app)
        tap("choose-workout", in: app)
        element("workout-template-full-body", in: app).tap()
        element("apply-workout-template", in: app).tap()
        XCTAssertTrue(app.buttons["exercise-squat"].waitForExistence(timeout: 5))
        tap("back-to-week", in: app)
        let day = element(dayID, in: app)
        XCTAssertTrue(day.label.contains("4 exercises planned"), day.label)
        XCTAssertTrue(day.label.contains("0 sets"), day.label)
        attach("Four planned exercises in Week", app)
        day.tap()
        XCTAssertTrue(app.buttons["exercise-squat"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testChooseStarterWorkoutKeepsExistingSets() {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "8", in: app)
        tap("input-done", in: app)

        tap("workout-options", in: app)
        tap("choose-workout", in: app)
        element("workout-template-full-body", in: app).tap()
        XCTAssertTrue(element("workout-template-detail", in: app).exists)
        attach("Starter workout preview", app)
        element("apply-workout-template", in: app).tap()

        let expected = ["exercise-bench", "exercise-squat", "exercise-cable-row", "exercise-romanian-deadlift"]
        let movements = app.buttons.allElementsBoundByIndex.filter { expected.contains($0.identifier) }
        XCTAssertEqual(movements.map(\.identifier), expected)
        let squat = app.buttons["exercise-squat"]
        XCTAssertTrue(squat.isSelected)
        XCTAssertEqual(selectedExercise(in: app).label, "Squat")
        attach("Ordered starter workout movements", app)
        app.buttons["exercise-bench"].tap()
        XCTAssertTrue(app.buttons["exercise-bench"].isSelected)
        XCTAssertFalse(squat.isSelected)
        XCTAssertEqual(selectedExercise(in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("8 reps"))

        tap("repeat-set", in: app)
        let undo = element("undo-set-change", in: app)
        tap("exercise-bench", in: app)
        XCTAssertTrue(undo.exists, "Tapping the selected exercise should keep Undo available")
        tap("undo-set-change", in: app)
    }

    @MainActor
    func testPersonalWorkoutCanBeSavedAndReusedAfterReopening() {
        let app = launch()
        _ = openDay(0, in: app)
        tap("choose-workout", in: app)
        tap("workout-library-tab-personal", in: app)
        func submitTemplate() {
            element("create-workout-template", in: app).tap()
            let name = element("workout-template-name", in: app)
            name.tap()
            name.typeText("My row day")
            element("workout-template-add-exercise", in: app).tap()
            let search = element("workout-template-search", in: app)
            search.tap()
            search.typeText("Face pull")
            element("workout-template-exercise-face-pull", in: app).tap()
            element("finish-workout-template-exercises", in: app).tap()
            element("save-workout-template", in: app).tap()
        }

        submitTemplate()
        submitTemplate()
        let validation = element("workout-template-validation", in: app)
        XCTAssertTrue(validation.label.contains("already have a workout with this name"))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(validation.waitForExistence(timeout: 5))
        XCTAssertEqual(element("workout-template-name", in: app).value as? String, "My row day")
        element("cancel-workout-template", in: app).tap()

        app.terminate()
        app.launch()
        let stored = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My row day")).firstMatch
        tap("choose-workout", in: app)
        tap("workout-library-tab-personal", in: app)
        XCTAssertTrue(stored.waitForExistence(timeout: 5))
        attach("Personal workout in the library", app)
        stored.tap()
        element("apply-workout-template", in: app).tap()
        XCTAssertEqual(selectedExercise(in: app).label, "Face pull")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("—"))
    }

    @MainActor private func auditAccessibility(in app: XCUIApplication) throws {
        let previousContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = previousContinueAfterFailure }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Accessibility hierarchy before audit"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        try app.performAccessibilityAudit { issue in
            let details = XCTAttachment(string: "\(issue.auditType)\n\(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No associated element")")
            details.name = "Accessibility audit issue"
            details.lifetime = .keepAlways
            self.add(details)
            return false // Preserve every audit failure; the handler records diagnostics only.
        }
    }

    @MainActor private func assertProfileDestinations(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for id in ["profile-settings", "add-strength-goal"] {
            XCTAssertTrue(element(id, in: app, file: file, line: line).exists, file: file, line: line)
        }
        for id in ["training-records", "big-three-total", "profile-progress"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: id).firstMatch.exists, file: file, line: line)
        }
    }

    @MainActor private func launch(extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launchEnvironment["SENDA_UI_TEST_JOURNAL_ID"] = UUID().uuidString
        app.launch()
        _ = element("week-summary", in: app)
        return app
    }
    private func todayRowID() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "day-" + formatter.string(from: Date())
    }
    @MainActor @discardableResult private func openDay(_ index: Int, in app: XCUIApplication) -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        let button = buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let id = button.identifier
        tap(id, in: app)
        _ = element("day-title", in: app)
        return id
    }
    @MainActor private func selectedExercise(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND selected == YES", "exercise-")).firstMatch
    }

    @MainActor private func openLibraryExercises(in app: XCUIApplication) {
        tap("dock-library", in: app)
        let exercises = element("library-exercises", in: app)
        if !exercises.isSelected { tap("library-exercises", in: app) }
    }

    @MainActor private func openExerciseCatalog(in app: XCUIApplication) {
        tap("add-exercise", in: app)
        tap("browse-all-exercises", in: app)
    }

    @MainActor private func add(_ query: String, id: String, in app: XCUIApplication) {
        tap("add-exercise", in: app)
        let search = element("picker-search", in: app)
        search.tap(); search.typeText(query + "\n")
        tap("picker-\(id)", in: app)
        XCTAssertTrue(selectedExercise(in: app).waitForExistence(timeout: 3))
    }
    @MainActor private func enter(weight: String, reps: String, in app: XCUIApplication) {
        tap("row-1-weight", in: app); replace(weight, in: app)
        tap("input-next", in: app); replace(reps, in: app)
    }
    @MainActor private func changeUnit(_ symbol: String, in app: XCUIApplication) {
        let toggle = reveal("weight-unit-toggle", in: app)
        let expected = symbol == "kg" ? "Kilograms" : "Pounds"
        let original = symbol == "kg" ? "Pounds" : "Kilograms"
        XCTAssertEqual(toggle.value as? String, original)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, expected)
    }
    @MainActor private func replace(_ value: String, in app: XCUIApplication) {
        let field = element("set-input", in: app)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let old = field.value as? String ?? ""
        let current = old == "lb" || old == "kg" || old == "Reps" ? "" : old
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value)
        let observed = field.value as? String ?? ""
        XCTAssertTrue(observed == value || (value.isEmpty && ["lb", "kg", "Reps"].contains(observed)),
                      "Expected input \(value), got \(observed)")
    }
    @MainActor private func element(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let result = app.descendants(matching: .any).matching(identifier: id).firstMatch
        if !result.exists && ["last-reference", "personal-best-reference"].contains(id) {
            tap("toggle-entry-references", in: app, file: file, line: line)
        }
        if !result.exists { XCTAssertTrue(result.waitForExistence(timeout: 5), "Missing \(id)", file: file, line: line) }
        return result
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let exists = app.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        if !exists {
            if id.hasPrefix("row-") && id.hasSuffix("-details"), let index = id.split(separator: "-").dropFirst().first {
                let menu = id.contains("-drop-") ? String(id.dropLast("-details".count)) + "-actions" : "set-\(index)-actions"
                reveal(menu, in: app, file: file, line: line).tap()
            } else if ["all-exercises", "choose-workout", "day-save-template", "hide-exercise-menu"].contains(id) {
                reveal("workout-options", in: app, file: file, line: line).tap()
            }
        }
        reveal(id, in: app, file: file, line: line).tap()
    }
    @discardableResult
    @MainActor private func reveal(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(id, in: app, file: file, line: line)
        let day = app.scrollViews["day-scroll"]
        let dock = app.descendants(matching: .any).matching(identifier: "app-dock").firstMatch
        let controls = app.descendants(matching: .any).matching(identifier: "day-controls").firstMatch
        let inDay = day.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        let inControls = controls.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        if inDay && !inControls {
            for _ in 0..<6 {
                let viewport = app.frame.intersection(day.frame)
                let top = max(viewport.minY, app.frame.minY + 59)
                let keyboard = app.keyboards.firstMatch
                let bottom = min(viewport.maxY, app.frame.maxY - 30,
                                 controls.exists && controls.frame.height > 0 ? controls.frame.minY - 4 : viewport.maxY,
                                 dock.exists ? dock.frame.minY - 4 : viewport.maxY,
                                 keyboard.exists ? keyboard.frame.minY - 4 : viewport.maxY)
                let frame = target.frame
                if frame.minY >= top - 1 && frame.maxY <= bottom + 1 { break }
                guard bottom - top > 50 else { break }
                let upward = frame.maxY > bottom
                let middle = (top + bottom) / 2
                let overflow = upward ? frame.maxY - bottom : top - frame.minY
                let halfDrag = min(90, (bottom - top) / 4, max(18, (overflow + 12) / 2))
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let x = viewport.midX - app.frame.minX
                let start = middle + (upward ? halfDrag : -halfDrag) - app.frame.minY
                let end = middle + (upward ? -halfDrag : halfDrag) - app.frame.minY
                origin.withOffset(CGVector(dx: x, dy: start))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: end)),
                           withVelocity: .slow, thenHoldForDuration: 0.2)
            }
        }
        let picker = app.scrollViews["exercise-picker-scroll"]
        let filters = app.scrollViews["exercise-filters-scroll"]
        let gymFilters = app.scrollViews["gym-filter-scroll"]
        let customSetup = app.scrollViews["custom-setup-scroll"]
        let workoutLibrary = app.scrollViews["workout-library"]
        let workoutTemplate = app.scrollViews["workout-template-detail"]
        let recentWorkout = app.scrollViews["recent-workout-detail"]
        let custom = app.scrollViews["custom-exercise-scroll"]
        let dayIndex = app.scrollViews["day-exercises-scroll"]
        let profileSettings = app.scrollViews["profile-settings-scroll"]
        let goalEditor = app.scrollViews["strength-goal-editor-scroll"]
        let details = app.scrollViews["profile-details-scroll"]
        let settings = app.scrollViews["settings-scroll"]
        let progress = app.scrollViews["progress-scroll"]
        let planEditor = app.scrollViews["exercise-plan-editor"]
        let setDetailsEditor = app.scrollViews["set-details-editor"]
        let setTypePicker = app.scrollViews["set-type-picker"]
        let trends = app.scrollViews["trends-scroll"]
        let profile = app.scrollViews["profile-scroll"]
        let learnGuide = app.scrollViews["learn-guide-scroll"]
        let learn = learnGuide.exists ? learnGuide : app.scrollViews["learn-scroll"]
        let libraryScroll = [workoutLibrary, workoutTemplate, recentWorkout].first { $0.exists }
        let libraryTab = app.buttons["dock-library"]
        let isLibraryPage = libraryScroll != nil && libraryTab.exists && libraryTab.isSelected
        let sheetScrolls = [customSetup, gymFilters, picker, filters, custom, dayIndex, profileSettings, goalEditor,
                            details, settings, progress, planEditor, setDetailsEditor, setTypePicker]
        let sheetScroll = sheetScrolls.first { $0.exists } ?? (isLibraryPage ? nil : libraryScroll)
        let pageScroll = [trends, profile, learn].first { $0.exists } ?? (isLibraryPage ? libraryScroll : nil)
        let scroll = sheetScroll ?? pageScroll ?? app.scrollViews.firstMatch
        let isFixedLibraryControl = ["apply-workout-template", "apply-recent-workout", "back-to-workout-library",
                                     "close-workout-library", "close-workout-reuse"].contains(id)
        let inScroll = !isFixedLibraryControl && scroll.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        let inPageContent = sheetScroll == nil && pageScroll != nil && inScroll
        let inSheetContent = sheetScroll != nil && inScroll
        let isFilterChip = filters.exists && (id.hasPrefix("group-") || id.hasPrefix("equipment-"))
        let filterHeading = app.staticTexts["Filters"].firstMatch
        let clearFilters = app.buttons["clear-exercise-filters"].firstMatch
        let showResults = app.buttons["picker-show-results"].firstMatch
        let gymFooterTop: CGFloat
        if id.hasPrefix("gym-gear-") {
            gymFooterTop = app.buttons["gym-filter-apply"].frame.minY - 10
        } else if customSetup.exists {
            gymFooterTop = app.buttons["custom-setup-save"].frame.minY - 10
        } else {
            gymFooterTop = .greatestFiniteMagnitude
        }
        if inSheetContent || inPageContent || !target.isHittable {
            var upward = true
            var recoveringTarget = false
            for _ in 0..<20 {
                guard scroll.exists else { break }
                // Offscreen picker rows can report hittable behind the keyboard.
                // Include its prediction strip and require the whole row to show.
                let keyboard = app.keyboards.firstMatch
                let top = isFilterChip
                    ? max(scroll.frame.minY, filterHeading.frame.maxY, clearFilters.frame.maxY)
                    : max(app.frame.minY + 80, scroll.frame.minY + 16)
                let bottom = min(scroll.frame.maxY - 16, app.frame.maxY - 36,
                    keyboard.exists ? keyboard.frame.minY - 72 : app.frame.maxY,
                    inPageContent && dock.exists ? dock.frame.minY - 8 : app.frame.maxY,
                    isFilterChip ? showResults.frame.minY : app.frame.maxY, gymFooterTop)
                if target.exists {
                    let frame = target.frame
                    recoveringTarget = false
                    if target.isHittable && frame.minY >= top && frame.maxY <= bottom { break }
                    if frame.maxY > bottom { upward = true }
                    else if frame.minY < top { upward = false }
                    else { break }
                } else if !recoveringTarget {
                    // Accessibility prunes a row after an overshoot. Reverse once
                    // and keep approaching until it returns to the visible tree.
                    upward.toggle()
                    recoveringTarget = true
                }
                guard bottom - top > 50 else { break }
                let distance: CGFloat
                if workoutLibrary.exists && target.exists {
                    // At the largest text size a single workout can span several ordinary rows.
                    let overflow = upward ? target.frame.maxY - bottom : top - target.frame.minY
                    distance = min((bottom - top) / 2, max(40, overflow + 16))
                } else {
                    distance = min(90, (bottom - top) / 3)
                }
                let startY = upward ? top + distance + 16 : top + 16
                let endY = upward ? top + 16 : top + distance + 16
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.width / 2, dy: startY - app.frame.minY))
                    .press(forDuration: 0.05,
                        thenDragTo: origin.withOffset(CGVector(dx: app.frame.width / 2, dy: endY - app.frame.minY)),
                        withVelocity: .slow, thenHoldForDuration: 0.25)
            }
            if inSheetContent || inPageContent {
                let keyboard = app.keyboards.firstMatch
                let bottom = min(scroll.frame.maxY - 16, app.frame.maxY - 36,
                    keyboard.exists ? keyboard.frame.minY - 72 : app.frame.maxY,
                    inPageContent && dock.exists ? dock.frame.minY - 8 : app.frame.maxY,
                    isFilterChip ? showResults.frame.minY : app.frame.maxY, gymFooterTop)
                if isFilterChip {
                    let top = max(scroll.frame.minY, filterHeading.frame.maxY, clearFilters.frame.maxY)
                    XCTAssertGreaterThanOrEqual(target.frame.minY, top, "Covered \(id) behind filter header", file: file, line: line)
                }
                XCTAssertLessThanOrEqual(target.frame.maxY, bottom, "Covered \(id); row \(target.frame), scroll \(scroll.frame), keyboard \(keyboard.exists ? String(describing: keyboard.frame) : "none")", file: file, line: line)
            }
        }
        if !target.isHittable { diagnostics(app) }
        XCTAssertTrue(target.isHittable, "Unreachable \(id)", file: file, line: line)
        return target
    }
    @MainActor private func diagnostics(_ app: XCUIApplication) {
        attach("Workout and history validation", app)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "Accessibility state"; tree.lifetime = .keepAlways; add(tree)
    }
    @MainActor private func attach(_ title: String, _ app: XCUIApplication) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = title; item.lifetime = .keepAlways; add(item)
    }
}
