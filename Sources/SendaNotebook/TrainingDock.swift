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
                .shadow(color: NotebookStyle.dockShadow, radius: 10, x: 0, y: 4)
        }
        .overlay {
            outline.strokeBorder(NotebookStyle.dockOutline, lineWidth: 0.5)
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
                let title = Text(section.title)
                    .font(.caption.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? NotebookStyle.dockSelectionText : NotebookStyle.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if textSize.isAccessibilitySize {
                        title
                    } else {
                        VStack(spacing: 3) {
                            Image(systemName: section.symbol)
                                .symbolVariant(selected ? .fill : .none)
                                .font(.system(size: 19, weight: .medium))
                                .frame(width: 54, height: 28)
                                .accessibilityHidden(true)
                            title
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: textSize.isAccessibilitySize ? 44 : 54)
                .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.quiet)
                .background(selected ? NotebookStyle.dockSelectionFill : .clear, in: RoundedRectangle(cornerRadius: 17))
                .contentShape(Rectangle())
            }
            .accessibilityLabel(section.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("dock-\(section.title.lowercased())")
            #if os(iOS)
            .accessibilityShowsLargeContentViewer {
                Label(section.title, systemImage: section.symbol)
                    .symbolVariant(selected ? .fill : .none)
            }
            #endif
        }
    }

}
