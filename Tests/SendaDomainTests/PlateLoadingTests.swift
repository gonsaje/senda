import Foundation
import Testing
import SendaDomain

struct PlateLoadingTests {
    @Test func usesFewestPlatesAndBreaksTiesLargestFirst() {
        let plan = PlateLoading.calculate(totalWeight: 18_500, barbellWeight: 4_500, unit: .pounds)
        #expect(plan == .exact(total: 18_500, perSide: [.init(size: 45, count: 1), .init(size: 25, count: 1)]))
        #expect(PlateLoading.calculate(totalWeight: 26_500, barbellWeight: 4_500, unit: .pounds)
                == .exact(total: 26_500, perSide: [.init(size: 55, count: 2)]))
        #expect(PlateLoading.calculate(totalWeight: 22_500, barbellWeight: 4_500, unit: .pounds)
                == .exact(total: 22_500, perSide: [.init(size: 55, count: 1), .init(size: 35, count: 1)]))
    }

    @Test func handlesKilogramFractionalPlatesAndCustomBar() throws {
        let kg = WeightUnit.kilograms
        let bar = try #require(kg.parse("12.35"))
        let target = try #require(kg.parse("54.85"))
        #expect(PlateLoading.calculate(totalWeight: target, barbellWeight: bar, unit: kg)
                == .exact(total: target, perSide: [.init(size: 20, count: 1), .init(size: 1.25, count: 1)]))
        let uneven = try #require(kg.parse("13.35"))
        let upper = try #require(kg.parse("14.85"))
        #expect(PlateLoading.calculate(totalWeight: uneven, barbellWeight: bar, unit: kg)
                == .between(lower: bar, upper: upper))
    }

    @Test func calculatesInDisplayedUnitAndPreservesBarOnlyAtOriginalPrecision() throws {
        let kg = WeightUnit.kilograms
        let bar = 4_401 // 44.01 lb displays as 19.96 kg.
        let sameDisplayedWeight = try #require(kg.parse(kg.text(for: bar)))
        #expect(sameDisplayedWeight != bar)
        #expect(PlateLoading.calculate(totalWeight: sameDisplayedWeight, barbellWeight: bar, unit: kg)
                == .exact(total: bar, perSide: []))
        let target = try #require(kg.parse("22.46"))
        #expect(PlateLoading.calculate(totalWeight: target, barbellWeight: bar, unit: kg)
                == .exact(total: target, perSide: [.init(size: 1.25, count: 1)]))
    }

    @Test func givesBothLoadableNeighborsAndRespectsUpperBound() {
        #expect(PlateLoading.calculate(totalWeight: 4_750, barbellWeight: 4_500, unit: .pounds)
                == .between(lower: 4_500, upper: 5_000))
        #expect(PlateLoading.calculate(totalWeight: 1_000_000, barbellWeight: 4_250, unit: .pounds)
                == .between(lower: 999_750, upper: nil))
    }

    @Test func distinguishesBarOnlyBelowBarAndInvalidWeights() {
        #expect(PlateLoading.calculate(totalWeight: 4_500, barbellWeight: 4_500, unit: .pounds)
                == .exact(total: 4_500, perSide: []))
        #expect(PlateLoading.calculate(totalWeight: 4_000, barbellWeight: 4_500, unit: .pounds) == .belowBar)
        #expect(PlateLoading.calculate(totalWeight: 0, barbellWeight: 4_500, unit: .pounds) == .belowBar)
        #expect(PlateLoading.calculate(totalWeight: 5_000, barbellWeight: 0, unit: .pounds) == nil)
        #expect(PlateLoading.calculate(totalWeight: Int.max, barbellWeight: 100, unit: .pounds) == nil)
        #expect(PlateLoading.calculate(totalWeight: 100, barbellWeight: Int.min, unit: .pounds) == nil)
    }
}
