import SwiftUI
import SendaDomain
import SendaLogger

/// A single-choice exercise list. Sections give familiar lifts priority while searching covers the full list.
struct ExerciseChoiceSheet: View {
    struct Group: Identifiable {
        let title: String
        let exercises: [Exercise]
        var id: String { title }
    }

    let title: String
    let groups: [Group]
    let selectedID: String?
    let identifierPrefix: String
    let emptyMessage: String
    var clearTitle: String? = nil
    let select: (String?) -> Void
    let close: () -> Void
    @State private var search = ""
    @FocusState private var searching: Bool
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let key = ExerciseLibrary.matchingKey(search)
        let all = groups.flatMap(\.exercises)
        NavigationStack {
            List {
                if key.isEmpty {
                    if let clearTitle { row(clearTitle, id: nil) }
                    ForEach(groups) { group in
                        if !group.exercises.isEmpty {
                            Section {
                                ForEach(group.exercises) { item in row(item.displayName, id: item.id) }
                            } header: {
                                if !group.title.isEmpty { Text(group.title) }
                            }
                        }
                    }
                    if all.isEmpty { Text(emptyMessage).foregroundStyle(NotebookStyle.quiet) }
                } else {
                    let matches = ExerciseSelectionFilter.rankedMatches(all.filter { $0.matchesExerciseName(key: key) }, query: search)
                    ForEach(matches) { item in row(item.displayName, id: item.id) }
                    if matches.isEmpty { Text("No matching exercises.").foregroundStyle(NotebookStyle.quiet) }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) {
                if all.count > 8 {
                    ExerciseSearchField(search: $search, focus: $searching,
                        identifier: identifierPrefix + "search", clearIdentifier: identifierPrefix + "clear-search")
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(NotebookStyle.ivory)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NotebookStyle.ivory)
            .foregroundStyle(NotebookStyle.ink)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", action: close) } }
        }
        .tint(NotebookStyle.clay)
        #if os(iOS)
        .presentationDetents(all.count <= 5 && textSize < .xxLarge ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func row(_ name: String, id: String?) -> some View {
        Button { select(id) } label: {
            HStack(spacing: 12) {
                Text(name).multilineTextAlignment(.leading)
                    .fontWeight(id == selectedID ? .semibold : .regular)
                Spacer(minLength: 6)
                if id == selectedID {
                    Image(systemName: "checkmark").foregroundStyle(NotebookStyle.clay).accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(NotebookStyle.ivory)
        .accessibilityAddTraits(id == selectedID ? .isSelected : [])
        .accessibilityIdentifier(identifierPrefix + (id ?? "none"))
    }
}


struct ExerciseSearchField: View {
    @Binding var search: String
    let focus: FocusState<Bool>.Binding
    let identifier: String
    let clearIdentifier: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(NotebookStyle.quiet).accessibilityHidden(true)
            TextField("Find an exercise", text: $search).textFieldStyle(.plain).autocorrectionDisabled()
                .focused(focus).submitLabel(.search).onSubmit { focus.wrappedValue = false }
                .accessibilityLabel("Find an exercise").accessibilityIdentifier(identifier)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(NotebookStyle.quiet)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Clear search").accessibilityIdentifier(clearIdentifier)
            }
        }.padding(.leading, 12).padding(.trailing, search.isEmpty ? 12 : 0).frame(minHeight: 48)
            .overlay { NotebookStyle.squircle(7).stroke(NotebookStyle.rule, lineWidth: 1) }
    }
}
