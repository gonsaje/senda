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
        var candidate = details
        candidate.name = name
        candidate.email = email
        return persist(candidate)
    }
    @discardableResult public func saveGoal(_ goal: StrengthGoal) -> Bool {
        var candidate = details
        if let index = candidate.goals.firstIndex(where: { $0.id == goal.id }) {
            candidate.goals[index] = goal
        } else {
            candidate.goals.append(goal)
        }
        return persist(candidate)
    }
    @discardableResult public func removeGoal(_ id: UUID) -> Bool {
        var candidate = details
        candidate.goals.removeAll { $0.id == id }
        return persist(candidate)
    }
    @discardableResult public func saveWeeklyMuscleTarget(_ target: WeeklyMuscleTarget) -> Bool {
        var candidate = details
        if let index = candidate.weeklyMuscleTargets.firstIndex(where: { $0.muscle == target.muscle }) {
            candidate.weeklyMuscleTargets[index] = target
        } else {
            candidate.weeklyMuscleTargets.append(target)
        }
        return persist(candidate)
    }
    @discardableResult public func removeWeeklyMuscleTarget(_ muscle: MuscleRegion) -> Bool {
        var candidate = details
        candidate.weeklyMuscleTargets.removeAll { $0.muscle == muscle }
        return persist(candidate)
    }
    @discardableResult public func saveTrainerApplication(_ application: TrainerApplication) -> Bool {
        var candidate = details
        candidate.trainerApplication = application
        return persist(candidate)
    }

    private func persist(_ next: ProfileDetails) -> Bool {
        guard openingError == nil else { errorMessage = openingError; return false }
        do {
            let candidate = try next.validated()
            try repository.save(candidate)
            details = candidate; errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}
