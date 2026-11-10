// Render the approved SVG geometry; do not redraw or recolor the mark.
// Usage: swift scripts/render-logo.swift [--app-icon] input.svg output.png
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum LogoExportError: Error { case invalid(String) }

func outline(_ data: String, translation: CGPoint) throws -> CGPath {
    let expression = try NSRegularExpression(pattern: "[A-Za-z]|[-+]?(?:\\d*\\.\\d+|\\d+\\.?\\d*)(?:[eE][-+]?\\d+)?")
    let tokens = expression.matches(in: data, range: NSRange(data.startIndex..., in: data)).map {
        String(data[Range($0.range, in: data)!])
    }
    var index = 0, command = ""
    let path = CGMutablePath()
    func number() throws -> CGFloat {
        guard index < tokens.count, let value = Double(tokens[index]) else { throw LogoExportError.invalid("Path coordinate") }
        index += 1
        return CGFloat(value)
    }
    func point() throws -> CGPoint {
        let x = try number(), y = try number()
        return CGPoint(x: x + translation.x, y: y + translation.y)
    }
    while index < tokens.count {
        if tokens[index].first?.isLetter == true { command = tokens[index]; index += 1 }
        switch command {
        case "M": path.move(to: try point()); command = "L"
        case "L": path.addLine(to: try point())
        case "C":
            let first = try point(), second = try point(), end = try point()
            path.addCurve(to: end, control1: first, control2: second)
        case "Z": path.closeSubpath(); command = ""
        default: throw LogoExportError.invalid("Unsupported path command: \(command)")
        }
    }
    return path
}

final class LogoReader: NSObject, XMLParserDelegate {
    var paths: [(CGPath, String)] = []
    var fills: [String] = []
    var failure: Error?
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "g" { fills.append(attributes["fill"] ?? fills.last ?? "") }
        guard name == "path" else { return }
        do {
            guard let data = attributes["d"], let fill = attributes["fill"] ?? fills.last,
                  ["#A94E32", "#302720"].contains(fill), let transform = attributes["transform"],
                  transform.hasPrefix("translate("), transform.hasSuffix(")") else {
                throw LogoExportError.invalid("Unexpected SVG shape, color or transform")
            }
            let values = transform.dropFirst(10).dropLast().split { $0 == "," || $0.isWhitespace }.compactMap { Double($0) }
            guard values.count == 2 else { throw LogoExportError.invalid("Translation") }
            paths.append((try outline(data, translation: CGPoint(x: values[0], y: values[1])), fill))
        } catch { failure = error; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "g" { fills.removeLast() }
    }
}

let appIcon = CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--app-icon"
guard CommandLine.arguments.count == 3 || appIcon else { throw LogoExportError.invalid("Provide [--app-icon] input SVG and output PNG paths") }
let source = URL(fileURLWithPath: CommandLine.arguments[appIcon ? 2 : 1]), destination = URL(fileURLWithPath: CommandLine.arguments[appIcon ? 3 : 2])
let reader = LogoReader(), parser = XMLParser(data: try Data(contentsOf: source))
parser.delegate = reader
guard parser.parse(), reader.paths.count == 6 else { throw reader.failure ?? LogoExportError.invalid("Expected six approved paths") }
let paths = appIcon ? reader.paths.filter { $0.1 == "#A94E32" } : reader.paths
guard !appIcon || paths.count == 1 else { throw LogoExportError.invalid("Expected one approved trail path") }
let artworkBounds = paths.reduce(CGRect.null) { $0.union($1.0.boundingBoxOfPath) }
let bounds = appIcon ? artworkBounds : artworkBounds.integral.insetBy(dx: -2, dy: -2)
let width = appIcon ? 1024 : 1536
let scale = CGFloat(width) * (appIcon ? 0.64 : 1) / bounds.width
let height = appIcon ? width : Int(ceil(bounds.height * scale))
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: space, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | (appIcon ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
if appIcon {
    context.setFillColor(CGColor(colorSpace: space, components: [247.0 / 255, 243.0 / 255, 235.0 / 255, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
} else { context.clear(CGRect(x: 0, y: 0, width: width, height: height)) }
context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: scale, y: -scale)
if appIcon {
    // Preserve the asymmetrical trail; only adjust its placement optically.
    let x = (CGFloat(width) - bounds.width * scale) / 2 - CGFloat(width) * 0.02
    let y = (CGFloat(height) - bounds.height * scale) / 2 - CGFloat(height) * 0.03
    context.translateBy(x: x / scale, y: y / scale)
}
context.translateBy(x: -bounds.minX, y: -bounds.minY)
for (path, fill) in paths {
    let rgb = UInt32(fill.dropFirst(), radix: 16)!
    context.setFillColor(CGColor(colorSpace: space, components: [CGFloat((rgb >> 16) & 255) / 255,
        CGFloat((rgb >> 8) & 255) / 255, CGFloat(rgb & 255) / 255, 1])!)
    context.addPath(path); context.fillPath()
}
guard let image = context.makeImage(), let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw LogoExportError.invalid("PNG destination")
}
CGImageDestinationAddImage(output, image, nil)
guard CGImageDestinationFinalize(output) else { throw LogoExportError.invalid("PNG encoding") }
print("Rendered \(paths.count) unchanged paths: artwork \(artworkBounds), output \(width) × \(height), \(appIcon ? "opaque" : "transparent") sRGB.")
