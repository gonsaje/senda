import SwiftUI
import SendaDomain
import SendaLogger

enum NotebookStyle {
    static let ivory = Color(red: 247 / 255, green: 243 / 255, blue: 235 / 255)
    static let clay = Color(red: 169 / 255, green: 78 / 255, blue: 50 / 255)
    static let ink = Color(red: 48 / 255, green: 39 / 255, blue: 32 / 255)
    static let quiet = ink.opacity(0.65)
    static let rule = ink.opacity(0.16)
}

struct RecordButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(.headline, design: .default))
                .frame(maxWidth: .infinity).frame(minHeight: 54)
                .foregroundStyle(NotebookStyle.ivory)
                .background(NotebookStyle.clay, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .opacity(1)
    }
}

enum EntryText {
    static func summary(_ values: [SetValues]) -> String {
        guard let first = values.first else { return "No sets" }
        if values.allSatisfy({ $0 == first }) {
            return "\(NumericField.weight.text(first.weight)) lb × \(first.reps) × \(values.count)"
        }
        if values.allSatisfy({ $0.weight == first.weight }) {
            return "\(NumericField.weight.text(first.weight)) lb / " + values.map { String($0.reps) }.joined(separator: "  ")
        }
        return values.map { "\(NumericField.weight.text($0.weight)) lb × \($0.reps)" }.joined(separator: "; ")
    }

    static func date(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }
}

extension View {
    @ViewBuilder func numericKeyboard(decimal: Bool) -> some View {
        #if os(iOS)
        keyboardType(decimal ? .decimalPad : .numberPad)
        #else
        self
        #endif
    }
}
