import Foundation
import Testing
@testable import SendaDomain

struct WeightUnitTests {
    @Test func switchingUnitsKeepsCanonicalWeightAndShowsBothAmounts() throws {
        let weight = 13_500
        let unit = WeightUnit.pounds
        #expect(unit.symbol == "lb")
        #expect(unit.alternate.symbol == "kg")
        #expect(unit.alternate.alternate == unit)
        #expect(unit.text(for: weight) == "135")
        #expect(unit.alternate.text(for: weight) == "61.23")
        #expect(unit.text(for: weight) == "135")
        #expect(WeightUnit.allCases == [.pounds, .kilograms])
        #expect(try JSONEncoder().encode(unit.alternate) == Data("\"kg\"".utf8))
        #expect(try JSONDecoder().decode(WeightUnit.self, from: Data("\"lb\"".utf8)) == .pounds)
    }

    @Test func amountUsesExactPoundDefinitionAndCanonicalHundredths() {
        #expect(WeightUnit.pounds.amount(for: 13_500) == 135)
        #expect(WeightUnit.pounds.amount(for: 1) == Decimal(string: "0.01"))
        #expect(WeightUnit.kilograms.amount(for: 13_500) == Decimal(string: "61.23496995"))
        #expect(WeightUnit.pounds.maximumAmount == 10_000)
        #expect(WeightUnit.kilograms.maximumAmount == Decimal(string: "4535.9237"))
    }

    @Test(arguments: [
        (0, "0", "0"), (1, "0.01", "0"), (100, "1", "0.45"), (12, "0.12", "0.05"),
        (13, "0.13", "0.06"), (13_510, "135.1", "61.28"),
        (13_599, "135.99", "61.68"), (1_000_000, "10000", "4535.92")
    ])
    func textRoundsToTwoDecimalsAndTrimsZeros(weight: Int, pounds: String, kilograms: String) {
        #expect(WeightUnit.pounds.text(for: weight) == pounds)
        #expect(WeightUnit.kilograms.text(for: weight) == kilograms)
    }

    @Test func canonicalConversionRoundsHalfUpToNearestHundredthPound() {
        #expect(WeightUnit.pounds.canonicalValue(for: 135) == 13_500)
        #expect(WeightUnit.pounds.canonicalValue(for: Decimal(string: "135.1249")!) == 13_512)
        #expect(WeightUnit.pounds.canonicalValue(for: Decimal(string: "135.125")!) == 13_513)
        #expect(WeightUnit.kilograms.canonicalValue(for: 60) == 13_228)
        #expect(WeightUnit.kilograms.canonicalValue(for: Decimal(string: "0.45359237")!) == 100)
        #expect(WeightUnit.kilograms.canonicalValue(for: Decimal(string: "0.00226796184")!) == 0)
        #expect(WeightUnit.kilograms.canonicalValue(for: Decimal(string: "0.00226796185")!) == 1)
    }

    @Test func conversionRejectsAmountsOutsideCanonicalRange() {
        for unit in WeightUnit.allCases {
            #expect(unit.canonicalValue(for: 0) == 0)
            #expect(unit.canonicalValue(for: unit.maximumAmount) == 1_000_000)
            #expect(unit.canonicalValue(for: Decimal(string: "-0.001")!) == nil)
            #expect(unit.canonicalValue(for: unit.maximumAmount + Decimal(string: "0.0001")!) == nil)
            #expect(unit.canonicalValue(for: .nan) == nil)
            #expect(unit.canonicalValue(for: .greatestFiniteMagnitude) == nil)
        }
    }

    @Test func parseAcceptsStrictDecimalOrCommaInSelectedUnit() {
        #expect(WeightUnit.pounds.parse("135") == 13_500)
        #expect(WeightUnit.pounds.parse("135.25") == 13_525)
        #expect(WeightUnit.pounds.parse("135,5") == 13_550)
        #expect(WeightUnit.pounds.parse("0.01") == 1)
        #expect(WeightUnit.pounds.parse("10000") == 1_000_000)
        #expect(WeightUnit.kilograms.parse("60") == 13_228)
        #expect(WeightUnit.kilograms.parse("61,25") == 13_503)
        #expect(WeightUnit.kilograms.parse("4535.92") == 999_999)
        for unit in WeightUnit.allCases {
            #expect(unit.parse("0,00") == 0)
            #expect(unit.parse("000") == 0)
        }
    }

    @Test(arguments: [
        "", " ", "+1", "-1", "1e2", "1E2", "NaN", "inf", "1.", "1,", ".5", ",5",
        "1.234", "1,234", "1.2.3", "1,2.3", "1_000", "1 000", "１２", "١٢", "1\n", "\t1",
        "10lb", "10 kg", "10000.01", "999999999999999999999999999999999999"
    ])
    func parseRejectsMalformedOrExcessiveInput(text: String) {
        for unit in WeightUnit.allCases { #expect(unit.parse(text) == nil) }
    }

    @Test func parseRejectsKilogramsBeyondPoundStorageLimit() {
        #expect(WeightUnit.kilograms.parse("4535.93") == nil)
        #expect(WeightUnit.kilograms.parse("10000") == nil)
    }

    @Test func poundStepsPreserveExistingIncrement() {
        #expect(WeightUnit.pounds.step == Decimal(string: "2.5"))
        #expect(WeightUnit.pounds.stepped(13_500, increasing: true) == 13_750)
        #expect(WeightUnit.pounds.stepped(13_500, increasing: false) == 13_250)
    }

    @Test func kilogramStepsUseDisplayedAmountWithoutAccumulatingRoundingDrift() {
        let unit = WeightUnit.kilograms
        #expect(unit.step == Decimal(string: "1.25"))
        #expect(unit.stepped(13_500, increasing: true) == 13_774)
        #expect(unit.stepped(13_228, increasing: true) == 13_503)
        var weight = 0
        for _ in 0..<48 { weight = unit.stepped(weight, increasing: true) }
        #expect(weight == 13_228)
        #expect(unit.text(for: weight) == "60")
        for _ in 0..<48 { weight = unit.stepped(weight, increasing: false) }
        #expect(weight == 0)
    }

    @Test func stepsClampAtBothStorageBounds() {
        for unit in WeightUnit.allCases {
            #expect(unit.stepped(0, increasing: false) == 0)
            #expect(unit.stepped(1, increasing: false) == 0)
            #expect(unit.stepped(1_000_000, increasing: true) == 1_000_000)
            #expect(unit.stepped(999_999, increasing: true) == 1_000_000)
            #expect(unit.stepped(Int.min, increasing: false) == 0)
            #expect(unit.stepped(Int.max, increasing: true) == 1_000_000)
        }
    }
}
