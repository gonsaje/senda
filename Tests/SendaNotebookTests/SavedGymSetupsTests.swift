import Foundation
import Testing
import SendaDomain
@testable import SendaNotebook

struct SavedGymSetupsTests {
    private let home = ExerciseGymFilter(gym: .home, availableEquipment: [.dumbbells, .flatBench])
    private let travel = ExerciseGymFilter(availableEquipment: [])

    @Test func oldInventoryBecomesAReusableSetupEvenIfFirstActionIsClear() throws {
        let previous = try JSONEncoder().encode(home)
        var setups = SavedGymSetups(data: Data(), legacy: previous)
        #expect(setups.filter == home)
        #expect(setups.selected?.name == "Home gym")
        let id = try #require(setups.selectedID)
        #expect(SavedGymSetups(data: Data(), legacy: previous).selectedID == id)
        setups.applyTemporary(.init())
        #expect(setups.filter == .init())
        #expect(setups.selected == nil)
        var reopened = SavedGymSetups(data: try JSONEncoder().encode(setups), legacy: previous)
        reopened.select(id)
        #expect(reopened.filter == home)
        #expect(reopened.setups.count == 1)
    }

    @Test func firstUnnamedInventoryCanBeReusedAfterClearingTheLibraryFilters() throws {
        var setups = SavedGymSetups()
        setups.save(home, named: "", editing: nil)
        let garage = try #require(setups.selectedID)
        #expect(setups.selected?.name == "Home gym")
        setups.applyTemporary(.init())
        #expect(setups.filter == .init())
        setups.select(garage)
        #expect(setups.filter == home)
    }

    @Test func changingActiveFiltersDoesNotChangeSavedInventories() throws {
        var setups = SavedGymSetups()
        setups.save(home, named: "Garage", editing: nil)
        let garage = try #require(setups.selectedID)
        setups.save(travel, named: "Travel", editing: nil)
        let hotel = try #require(setups.selectedID)
        setups.select(garage)
        #expect(setups.filter == home)
        setups.applyTemporary(.init(gym: .home))
        #expect(setups.selected == nil)
        setups.select(garage)
        #expect(setups.filter == home)
        setups.select(hotel)
        #expect(setups.filter == travel)
        setups.applyTemporary(.init())
        #expect(setups.setups.map(\.name) == ["Garage", "Travel"])
    }

    @Test func editingAndRemovingAddressOnlyTheChosenSetup() throws {
        var setups = SavedGymSetups()
        setups.save(home, named: "Garage", editing: nil)
        let garage = try #require(setups.selectedID)
        setups.save(travel, named: "Trip", editing: nil)
        let trip = try #require(setups.selectedID)
        #expect(!setups.allowsName(" GARAGE ", editing: trip))
        #expect(!setups.allowsName("  ", editing: nil))
        #expect(setups.allowsName("Garage", editing: garage))
        #expect(setups.suggestedName(for: .init(gym: .home)) == "Home gym")
        setups.save(.init(gym: .commercial), named: "  Hotel  ", editing: trip)
        #expect(setups.selectedID == trip)
        #expect(setups.selected?.name == "Hotel")
        setups.remove(garage)
        #expect(setups.filter == .init(gym: .commercial))
        setups.remove(trip)
        #expect(setups.filter == .init())
        #expect(setups.setups.isEmpty)
    }

    @Test func repeatedSuggestedNamesAreDistinctAndUnrestrictedInstallsHaveNoSetups() throws {
        let unrestricted = try JSONEncoder().encode(ExerciseGymFilter())
        var setups = SavedGymSetups(data: Data(), legacy: unrestricted)
        #expect(setups.setups.isEmpty)
        setups.save(home, named: "", editing: nil)
        setups.save(home, named: "", editing: nil)
        #expect(setups.setups.map(\.name) == ["Home gym", "Home gym 2"])
        let stored = try JSONEncoder().encode(setups)
        #expect(SavedGymSetups(data: stored, legacy: Data()).setups == setups.setups)
    }
}
