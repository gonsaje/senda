import SwiftUI
import SendaDomain

struct CustomExerciseMusclePicker: View {
    @Binding var selection: [MuscleRegion]
    let mainGroup: MuscleGroup
    let onOpen: () -> Void
    @State private var choosing = false

    var body: some View {
        Button {
            onOpen()
            choosing = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muscles worked").font(.body.weight(.medium))
                    Text(selection.isEmpty ? "Optional" : selection.map(\.name).joined(separator: ", "))
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
                    .foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("custom-muscle-tags")
        .sheet(isPresented: $choosing) {
            NavigationStack {
                List {
                    ForEach(groups, id: \.self) { group in
                        let regions = MuscleRegion.allCases.filter { $0.group == group }
                        if !regions.isEmpty {
                            Section(group.rawValue) {
                                ForEach(regions, id: \.self) { region in choice(region) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(NotebookStyle.ivory)
                .foregroundStyle(NotebookStyle.ink)
                .navigationTitle("Muscles worked")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { choosing = false }
                            .accessibilityIdentifier("custom-muscle-tags-done")
                    }
                }
            }
            .tint(NotebookStyle.clay)
            #if os(iOS)
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var groups: [MuscleGroup] {
        guard mainGroup != .fullBody else { return MuscleGroup.allCases }
        return [mainGroup] + MuscleGroup.allCases.filter { $0 != mainGroup }
    }

    private func choice(_ region: MuscleRegion) -> some View {
        let selected = selection.contains(region)
        return Button {
            var tags = Set(selection)
            if selected { tags.remove(region) } else { tags.insert(region) }
            selection = MuscleRegion.allCases.filter(tags.contains)
        } label: {
            HStack(spacing: 12) {
                Text(region.name).fontWeight(selected ? .semibold : .regular)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(NotebookStyle.ivory)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("custom-muscle-tag-\(region.rawValue)")
    }
}
