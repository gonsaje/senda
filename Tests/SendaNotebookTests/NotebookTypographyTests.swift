import CoreText
import SwiftUI
import Testing
@testable import SendaNotebook

struct NotebookTypographyTests {
    @Test @MainActor func headingsUseDMSansSemiboldAtTheirDesignSize() throws {
        let weightAxis = NSNumber(value: 0x77676874) // wght
        let opticalAxis = NSNumber(value: 0x6F70737A) // opsz
        let cases: [(CGFloat, Bool, Font.TextStyle)] = [
            (22, false, .title2), (31, true, .title), (8, false, .caption), (44, false, .largeTitle)
        ]
        for (size, italic, style) in cases {
            let heading = NotebookTypography.heading(size, italic: italic, relativeTo: style)
            let baseName = italic ? "DMSans-9ptItalic" : "DMSans-9ptRegular"
            let base = CTFontCreateWithName(baseName as CFString, size, nil)
            let opticalSize = Double(min(40, max(9, size)))
            let axes = [weightAxis: NSNumber(value: 600), opticalAxis: NSNumber(value: opticalSize)]
            let descriptor = CTFontDescriptorCreateCopyWithAttributes(
                CTFontCopyFontDescriptor(base), [kCTFontVariationAttribute: axes] as CFDictionary)
            let expected = CTFontCreateWithFontDescriptor(descriptor, size, nil)
            let name = CTFontCopyPostScriptName(expected) as String
            #expect(heading == Font.custom(name, size: size, relativeTo: style))

            let resolved = CTFontCreateWithName(name as CFString, size, nil)
            #expect(CTFontCopyFamilyName(resolved) as String == "DM Sans")
            #expect(CTFontGetSymbolicTraits(resolved).contains(.traitItalic) == italic)
            let variation = try #require(CTFontCopyVariation(resolved) as? [NSNumber: NSNumber])
            #expect(variation[weightAxis]?.intValue == 600)
            // Core Text omits axes at their default, which is 9 pt for DM Sans.
            #expect((variation[opticalAxis]?.doubleValue ?? 9) == opticalSize)
        }
    }
}
