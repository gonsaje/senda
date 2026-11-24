import Testing
@testable import SendaNotebook

struct SendaAccountRegistrationTests {
    @Test func requiresBothNamesAndPreservesTheirSpelling() {
        var form = SendaAccountRegistration(firstName: " ", lastName: " ")
        #expect(form.firstInvalidField == .firstName)
        form.firstName = "  María José "
        #expect(form.firstInvalidField == .lastName)
        form.lastName = " O’Neill-López "
        #expect(form.displayName == "María José O’Neill-López")
        #expect(form.firstInvalidField == .email)
    }

    @Test func recognizesEmailFormatAndTrimsSurroundingSpaces() {
        var form = SendaAccountRegistration()
        for email in ["senda+training@test.example.com", " Zoë.O'Neil@example.test "] {
            form.email = email
            #expect(form.error(for: .email) == nil)
        }
        for email in ["", "me", "a@b", "a..b@mail.test", "a@-domain.test", "a@host..test", "a@@host.test", "a b@host.test"] {
            form.email = email
            #expect(form.error(for: .email) != nil)
        }
    }

    @Test func requiresAFullMatchingPasswordOnEveryEdit() {
        var form = SendaAccountRegistration(firstName: "Test", lastName: "User", email: "test@example.com", password: "short")
        #expect(form.firstInvalidField == .password)
        form.password = "Maple cafés at dawn!"
        #expect(form.firstInvalidField == .confirmation)
        form.confirmation = "Maple cafe\u{301}s at dawn!"
        #expect(form.firstInvalidField == .confirmation)
        form.confirmation = form.password
        #expect(form.firstInvalidField == nil)
        form.password += " "
        #expect(form.firstInvalidField == .confirmation)
    }

    @Test func estimatesGuessablePasswordsAndLongPassphrases() {
        var form = SendaAccountRegistration()
        for weak in ["Password123!", "AbcdeAbcdeAbcdeAbcde", "3333333333333", "short"] {
            form.password = weak
            #expect(form.strength == .weak)
        }
        form.password = "Maple!Atlas9"
        #expect(form.strength == .fair)
        form.password = "violet kettle amber meadow"
        #expect(form.strength == .strong)
    }
}
