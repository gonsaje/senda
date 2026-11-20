import SwiftUI
import SendaDomain
import SendaLogger

struct TrainingWeekMuscleThumbnail: View {
    let counts: [MuscleRegion: Int]

    var body: some View {
        HStack(spacing: 1) {
            MuscleFigure(aspect: .front, counts: counts, onCharcoal: true)
            MuscleFigure(aspect: .back, counts: counts, onCharcoal: true)
        }
        .frame(width: 36, height: 38)
        .accessibilityHidden(true)
    }
}

struct TrainingWeekMusclesView: View {
    let training: WeeklyMuscleTraining
    let profile: ProfileModel
    private var targets: [WeeklyMuscleTarget] { profile.details.weeklyMuscleTargets }
    let exerciseName: (String) -> String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selection: MuscleRegion?
    @State private var editsTarget = false

    private var listedMuscles: [MuscleRegion] {
        let trained = training.regions.map(\.muscle)
        let targeted = targets.map(\.muscle).filter { !trained.contains($0) }
        return trained + targeted.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectedMuscle: MuscleRegion? {
        selection.flatMap { listedMuscles.contains($0) ? $0 : nil } ?? listedMuscles.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(NotebookStyle.ivory)
        .foregroundStyle(NotebookStyle.ink)
        .buttonStyle(.plain)
        .sheet(isPresented: $editsTarget) {
            if let selectedMuscle {
                TrainingWeeklyMuscleTargetEditor(profile: profile,
                    target: targets.first { $0.muscle == selectedMuscle },
                    availableMuscles: [selectedMuscle], initialMuscle: selectedMuscle,
                    close: { editsTarget = false })
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let selectedMuscle {
                    Text("One working or drop set can train several muscles.")
                        .font(.subheadline)
                        .foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                    if listedMuscles.contains(where: ExerciseMuscleMap.illustratedRegions.contains) {
                        figures(selected: selectedMuscle)
                        legend
                    }
                    contribution(selectedMuscle)
                    muscles
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No muscles to show")
                            .font(.headline)
                        Text("Log a working set or drop set for a tagged exercise.")
                            .font(.subheadline)
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("week-muscle-empty")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("week-muscles-sheet")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Muscles trained")
                .font(NotebookTypography.heading(26))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("close-week-muscles")
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .background(NotebookStyle.ivory)
        .overlay(alignment: .bottom) { rule }
    }

    private func figures(selected: MuscleRegion) -> some View {
        HStack(alignment: .top, spacing: 32) {
            figure(.front, label: "Front", selected: selected)
            figure(.back, label: "Back", selected: selected)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func figure(_ aspect: MuscleFigureAspect, label: String, selected: MuscleRegion) -> some View {
        VStack(spacing: 2) {
            MuscleFigure(aspect: aspect, counts: training.counts, selected: selected, onRegionTap: { muscle in
                if listedMuscles.contains(muscle) { selection = muscle }
            })
                .frame(width: 76, height: 162)
            Text(label)
                .font(.caption)
                .foregroundStyle(NotebookStyle.quiet)
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                ForEach(MuscleHeatLevel.allCases, id: \.self) { key($0) }
                Text("sets").font(.caption).foregroundStyle(NotebookStyle.quiet).fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Sets per muscle")
                    .font(.caption)
                    .foregroundStyle(NotebookStyle.quiet)
                ForEach(MuscleHeatLevel.allCases, id: \.self) { key($0) }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func key(_ level: MuscleHeatLevel) -> some View {
        HStack(spacing: 4) {
            Circle().fill(level.fill(onCharcoal: false)).frame(width: 8, height: 8)
            Text(level.label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(NotebookStyle.quiet)
                .fixedSize()
        }
    }

    private var muscles: some View {
        let column = GridItem(.flexible(), spacing: 14, alignment: .leading)
        return LazyVGrid(columns: textSize >= .xxLarge ? [column] : [column, column], spacing: 0) {
            ForEach(listedMuscles, id: \.self) { muscle in
                let region = training.regions.first { $0.muscle == muscle }
                let isSelected = selectedMuscle == muscle
                Button { selection = muscle } label: {
                    HStack(spacing: 4) {
                        Text(muscle.name)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .fixedSize(horizontal: false, vertical: true)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        Spacer(minLength: 0)
                        Text((region?.count ?? 0).formatted())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(NotebookStyle.quiet)
                    }
                    .foregroundStyle(isSelected ? NotebookStyle.clay : NotebookStyle.ink)
                    .padding(.vertical, 4)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .overlay(alignment: .top) { rule }
                }
                .accessibilityLabel(muscle.name)
                .accessibilityValue(volume(region))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("week-muscle-region-\(muscle.rawValue)")
            }
        }
    }

    private func contribution(_ muscle: MuscleRegion) -> some View {
        let region = training.regions.first { $0.muscle == muscle }
        let target = targets.first { $0.muscle == muscle }
        return VStack(alignment: .leading, spacing: 8) {
            rule
            VStack(alignment: .leading, spacing: 4) {
                Text(muscle.name)
                    .font(NotebookTypography.heading(17, relativeTo: .headline))
                    .accessibilityAddTraits(.isHeader)
                Text(volume(region))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .accessibilityIdentifier("week-muscle-volume")
                if let region, region.supportingCount > 0 {
                    Text("\(region.primaryCount.formatted()) primary · \(region.supportingCount.formatted()) supporting")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(NotebookStyle.quiet)
                        .accessibilityIdentifier("week-muscle-roles")
                }
                Button { editsTarget = true } label: {
                    HStack(spacing: 8) {
                        if let target {
                            Text("Weekly target · \(target.setRangeText) primary \(target.maximumSets == 1 ? "set" : "sets")")
                        } else {
                            Text("Set weekly target")
                        }
                        Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                    }
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(NotebookStyle.clay)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("Edit the weekly set target for \(muscle.name)")
                .accessibilityIdentifier("week-muscle-target")
            }
            .fixedSize(horizontal: false, vertical: true)
            ForEach(region?.lifts ?? []) { lift in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(exerciseName(lift.exerciseID))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(lift.isPrimary ? sets(lift.count) : "\(sets(lift.count)) · supporting")
                        .monospacedDigit()
                        .foregroundStyle(NotebookStyle.quiet)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("week-muscle-lift-\(lift.exerciseID)")
            }
        }
    }

    private func sets(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "set" : "sets")"
    }

    private func volume(_ region: WeeklyMuscleTraining.Region?) -> String {
        let days = region?.dayCount ?? 0
        return "\(sets(region?.count ?? 0)) across \(days.formatted()) \(days == 1 ? "day" : "days")"
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}
