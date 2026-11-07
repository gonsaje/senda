import XCTest

final class LoggerUITests: XCTestCase {
    @MainActor
    func testRowExceptionRecordCorrectionAndUndo() throws {
        let app = launchSample()
        XCTAssertFalse(app.staticTexts["DRAFT · NOT RECORDED"].exists)
        setRow(4, field: "reps", to: "8", in: app)
        tap("apply-number-input", in: app)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("8 reps"))
        XCTAssertTrue(element("row-3-reps", in: app).label.contains("10 reps"))
        tap("record-batch", in: app)
        tap("compare-entries", in: app)
        XCTAssertTrue(app.staticTexts["2 fewer reps at the same weight"].waitForExistence(timeout: 3))
        setRow(4, field: "reps", to: "9", in: app)
        tap("save-entry-changes", in: app)
        tap("compare-entries", in: app)
        XCTAssertTrue(app.staticTexts["1 fewer rep at the same weight"].waitForExistence(timeout: 3))
        tap("undo-batch", in: app)
        XCTAssertTrue(element("record-batch", in: app).exists)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("9 reps"))
        attachScreenshot("Undo restores corrected sets for entry", app: app)
    }

    @MainActor
    func testIdenticalNewEntryCanRecordAndUndo() throws {
        let app = launchSample()
        for row in 1...4 {
            setRow(row, field: "lb", to: "152.5", in: app)
            tap("apply-number-input", in: app)
            XCTAssertTrue(element("row-\(row)-lb", in: app).label.contains("152.5 lb"))
        }
        tap("record-batch", in: app)
        tap("another-batch", in: app)
        tap("record-batch", in: app)
        XCTAssertTrue(element("another-batch", in: app).exists)
        let previous = element("prior-performed-reference", in: app).label
        XCTAssertTrue(previous.contains("152.5 lb"), "Previous top set: \(previous)")
        tap("undo-batch", in: app)
        XCTAssertTrue(element("prior-performed-reference", in: app).label.contains("152.5 lb"), "Undo keeps the first intentional identical entry")
        XCTAssertTrue(element("record-batch", in: app).exists)
    }

    @MainActor
    func testRecordIsReachableWithKeyboardAndUsesTypedReps() throws {
        let app = launchSample()
        setRow(4, field: "reps", to: "8", in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let record = element("record-batch", in: app)
        XCTAssertEqual(record.label, "Record 4 sets")
        XCTAssertTrue(record.isHittable, "Record stays above the keyboard")
        attachScreenshot("Record with keyboard open", app: app)
        record.tap()
        XCTAssertTrue(element("another-batch", in: app).exists)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("8 reps"))
    }

    @MainActor
    func testBothUnitsUnitSwitchAndScrollingDialEditOnlySelectedRow() throws {
        let app = launchSample()
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-1-kg", in: app).label.contains("61.23 kg"))
        tap("row-1-kg", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "61.23")
        tap("weight-unit-lb", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "135")
        tap("weight-unit-kg", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "61.23")
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("135 lb"), "Unit switches preserve the original weight")
        let dial = element("weight-dial", in: app)
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4))
            .press(forDuration: 0.1, thenDragTo: dial.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)))
        XCTAssertFalse(element("row-1-lb", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-2-lb", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("row-2-kg", in: app).label.contains("61.23 kg"))
        tap("record-batch", in: app)
        setRow(1, field: "kg", to: "60", in: app)
        tap("save-entry-changes", in: app)
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("132.28 lb"))
        XCTAssertTrue(element("row-1-kg", in: app).label.contains("60 kg"))
        setRow(1, field: "lb", to: "1", in: app)
        tap("save-entry-changes", in: app)
        tap("row-1-kg", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "0.45")
        tap("weight-unit-lb", in: app)
        tap("weight-unit-kg", in: app)
        tap("save-entry-changes", in: app)
        XCTAssertTrue(element("row-1-lb", in: app).label.contains(", 1 lb"), "Opening and switching the dial never rounds an untouched weight")
        attachScreenshot("Dual units and independent set weights", app: app)
    }

    @MainActor
    func testInvalidInputCannotRecordAndStepperUsesTypedWeight() throws {
        let app = launchSample()
        setRow(1, field: "lb", to: "150", in: app)
        tap("dock-increase", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "152.5")
        replaceNumber(element("dock-number", in: app), with: "31.")
        XCTAssertFalse(element("record-batch", in: app).isEnabled)
        tap("cancel-number-input", in: app)
        XCTAssertTrue(element("record-batch", in: app).isEnabled)
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("152.5 lb"))
    }

    @MainActor
    func testRecordedRowsSurviveRelaunchAndRemainEditable() throws {
        let app = try launchPersistent()
        XCTAssertFalse(app.buttons["personal-best-reference"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["common-working-reference"].exists)
        setRow(4, field: "reps", to: "8", in: app)
        tap("record-batch", in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(element("another-batch", in: app).exists)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("8 reps"))
        setRow(4, field: "reps", to: "9", in: app)
        tap("cancel-entry-changes", in: app)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("8 reps"))
        attachScreenshot("Reopened logged entry", app: app)
    }

    @MainActor
    func testUnfinishedRowsUnitAndPartialInputSurviveRelaunch() throws {
        let app = try launchPersistent()
        tap("lift-deadlift", in: app)
        setRow(3, field: "reps", to: "5", in: app)
        tap("apply-number-input", in: app)
        setRow(4, field: "kg", to: "61.", in: app)
        app.terminate()
        app.launch()
        XCTAssertEqual(element("entry-exercise", in: app).label, "Deadlift")
        XCTAssertEqual(element("dock-number", in: app).value as? String, "61.")
        XCTAssertFalse(element("record-batch", in: app).isEnabled)
        XCTAssertFalse(app.buttons["another-batch"].exists)
        tap("cancel-number-input", in: app)
        XCTAssertTrue(element("row-3-reps", in: app).label.contains("5 reps"))
        XCTAssertTrue(element("record-batch", in: app).isEnabled)
        attachScreenshot("Unfinished entry recovered outside history", app: app)
    }

    @MainActor
    func testPendingCorrectionRecoversAndSavesOnlyOnDone() throws {
        let app = try launchPersistent()
        tap("record-batch", in: app)
        setRow(1, field: "kg", to: "60", in: app)
        app.terminate()
        app.launch()
        XCTAssertEqual(element("dock-number", in: app).value as? String, "60")
        XCTAssertTrue(element("save-entry-changes", in: app).exists)
        tap("save-entry-changes", in: app)
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("132.28 lb"))
        setRow(1, field: "kg", to: "65", in: app)
        tap("cancel-entry-changes", in: app)
        XCTAssertTrue(element("row-1-lb", in: app).label.contains("132.28 lb"))
    }

    @MainActor
    func testOlderEntryEditorRecoversInvalidTextWithoutRecordingCurrentEntry() throws {
        let app = try launchPersistent()
        tap("record-batch", in: app)
        tap("another-batch", in: app)
        tap("prior-performed-reference", in: app)
        tap("editor-unit-kg", in: app)
        replaceNumber(element("set-4-reps", in: app), with: "")
        XCTAssertFalse(element("confirm-set-edits", in: app).isEnabled)
        app.terminate()
        app.launch()
        XCTAssertFalse(element("confirm-set-edits", in: app).isEnabled)
        XCTAssertTrue(element("set-4-alternate-weight", in: app).label.contains("135 lb"))
        replaceNumber(element("set-4-reps", in: app), with: "8")
        tap("confirm-set-edits", in: app)
        XCTAssertTrue(element("record-batch", in: app).exists)
        XCTAssertTrue(element("row-4-reps", in: app).label.contains("10 reps"))
        XCTAssertTrue(element("prior-performed-reference", in: app).label.contains("× 10"), "The reference shows its top set, not every rep count")
        tap("prior-performed-reference", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "8")
        tap("cancel-set-edits", in: app)
    }

    @MainActor
    func testPrimaryActionsAndUnitsRemainReachableAtLargeTextSize() throws {
        let app = launchSample(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(element("record-batch", in: app).isHittable)
        tap("row-1-lb", in: app)
        tap("apply-number-input", in: app)
        tap("row-1-kg", in: app)
        tap("apply-number-input", in: app)
        tap("record-batch", in: app)
        XCTAssertTrue(element("another-batch", in: app).isHittable)
        attachScreenshot("Large text logged entry", app: app)
    }

    @MainActor
    func testTopSetPrAndCommonReferencesUseOnlySavedHistory() throws {
        let app = launchSample()
        let prior = element("prior-performed-reference", in: app).label
        XCTAssertFalse(prior.contains("Last"))
        XCTAssertFalse(prior.contains("× 4"))
        XCTAssertTrue(prior.contains("135 lb"))
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("common-working-reference", in: app).label.contains("135 lb"))
        setRow(1, field: "lb", to: "200", in: app)
        tap("apply-number-input", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        tap("record-batch", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        setRow(1, field: "lb", to: "225", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        tap("save-entry-changes", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("225 lb"))
        tap("undo-batch", in: app)
        tap("apply-number-input", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        tap("personal-best-reference", in: app)
        replaceNumber(element("set-1-weight", in: app), with: "140")
        tap("confirm-set-edits", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("140 lb"))
        XCTAssertTrue(element("common-working-reference", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("record-batch", in: app).exists)
        attachScreenshot("PR and common working set from performed history", app: app)
    }

    private var languageArguments: [String] { ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] }

    @MainActor
    private func launchSample(extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"] + languageArguments + extraArguments
        app.launch()
        _ = element("entry-exercise", in: app)
        return app
    }

    @MainActor
    private func launchPersistent() throws -> XCUIApplication {
        #if !DEBUG
        throw XCTSkip("Persistence-test isolation requires a Debug app and test build.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = languageArguments
        app.launchEnvironment["SENDA_UI_TEST_JOURNAL_ID"] = UUID().uuidString
        app.launch()
        _ = element("entry-exercise", in: app)
        return app
        #endif
    }

    @MainActor
    private func setRow(_ row: Int, field: String, to value: String, in app: XCUIApplication) {
        tap("row-\(row)-\(field)", in: app)
        replaceNumber(element("dock-number", in: app), with: value)
        XCTAssertEqual(element("dock-number", in: app).value as? String, value)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(identifier)", file: file, line: line)
        return element
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier, in: app, file: file, line: line)
        let notebook = app.scrollViews["notebook-scroll"]
        let controls = app.descendants(matching: .any).matching(identifier: "entry-controls").firstMatch
        let belongsToNotebook = notebook.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists
        let belongsToControls = controls.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists
        if belongsToNotebook && !belongsToControls && controls.exists {
            // SwiftUI reports covered scroll content as hittable. Keep the entire
            // target above the pinned controls before synthesizing a finger tap.
            for _ in 0..<6 {
                let top = max(app.frame.minY + 65, notebook.frame.minY)
                let bottom = controls.frame.minY - 8
                let frame = target.frame
                if target.isHittable && frame.minY >= top && frame.maxY <= bottom { break }
                guard bottom - top > 50 else { break }
                let upward = frame.maxY > bottom
                let startY = upward ? bottom - 12 : top + 12
                let endY = upward ? top + 12 : bottom - 12
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.width / 2, dy: startY - app.frame.minY))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width / 2, dy: endY - app.frame.minY)))
            }
            XCTAssertGreaterThanOrEqual(target.frame.minY, max(app.frame.minY + 65, notebook.frame.minY), file: file, line: line)
            XCTAssertLessThanOrEqual(target.frame.maxY, controls.frame.minY - 8, file: file, line: line)
        }
        if !target.isHittable {
            let editor = app.scrollViews["set-editor-scroll"]
            let scroll = editor.exists ? editor : app.scrollViews["notebook-scroll"]
            for _ in 0..<4 {
                if target.isHittable { break }
                scroll.swipeUp()
            }
            for _ in 0..<4 {
                if target.isHittable { break }
                scroll.swipeDown()
            }
        }
        XCTAssertTrue(target.isHittable, "Unreachable \(identifier)", file: file, line: line)
        target.tap()
    }

    @MainActor
    private func replaceNumber(_ field: XCUIElement, with text: String) {
        // Tap to the right of the centered value so deletion starts at its end.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let oldValue = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + text)
    }

    @MainActor
    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
