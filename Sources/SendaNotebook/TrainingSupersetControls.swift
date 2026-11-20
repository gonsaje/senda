import SwiftUI
import SendaDomain
import SendaLogger

enum SupersetOrder {
    static func groups(_ ids: [String], plans: [SupersetPlan]) -> [[String]] {
        let paired = Dictionary(uniqueKeysWithValues: plans.map { ($0.first, $0.second) })
        let seconds = Set(paired.values)
        return ids.compactMap { id in
            if seconds.contains(id) { return nil }
            return [id] + (paired[id].map { [$0] } ?? [])
        }
    }
}

struct SupersetMembership {
    let group: WorkoutSuperset
    let letter: String

    func code(for exerciseID: String) -> String {
        letter + (group.plan.first == exerciseID ? "1" : "2")
    }

    static func letter(at offset: Int) -> String {
        var index = offset + 1
        var letter = ""
        while index > 0 {
            index -= 1
            letter = String(UnicodeScalar(65 + index % 26)!) + letter
            index /= 26
        }
        return letter
    }

    var title: String { "Superset \(letter)" }

    var status: String {
        switch group.phase {
        case .ready: group.plan.rounds == 1 ? "1 round" : "\(group.plan.rounds) rounds"
        case .working: "Round \(group.round) of \(group.plan.rounds)"
        case .resting: "Round \(group.round) complete"
        case .finished: group.plan.rounds == 1 ? "1 round complete" : "\(group.plan.rounds) rounds complete"
        }
    }

    @MainActor func advanceTitle(in model: TrainingNotebookModel) -> String {
        if group.currentExerciseID == group.plan.first { return "Next · \(model.exercise(group.plan.second).displayName)" }
        return group.round == group.plan.rounds ? "Finish superset" : "Finish round \(group.round)"
    }
}

extension TrainingNotebookModel {
    /// The letter follows the pair's position in this workout, including after reordering.
    var supersetMemberships: [String: SupersetMembership] {
        var result: [String: SupersetMembership] = [:]
        for (index, group) in supersets.enumerated() {
            let member = SupersetMembership(group: group, letter: SupersetMembership.letter(at: index))
            result[group.plan.first] = member
            result[group.plan.second] = member
        }
        return result
    }
}

struct TrainingSupersetControls: View {
    let model: TrainingNotebookModel
    let member: SupersetMembership
    let advance: (UUID) -> Void
    let showExercises: () -> Void
    private var group: WorkoutSuperset { member.group }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let timer = group.timer {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = timer.remaining(at: context.date)
                    VStack(alignment: .leading, spacing: 6) {
                        timerControls(seconds: seconds, paused: timer.isPaused)
                        primary(seconds: seconds)
                    }
                    .onChange(of: seconds == 0) { _, ended in
                        if ended { TrainingAccessibility.announce("Rest complete") }
                    }
                }
            } else {
                if group.phase == .working {
                    Button {
                        model.setSupersetTimer(.start, for: group.id)
                    } label: {
                        Label("Rest timer", systemImage: "timer").frame(minHeight: 44)
                    }
                    .foregroundStyle(NotebookStyle.clay)
                    .accessibilityIdentifier("superset-start-timer")
                }
                primary(seconds: 0)
            }
        }
        .disabled(model.canRetrySave)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func primary(seconds: Int) -> some View {
        switch group.phase {
        case .ready:
            action("Start superset", id: "superset-start") { _ = model.startSuperset(group.id) }
        case .working:
            if model.exercise?.id == group.currentExerciseID {
                action(member.advanceTitle(in: model), id: "superset-advance") { advance(group.id) }
                    .disabled(!model.canAdvanceSuperset(group.id))
            } else {
                action("Return to \(model.exercise(group.currentExerciseID).displayName)", id: "superset-return") {
                    _ = model.startSuperset(group.id)
                }
            }
        case .resting:
            action(seconds > 0 ? "Skip rest & start round \(group.round + 1)" : "Start round \(group.round + 1)",
                   id: "superset-next-round") { _ = model.startNextSupersetRound(group.id) }
        case .finished:
            action("All exercises", id: "superset-all-exercises", body: showExercises)
        }
    }

    private func action(_ title: String, id: String, body: @escaping () -> Void) -> some View {
        Button(action: body) {
            Text(title).font(.body.weight(.semibold)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(SupersetPrimaryStyle())
        .accessibilityIdentifier(id)
    }

    private func timerControls(seconds: Int, paused: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    timerTitle(seconds).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    countdown(seconds)
                }
                VStack(alignment: .leading) { timerTitle(seconds); countdown(seconds) }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { timerButtons(seconds: seconds, paused: paused) }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 0) { timerButtons(seconds: seconds, paused: paused) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotebookStyle.clay.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private func timerTitle(_ seconds: Int) -> some View {
        Label(seconds == 0 ? "Rest complete" : group.phase == .resting ? "Rest between rounds" : "Rest timer",
              systemImage: "timer")
            .font(.subheadline.weight(.medium))
    }

    private func countdown(_ seconds: Int) -> some View {
        Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
            .font(NotebookTypography.heading(28, relativeTo: .title2).monospacedDigit())
            .accessibilityLabel("\(seconds) seconds remaining")
            .accessibilityIdentifier("superset-countdown")
    }

    @ViewBuilder private func timerButtons(seconds: Int, paused: Bool) -> some View {
        if seconds > 0 {
            timerButton(paused ? "Resume" : "Pause", id: paused ? "resume" : "pause", action: paused ? .resume : .pause)
        }
        timerButton("−15 sec", id: "shorten", action: .adjust(-15)).disabled(seconds == 0)
        timerButton("+15 sec", id: "extend", action: .adjust(15))
        if group.phase != .resting { timerButton(seconds > 0 ? "End" : "Done", id: "end", action: .end) }
    }

    private func timerButton(_ text: String, id: String, action: SupersetTimerAction) -> some View {
        Button {
            model.setSupersetTimer(action, for: group.id)
        } label: {
            Text(text).font(.subheadline.weight(.medium))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .foregroundStyle(NotebookStyle.clay)
        .accessibilityIdentifier("superset-\(id)-timer")
    }
}

struct SupersetPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).padding(.vertical, 2)
            .foregroundStyle(isEnabled ? NotebookStyle.onPrimary : NotebookStyle.quiet)
            .background(isEnabled ? NotebookStyle.primaryFill : NotebookStyle.clay.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
