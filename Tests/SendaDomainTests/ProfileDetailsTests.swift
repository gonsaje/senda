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
}
