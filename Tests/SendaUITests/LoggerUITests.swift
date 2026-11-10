import XCTest

final class LoggerUITests: XCTestCase {
    @MainActor
    func testCompletedRepsContinueIntoNextSetWithoutDismissingKeyboard() throws {
        let preview = launch(extra: ["--sample-data"])
        _ = openDay(0, in: preview)
        attach("Workout overview", preview)
        preview.terminate()

        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        tap("row-1-weight", in: app)
        attach("Weight adjustment", app)
        replace("135", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        attach("Typing weight", app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "weight-dial").firstMatch.exists)
        tap("input-use-dial", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("weight-dial", in: app).exists)
        XCTAssertEqual(element("set-input", in: app).value as? String, "135")
        replace("135", in: app)
        tap("input-next", in: app)
        let next = element("input-next-set", in: app)
        XCTAssertFalse(next.isEnabled)
        replace("0", in: app)
        XCTAssertFalse(next.isEnabled)
        replace("10", in: app)
        XCTAssertTrue(next.isEnabled)
        XCTAssertGreaterThanOrEqual(next.frame.height, 44 - 0.01)
        attach("Reps with direct next set", app)
        next.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(element("input-set-context", in: app).label.contains("Set 2"))
        XCTAssertTrue(element("input-field-label", in: app).label.contains("Weight"))
        XCTAssertEqual(element("set-input", in: app).value as? String, "")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        XCTAssertTrue(element("row-2-type", in: app).label.contains("Working set"))
        attach("Next set keeps typing focus", app)
        replace("145", in: app); tap("input-next", in: app); replace("8", in: app)
        tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
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
    }

    @MainActor
    func testPickerSearchReturnDismissesKeyboardAndKeepsResults() throws {
        let app = launch()
        _ = openDay(0, in: app)
        tap("add-exercise", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Cable")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        search.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(search.value as? String, "Cable")
        XCTAssertTrue(element("picker-cable-row", in: app).exists)
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        attach("Search Return keeps the query and results", app)
        tap("picker-cable-row", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Cable row")
    }

    @MainActor
    func testOpeningFiltersDismissesSearchKeyboardAndKeepsSelectedFilters() throws {
        let app = launch()
        _ = openDay(0, in: app)
        tap("add-exercise", in: app)
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
    func testLargestTextFilteredMultiplePickerPreservesStateAcrossKeyboardDismissal() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        defer { diagnostics(app) }
        _ = openDay(0, in: app)
        tap("add-exercise", in: app); tap("picker-filter-toggle", in: app)
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Cable row")
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
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Cancelled row")
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("10 reps"))
        tap("add-exercise", in: app)
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
        tap("input-decrease", in: app)
        XCTAssertEqual(element("input-decrease", in: app).value as? String, "8 reps")
        XCTAssertEqual(element("set-input", in: app).value as? String, "8")
        attach("Number controls expose their current value to VoiceOver", app)
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
    func testLargestTextProfileDestinationsAndNameActionsStayReachable() throws {
        continueAfterFailure = false
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-profile", in: app)
        attach("Larger Text Profile", app)
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
        tap("dock-profile", in: app); tap("profile-details", in: app)
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
        tap("add-exercise", in: app)
        _ = element("exercise-search", in: app)
        attach("Exercise picker accessibility audit", app)
        try auditAccessibility(in: app)
    }

    @MainActor
    func testExerciseFiltersPassAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        _ = openDay(0, in: app)
        tap("add-exercise", in: app); tap("picker-filter-toggle", in: app)
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
    func testPopulatedWorkoutPassesAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Accessibility audits require iOS 17 or later.") }
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
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
        tap("dock-profile", in: app); tap("profile-backup", in: app)
        _ = element("export-backup", in: app)
        attach("Backup settings accessibility audit", app)
        try auditAccessibility(in: app)
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
        attach("Trained categories reflected in week", app)
        tap(day, in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        let originalDate = element("day-date", in: app).label
        let originalHeaderY = element("back-to-week", in: app).frame.minY
        tap("next-day", in: app)
        XCTAssertNotEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("back-to-week", in: app).frame.minY, originalHeaderY, accuracy: 1)
        XCTAssertFalse(app.staticTexts["entry-exercise"].exists)
        XCTAssertTrue(element("back-to-week", in: app).exists)
        tap("previous-day", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("back-to-week", in: app).frame.minY, originalHeaderY, accuracy: 1)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        attach("Adjacent day navigation", app)
    }

    @MainActor
    func testWeekSwipesNavigateWithoutOpeningDaysAndKeepVerticalScrolling() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        let originalDay = days.element(boundBy: 0).identifier
        let todayControl = element("today-week", in: app)
        XCTAssertTrue(todayControl.isSelected)
        let previousControl = element("previous-week", in: app)
        let nextControl = element("next-week", in: app)
        XCTAssertEqual(todayControl.frame.midY, previousControl.frame.midY, accuracy: 2)
        XCTAssertEqual(previousControl.frame.midY, nextControl.frame.midY, accuracy: 2)
        XCTAssertGreaterThanOrEqual(todayControl.frame.width, 44)
        XCTAssertLessThan(todayControl.frame.minX, previousControl.frame.minX)
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
        tap("repeat-set", in: app)
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
        XCTAssertFalse(app.staticTexts["entry-exercise"].exists)
        tap("previous-day", in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(element("entry-exercise", in: app).label.contains("Bench"))
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
        XCTAssertFalse(app.staticTexts["entry-exercise"].exists)
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
    func testGroupedPickerSearchAndCustomExerciseRecover() throws {
        let app = launch()
        let day = openDay(0, in: app)
        tap("add-exercise", in: app)
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
        XCTAssertTrue(element("picker-bench", in: app).exists)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("picker-bench", in: app)
        tap("add-exercise", in: app)
        tap("picker-more", in: app); tap("create-exercise", in: app)
        let name = element("custom-name", in: app)
        name.tap(); name.typeText("Travel row")
        tap("custom-group", in: app)
        app.buttons["Back"].firstMatch.tap()
        tap("custom-equipment", in: app)
        app.buttons["Cable"].firstMatch.tap()
        tap("save-custom-exercise", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Travel row")
        enter(weight: "50", reps: "8", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        app.terminate(); app.launch()
        tap(day, in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Travel row")
        tap("add-exercise", in: app)
        tap("picker-filter-toggle", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        tap("picker-show-results", in: app)
        let custom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "picker-custom-", "Travel row")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        XCTAssertTrue(custom.label.contains("added"))
        attach("Grouped local exercise picker", app)
        let customID = String(custom.identifier.dropFirst("picker-".count))
        tap("close-exercise-picker", in: app)
        let selector = element("entry-exercise", in: app)
        XCTAssertGreaterThanOrEqual(selector.frame.height, 44)
        XCTAssertEqual(element("add-exercise", in: app).frame.midY, selector.frame.midY, accuracy: 2)
        tap("entry-exercise", in: app)
        XCTAssertTrue(element("exercise-\(customID)", in: app).isSelected)
        XCTAssertTrue(element("exercise-bench", in: app).exists)
        tap("exercise-\(customID)", in: app)
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-bench", in: app).label.contains("No sets yet"))
        XCTAssertTrue(element("day-exercise-\(customID)", in: app).label.contains("1 set"))
        attach("Day exercise index and actual set counts", app)
        tap("day-exercise-bench", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        tap("all-exercises", in: app)
        tap("day-exercise-\(customID)", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("50 lb"))
        tap("all-exercises", in: app)
        tap("day-list-add-exercise", in: app)
        _ = element("exercise-search", in: app)
        tap("close-exercise-picker", in: app)
        app.terminate(); app.launch()
        XCTAssertEqual(element("entry-exercise", in: app).label, "Travel row")
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
        tap("add-exercise", in: app)
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Dumbbell bench")
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
        tap("reuse-workout", in: app); tap("reuse-workout-" + source, in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("—"))
        tap("row-1-weight", in: app); replace("95", in: app); tap("input-done", in: app)
        tap("add-exercise", in: app); tap("picker-more", in: app); tap("reuse-workout", in: app)
        tap("reuse-workout-" + source, in: app)
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
            tap("entry-exercise", in: app)
            tap("hide-exercise-menu", in: app)
            tap("hide-exercise-" + id, in: app)
        }
        tap("all-exercises", in: app)
        XCTAssertTrue(element("day-exercise-deadlift", in: app).label.localizedCaseInsensitiveContains("hidden"))
        tap("day-exercise-deadlift", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("225 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("2 sets"))
        attach("Hidden tabs retain discoverable recorded sets", app)
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
        tap("new-set", in: app)
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
        XCTAssertTrue(element("weight-unit-menu", in: app).label.contains("kg"))
        let originalDate = element("day-date", in: app).label
        tap("next-day", in: app)
        XCTAssertNotEqual(element("day-date", in: app).label, originalDate)
        tap("previous-day", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        attach("Large text day navigation", app)
        add("Cable row", id: "cable-row", in: app)
        tap("all-exercises", in: app)
        _ = element("day-exercises-title", in: app)
        attach("Large text All action in the tab row", app)
    }

    @MainActor
    func testLearnSearchClearAndBackPreserveResults() throws {
        let app = launch()
        tap("dock-learn", in: app)
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
    func testLargestTextLearnSearchAndIllustrationsStayReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap("dock-learn", in: app)
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
        tap("dock-learn", in: app)
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
        tap("dock-profile", in: app)
        assertProfileDestinations(in: app)
        tap("profile-details", in: app)
        let name = element("profile-name", in: app)
        name.tap(); name.typeText("Jae")
        XCTAssertFalse(app.textFields["profile-email"].exists)
        tap("profile-save", in: app)
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        tap("profile-weight-units", in: app)
        tap("preference-kg", in: app)
        tap("close-settings", in: app)
        tap("dock-learn", in: app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        XCTAssertTrue(element("form-source", in: app).exists)
        tap("dock-profile", in: app); tap("dock-learn", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("dock-log", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
        tap("input-done", in: app)
        app.terminate(); app.launch()
        tap("dock-profile", in: app)
        XCTAssertTrue(element("profile-details", in: app).label.contains("Jae"))
        assertProfileDestinations(in: app)
        tap("profile-weight-units", in: app)
        XCTAssertTrue(element("preference-kg", in: app).isSelected)
        attach("Local profile and unit setting", app)
    }

    @MainActor
    func testBackupSettingsExposeExportAndValidatedRestoreActions() throws {
        let app = launch()
        tap("dock-profile", in: app)
        XCTAssertTrue(element("profile-storage-explanation", in: app).exists)
        tap("profile-weight-units", in: app)
        XCTAssertTrue(element("preference-lb", in: app).exists)
        tap("close-settings", in: app)
        tap("profile-backup", in: app)
        XCTAssertTrue(app.staticTexts["Backup & restore"].exists)
        XCTAssertFalse(app.buttons["preference-lb"].exists)
        for id in ["export-backup", "export-csv", "restore-import", "export-pre-restore-backup"] {
            reveal(id, in: app)
            XCTAssertTrue(element(id, in: app).isHittable)
        }
        tap("export-pre-restore-backup", in: app)
        reveal("backup-status", in: app)
        XCTAssertTrue(element("backup-status", in: app).label.contains("no pre-restore copy"))
        tap("close-settings", in: app)
        attach("Backup and restore settings", app)
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
        XCTAssertTrue(element("progress-range-12", in: app).isSelected)
        tap("progress-range-8", in: app)
        XCTAssertTrue(element("progress-range-8", in: app).isSelected)
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
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
        tap("entry-exercise", in: app)
        XCTAssertTrue(element("exercise-bench", in: app).isSelected)
        tap("exercise-bench", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
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
        tap("dock-trends", in: app)
        attach("Strength Trends overview", app)
        let picker = element("trends-strength-picker", in: app)
        XCTAssertEqual(picker.value as? String, "Bench")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Bench"))
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("145 lb"))
        picker.tap()
        tap("trends-strength-exercise-overhead-press", in: app)
        XCTAssertEqual(picker.value as? String, "Overhead press")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Overhead press"))
        XCTAssertTrue(element("trends-strength-latest", in: app).label.contains("65 lb"))
        attach("Strength Trends one-day exercise", app)
        tap("trends-range-8", in: app)
        XCTAssertEqual(picker.value as? String, "Overhead press")
        XCTAssertTrue(element("trends-range-8", in: app).isSelected)
        tap("trends-range-12", in: app)
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
        picker.tap(); tap("trends-strength-exercise-overhead-press", in: app)
        XCTAssertEqual(picker.value as? String, "Overhead press")
        XCTAssertTrue(element("trends-strength-chart", in: app).label.contains("Overhead press"))
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
        XCTAssertTrue(element("trends-range-12", in: app).isSelected)
        tap("trends-range-8", in: app)
        XCTAssertTrue(element("trends-range-8", in: app).isSelected)
        XCTAssertTrue(element("trends-period-summary", in: app).exists)
        tap("trends-exercise-bench", in: app)
        XCTAssertTrue(app.scrollViews["progress-scroll"].exists)
        XCTAssertTrue(element("progress-range-8", in: app).isSelected)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        tap("dock-log", in: app)
        XCTAssertEqual(element("day-date", in: app).label, originalDate)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
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
        XCTAssertEqual(element("entry-exercise", in: app).label, "Squat")
        tap("dock-trends", in: app)
        tap("trends-records-toggle", in: app)
        tap("records-pr-bench", in: app)
        tap("progress-edit-workout", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Bench")
        tap("row-1-weight", in: app); replace("145", in: app); tap("input-done", in: app)
        tap("history-return-workout", in: app)
        XCTAssertEqual(element("entry-exercise", in: app).label, "Squat")
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
        XCTAssertTrue(reveal("progress-range-12", in: app).isSelected)
        attach("Larger Text exercise history range", app)
        tap("progress-close", in: app)
        XCTAssertTrue(app.scrollViews["trends-scroll"].exists)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
    }

    @MainActor
    func testLargeTextDockKeepsProfileAndLearningReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        continueAfterFailure = false
        attach("Largest Text bottom bar", app)
        let dock = element("app-dock", in: app)
        // Includes the bottom safe area; leave the page room to remain useful.
        XCTAssertLessThanOrEqual(dock.frame.height, 120)
        let tabs = [("dock-log", "Log"), ("dock-trends", "Trends"), ("dock-learn", "Learn"), ("dock-profile", "Profile")]
        var previous: CGRect?
        for (id, title) in tabs {
            let tab = element(id, in: app)
            XCTAssertTrue(tab.isHittable)
            XCTAssertEqual(tab.label, title)
            XCTAssertGreaterThanOrEqual(tab.frame.width, 44 - 0.01)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44 - 0.01)
            XCTAssertTrue(dock.frame.contains(tab.frame))
            if let previous {
                XCTAssertLessThanOrEqual(previous.maxX, tab.frame.minX + 0.01)
                XCTAssertEqual(previous.minY, tab.frame.minY, accuracy: 1)
                XCTAssertEqual(previous.height, tab.frame.height, accuracy: 1)
            }
            previous = tab.frame
        }
        XCTAssertTrue(element("dock-log", in: app).isSelected)
        tap("dock-trends", in: app)
        XCTAssertTrue(element("dock-trends", in: app).isSelected)
        XCTAssertTrue(element("trends-empty-log", in: app).exists)
        element("dock-profile", in: app).press(forDuration: 3)
        tap("dock-profile", in: app)
        XCTAssertTrue(element("dock-profile", in: app).isSelected)
        attach("Profile Largest Text bottom bar", app)
        assertProfileDestinations(in: app)
        tap("profile-weight-units", in: app); tap("preference-kg", in: app); tap("close-settings", in: app)
        tap("dock-learn", in: app)
        let search = element("learn-search", in: app)
        search.tap(); search.typeText("Bench\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        tap("learn-exercise-bench", in: app)
        XCTAssertTrue(element("form-guide-bench", in: app).exists)
        tap("dock-log", in: app)
        XCTAssertTrue(app.scrollViews["week-view"].exists)
        attach("Large text Log Trends Learn Profile dock", app)
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
        for id in ["profile-details", "profile-weight-units", "profile-backup"] {
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
    @MainActor @discardableResult private func openDay(_ index: Int, in app: XCUIApplication) -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-"))
        let button = buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let id = button.identifier
        tap(id, in: app)
        _ = element("day-title", in: app)
        return id
    }
    @MainActor private func add(_ query: String, id: String, in app: XCUIApplication) {
        tap("add-exercise", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText(query + "\n")
        tap("picker-\(id)", in: app)
        _ = element("entry-exercise", in: app)
    }
    @MainActor private func enter(weight: String, reps: String, in app: XCUIApplication) {
        tap("row-1-weight", in: app); replace(weight, in: app)
        tap("input-next", in: app); replace(reps, in: app)
    }
    @MainActor private func changeUnit(_ symbol: String, in app: XCUIApplication) {
        tap("weight-unit-menu", in: app)
        tap("day-unit-\(symbol)", in: app)
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
            } else if id == "all-exercises" || id == "hide-exercise-menu" {
                reveal("entry-exercise", in: app, file: file, line: line).tap()
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
                let top = max(app.frame.minY + 65, day.frame.minY)
                let editorBottom = controls.exists && controls.frame.height > 0 ? controls.frame.minY - 8 : app.frame.maxY - 36
                let bottom = min(editorBottom, dock.exists ? dock.frame.minY - 8 : app.frame.maxY - 36)
                if target.isHittable && target.frame.minY >= top && target.frame.maxY <= bottom { break }
                guard bottom - top > 50 else { break }
                let upward = target.frame.maxY > bottom
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.width / 2, dy: (upward ? bottom - 12 : top + 12) - app.frame.minY))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width / 2, dy: (upward ? top + 12 : bottom - 12) - app.frame.minY)))
            }
        }
        let picker = app.scrollViews["exercise-picker-scroll"]
        let filters = app.scrollViews["exercise-filters-scroll"]
        let reuse = app.scrollViews["workout-reuse-scroll"]
        let custom = app.scrollViews["custom-exercise-scroll"]
        let dayIndex = app.scrollViews["day-exercises-scroll"]
        let details = app.scrollViews["profile-details-scroll"]
        let settings = app.scrollViews["settings-scroll"]
        let progress = app.scrollViews["progress-scroll"]
        let planEditor = app.scrollViews["exercise-plan-editor"]
        let setDetailsEditor = app.scrollViews["set-details-editor"]
        let setTypePicker = app.scrollViews["set-type-picker"]
        let trends = app.scrollViews["trends-scroll"]
        let profile = app.scrollViews["profile-scroll"]
        let learn = app.scrollViews["learn-scroll"]
        let sheetScroll = [picker, filters, reuse, custom, dayIndex, details, settings, progress, planEditor, setDetailsEditor, setTypePicker].first { $0.exists }
        let scroll = sheetScroll ?? [trends, profile, learn, app.scrollViews.firstMatch].first { $0.exists } ?? app.scrollViews.firstMatch
        let inPageContent = sheetScroll == nil && (trends.exists || profile.exists || learn.exists) && scroll.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        let inSheetContent = sheetScroll != nil && scroll.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        let isFilterChip = filters.exists && (id.hasPrefix("group-") || id.hasPrefix("equipment-"))
        let filterHeading = app.staticTexts["Filters"].firstMatch
        let clearFilters = app.buttons["clear-exercise-filters"].firstMatch
        let showResults = app.buttons["picker-show-results"].firstMatch
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
                    isFilterChip ? showResults.frame.minY : app.frame.maxY)
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
                let distance = min(90, (bottom - top) / 3)
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
                    isFilterChip ? showResults.frame.minY : app.frame.maxY)
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
