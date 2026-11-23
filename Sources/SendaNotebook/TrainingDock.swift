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
            outline.fill(NotebookStyle.inputSurface)
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
                            TrainingDockIcon(section: section, selected: selected)
                                .frame(width: 27, height: 27)
                                .frame(height: 28)
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
            .accessibilityHint(section == .log ? "Returns to today in your preferred calendar view" : "")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(section == .learn ? "dock-library" : "dock-\(section.rawValue.lowercased())")
            #if os(iOS)
            .accessibilityShowsLargeContentViewer {
                Label {
                    Text(section.title)
                } icon: {
                    TrainingDockIcon(section: section, selected: selected)
                        .frame(width: 54, height: 54)
                }
            }
            #endif
        }
    }

}
