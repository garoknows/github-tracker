import AppKit
import SwiftUI

// Renders the printable install guide from docs/INSTALL.md, so the PDF can never drift from it.
// Run from the repo root: swift run --package-path tools/docgen docgen .
// Writes docs/Tracker-for-GitHub-Install-Guide.pdf and site/Tracker-for-GitHub-Install-Guide.pdf.

// Shared look: GitHub Primer neutrals, the green contribution scale, the 3×3 brand mark.
enum Style {
    static let fg = Color(red: 0x1f / 255, green: 0x23 / 255, blue: 0x28 / 255)
    static let muted = Color(red: 0x59 / 255, green: 0x63 / 255, blue: 0x6e / 255)
    static let border = Color(red: 0xd1 / 255, green: 0xd9 / 255, blue: 0xe0 / 255)
    static let canvas = Color(red: 0xf6 / 255, green: 0xf8 / 255, blue: 0xfa / 255)
    static let green = Color(red: 0x1a / 255, green: 0x7f / 255, blue: 0x37 / 255)
    static let scale: [Color] = [0xeff2f5, 0xaceebb, 0x4ac26b, 0x2da44e, 0x116329].map {
        Color(red: Double(($0 >> 16) & 0xff) / 255, green: Double(($0 >> 8) & 0xff) / 255, blue: Double($0 & 0xff) / 255)
    }
}

struct BrandMark: View {
    var size: CGFloat
    var body: some View {
        let levels = [1, 3, 2, 4, 2, 0, 3, 1, 4]
        Grid(horizontalSpacing: size * 0.08, verticalSpacing: size * 0.08) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: size * 0.06).fill(Style.scale[levels[r * 3 + c]])
                            .frame(width: size * 0.28, height: size * 0.28)
                    }
                }
            }
        }
    }
}

// MARK: A small Markdown reader (only what INSTALL.md uses)

enum Block {
    case title(String)
    case heading(String)
    case paragraph(String)
    case numbered(Int, String)
    case bullet(String)
    case note(String)
    case image(path: String, alt: String)
    case code(String)
    case rule

    var isHeading: Bool {
        switch self {
        case .title, .heading: true
        default: false
        }
    }
}

func parse(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    var paragraph: [String] = []
    var note: [String] = []
    var code: [String]?

    func flush() {
        if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
        if !note.isEmpty { blocks.append(.note(note.joined(separator: "\n"))) }
        paragraph = []
        note = []
    }

    for raw in markdown.components(separatedBy: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if var lines = code {
            if line.hasPrefix("```") {
                blocks.append(.code(lines.joined(separator: "\n")))
                code = nil
            } else {
                lines.append(raw)
                code = lines
            }
            continue
        }
        if line.hasPrefix("```") { flush(); code = []; continue }
        if line.isEmpty { flush(); continue }
        if line == "---" { flush(); blocks.append(.rule); continue }
        if line.hasPrefix("# ") { flush(); blocks.append(.title(String(line.dropFirst(2)))); continue }
        if line.hasPrefix("## ") { flush(); blocks.append(.heading(String(line.dropFirst(3)))); continue }
        if line.hasPrefix(">") {
            if !paragraph.isEmpty { flush() }
            note.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
            continue
        }
        if line.hasPrefix("<img") {
            flush()
            blocks.append(.image(path: attribute("src", in: line) ?? "", alt: attribute("alt", in: line) ?? ""))
            continue
        }
        if line.hasPrefix("- ") { flush(); blocks.append(.bullet(String(line.dropFirst(2)))); continue }
        if let dot = line.firstIndex(of: "."), let n = Int(line[..<dot]), line[line.index(after: dot)...].hasPrefix(" ") {
            flush()
            blocks.append(.numbered(n, line[line.index(dot, offsetBy: 2)...].trimmingCharacters(in: .whitespaces)))
            continue
        }
        paragraph.append(line)
    }
    flush()
    return blocks
}

func attribute(_ name: String, in tag: String) -> String? {
    guard let start = tag.range(of: "\(name)=\"") else { return nil }
    let rest = tag[start.upperBound...]
    guard let end = rest.firstIndex(of: "\"") else { return nil }
    return String(rest[..<end])
}

/// Inline Markdown (bold, code, links) as styled text. Links print their address too, since paper can't be clicked.
func inline(_ text: String) -> Text {
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .inlineOnlyPreservingWhitespace
    guard let parsed = try? AttributedString(markdown: text, options: options) else { return Text(text) }
    var out = AttributedString()
    for run in parsed.runs {
        var piece = AttributedString(parsed[run.range])
        guard let link = run.link, link.scheme?.hasPrefix("http") == true else { out += piece; continue }
        piece.swiftUI.foregroundColor = Style.green
        out += piece
        let address = link.absoluteString.replacingOccurrences(of: "https://", with: "")
        if !String(piece.characters).contains(address) {
            var suffix = AttributedString(" (\(address))")
            suffix.swiftUI.foregroundColor = Style.muted
            out += suffix
        }
    }
    return Text(out)
}

// MARK: Pages

let page = CGSize(width: 612, height: 792) // US Letter
let margin: CGFloat = 54
let contentWidth = page.width - margin * 2

struct BlockView: View {
    let block: Block
    let docs: URL

    var body: some View {
        switch block {
        case .title(let t):
            HStack(spacing: 12) {
                BrandMark(size: 34)
                Text(t).font(.system(size: 22, weight: .bold)).foregroundStyle(Style.fg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .heading(let t):
            Text(t).font(.system(size: 15, weight: .bold)).foregroundStyle(Style.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        case .paragraph(let t):
            inline(t).font(.system(size: 10.5)).foregroundStyle(Style.fg).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .numbered(let n, let t):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n).").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Style.green).frame(width: 16, alignment: .trailing)
                inline(t).font(.system(size: 10.5)).foregroundStyle(Style.fg).lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let t):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(Style.scale[3]).frame(width: 5, height: 5).frame(width: 16, alignment: .trailing)
                inline(t).font(.system(size: 10.5)).foregroundStyle(Style.fg).lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .note(let t):
            inline(t).font(.system(size: 10)).foregroundStyle(Style.muted).lineSpacing(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Style.canvas))
                .overlay(alignment: .leading) { Rectangle().fill(Style.scale[3]).frame(width: 3) }
        case .image(let path, let alt):
            if let image = NSImage(contentsOf: docs.appendingPathComponent(path)) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 340, maxHeight: 230)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Style.border))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(alt)
            } else {
                Text("[\(alt)]").font(.system(size: 9)).foregroundStyle(Style.muted)
            }
        case .code(let t):
            Text(t).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Style.fg)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Style.canvas))
        case .rule:
            Rectangle().fill(Style.border).frame(height: 1).padding(.vertical, 4)
        }
    }
}

struct PageView: View {
    let blocks: [Block]
    let docs: URL
    let number: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in BlockView(block: b, docs: docs) }
            }
            Spacer(minLength: 0)
            HStack {
                Text("Tracker for GitHub · github.com/garoknows/github-tracker")
                Spacer()
                Text("Page \(number) of \(count)")
            }
            .font(.system(size: 8)).foregroundStyle(Style.muted)
        }
        .padding(margin)
        .frame(width: page.width, height: page.height)
        .background(Color.white)
    }
}

@MainActor
func height(of block: Block, docs: URL) -> CGFloat {
    let renderer = ImageRenderer(content: BlockView(block: block, docs: docs).frame(width: contentWidth))
    renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
    return renderer.nsImage?.size.height ?? 0
}

/// Splits blocks into pages. A heading always stays on the same page as the block after it.
@MainActor
func paginate(_ blocks: [Block], docs: URL) -> [[Block]] {
    let available = page.height - margin * 2 - 24 // room for the footer
    let heights = blocks.map { height(of: $0, docs: docs) + 8 }
    var pages: [[Block]] = [[]]
    var used: CGFloat = 0
    var i = 0
    while i < blocks.count {
        var group = [i]
        if blocks[i].isHeading, i + 1 < blocks.count { group.append(i + 1) }
        let need = group.map { heights[$0] }.reduce(0, +)
        if used + need > available, !pages[pages.count - 1].isEmpty {
            pages.append([])
            used = 0
        }
        if case .rule = blocks[i], pages[pages.count - 1].isEmpty { i += 1; continue } // no rule at a page top
        for j in group { pages[pages.count - 1].append(blocks[j]) }
        used += need
        i += group.count
    }
    return pages
}

/// Writes a PDF whose only metadata is a title and a generic creator: no author, user name or file path.
@MainActor
func renderPDF(_ pages: [[Block]], docs: URL, to url: URL) {
    var box = CGRect(origin: .zero, size: page)
    let info: [String: Any] = [kCGPDFContextTitle as String: "Install and use Tracker for GitHub",
                               kCGPDFContextCreator as String: "Tracker for GitHub docgen"]
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary) else {
        fatalError("Can't create the PDF at \(url.lastPathComponent)")
    }
    for (n, blocks) in pages.enumerated() {
        let renderer = ImageRenderer(content: PageView(blocks: blocks, docs: docs, number: n + 1, count: pages.count))
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
    }
    ctx.closePDF()
    print("Wrote \(url.lastPathComponent) (\(pages.count) pages)")
}

@MainActor
func run() {
    let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".", isDirectory: true)
    let docs = root.appendingPathComponent("docs", isDirectory: true)
    guard let markdown = try? String(contentsOf: docs.appendingPathComponent("INSTALL.md"), encoding: .utf8) else {
        fatalError("Run from the repo root (or pass it): docs/INSTALL.md not found")
    }
    let pages = paginate(parse(markdown), docs: docs)
    for folder in ["docs", "site"] {
        renderPDF(pages, docs: docs,
                  to: root.appendingPathComponent(folder).appendingPathComponent("Tracker-for-GitHub-Install-Guide.pdf"))
    }
}

MainActor.assumeIsolated { run() }
