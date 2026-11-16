import Testing
@testable import SendaDomain
struct ProfileDetailsTests {
    @Test func optionalDetailsAreNormalizedWithoutInventingAnAccount() throws {
        #expect(try ProfileDetails(name: "  Jae Song  ", email: " jae@example.com ").validated() == ProfileDetails(name: "Jae Song", email: "jae@example.com"))
        #expect(try ProfileDetails().validated() == ProfileDetails())
    }
    @Test func invalidNamesAndEmailsCannotBeSaved() {
        #expect(throws: (any Error).self) { try ProfileDetails(name: String(repeating: "x", count: 81)).validated() }
        for email in ["missing-at", "@example.com", "jae@", "ja e@example.com", "jae@@example.com"] {
            #expect(throws: (any Error).self) { try ProfileDetails(email: email).validated() }
        }
    }

    @Test func weeklyTargetsAllowAnExactCountAndRejectInvalidRangesOrDuplicateMuscles() throws {
        let chest = WeeklyMuscleTarget(muscle: .chest, minimumSets: 8, maximumSets: 8)
        let calves = WeeklyMuscleTarget(muscle: .calves, minimumSets: 1, maximumSets: 12)
        let profile = ProfileDetails(weeklyMuscleTargets: [chest, calves])
        #expect(try profile.validated() == profile)
        for (minimum, maximum) in [(0, 8), (12, 8)] {
            let invalid = WeeklyMuscleTarget(muscle: .chest, minimumSets: minimum, maximumSets: maximum)
            #expect(throws: WeeklyMuscleTargetError.invalidRange) {
                try ProfileDetails(weeklyMuscleTargets: [invalid]).validated()
            }
        }
        #expect(throws: WeeklyMuscleTargetError.duplicateMuscle) {
            try ProfileDetails(weeklyMuscleTargets: [chest, chest]).validated()
        }
    }
}
