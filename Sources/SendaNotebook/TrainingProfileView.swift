import SwiftUI
import SendaDomain
import SendaLogger

private enum ProfileSheet: String, Identifiable {
    case details, units, backup
    var id: String { rawValue }
}

struct TrainingProfileView: View {
    @Bindable var model: TrainingNotebookModel
    @State private var sheet: ProfileSheet?
    @Environment(\.dynamicTypeSize) private var textSize

    private var unit: WeightUnit { model.workspace.preferredUnit }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Profile")
                    .font(NotebookTypography.heading(31))
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    rule
                    Button { sheet = .details } label: {
                        destinationRow(title: "Name",
                            detail: model.profile.details.name.isEmpty ? "Optional" : model.profile.details.name)
                    }
                    .disabled(model.profile.openingError != nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-details")
                    rule
                    Button { sheet = .units } label: {
                        HStack(spacing: 12) {
                            Group {
                                if textSize >= .xxxLarge {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Weight units").font(.body.weight(.medium))
                                        Text(unitLabel).foregroundStyle(NotebookStyle.quiet)
                                    }
                                } else {
                                    HStack(spacing: 12) {
                                        Text("Weight units").font(.body.weight(.medium))
                                        Spacer(minLength: 8)
                                        Text(unitLabel).foregroundStyle(NotebookStyle.quiet)
                                    }
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            chevron
                        }
                        .frame(minHeight: 44)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-weight-units")
                    rule
                    Button { sheet = .backup } label: {
                        destinationRow(title: "Backup & restore", detail: "Save a copy or restore your notebook")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-backup")
                    rule
                }
                Text("Your notebook is saved on this device and does not sync automatically.")
                    .font(.subheadline)
                    .foregroundStyle(NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile-storage-explanation")
                if let error = model.profile.openingError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error).font(.callout).foregroundStyle(NotebookStyle.clay)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try profile again") { model.profile.reload() }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                if let error = model.errorMessage {
                    if model.canRetryProgressAction { TrainingSaveError(model: model, message: error) }
                    else { ProfileActionError(model: model, message: error) }
                }
            }
            .padding(24)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .accessibilityIdentifier("profile-scroll")
        .sheet(item: $sheet) { destination in
            switch destination {
            case .details: ProfileDetailsView(profile: model.profile, close: { sheet = nil })
            case .units: TrainingSettingsView(model: model, close: { sheet = nil })
            case .backup: TrainingSettingsView(model: model, destination: .backup, close: { sheet = nil })
            }
        }
    }

    private var unitLabel: String { unit == .pounds ? "Pounds · lb" : "Kilograms · kg" }

    private func destinationRow(title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(NotebookStyle.quiet)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            chevron
        }
        .frame(minHeight: 44)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundStyle(NotebookStyle.quiet)
            .accessibilityHidden(true)
    }

    private var rule: some View {
        Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
    }
}
