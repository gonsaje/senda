import Foundation
import Observation
import SendaDomain
import SendaPersistence

@Observable @MainActor public final class ProfileModel {
    public private(set) var details = ProfileDetails()
    public private(set) var openingError: String?
    public private(set) var errorMessage: String?
    @ObservationIgnored private let repository: any ProfileRepository
    public init(repository: any ProfileRepository) { self.repository = repository; reload() }
    public func reload() {
        do { details = try repository.load().validated(); openingError = nil; errorMessage = nil }
        catch { openingError = error.localizedDescription }
    }
    @discardableResult public func saveName(_ name: String) -> Bool {
        save(name: name, email: details.email)
    }
    @discardableResult public func save(name: String, email: String) -> Bool {
        guard openingError == nil else { errorMessage = openingError; return false }
        do {
            let candidate = try ProfileDetails(name: name, email: email).validated()
            try repository.save(candidate)
            details = candidate; errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}
