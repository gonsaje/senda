import SwiftUI
import SendaDomain
import SendaLogger

public struct ProfileDetailsView: View {
    @Bindable var profile: ProfileModel
    let close: () -> Void
    @State private var name: String
    @FocusState private var nameFocused: Bool

    public init(profile: ProfileModel, close: @escaping () -> Void) {
        self.profile = profile; self.close = close
        _name = State(initialValue: profile.details.name)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Text("Cancel").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("profile-cancel")
                Spacer(minLength: 8)
                Button(action: save) {
                    Text("Done").fontWeight(.semibold).frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }.accessibilityIdentifier("profile-save")
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your name").font(NotebookTypography.heading(31))
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name · optional").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        TextField("Your name", text: $name).textContentType(.name).frame(minHeight: 44)
                            .focused($nameFocused).submitLabel(.done)
                            .onSubmit(save)
                            .accessibilityLabel("Name, optional")
                            .accessibilityIdentifier("profile-name")
                        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
                        if let error = profile.errorMessage {
                            Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("profile-save-error")
                        }
                    }
                    Text("Saved on this device and included in full backups.")
                        .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("profile-details-scroll")
        }
        .textFieldStyle(.plain).background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay).buttonStyle(.plain).scrollIndicators(.never)
    }

    private func save() {
        if profile.saveName(name) {
            nameFocused = false
            close()
        } else if let error = profile.errorMessage {
            TrainingAccessibility.announce(error)
        }
    }
}

struct ProfileActionError: View {
    @Bindable var model: TrainingNotebookModel
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message).font(.callout).foregroundStyle(NotebookStyle.clay)
            if model.canRetryProfileAction {
                Button { model.retryProfileAction() } label: {
                    Text("Try again").frame(minHeight: 44).contentShape(Rectangle())
                }
                    .accessibilityIdentifier("retry-profile-action")
            }
        }
    }
}
