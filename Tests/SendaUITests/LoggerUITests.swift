import XCTest

final class LoggerUITests: XCTestCase {
    @MainActor
    func testExceptionCancelConfirmRecordCorrectionAndUndo() throws {
        let app = launchSample()
        let status = element("entry-status", in: app)
        XCTAssertEqual(status.label, "DRAFT · NOT RECORDED")
        tap("draft-edit-sets", in: app)
        tap("set-4-reps-decrease", in: app)
        tap("set-4-reps-decrease", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "8")
        tap("cancel-set-edits", in: app)
        tap("draft-edit-sets", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "10")
        tap("set-4-reps-decrease", in: app)
        tap("set-4-reps-decrease", in: app)
        tap("confirm-set-edits", in: app)
        XCTAssertEqual(status.label, "DRAFT · NOT RECORDED")
        XCTAssertTrue(element("sentence-sets", in: app).exists, "Batch size stays editable with exceptions")
        tap("record-batch", in: app)
        XCTAssertEqual(status.label, "RECORDED")
        tap("compare-entries", in: app)
        XCTAssertTrue(app.staticTexts["2 fewer reps at the same weight"].waitForExistence(timeout: 3))
        tap("recorded-edit-sets", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "8")
        tap("set-4-reps-increase", in: app)
        tap("confirm-set-edits", in: app)
        XCTAssertTrue(app.staticTexts["1 fewer rep at the same weight"].waitForExistence(timeout: 3))
        tap("undo-batch", in: app)
        XCTAssertEqual(status.label, "DRAFT · NOT RECORDED")
        tap("draft-edit-sets", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "9")
        tap("cancel-set-edits", in: app)
        attachScreenshot("Undo restores corrected unrecorded sets", app: app)
    }

    @MainActor
    func testIdenticalAnotherBatchCanRecordAndUndo() throws {
        let app = launchSample()
        replaceNumber(element("dock-number", in: app), with: "152.5")
        tap("apply-number-input", in: app)
        tap("record-batch", in: app)
        tap("another-batch", in: app)
        XCTAssertEqual(element("entry-status", in: app).label, "DRAFT · NOT RECORDED")
        tap("record-batch", in: app)
        XCTAssertEqual(element("entry-status", in: app).label, "RECORDED")
        XCTAssertTrue(element("prior-performed-reference", in: app).label.contains("152.5 lb"))
        tap("undo-batch", in: app)
        XCTAssertTrue(element("prior-performed-reference", in: app).label.contains("152.5 lb"), "Undo keeps the first intentional identical batch")
        XCTAssertEqual(element("entry-status", in: app).label, "DRAFT · NOT RECORDED")
    }

    @MainActor
    func testRecordIsReachableWithKeyboardAndUsesCompleteTypedSetCount() throws {
        let app = launchSample()
        tap("sentence-sets", in: app)
        replaceNumber(element("dock-number", in: app), with: "15")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let record = element("record-batch", in: app)
        XCTAssertEqual(record.label, "Record 15 sets")
        XCTAssertTrue(record.isHittable, "The Record action must remain above the keyboard")
        attachScreenshot("Record with keyboard open", app: app)
        record.tap()
        XCTAssertEqual(element("entry-status", in: app).label, "RECORDED")
        XCTAssertTrue(app.staticTexts["15 individual sets"].exists)
    }

    @MainActor
    func testStepperUsesPendingTypedWeightAndInvalidInputCannotRecord() throws {
        let app = launchSample()
        replaceNumber(element("dock-number", in: app), with: "150")
        tap("dock-increase", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "152.5")
        tap("sentence-sets", in: app)
        replaceNumber(element("dock-number", in: app), with: "31")
        XCTAssertFalse(element("record-batch", in: app).isEnabled)
        tap("cancel-number-input", in: app)
        XCTAssertEqual(element("dock-number", in: app).value as? String, "4")
        XCTAssertTrue(element("record-batch", in: app).isEnabled)
    }

    @MainActor
    func testRecordedSetsSurviveRelaunchAsHistoryAndANewDraft() throws {
        #if !DEBUG
        throw XCTSkip("Persistence-test isolation requires a Debug app and test build.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = languageArguments
        app.launchEnvironment["SENDA_UI_TEST_JOURNAL_ID"] = UUID().uuidString
        app.launch()
        tap("draft-edit-sets", in: app)
        tap("set-4-reps-decrease", in: app)
        tap("set-4-reps-decrease", in: app)
        tap("confirm-set-edits", in: app)
        tap("record-batch", in: app)
        XCTAssertEqual(element("entry-status", in: app).label, "RECORDED")
        app.terminate()
        app.launch()
        XCTAssertEqual(element("entry-status", in: app).label, "DRAFT · NOT RECORDED")
        XCTAssertTrue(element("prior-performed-reference", in: app).label.contains("Last ·"))
        tap("draft-edit-sets", in: app)
        XCTAssertEqual(element("set-4-reps", in: app).value as? String, "8")
        tap("cancel-set-edits", in: app)
        attachScreenshot("Reopened journal preserves performed history", app: app)
        #endif
    }

    @MainActor
    func testRecordAndAnotherBatchRemainReachableAtLargeTextSize() throws {
        let app = launchSample(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(element("record-batch", in: app).isHittable)
        tap("record-batch", in: app)
        XCTAssertTrue(element("another-batch", in: app).isHittable)
        attachScreenshot("Large text recorded state", app: app)
    }

    private var languageArguments: [String] { ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] }

    @MainActor
    private func launchSample(extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"] + languageArguments + extraArguments
        app.launch()
        _ = element("entry-status", in: app)
        return app
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
