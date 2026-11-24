import SwiftUI
import SendaDomain

struct ProgramWeekPicker: View {
    let program: TrainingProgram
    @Binding var week: Int
    @State private var picking = false
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var cellWidth = 48.0

    var body: some View {
        HStack(spacing: 0) {
            arrow(previous: true)
            Button { picking = true } label: {
                HStack(spacing: 6) {
                    Text("Week \(week) of \(program.weeks)").font(.body.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
            }
            .accessibilityHint("Choose a week by training block")
            .accessibilityIdentifier("program-week-preview")
            arrow(previous: false)
        }
        .buttonStyle(.plain)
        .foregroundStyle(NotebookStyle.ink)
        .background(NotebookStyle.inputSurface, in: NotebookStyle.squircle(12))
        .sheet(isPresented: $picking) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Choose week")
                        .font(NotebookTypography.heading(25, relativeTo: .title2))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Button { picking = false } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close week picker")
                }
                .padding(.leading, 20).padding(.trailing, 8).padding(.top, 16).padding(.bottom, 6)
                .frame(maxWidth: 560)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(program.blocks.indices, id: \.self) { index in
                                let block = program.blocks[index]
                                let first = 1 + program.blocks.prefix(index).reduce(0) { $0 + $1.weeks }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(block.title).font(.headline).accessibilityAddTraits(.isHeader)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: 8)], spacing: 8) {
                                        ForEach(first..<(first + block.weeks), id: \.self) { number in
                                            Button { week = number; picking = false } label: {
                                                Text("\(number)").font(.body.monospacedDigit().weight(.medium))
                                                    .frame(maxWidth: .infinity, minHeight: 44)
                                                    .foregroundStyle(number == week ? NotebookStyle.onPrimary : NotebookStyle.ink)
                                                    .background(number == week ? NotebookStyle.primaryFill : NotebookStyle.inputSurface,
                                                                in: NotebookStyle.squircle(10))
                                            }.buttonStyle(.plain)
                                                .accessibilityLabel("Week \(number)")
                                                .accessibilityAddTraits(number == week ? .isSelected : [])
                                                .accessibilityIdentifier("program-week-\(number)")
                                                .id(number)
                                        }
                                    }
                                }
                            }
                        }.padding().frame(maxWidth: 560)
                    }.accessibilityIdentifier("program-choose-week")
                        .onAppear { proxy.scrollTo(week, anchor: .center) }
                }
            }
            .foregroundStyle(NotebookStyle.ink)
            .frame(maxWidth: .infinity)
            .background(NotebookStyle.ivory)
            #if os(iOS)
            .presentationDetents(textSize.isAccessibilitySize ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private func arrow(previous: Bool) -> some View {
        Button { week += previous ? -1 : 1 } label: {
            Image(systemName: previous ? "chevron.backward" : "chevron.forward")
                .frame(width: 48, height: 44).contentShape(Rectangle())
        }
        .disabled(previous ? week <= 1 : week >= program.weeks)
        .accessibilityLabel(previous ? "Previous program week" : "Next program week")
    }
}
