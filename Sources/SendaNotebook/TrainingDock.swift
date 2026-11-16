import SwiftUI
import SendaLogger

struct TrainingDock: View {
    @Bindable var model: TrainingNotebookModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let outline = RoundedRectangle(cornerRadius: 24)
        HStack(spacing: 0) {
            ForEach(TrainingSection.allCases, id: \.self) { section in
                let selected = model.section == section
                Button { model.selectDockSection(section) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: section.symbol)
                            .symbolVariant(selected ? .fill : .none)
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 54, height: 28)
                            .anchorPreference(key: DockIconBounds.self, value: .bounds) { [section: $0] }
                            .accessibilityHidden(true)
                        Text(section.rawValue)
                            .font(.caption.weight(selected ? .semibold : .medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .lineLimit(1).fixedSize()
                    }.frame(maxWidth: .infinity, minHeight: 54).contentShape(Rectangle())
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
        .backgroundPreferenceValue(DockIconBounds.self) { bounds in
            GeometryReader { geometry in
                if let anchor = bounds[model.section] {
                    let icon = geometry[anchor]
                    Capsule()
                        .fill(NotebookStyle.clay.opacity(0.05))
                        .frame(width: icon.width, height: icon.height)
                        .position(x: icon.midX, y: icon.midY)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.section)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
}

private struct DockIconBounds: PreferenceKey {
    static var defaultValue: [TrainingSection: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [TrainingSection: Anchor<CGRect>], nextValue: () -> [TrainingSection: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
