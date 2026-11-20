import Foundation
import SendaDomain
import SendaPersistence

extension TrainingNotebookModel {
    public var customPrograms: [TrainingProgram] { workspace.programs ?? [] }
    public var programs: [TrainingProgram] {
        guard snapshot.customExercises?.isEmpty == false else { return TrainingProgram.catalog + customPrograms }
        let mapping = presetMapping
        return TrainingProgram.catalog.map { $0.mappingExercises(mapping) } + customPrograms
    }

    private var presetMapping: [String: String] {
        var mapping: [String: String] = [:]
        for exercise in exercises {
            if let preset = exercise.presetID, preset != exercise.id { mapping[preset] = exercise.id }
        }
        return mapping
    }

    @discardableResult public func saveProgram(_ program: TrainingProgram) -> Bool {
        commit(synchronizeInput: false) { state in
            guard UUID(uuidString: program.id) != nil else { throw ProgramError.immutable }
            var list = state.training!.programs ?? []
            let index = list.firstIndex { $0.id == program.id }
            let existingIDs = index.map { list[$0].referencedExerciseIDs } ?? []
            try program.validated(against: Set(activeExercises.map(\.id)).union(existingIDs))
            if let index { list[index] = program }
            else { list.append(program) }
            state.training!.programs = list
        }
    }

    @discardableResult public func deleteProgram(id: String) -> Bool {
        commit(synchronizeInput: false) { state in
            guard !TrainingProgram.catalog.contains(where: { $0.id == id }) else { throw ProgramError.immutable }
            let remaining = (state.training!.programs ?? []).filter { $0.id != id }
            state.training!.programs = remaining.isEmpty ? nil : remaining
        }
    }

    public func exportProgram(_ program: TrainingProgram) throws -> Data {
        try program.validated(against: Set(activeExercises.map(\.id)))
        let ids = program.referencedExerciseIDs
        let definitions = (snapshot.customExercises ?? []).filter { ids.contains($0.id) }
        guard definitions.allSatisfy({ !$0.isArchived }) else { throw ProgramError.unavailableExercise }
        let customIDs = Set(definitions.map(\.id))
        var mapping: [String: String] = [:]
        for (canonical, local) in presetMapping where ids.contains(local) {
            guard !customIDs.contains(canonical) else { throw ProgramError.exerciseConflict }
            mapping[local] = canonical
        }
        return try program.mappingExercises(mapping).exportData(customExercises: definitions)
    }

    /// Import the program and only its referenced custom exercises in the same journal transaction.
    @discardableResult public func importProgram(_ data: Data) throws -> TrainingProgram {
        let file = try ProgramFile.decode(data)
        let incoming = file.customExercises ?? []
        var merged = snapshot.customExercises ?? []
        let localByID = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
        var usedNames = Set(activeExercises.flatMap(\.searchNames).map(ExerciseLibrary.matchingKey))
        let reserved = Set(Exercise.catalog.map(\.id))
        var seen: Set<String> = []
        for item in incoming {
            guard seen.insert(item.id).inserted else { throw ProgramError.invalidFile }
            if let local = localByID[item.id] {
                guard !local.isArchived, local == item else { throw ProgramError.exerciseConflict }
            } else {
                let names = Set(item.searchNames.map(ExerciseLibrary.matchingKey))
                guard !reserved.contains(item.id), ExerciseLibrary.canManageCustom(item), usedNames.isDisjoint(with: names)
                else { throw ProgramError.exerciseConflict }
                usedNames.formUnion(names)
                merged.append(item)
            }
        }
        let resolved = try ExerciseLibrary.validated(custom: merged)
        var mapping = presetMapping
        for item in incoming { mapping[item.id] = nil }
        let program = file.program.mappingExercises(mapping)
        try program.validated(against: Set(resolved.filter { !$0.isArchived }.map(\.id)))
        if let existing = programs.first(where: { $0.id == program.id }) {
            guard existing == program else { throw ProgramError.duplicateID }
            return existing
        }
        guard UUID(uuidString: program.id) != nil else { throw ProgramError.invalidID }
        guard commit(synchronizeInput: false, { candidate in
            if !incoming.isEmpty { candidate.customExercises = merged }
            candidate.training!.programs = (candidate.training!.programs ?? []) + [program]
        }) else { throw ProgramError.writeFailure }
        return program
    }

    public func unavailableProgramExercises(_ program: TrainingProgram) -> [Exercise] {
        let referenced = program.referencedExerciseIDs
        return exercises.filter { $0.isArchived && referenced.contains($0.id) }
    }

    public func isProgramScheduled(_ program: TrainingProgram, starting start: TrainingDay) -> Bool {
        scheduledProgram(program, starting: start) != nil
    }

    public func scheduledProgram(_ program: TrainingProgram, starting start: TrainingDay) -> TrainingProgram? {
        workspace.activeProgramEnrollments.first { $0.programID == program.id && $0.start == start }?.program
    }

    public func programSession(on day: TrainingDay) -> ScheduledProgramSession? {
        guard let reference = workspace.days[day.rawValue]?.programSession else { return nil }
        let enrollment = workspace.programEnrollments?.first { $0.programID == reference.programID && $0.start == reference.start }
        return enrollment?.session(for: reference)
    }

    public func previewProgram(_ program: TrainingProgram, starting start: TrainingDay) throws -> [ProgramScheduleSlot] {
        let definition = scheduledProgram(program, starting: start) ?? program
        try definition.validated(against: Set(exercises.map(\.id)))
        return try programSlots(definition, starting: start, in: workspace)
    }

    @discardableResult public func scheduleProgram(_ program: TrainingProgram, starting start: TrainingDay) -> Bool {
        commit(synchronizeInput: false) { state in
            var workspace = state.training!
            workspace.discardUnusedProgramEnrollments()
            let enrollment = ProgramEnrollment(program: program, start: start)
            if let previous = workspace.programEnrollments?.first(where: { $0.programID == program.id && $0.start == start }) {
                if workspace.activeProgramEnrollments.contains(where: { $0.programID == program.id && $0.start == start }) { return }
                guard previous.program == program else { throw ProgramError.previousRemoval }
            }
            try program.validated(against: Set(activeExercises.map(\.id)))
            let slots = try programSlots(program, starting: start, in: workspace).filter { !$0.isOccupied }
            guard !slots.isEmpty else { throw ProgramError.allOccupied }
            for slot in slots {
                let session = slot.session
                let ids = session.exercises.map(\.exerciseID)
                let unit = workspace.days[slot.day.rawValue]?.unit ?? workspace.preferredUnit
                let rows = Dictionary(uniqueKeysWithValues: ids.map { ($0, [TrainingRow(unit: unit, kind: .working)]) })
                let plans = Dictionary(uniqueKeysWithValues: session.exercises.map { ($0.exerciseID, $0.plan) })
                var workout = DayWorkout(exerciseIDs: ids, selectedExerciseID: ids.first, rows: rows, unit: unit,
                                         exercisePlans: plans, supersets: session.supersets.isEmpty ? nil : session.supersets.map(WorkoutSuperset.init(plan:)))
                workout.programSession = ScheduledProgramReference(program: program, start: start, slot: slot)
                workspace.days[slot.day.rawValue] = workout
            }
            if workspace.programEnrollments?.contains(enrollment) != true {
                workspace.programEnrollments = (workspace.programEnrollments ?? []) + [enrollment]
            }
            state.training = workspace
        }
    }

    private func programSlots(_ program: TrainingProgram, starting start: TrainingDay, in workspace: TrainingWorkspace) throws -> [ProgramScheduleSlot] {
        let reservedForUndo: TrainingDay?
        if case let .removedFromWorkout(day, _, _, _)? = workspace.undo { reservedForUndo = day }
        else { reservedForUndo = nil }
        var slots: [ProgramScheduleSlot] = []
        var week = 0
        for block in program.blocks {
            let sessions = block.sessions.sorted { $0.dayOffset < $1.dayOffset }
            for _ in 0..<block.weeks {
                for session in sessions {
                    let day = try start.adding(days: week * 7 + session.dayOffset)
                    let existing = workspace.days[day.rawValue]
                    let isOccupied = reservedForUndo == day || (existing.map {
                        !$0.exerciseIDs.isEmpty || !$0.rows.isEmpty || $0.exercisePlans?.isEmpty == false || $0.programSession != nil
                    } ?? false)
                    let sameEnrollment = existing?.programSession.map { $0.programID == program.id && $0.start == start } ?? false
                    slots.append(ProgramScheduleSlot(day: day, week: week + 1, blockTitle: block.title, session: session,
                                                     isOccupied: isOccupied, isScheduled: sameEnrollment))
                }
                week += 1
            }
        }
        return slots
    }
}
