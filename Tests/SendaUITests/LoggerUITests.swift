import XCTest

final class LoggerUITests: XCTestCase {
    @MainActor
    func testAutomaticEntryAndHeaderUnitsUpdateTheWeek() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Record ")).firstMatch.exists)
        enter(weight: "135", reps: "10", in: app)
        tap("input-done", in: app)
        tap("day-unit-kg", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("61.23 kg"))
        tap("day-unit-lb", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("1 set"))
        XCTAssertTrue(element("week-summary", in: app).label.contains("1 set"))
        attach("Automatic set reflected in week", app)
    }

    @MainActor
    func testBodyweightRepeatDeleteAndUndo() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Push", id: "push-up", in: app)
        tap("row-1-reps", in: app)
        replace("12", in: app)
        tap("input-done", in: app)
        tap("repeat-set", in: app)
        XCTAssertTrue(element("row-2-reps", in: app).label.contains("12 reps"))
        tap("undo-set-change", in: app)
        XCTAssertFalse(app.buttons["row-2-reps"].exists)
        tap("delete-row-1", in: app)
        XCTAssertFalse(app.buttons["row-1-reps"].exists)
        tap("undo-set-change", in: app)
        XCTAssertTrue(element("row-1-reps", in: app).label.contains("12 reps"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("1 set"))
    }

    @MainActor
    func testPartialNumbersSurviveReopeningWithoutProgress() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "31.", reps: "8", in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(element("entry-exercise", in: app).label.contains("Bench"))
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "31.")
        tap("input-done", in: app)
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("0 sets"))
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
    func testLastAndPrAreSeparateAndOpenTheirSourceDay() throws {
        let app = launch()
        let first = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "135", reps: "10", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        let second = openDay(1, in: app)
        add("Bench", id: "bench", in: app)
        XCTAssertTrue(element("last-reference", in: app).label.contains("135 lb"))
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        enter(weight: "200", reps: "5", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("135 lb"))
        tap("input-done", in: app)
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        XCTAssertTrue(element("last-reference", in: app).label.contains("135 lb"))
        tap("last-reference", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("135 lb"))
        tap("row-1-weight", in: app); replace("140", in: app); tap("input-done", in: app)
        tap("back-to-week", in: app)
        XCTAssertTrue(element(first, in: app).label.contains("1 set"))
        tap(second, in: app)
        XCTAssertTrue(element("last-reference", in: app).label.contains("140 lb"))
        XCTAssertTrue(element("personal-best-reference", in: app).label.contains("200 lb"))
        attach("Separate Last and PR banners", app)
    }

    @MainActor
    func testGroupedPickerSearchAndCustomExerciseRecover() throws {
        let app = launch()
        let day = openDay(0, in: app)
        tap("add-exercise", in: app)
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        XCTAssertTrue(element("picker-cable-row", in: app).exists)
        XCTAssertFalse(app.buttons["picker-bench"].exists)
        tap("equipment-All", in: app)
        let search = element("exercise-search", in: app)
        search.tap(); search.typeText("Bench")
        tap("picker-bench", in: app)
        tap("add-exercise", in: app)
        tap("create-exercise", in: app)
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
        tap("group-Back", in: app); tap("equipment-Cable", in: app)
        let custom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "picker-custom-", "Travel row")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        XCTAssertTrue(custom.label.contains("added"))
        attach("Grouped local exercise picker", app)
    }

    @MainActor
    func testRoundedUnitFocusDoesNotChangeStoredPounds() throws {
        let app = launch()
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        enter(weight: "1", reps: "10", in: app); tap("input-done", in: app)
        tap("day-unit-kg", in: app)
        tap("row-1-weight", in: app)
        XCTAssertEqual(element("set-input", in: app).value as? String, "0.45")
        tap("input-done", in: app)
        tap("day-unit-lb", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains(", 1 lb"))
    }

    @MainActor
    func testFastDecimalTypingAndFingerDial() throws {
        let app = launch()
        let day = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        for row in 1...3 {
            tap("row-\(row)-weight", in: app)
            for value in ["152.5", "127.25", "135", "152.5"] {
                replace(value, in: app)
                XCTAssertEqual(element("set-input", in: app).value as? String, value)
                XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "weight-dial").firstMatch.exists)
            }
            tap("input-next", in: app); replace("10", in: app); tap("input-done", in: app)
            if row < 3 { tap("new-set", in: app) }
        }
        tap("row-3-weight", in: app); tap("input-mode", in: app)
        let dial = element("weight-dial", in: app)
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)).press(forDuration: 0.1,
            thenDragTo: dial.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)))
        tap("input-done", in: app)
        XCTAssertTrue(element("row-1-weight", in: app).label.contains("152.5 lb"))
        tap("back-to-week", in: app)
        XCTAssertTrue(element(day, in: app).label.contains("3 sets"))
    }

    @MainActor
    func testLargeTextKeepsEditingActionsReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        _ = openDay(0, in: app)
        add("Bench", id: "bench", in: app)
        tap("new-set", in: app)
        XCTAssertTrue(element("input-done", in: app).isHittable)
        XCTAssertTrue(element("input-next", in: app).isHittable)
        attach("Large text automatic entry", app)
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
        search.tap(); search.typeText(query)
        tap("picker-\(id)", in: app)
        _ = element("entry-exercise", in: app)
    }
    @MainActor private func enter(weight: String, reps: String, in app: XCUIApplication) {
        tap("row-1-weight", in: app); replace(weight, in: app)
        tap("input-next", in: app); replace(reps, in: app)
    }
    @MainActor private func replace(_ value: String, in app: XCUIApplication) {
        let field = element("set-input", in: app)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let old = field.value as? String ?? ""
        let current = old == "lb" || old == "kg" || old == "Reps" ? "" : old
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value)
        XCTAssertEqual(field.value as? String, value)
    }
    @MainActor private func element(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let result = app.descendants(matching: .any).matching(identifier: id).firstMatch
        if !result.exists { XCTAssertTrue(result.waitForExistence(timeout: 5), "Missing \(id)", file: file, line: line) }
        return result
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, in: app, file: file, line: line)
        let day = app.scrollViews["day-scroll"]
        let controls = app.descendants(matching: .any).matching(identifier: "day-controls").firstMatch
        let inDay = day.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        let inControls = controls.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        if inDay && !inControls {
            for _ in 0..<6 {
                let top = max(app.frame.minY + 65, day.frame.minY)
                let bottom = controls.exists && controls.frame.height > 0 ? controls.frame.minY - 8 : app.frame.maxY - 36
                if target.isHittable && target.frame.minY >= top && target.frame.maxY <= bottom { break }
                guard bottom - top > 50 else { break }
                let upward = target.frame.maxY > bottom
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.width / 2, dy: (upward ? bottom - 12 : top + 12) - app.frame.minY))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width / 2, dy: (upward ? top + 12 : bottom - 12) - app.frame.minY)))
            }
        }
        let picker = app.scrollViews["exercise-picker-scroll"]
        let custom = app.scrollViews["custom-exercise-scroll"]
        let scroll = picker.exists ? picker : (custom.exists ? custom : app.scrollViews.firstMatch)
        let inPickerContent = (picker.exists || custom.exists) && scroll.descendants(matching: .any).matching(identifier: id).firstMatch.exists
        if inPickerContent || !target.isHittable {
            var upward = true
            var recoveringTarget = false
            for _ in 0..<20 {
                guard scroll.exists else { break }
                // Offscreen picker rows can report hittable behind the keyboard.
                // Include its prediction strip and require the whole row to show.
                let keyboard = app.keyboards.firstMatch
                let top = max(app.frame.minY + 80, scroll.frame.minY + 16)
                let bottom = min(scroll.frame.maxY - 16, app.frame.maxY - 36,
                    keyboard.exists ? keyboard.frame.minY - 72 : app.frame.maxY)
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
            if inPickerContent {
                let keyboard = app.keyboards.firstMatch
                let bottom = min(scroll.frame.maxY - 16, app.frame.maxY - 36,
                    keyboard.exists ? keyboard.frame.minY - 72 : app.frame.maxY)
                XCTAssertLessThanOrEqual(target.frame.maxY, bottom, "Covered \(id)", file: file, line: line)
            }
        }
        XCTAssertTrue(target.isHittable, "Unreachable \(id)", file: file, line: line)
        target.tap()
    }
    @MainActor private func attach(_ title: String, _ app: XCUIApplication) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = title; item.lifetime = .keepAlways; add(item)
    }
}
