//
//  PreviewViewController.swift
//  Gor
//
//  Created by alp tugan on 20.02.2026.
//

import Cocoa
import Quartz
import Highlighter

class PreviewViewController: NSViewController, QLPreviewingController {

    // Cache the highlighter instance to avoid expensive JS context initialization on every file load
    private static let sharedHighlighter = Highlighter()

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            var text = ""
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                text = try String(contentsOf: url, encoding: .macOSRoman)
            }

            // Highlighting large files is extremely slow, limit to first 10,000 lines or so if necessary,
            // or just bypass auto-detect by passing the extension.
            setupTextView(with: text, fileExtension: url.pathExtension)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    private func setupTextView(with content: String, fileExtension: String) {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = self.view.bounds
        scrollView.autoresizingMask = [.width, .height]

        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Read preferences from App Group UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.alptugan.Bak")
        let storedSize = defaults?.double(forKey: "fontSize") ?? 0
        let fontSize = storedSize > 0 ? CGFloat(storedSize) : 12.0
        let syntaxTheme = defaults?.string(forKey: "syntaxTheme") ?? "xcode-dark"

        self.view.appearance = nil
        let isDarkMode = self.view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        var themeBackgroundColor: NSColor?

        // Use the cached Highlighter
        if let highlighter = PreviewViewController.sharedHighlighter {
            // Choose the appropriate theme
            highlighter.setTheme(syntaxTheme)

            themeBackgroundColor = highlighter.theme.themeBackgroundColour

            highlighter.theme.setCodeFont(font)
            highlighter.theme.lineSpacing = 4

            // Using `as: nil` forces highlight.js to auto-detect the language out of 100+ languages.
            // This is extremely slow.pass the file extension directly to bypass auto-detection.
            let lang = fileExtension.isEmpty ? nil : fileExtension.lowercased()
            if let highlightedString = highlighter.highlight(content, as: lang) {
                textView.textStorage?.setAttributedString(highlightedString)
            } else {
                textView.string = content
                textView.font = font
            }
        } else {
            textView.string = content
            textView.font = font
        }

        // Apply theme's background color, falling back to defaults if extraction fails
        let fallbackDark = NSColor(red: 21/255, green: 22/255, blue: 28/255, alpha: 1.0)
        let fallbackLight = NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1.0)
        let finalBgColor = themeBackgroundColor ?? (isDarkMode ? fallbackDark : fallbackLight)

        textView.backgroundColor = finalBgColor
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = finalBgColor.cgColor

        textView.isEditable = false
        textView.isSelectable = true

        self.view.addSubview(scrollView)
    }
}
