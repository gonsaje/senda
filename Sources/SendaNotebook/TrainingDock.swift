import SwiftUI
import SendaLogger

struct TrainingDock: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 24)
        Group {
            if textSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                    tabs
                }
            } else {
                HStack(spacing: 0) { tabs }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: 380)
        .background {
            outline.fill(NotebookStyle.ivory)
                .shadow(color: NotebookStyle.ink.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .overlay {
            outline.strokeBorder(NotebookStyle.ink.opacity(0.14), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("app-dock")
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }
    private var tabs: some View {
        ForEach(TrainingSection.allCases, id: \.self) { section in
            let selected = model.section == section
            Button { model.selectDockSection(section) } label: {
                let title = Text(section.rawValue)
                    .font(.caption.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? NotebookStyle.ink : NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                if textSize.isAccessibilitySize {
                    HStack(spacing: 5) {
                        if selected {
                            Image(systemName: "checkmark").font(.footnote.weight(.bold))
                                .accessibilityHidden(true)
                        }
                        title
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: section.symbol)
                            .symbolVariant(selected ? .fill : .none)
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 54, height: 28)
                            .accessibilityHidden(true)
                        title
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
                }
            }
            .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.quiet)
            .accessibilityLabel(section.rawValue)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("dock-\(section.rawValue.lowercased())")
            #if os(iOS)
            .accessibilityShowsLargeContentViewer {
                Label(section.rawValue, systemImage: section.symbol)
                    .symbolVariant(selected ? .fill : .none)
            }
            #endif
        }
    }

}
