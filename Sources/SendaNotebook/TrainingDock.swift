import SwiftUI
import SendaLogger

struct TrainingDock: View {
    @Bindable var model: TrainingNotebookModel
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrainingSection.allCases, id: \.self) { section in
                let selected = model.section == section
                Button { model.selectSection(section) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.symbol + (selected ? ".fill" : "")).font(.system(size: 20))
                        Text(section.rawValue).font(.caption.weight(selected ? .semibold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }.frame(maxWidth: .infinity, minHeight: 54).contentShape(Rectangle())
                }
                .foregroundStyle(selected ? NotebookStyle.clay : NotebookStyle.quiet)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("dock-\(section.rawValue.lowercased())")
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 4)
        .background(alignment: .top) { Rectangle().fill(NotebookStyle.rule).frame(height: 0.5) }
        .background(NotebookStyle.ivory.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .contain).accessibilityIdentifier("app-dock")
    }
}
