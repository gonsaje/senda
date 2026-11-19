import CoreText
import SwiftUI
import SendaDomain
import SendaLogger

enum NotebookStyle {
    private struct AdaptiveColor: ShapeStyle, Hashable {
        let light: Color
        let dark: Color

        func resolve(in environment: EnvironmentValues) -> Color.Resolved {
            (environment.colorScheme == .dark ? dark : light).resolve(in: environment)
        }
    }

    private static func pair(_ light: Color, _ dark: Color) -> Color {
        Color(AdaptiveColor(light: light, dark: dark))
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
              green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }

    private static let paper = rgb(0xF7F3EB)
    private static let charcoal = rgb(0x302720)
    private static let terracotta = rgb(0xA94E32)
    private static let peach = rgb(0xEEA080)
    private static let selectedBrown = rgb(0x443026)
    private static let brownRule = rgb(0x494138)

    static let ivory = pair(paper, rgb(0x251F1A))
    static let ink = pair(charcoal, paper)
    static let clay = pair(terracotta, peach)
    static let olive = pair(rgb(0x626854), rgb(0xB4B99E))
    static let quiet = pair(charcoal.opacity(0.65), rgb(0xC6B9AA))
    static let rule = pair(charcoal.opacity(0.10), brownRule)

    static let cover = pair(charcoal, rgb(0x382F28))
    static let onCover = pair(paper, rgb(0xFAF4EA))
    static let coverRule = pair(paper.opacity(0.2), rgb(0x63594F))
    static let todayFill = pair(terracotta.opacity(0.07), selectedBrown)
    static let primaryFill = pair(terracotta, rgb(0x89442D))
    static let onPrimary = pair(paper, rgb(0xFFF8EE))
    static let typeFill = pair(terracotta.opacity(0.06), rgb(0x3A3029))

    static let dockSelectionFill = pair(terracotta.opacity(0.12), selectedBrown)
    static let dockSelectionText = pair(charcoal, peach)
    static let dockOutline = pair(charcoal.opacity(0.14), brownRule)
    static let dockShadow = pair(charcoal.opacity(0.12), .black.opacity(0.18))
}

public enum NotebookTypography {
    private static let upright = registerFace("DMSans")
    private static let slanted = registerFace("DMSans-Italic")

    public static func heading(_ size: CGFloat, italic: Bool = false, relativeTo style: Font.TextStyle = .title) -> Font {
        guard let name = italic ? slanted : upright else {
            let fallback = Font.system(style, weight: .semibold)
            return italic ? fallback.italic() : fallback
        }
        // The named Semibold instance uses a fixed 14 pt optical size. Match the design
        // to the base heading size, then let SwiftUI scale it with Dynamic Type.
        let axes = [0x77676874: CGFloat(600), 0x6F70737A: min(40, max(9, size))] // wght, opsz
        let base = CTFontDescriptorCreateWithNameAndSize(name as CFString, size)
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: axes] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        return .custom(CTFontCopyPostScriptName(font) as String, size: size, relativeTo: style)
    }

    private static func registerFace(_ resource: String) -> String? {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "ttf") else { return nil }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        let faces = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        guard let face = faces?.first else { return nil }
        return CTFontDescriptorCopyAttribute(face, kCTFontNameAttribute) as? String
    }
}

struct RecordButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(.headline, design: .default))
                .frame(maxWidth: .infinity).frame(minHeight: 54)
                .foregroundStyle(NotebookStyle.onPrimary)
                .background(NotebookStyle.primaryFill, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .opacity(1)
    }
}

enum EntryText {
    static func load(_ weight: Int) -> String {
        "\(WeightUnit.pounds.text(for: weight)) lb / \(WeightUnit.kilograms.text(for: weight)) kg"
    }

    static func set(_ values: SetValues) -> String { "\(load(values.weight)) × \(values.reps)" }

    static func working(_ common: CommonWorkingSet) -> String {
        let reps = common.reps.lowerBound == common.reps.upperBound ? String(common.reps.lowerBound)
            : "\(common.reps.lowerBound)–\(common.reps.upperBound)"
        return "\(load(common.weight)) × \(reps)"
    }

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
