import SwiftUI
import SendaDomain
import SendaLogger

public struct TrainingSettingsView: View {
    public enum Destination { case weightUnits, backup }

    @Bindable var model: TrainingNotebookModel
    let destination: Destination
    let close: () -> Void

    public init(model: TrainingNotebookModel, destination: Destination = .weightUnits, close: @escaping () -> Void) {
        self.model = model; self.destination = destination; self.close = close
    }

    public var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    title.fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 0)
                    done.fixedSize(horizontal: true, vertical: true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title
                    done.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch destination {
                    case .weightUnits: weightUnits
                    case .backup:
                        NotebookBackupTools(
                            showsHeading: false,
                            exportBackup: { try model.backupData() },
                            exportCSV: { try model.csvData() },
                            previousBackup: { try model.previousBackupData() },
                            previousOriginalFiles: { try model.previousOriginalFilesData() },
                            restore: { archive in
                                model.restoreBackup(archive) ? nil : (model.backupErrorMessage ?? "Your notebook could not be restored. Try again.")
                            }
                        )
                    }
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .clipped()
            .accessibilityIdentifier("settings-scroll")
        }
        .background(NotebookStyle.ivory).foregroundStyle(NotebookStyle.ink).tint(NotebookStyle.clay)
        .buttonStyle(.plain).scrollIndicators(.never)
    }

    private var title: some View {
        Text(destination == .backup ? "Backup & restore" : "Weight units")
            .font(NotebookTypography.heading(31))
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var done: some View {
        Button(action: close) {
            Text("Done").frame(minWidth: 44, minHeight: 44)
        }.accessibilityIdentifier("close-settings")
    }

    private var weightUnits: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    let selected = model.workspace.preferredUnit == unit
                    Button { model.setPreferredUnit(unit) } label: {
                        HStack(spacing: 12) {
                            Text(unit == .pounds ? "Pounds (lb)" : "Kilograms (kg)")
                                .font(.body.weight(selected ? .semibold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if selected {
                                Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold))
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 8).frame(minHeight: 48).contentShape(Rectangle())
                    }
                    .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.ink)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("preference-\(unit.symbol)")
                    Rectangle().fill(NotebookStyle.rule).frame(height: 0.5).accessibilityHidden(true)
                }
            }
            Text("Used for progress and new workouts.")
                .font(.subheadline).foregroundStyle(NotebookStyle.quiet)
                .fixedSize(horizontal: false, vertical: true)
            if let error = model.errorMessage { ProfileActionError(model: model, message: error) }
        }
    }
}
