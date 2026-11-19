import Foundation
import Testing
import SendaDomain
@testable import SendaNotebook

struct WeightDialScaleTests {
    @Test func dragTracksFractionalTicksAndReversesWithoutRounding() {
        let scale = WeightDialScale(unit: .pounds)
        let start = scale.position(for: 13_575)
        #expect(abs(start - 54.3) < 0.0001)
        let moved = scale.dragPosition(from: start, translation: -16)
        #expect(abs(moved - start - 0.5) < 0.0001)
        #expect(scale.nearestTick(to: moved) == 55)
        #expect(abs(scale.dragPosition(from: moved, translation: 16) - start) < 0.0001)
        #expect(scale.dragPosition(from: 0, translation: 44) == 0)
        #expect(scale.dragPosition(from: CGFloat(scale.lastTick), translation: -44) == CGFloat(scale.lastTick))
    }

    @Test(arguments: [WeightUnit.pounds, .kilograms])
    func everyDetentMapsBackToItsOwnExactPosition(unit: WeightUnit) {
        let scale = WeightDialScale(unit: unit)
        for tick in 0...scale.lastTick {
            let weight = scale.weight(at: tick)
            #expect(scale.position(for: weight) == CGFloat(tick))
        }
        #expect(scale.weight(at: -1) == 0)
        #expect(scale.weight(at: scale.lastTick + 1) == NumericField.weight.range.upperBound)
        #expect(scale.position(for: Int.min) == 0)
        #expect(scale.position(for: Int.max) == CGFloat(scale.lastTick))
    }

    @Test func lastKilogramDetentReachesTheStorageLimit() {
        let scale = WeightDialScale(unit: .kilograms)
        #expect(scale.lastTick == 3_629)
        #expect(scale.weight(at: 48) == 13_228)
        #expect(scale.weight(at: scale.lastTick - 1) == WeightUnit.kilograms.parse("4535"))
        #expect(scale.weight(at: scale.lastTick) == 1_000_000)
        let justBelowLimit = scale.position(for: 999_999)
        #expect(justBelowLimit < CGFloat(scale.lastTick))
        #expect(justBelowLimit > CGFloat(scale.lastTick - 1))
        #expect(scale.nearestTick(to: justBelowLimit) == scale.lastTick)
    }

    @Test func engagementClicksAtEachRidgeAndHoldsThroughWobble() {
        let scale = WeightDialScale(unit: .pounds)
        var engaged = 54
        for (raw, expected) in [(54.59, 54), (54.60, 55), (54.58, 55), (54.41, 55),
                                (54.40, 54), (54.43, 54), (54.59, 54), (54.60, 55)] {
            engaged = scale.engagedTick(at: raw, from: engaged)
            #expect(engaged == expected)
        }
    }

    @Test func fastDragsCrossMultipleDetentsAndStopAtTheEnds() {
        let scale = WeightDialScale(unit: .kilograms)
        #expect(scale.engagedTick(at: 59.6, from: 54) == 60)
        #expect(scale.engagedTick(at: 50.4, from: 60) == 50)
        #expect(scale.engagedTick(at: -20, from: 2) == 0)
        #expect(scale.engagedTick(at: CGFloat(scale.lastTick + 20), from: scale.lastTick - 3) == scale.lastTick)
    }

    @Test func firstNotchProtectsTypedValuesNearEitherSideOfTheMidpoint() {
        let scale = WeightDialScale(unit: .pounds)
        let below = scale.position(for: 13_624)
        let above = scale.position(for: 13_626)
        #expect(scale.nearestTick(to: below) == 54)
        #expect(scale.nearestTick(to: above) == 55)
        #expect(scale.engagedTick(at: below + 0.16, from: 54, preserving: below) == 54)
        #expect(scale.engagedTick(at: above - 0.16, from: 55, preserving: above) == 55)
        #expect(scale.engagedTick(at: below + 0.26, from: 54, preserving: below) == 55)
        #expect(scale.engagedTick(at: above - 0.26, from: 55, preserving: above) == 54)
    }

    @Test func displayResistsTravelThenCatchesUpAtTheClick() {
        let scale = WeightDialScale(unit: .pounds)
        #expect(scale.dragDisplayPosition(at: 54, engaged: 54) == 54)
        #expect(scale.dragDisplayPosition(at: 54.55, engaged: 54) < 54.55)
        #expect(scale.dragDisplayPosition(at: 54.45, engaged: 55) > 54.45)
        let before = scale.dragDisplayPosition(at: 54.60, engaged: 54)
        let after = scale.dragDisplayPosition(at: 54.60, engaged: 55)
        #expect((2...4).contains((after - before) * WeightDialScale.tickSpacing))
        for direction: CGFloat in [-1, 1] {
            var tick = 54
            var previous: CGFloat = 54
            for i in 1...160 {
                let raw = 54 + direction * CGFloat(i) / 100
                tick = scale.engagedTick(at: raw, from: tick)
                let display = scale.dragDisplayPosition(at: raw, engaged: tick)
                #expect(direction * (display - previous) >= 0)
                previous = display
            }
        }
    }

    @Test func releaseOnlyCentersOnTheSuppliedEngagedOrTypedPosition() {
        for end: CGFloat in [54, 54.496, 55] {
            let start: CGFloat = 54.57
            let release = WeightDialRelease(from: start, to: end)
            #expect(release.position(after: 0) == start)
            var previous = start
            for millisecond in 1...400 {
                let next = release.position(after: Double(millisecond) / 1_000)
                #expect(next >= min(previous, end) && next <= max(previous, end))
                previous = next
            }
            #expect(previous == end)
        }
    }
}
