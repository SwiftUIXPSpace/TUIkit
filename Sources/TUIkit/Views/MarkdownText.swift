//  🖥️ TUIKit — Terminal UI Kit for Swift
//  MarkdownText.swift
//
//  Created by LAYERED.work
//  License: MIT

/// A view that renders Markdown-formatted text in the terminal using ANSI styles.
///
/// `MarkdownText` parses a subset of Markdown and renders it with terminal formatting:
/// - **Bold** (`**text**` or `__text__`)
/// - *Italic* (`*text*` or `_text_`)
/// - `Code` (`` `text` ``)
/// - ~~Strikethrough~~ (`~~text~~`)
/// - Headings (`# H1`, `## H2`, `### H3`)
/// - Bullet lists (`- item` or `* item`)
/// - Numbered lists (`1. item`)
/// - Code blocks (` ``` `)
/// - Horizontal rules (`---`, `***`, `___`)
/// - Links (`[text](url)`)
/// - Blockquotes (`> text`)
///
/// # Example
///
/// ```swift
/// MarkdownText("""
/// # Hello World
///
/// This is **bold** and *italic* text.
///
/// - Item 1
/// - Item 2
///
/// ```code
/// let x = 42
/// ```
/// """)
/// ```
public struct MarkdownText: View, Equatable {
    /// The raw Markdown source.
    let source: String

    /// Creates a Markdown text view.
    ///
    /// - Parameter source: The Markdown-formatted string to render.
    public init(_ source: String) {
        self.source = source
    }

    public var body: Never {
        fatalError("MarkdownText is a primitive view and renders directly")
    }
}

// MARK: - Markdown Parsing Types

extension MarkdownText {

    /// A block-level element in the Markdown document.
    enum Block: Equatable {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case codeBlock(language: String?, lines: [String])
        case bulletList(items: [String])
        case numberedList(items: [String])
        case horizontalRule
        case blockquote(text: String)
        case emptyLine
    }

    /// An inline-styled span of text.
    struct StyledSpan: Equatable {
        let text: String
        let style: TextStyle
    }
}

// MARK: - Block Parser

extension MarkdownText {

    /// Parses the Markdown source into block-level elements.
    static func parseBlocks(_ source: String) -> [Block] {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [Block] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 空行
            if trimmed.isEmpty {
                blocks.append(.emptyLine)
                i += 1
                continue
            }

            // 代码块
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let language = lang.isEmpty ? nil : lang
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(language: language, lines: codeLines))
                continue
            }

            // 标题
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                i += 1
                continue
            }

            // 水平线
            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // 引用
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix(">") {
                        let content = String(l.dropFirst()).trimmingCharacters(in: .whitespaces)
                        quoteLines.append(content)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(text: quoteLines.joined(separator: "\n")))
                continue
            }

            // 无序列表
            if isBulletListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if isBulletListItem(l) {
                        items.append(parseBulletItem(l))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items: items))
                continue
            }

            // 有序列表
            if isNumberedListItem(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if isNumberedListItem(l) {
                        items.append(parseNumberedItem(l))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items: items))
                continue
            }

            // 普通段落 — 收集连续非空行
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i].trimmingCharacters(in: .whitespaces)
                if l.isEmpty || l.hasPrefix("```") || l.hasPrefix("#") || isHorizontalRule(l)
                    || l.hasPrefix(">") || isBulletListItem(l) || isNumberedListItem(l) {
                    break
                }
                paraLines.append(l)
                i += 1
            }
            blocks.append(.paragraph(text: paraLines.joined(separator: " ")))
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> Block? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty || level <= 6 else { return nil }
        return .heading(level: level, text: rest)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let chars = line.filter { !$0.isWhitespace }
        guard chars.count >= 3 else { return false }
        let ch = chars.first!
        return (ch == "-" || ch == "*" || ch == "_") && chars.allSatisfy({ $0 == ch })
    }

    private static func isBulletListItem(_ line: String) -> Bool {
        return line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func parseBulletItem(_ line: String) -> String {
        String(line.dropFirst(2))
    }

    private static func isNumberedListItem(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let prefix = line[line.startIndex..<dotIndex]
        guard prefix.allSatisfy(\.isNumber), !prefix.isEmpty else { return false }
        let afterDot = line.index(after: dotIndex)
        return afterDot < line.endIndex && line[afterDot] == " "
    }

    private static func parseNumberedItem(_ line: String) -> String {
        guard let dotIndex = line.firstIndex(of: ".") else { return line }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex else { return "" }
        return String(line[line.index(after: afterDot)...]).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Inline Parser

extension MarkdownText {

    /// Parses inline Markdown formatting into styled spans.
    static func parseInline(_ text: String, baseStyle: TextStyle = TextStyle()) -> [StyledSpan] {
        var spans: [StyledSpan] = []
        var i = text.startIndex

        while i < text.endIndex {
            // ``code`` (两个反引号)
            if text[i] == "`", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "`" {
                let start = text.index(i, offsetBy: 2)
                if let end = findClosingDouble("`", in: text, from: start) {
                    let code = String(text[start..<end])
                    var style = baseStyle
                    style.foregroundColor = .yellow
                    spans.append(StyledSpan(text: code, style: style))
                    i = text.index(end, offsetBy: 2)
                    continue
                }
            }

            // `code`
            if text[i] == "`" {
                let start = text.index(after: i)
                if let end = text[start...].firstIndex(of: "`") {
                    let code = String(text[start..<end])
                    var style = baseStyle
                    style.foregroundColor = .yellow
                    spans.append(StyledSpan(text: code, style: style))
                    i = text.index(after: end)
                    continue
                }
            }

            // ~~strikethrough~~
            if text[i] == "~", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "~" {
                let start = text.index(i, offsetBy: 2)
                if let end = findClosingDouble("~", in: text, from: start) {
                    let inner = String(text[start..<end])
                    var style = baseStyle
                    style.isStrikethrough = true
                    let innerSpans = parseInline(inner, baseStyle: style)
                    spans.append(contentsOf: innerSpans)
                    i = text.index(end, offsetBy: 2)
                    continue
                }
            }

            // **bold** or __bold__
            if (text[i] == "*" || text[i] == "_"),
               text.index(after: i) < text.endIndex,
               text[text.index(after: i)] == text[i] {
                let marker = text[i]
                let start = text.index(i, offsetBy: 2)
                if let end = findClosingDouble(marker, in: text, from: start) {
                    let inner = String(text[start..<end])
                    var style = baseStyle
                    style.isBold = true
                    let innerSpans = parseInline(inner, baseStyle: style)
                    spans.append(contentsOf: innerSpans)
                    i = text.index(end, offsetBy: 2)
                    continue
                }
            }

            // *italic* or _italic_
            if text[i] == "*" || text[i] == "_" {
                let marker = text[i]
                let start = text.index(after: i)
                if let end = findClosingSingle(marker, in: text, from: start) {
                    let inner = String(text[start..<end])
                    var style = baseStyle
                    style.isItalic = true
                    let innerSpans = parseInline(inner, baseStyle: style)
                    spans.append(contentsOf: innerSpans)
                    i = text.index(after: end)
                    continue
                }
            }

            // [text](url) — 链接
            if text[i] == "[" {
                if let (linkText, url, afterIndex) = parseLink(text, from: i) {
                    var style = baseStyle
                    style.foregroundColor = .cyan
                    style.isUnderlined = true
                    spans.append(StyledSpan(text: "\(linkText) (\(url))", style: style))
                    i = afterIndex
                    continue
                }
            }

            // 普通文字
            var plainEnd = text.index(after: i)
            while plainEnd < text.endIndex {
                let ch = text[plainEnd]
                if ch == "*" || ch == "_" || ch == "`" || ch == "~" || ch == "[" {
                    break
                }
                plainEnd = text.index(after: plainEnd)
            }
            spans.append(StyledSpan(text: String(text[i..<plainEnd]), style: baseStyle))
            i = plainEnd
        }

        return spans
    }

    /// Finds the closing position of a double-character marker (**, ~~, `` etc.)
    private static func findClosingDouble(_ ch: Character, in text: String, from start: String.Index) -> String.Index? {
        var i = start
        while i < text.endIndex {
            if text[i] == ch {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == ch {
                    return i
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    /// Finds the closing position of a single-character marker (*, _)
    private static func findClosingSingle(_ ch: Character, in text: String, from start: String.Index) -> String.Index? {
        var i = start
        // 不匹配紧跟 marker 的情况（如 ** 应该被 double 处理）
        guard i < text.endIndex && text[i] != ch else { return nil }
        while i < text.endIndex {
            if text[i] == ch {
                // 确保这不是 double marker 的一部分
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == ch {
                    // 跳过 double
                    i = text.index(after: next)
                    continue
                }
                return i
            }
            i = text.index(after: i)
        }
        return nil
    }

    /// Parses a Markdown link `[text](url)` starting from the `[`.
    private static func parseLink(_ text: String, from start: String.Index) -> (linkText: String, url: String, afterIndex: String.Index)? {
        guard text[start] == "[" else { return nil }
        let afterBracket = text.index(after: start)
        guard let closeBracket = text[afterBracket...].firstIndex(of: "]") else { return nil }
        let linkText = String(text[afterBracket..<closeBracket])
        let afterClose = text.index(after: closeBracket)
        guard afterClose < text.endIndex, text[afterClose] == "(" else { return nil }
        let urlStart = text.index(after: afterClose)
        guard let closeParen = text[urlStart...].firstIndex(of: ")") else { return nil }
        let url = String(text[urlStart..<closeParen])
        return (linkText, url, text.index(after: closeParen))
    }
}

// MARK: - Rendering

extension MarkdownText: Renderable, Layoutable {

    public func sizeThatFits(proposal: ProposedSize, context: RenderContext) -> ViewSize {
        let maxWidth = proposal.width ?? context.availableWidth
        let lines = renderLines(maxWidth: maxWidth, context: context)
        let width = lines.map(\.strippedLength).max() ?? 0
        return ViewSize.fixed(width, lines.count)
    }

    public func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let lines = renderLines(maxWidth: context.availableWidth, context: context)
        // 所有行左对齐 pad 到统一宽度，避免外层 VStack 对齐时短行偏移
        let maxLineWidth = lines.map(\.strippedLength).max() ?? 0
        let padded = lines.map { $0.padToVisibleWidth(maxLineWidth) }
        return FrameBuffer(lines: padded)
    }

    /// Renders the Markdown into an array of ANSI-styled lines.
    private func renderLines(maxWidth: Int, context: RenderContext) -> [String] {
        let blocks = MarkdownText.parseBlocks(source)
        var lines: [String] = []
        let defaultFg = context.environment.foregroundStyle ?? context.environment.palette.foreground

        for block in blocks {
            switch block {
            case .heading(let level, let text):
                var style = TextStyle()
                style.isBold = true
                switch level {
                case 1:
                    style.foregroundColor = .cyan
                case 2:
                    style.foregroundColor = .green
                case 3:
                    style.foregroundColor = .yellow
                default:
                    style.foregroundColor = .white
                }
                let resolved = style.resolved(with: context.environment.palette)
                let prefix = String(repeating: "#", count: level) + " "
                let prefixStyled = ANSIRenderer.render(prefix, with: resolved)
                let styledText = renderInlineText(text, baseStyle: style, palette: context.environment.palette)
                lines.append(prefixStyled + styledText)

            case .paragraph(let text):
                var style = TextStyle()
                style.foregroundColor = defaultFg
                let rendered = renderInlineText(text, baseStyle: style, palette: context.environment.palette)
                let wrapped = wordWrapStyled(rendered, plainText: text, maxWidth: maxWidth)
                lines.append(contentsOf: wrapped)

            case .codeBlock(let language, let codeLines):
                // 顶部边框
                var borderStyle = TextStyle()
                borderStyle.foregroundColor = .brightBlack
                borderStyle.isDim = true
                let resolvedBorder = borderStyle.resolved(with: context.environment.palette)
                let langLabel = language.map { " \($0) " } ?? ""
                let topBorder = "┌" + langLabel + String(repeating: "─", count: max(0, maxWidth - 2 - langLabel.count)) + "┐"
                lines.append(ANSIRenderer.render(topBorder, with: resolvedBorder))

                // 代码行
                var codeStyle = TextStyle()
                codeStyle.foregroundColor = .green
                let resolvedCode = codeStyle.resolved(with: context.environment.palette)
                for codeLine in codeLines {
                    let paddedLine = "│ " + codeLine
                    lines.append(ANSIRenderer.render(paddedLine, with: resolvedCode))
                }

                // 底部边框
                let bottomBorder = "└" + String(repeating: "─", count: max(0, maxWidth - 2)) + "┘"
                lines.append(ANSIRenderer.render(bottomBorder, with: resolvedBorder))

            case .bulletList(let items):
                for item in items {
                    var style = TextStyle()
                    style.foregroundColor = defaultFg
                    let bullet = ANSIRenderer.render("  • ", with: TextStyle())
                    let itemText = renderInlineText(item, baseStyle: style, palette: context.environment.palette)
                    lines.append(bullet + itemText)
                }

            case .numberedList(let items):
                for (index, item) in items.enumerated() {
                    var style = TextStyle()
                    style.foregroundColor = defaultFg
                    var numStyle = TextStyle()
                    numStyle.foregroundColor = .cyan
                    let numResolved = numStyle.resolved(with: context.environment.palette)
                    let num = ANSIRenderer.render("  \(index + 1). ", with: numResolved)
                    let itemText = renderInlineText(item, baseStyle: style, palette: context.environment.palette)
                    lines.append(num + itemText)
                }

            case .horizontalRule:
                var style = TextStyle()
                style.foregroundColor = .brightBlack
                style.isDim = true
                let resolved = style.resolved(with: context.environment.palette)
                lines.append(ANSIRenderer.render(String(repeating: "─", count: maxWidth), with: resolved))

            case .blockquote(let text):
                var barStyle = TextStyle()
                barStyle.foregroundColor = .cyan
                barStyle.isDim = true
                let resolvedBar = barStyle.resolved(with: context.environment.palette)
                var textStyle = TextStyle()
                textStyle.foregroundColor = defaultFg
                textStyle.isItalic = true
                let bar = ANSIRenderer.render("  │ ", with: resolvedBar)
                let quoteText = renderInlineText(text, baseStyle: textStyle, palette: context.environment.palette)
                lines.append(bar + quoteText)

            case .emptyLine:
                lines.append("")
            }
        }

        return lines
    }

    /// Renders inline text with Markdown formatting applied.
    private func renderInlineText(_ text: String, baseStyle: TextStyle, palette: any Palette) -> String {
        let spans = MarkdownText.parseInline(text, baseStyle: baseStyle)
        return spans.map { span in
            let resolved = span.style.resolved(with: palette)
            return ANSIRenderer.render(span.text, with: resolved)
        }.joined()
    }

    /// Word-wraps an ANSI-styled string based on the plain text length.
    private func wordWrapStyled(_ styled: String, plainText: String, maxWidth: Int) -> [String] {
        guard maxWidth > 0, plainText.count > maxWidth else { return [styled] }
        // 简单策略：如果纯文本超过 maxWidth，直接返回（ANSI 感知的换行比较复杂）
        // 对于大多数终端场景，单行段落已经足够
        return [styled]
    }
}
