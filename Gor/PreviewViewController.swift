//
//  PreviewViewController.swift
//  Gor
//
//  Created by alp tugan on 20.02.2026.
//

import Cocoa
import Quartz
import SwiftTreeSitter
import TreeSitterJSON
import TreeSitterSwift

class PreviewViewController: NSViewController, QLPreviewingController {
    private static let maximumPreviewBytes = 2 * 1024 * 1024
    private static let maximumPreviewLines = 5_000

    private var previewGeneration = 0
    private var previewWorkItem: DispatchWorkItem?
    private var previewCancellation: CancellationToken?
    private var highlightGeneration = 0
    private var pendingPages: [String] = []
    private var scrollObservation: NSObjectProtocol?

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        previewGeneration &+= 1
        let generation = previewGeneration
        previewWorkItem?.cancel()
        previewCancellation?.cancel()

        let textView = setupTextView()
        textView.string = "Loading preview..."
        completionHandler(nil)

        let cancellation = CancellationToken()
        let workItem = DispatchWorkItem { [weak self, cancellation] in
            do {
                let content = try Self.loadPreviewContent(from: url)
                guard !cancellation.isCancelled else { return }

                DispatchQueue.main.async {
                    guard let self, !cancellation.isCancelled, self.previewGeneration == generation else { return }
                    self.displayInitialPage(
                        from: content,
                        fileExtension: url.pathExtension,
                        in: textView,
                        generation: generation,
                        cancellation: cancellation
                    )
                }
            } catch {
                guard !cancellation.isCancelled else { return }

                DispatchQueue.main.async {
                    guard let self, !cancellation.isCancelled, self.previewGeneration == generation else { return }
                    textView.string = "Preview unavailable: \(error.localizedDescription)"
                }
            }
        }

        previewCancellation = cancellation
        previewWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        previewGeneration &+= 1
        previewWorkItem?.cancel()
        previewWorkItem = nil
        previewCancellation?.cancel()
        previewCancellation = nil
        pendingPages = []
        if let scrollObservation {
            NotificationCenter.default.removeObserver(scrollObservation)
            self.scrollObservation = nil
        }
    }

    private func setupTextView() -> NSTextView {
        view.subviews.forEach { $0.removeFromSuperview() }

        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]

        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("Expected the scrollable text view to contain an NSTextView")
        }

        let defaults = UserDefaults(suiteName: "com.alptugan.Bak")
        let storedSize = defaults?.double(forKey: "fontSize") ?? 0
        let fontSize = storedSize > 0 ? CGFloat(storedSize) : 12.0
        let syntaxTheme = defaults?.string(forKey: "syntaxTheme") ?? "xcode-dark"

        view.appearance = nil
        let isDarkMode = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = NativeSyntaxHighlighter.theme(named: syntaxTheme, isDarkMode: isDarkMode)

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let finalBgColor = theme.background

        textView.backgroundColor = finalBgColor
        textView.font = font
        textView.textColor = theme.foreground
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isEditable = false
        textView.isSelectable = true

        view.wantsLayer = true
        view.layer?.backgroundColor = finalBgColor.cgColor
        view.addSubview(scrollView)

        return textView
    }

    private static func loadPreviewContent(from url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let data = try handle.read(upToCount: maximumPreviewBytes) ?? Data()
        guard !data.contains(0) else {
            throw PreviewError.binaryContent
        }
        guard var content = String(data: data, encoding: .utf8) else {
            throw PreviewError.unsupportedEncoding
        }

        let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        if lines.count > maximumPreviewLines {
            content = lines.prefix(maximumPreviewLines).joined(separator: "\n")
            content += "\n\nPreview truncated for performance."
        } else if data.count == maximumPreviewBytes {
            content += "\n\nPreview truncated for performance."
        }

        return content
    }

    private func scheduleHighlighting(
        _ content: String,
        fileExtension: String,
        in textView: NSTextView,
        generation: Int,
        cancellation: CancellationToken
    ) {
        guard NativeSyntaxHighlighter.supports(fileExtension: fileExtension) else { return }
        highlightGeneration &+= 1
        let currentHighlightGeneration = highlightGeneration

        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let isDarkMode = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let syntaxTheme = UserDefaults(suiteName: "com.alptugan.Bak")?.string(forKey: "syntaxTheme") ?? "xcode-dark"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard !cancellation.isCancelled else { return }
            let highlightedContent = NativeSyntaxHighlighter.highlight(
                content,
                fileExtension: fileExtension,
                font: font,
                themeName: syntaxTheme,
                isDarkMode: isDarkMode
            )
            guard !cancellation.isCancelled, let highlightedContent else { return }

            DispatchQueue.main.async {
                guard let self,
                      !cancellation.isCancelled,
                      self.previewGeneration == generation,
                      self.highlightGeneration == currentHighlightGeneration else { return }
                textView.textStorage?.setAttributedString(highlightedContent)
            }
        }
    }

    private func displayInitialPage(
        from content: String,
        fileExtension: String,
        in textView: NSTextView,
        generation: Int,
        cancellation: CancellationToken
    ) {
        let pages = Self.previewPages(from: content)
        guard let firstPage = pages.first else {
            textView.string = ""
            return
        }

        pendingPages = Array(pages.dropFirst())
        textView.string = firstPage
        scheduleHighlighting(firstPage, fileExtension: fileExtension, in: textView, generation: generation, cancellation: cancellation)

        guard let clipView = textView.enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        scrollObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self, weak textView] _ in
            guard let self, let textView else { return }
            self.appendNextPageIfNeeded(
                fileExtension: fileExtension,
                to: textView,
                generation: generation,
                cancellation: cancellation
            )
        }
    }

    private func appendNextPageIfNeeded(
        fileExtension: String,
        to textView: NSTextView,
        generation: Int,
        cancellation: CancellationToken
    ) {
        guard !pendingPages.isEmpty,
              !cancellation.isCancelled,
              previewGeneration == generation,
              let scrollView = textView.enclosingScrollView else { return }

        let visibleBottom = scrollView.contentView.bounds.maxY
        let remainingHeight = textView.bounds.maxY - visibleBottom
        guard remainingHeight < scrollView.contentView.bounds.height * 1.5 else { return }

        let nextPage = pendingPages.removeFirst()
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textColor = textView.textColor ?? .textColor
        textView.textStorage?.append(NSAttributedString(string: nextPage, attributes: [
            .font: font,
            .foregroundColor: textColor,
        ]))
        scheduleHighlighting(textView.string, fileExtension: fileExtension, in: textView, generation: generation, cancellation: cancellation)
    }

    private static func previewPages(from content: String) -> [String] {
        let lines = content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return [""] }

        return stride(from: 0, to: lines.count, by: 200).map { start in
            let end = min(start + 200, lines.count)
            return lines[start..<end].joined(separator: "\n") + "\n"
        }
    }

    private enum PreviewError: LocalizedError {
        case binaryContent
        case unsupportedEncoding

        var errorDescription: String? {
            switch self {
            case .binaryContent:
                return "The file contains binary data."
            case .unsupportedEncoding:
                return "Only UTF-8 text files can be previewed."
            }
        }
    }

    private final class CancellationToken: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }
}

private enum NativeSyntaxHighlighter {
    private enum Language {
        case swift
        case json
        case nativeTokens
    }

    struct Theme {
        let background: NSColor
        let foreground: NSColor
        let palette: TokenPalette
    }

    struct TokenPalette {
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let type: NSColor
        let constant: NSColor
        let property: NSColor
    }

    static func supports(fileExtension: String) -> Bool {
        language(for: fileExtension) != nil
    }

    static func highlight(
        _ source: String,
        fileExtension: String,
        font: NSFont,
        themeName: String,
        isDarkMode: Bool
    ) -> NSAttributedString? {
        guard let language = language(for: fileExtension) else {
            return nil
        }

        if language == .nativeTokens {
            return tokenHighlight(source, font: font, themeName: themeName, isDarkMode: isDarkMode)
        }

        guard let configuration = configuration(for: language) else { return nil }

        let parser = Parser()
        do {
            try parser.setLanguage(configuration.language)
        } catch {
            return nil
        }

        guard let tree = parser.parse(source),
              let query = configuration.queries[.highlights] else {
            return nil
        }

        let theme = theme(named: themeName, isDarkMode: isDarkMode)
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: font,
            .foregroundColor: theme.foreground,
            ]
        )
        let sourceRange = NSRange(location: 0, length: (source as NSString).length)
        let highlights = query.execute(in: tree)
            .resolve(with: .init(string: source))
            .highlights()

        for highlight in highlights {
            let range = highlight.range
            guard NSMaxRange(range) <= NSMaxRange(sourceRange) else { continue }
            result.addAttribute(.foregroundColor, value: color(for: highlight.name, theme: theme), range: range)
        }

        return result
    }

    private static func language(for fileExtension: String) -> Language? {
        switch fileExtension.lowercased() {
        case "swift":
            return .swift
        case "json", "jsonc":
            return .json
        case "css", "scss", "yaml", "yml", "rs", "ejs", "plist", "py", "js", "mjs", "cjs", "xml", "toml":
            return .nativeTokens
        default:
            return nil
        }
    }

    private static func configuration(for language: Language) -> LanguageConfiguration? {
        do {
            switch language {
            case .swift:
                return try LanguageConfiguration(tree_sitter_swift(), name: "Swift")
            case .json:
                return try LanguageConfiguration(tree_sitter_json(), name: "JSON")
            case .nativeTokens:
                return nil
            }
        } catch {
            return nil
        }
    }

    private static func tokenHighlight(_ source: String, font: NSFont, themeName: String, isDarkMode: Bool) -> NSAttributedString {
        let theme = theme(named: themeName, isDarkMode: isDarkMode)
        let result = NSMutableAttributedString(
            string: source,
            attributes: [
                .font: font,
                .foregroundColor: theme.foreground,
            ]
        )
        let sourceRange = NSRange(location: 0, length: (source as NSString).length)
        let palette = theme.palette

        let tokenPatterns: [(String, NSColor)] = [
            (#"(?m)(//[^\n]*|#[^\n]*|/\*[\s\S]*?\*/)"#, palette.comment),
            (#"(?s)("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')"#, palette.string),
            (#"(?<![A-Za-z0-9_])(true|false|null|nil|None|yes|no)(?![A-Za-z0-9_])"#, palette.constant),
            (#"(?<![A-Za-z0-9_])(\d+(?:\.\d+)?)(?![A-Za-z0-9_])"#, palette.number),
            (#"(?<![A-Za-z0-9_])(class|struct|enum|protocol|func|let|var|if|else|for|while|return|import|from|def|async|await|function|const|new|public|private|static|use|mod|impl|match|case|in|extends|interface|type|where)(?![A-Za-z0-9_])"#, palette.keyword),
            (#"</?[A-Za-z][A-Za-z0-9:_-]*"#, palette.type),
            (#"(?m)^\s*[-A-Za-z0-9_.]+(?=\s*:)"#, palette.property),
        ]

        for (pattern, color) in tokenPatterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            expression.enumerateMatches(in: source, range: sourceRange) { match, _, _ in
                guard let range = match?.range else { return }
                result.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        return result
    }

    static func theme(named name: String, isDarkMode: Bool) -> Theme {
        let lowercasedName = name.lowercased()
        let background: NSColor
        let foreground: NSColor

        switch lowercasedName {
        case "a11y-light", "atom-one-light", "color-brewer", "default", "docco", "github", "github-gist", "intellij-light", "vs-light", "xcode":
            background = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            foreground = NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
        case "dracula", "shades-of-purple":
            background = NSColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1)
            foreground = NSColor(red: 0.97, green: 0.96, blue: 0.95, alpha: 1)
        case "monokai", "srcery":
            background = NSColor(red: 0.15, green: 0.16, blue: 0.13, alpha: 1)
            foreground = NSColor(red: 0.97, green: 0.97, blue: 0.89, alpha: 1)
        case "nord", "github-dark-dimmed":
            background = NSColor(red: 0.18, green: 0.23, blue: 0.29, alpha: 1)
            foreground = NSColor(red: 0.90, green: 0.93, blue: 0.96, alpha: 1)
        case "ocean", "night-owl", "obsidian", "vs-dark", "vs2015", "xcode-dark", "dark", "darcula", "stackoverflow-dark", "atom-one-dark", "a11y-dark":
            background = NSColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1)
            foreground = NSColor(red: 0.87, green: 0.90, blue: 0.94, alpha: 1)
        default:
            background = isDarkMode ? NSColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1) : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            foreground = isDarkMode ? NSColor(red: 0.87, green: 0.90, blue: 0.94, alpha: 1) : NSColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
        }

        return Theme(background: background, foreground: foreground, palette: tokenPalette(isLight: lowercasedName.contains("light") || lowercasedName == "github" || lowercasedName == "xcode" || lowercasedName == "default" || lowercasedName == "docco" || lowercasedName == "color-brewer"))
    }

    private static func tokenPalette(isLight: Bool) -> TokenPalette {
        if !isLight {
            return TokenPalette(
                keyword: NSColor(red: 0.98, green: 0.45, blue: 0.58, alpha: 1),
                string: NSColor(red: 0.67, green: 0.85, blue: 0.49, alpha: 1),
                comment: NSColor(red: 0.52, green: 0.56, blue: 0.65, alpha: 1),
                number: NSColor(red: 0.95, green: 0.73, blue: 0.45, alpha: 1),
                type: NSColor(red: 0.47, green: 0.76, blue: 0.96, alpha: 1),
                constant: NSColor(red: 0.82, green: 0.65, blue: 0.95, alpha: 1),
                property: NSColor(red: 0.60, green: 0.80, blue: 0.90, alpha: 1)
            )
        }

        return TokenPalette(
            keyword: NSColor(red: 0.67, green: 0.10, blue: 0.30, alpha: 1),
            string: NSColor(red: 0.12, green: 0.42, blue: 0.10, alpha: 1),
            comment: NSColor(red: 0.39, green: 0.42, blue: 0.47, alpha: 1),
            number: NSColor(red: 0.65, green: 0.33, blue: 0.06, alpha: 1),
            type: NSColor(red: 0.12, green: 0.34, blue: 0.68, alpha: 1),
            constant: NSColor(red: 0.48, green: 0.18, blue: 0.61, alpha: 1),
            property: NSColor(red: 0.10, green: 0.42, blue: 0.52, alpha: 1)
        )
    }

    private static func color(for captureName: String, theme: Theme) -> NSColor {
        let palette = theme.palette
        if captureName.hasPrefix("comment") {
            return palette.comment
        }
        if captureName.hasPrefix("string") {
            return palette.string
        }
        if captureName.hasPrefix("number") || captureName.hasPrefix("constant") {
            return palette.number
        }
        if captureName.hasPrefix("type") || captureName.hasPrefix("constructor") {
            return palette.type
        }
        return palette.keyword
    }
}
