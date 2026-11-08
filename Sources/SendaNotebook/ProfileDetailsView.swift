import SwiftUI
import SendaDomain
import SendaLogger

struct ProfileDetailsView: View {
    @Bindable var profile: ProfileModel
    let close: () -> Void
    @State private var name: String
    @State private var email: String
    init(profile: ProfileModel, close: @escaping () -> Void) {
        self.profile = profile; self.close = close
        _name = State(initialValue: profile.details.name); _email = State(initialValue: profile.details.email)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button("Cancel", action: close).frame(minHeight: 44)
                    Spacer()
                    Button("Done") { if profile.save(name: name, email: email) { close() } }
                        .fontWeight(.semibold).frame(minHeight: 44).accessibilityIdentifier("profile-save")
                }
                Text("Account details").font(NotebookTypography.heading(31))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    TextField("Your name", text: $name).textContentType(.name).frame(minHeight: 44)
                        .accessibilityIdentifier("profile-name")
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email · optional").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                    TextField("Email address", text: $email).textContentType(.emailAddress).autocorrectionDisabled().frame(minHeight: 44)
                        #if os(iOS)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        #endif
                        .accessibilityIdentifier("profile-email")
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5)
                }
                Text("Your details stay on this device.").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                if let error = profile.errorMessage { Text(error).font(.callout).foregroundStyle(NotebookStyle.clay) }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .textFieldStyle(.plain).background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink)
        .tint(NotebookStyle.clay).buttonStyle(.plain).scrollIndicators(.never)
        .accessibilityIdentifier("profile-details-scroll")
    }
}

struct TrainingSettingsView: View {
    @Bindable var model: TrainingNotebookModel
    let close: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Settings").font(NotebookTypography.heading(31))
                    Spacer()
                    Button("Done", action: close).frame(minHeight: 44).accessibilityIdentifier("close-settings")
                }
                Text("Weight units").font(.headline)
                HStack(spacing: 8) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        let selected = model.workspace.preferredUnit == unit
                        Button { model.setPreferredUnit(unit) } label: {
                            HStack(spacing: 8) {
                                Text(unit.symbol).monospacedDigit()
                                if selected { Image(systemName: "checkmark").font(.caption) }
                            }.frame(minWidth: 80, minHeight: 48)
                                .background(selected ? NotebookStyle.olive.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        }
                        .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
                        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("preference-\(unit.symbol)")
                    }
                }
                Text("Used for progress and new workouts.").font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                if let error = model.errorMessage { TrainingSaveError(model: model, message: error) }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.background(NotebookStyle.ivory).tint(NotebookStyle.clay).buttonStyle(.plain).scrollIndicators(.never)
            .accessibilityIdentifier("settings-scroll")
    }
}
