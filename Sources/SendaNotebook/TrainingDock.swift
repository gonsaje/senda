import SwiftUI
import SendaLogger

struct TrainingDock: View {
    @Bindable var model: TrainingNotebookModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrainingSection.allCases, id: \.self) { section in
                let selected = model.section == section
                let symbol = section.symbol + (selected ? ".fill" : "")
                Button { model.selectSection(section) } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: symbol).font(.system(size: 20))
                                .frame(width: 24, height: 24)
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .frame(width: 10, height: 10)
                                    .background(NotebookStyle.ivory, in: Circle())
                                    .offset(x: 2, y: 1)
                            }
                        }.accessibilityHidden(true)
                        Text(section.rawValue)
                            .font(.caption.weight(selected ? .semibold : .regular))
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
                    Label(section.rawValue, systemImage: symbol)
                }
                #endif
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
        .background(alignment: .top) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        .background(NotebookStyle.ivory.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .contain).accessibilityIdentifier("app-dock")
    }
}
