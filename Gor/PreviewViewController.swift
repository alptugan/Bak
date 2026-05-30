//
//  PreviewViewController.swift
//  Gor
//
//  Created by alp tugan on 20.02.2026.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        //let fileExtension = url.pathExtension.lowercased()
        do {
            // Attempt to load as UTF-8 first
            var text = ""
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                // FALLBACK: If standard UTF-8 fails (which causes the App Icon crash), force read it as MacRoman or ASCII
                text = try String(contentsOf: url, encoding: .macOSRoman)
            }

            setupTextView(with: text)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    private func setupTextView(with content: String) {
        let scrollView = NSTextView.scrollableTextView()
                scrollView.frame = self.view.bounds
                scrollView.autoresizingMask = [.width, .height]

                guard let textView = scrollView.documentView as? NSTextView else { return }

                // 2. Define the styling
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 4

                // Read font size from App Group UserDefaults
                let defaults = UserDefaults(suiteName: "group.com.alptugan.Bak")
                let storedSize = defaults?.double(forKey: "fontSize") ?? 0
                let fontSize = storedSize > 0 ? storedSize : 12.0

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                    .foregroundColor: NSColor.textColor,
                    .paragraphStyle: paragraphStyle
                ]

                // 3. Apply the styled string
                textView.textStorage?.setAttributedString(NSAttributedString(string: content, attributes: attributes))
                textView.isEditable = false
                textView.isSelectable = true

                // 4. Mount to view
                self.view.addSubview(scrollView)
    }

    /// Helper method to safely build the scrollable text viewport architecture
    /*private func setupTextView(with content: String) {
        let viewBounds = self.view.bounds

        // 1. Create and configure the Scroll View container wrapper
        let scrollView = NSScrollView(frame: viewBounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        // 2. Setup the dynamic Content Size geometry for the embedded text engine
        let contentSize = scrollView.contentSize

        // 3. Configure the underlying Text View container and options
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width

        // 4. Assign visual details and contents
        // Define a paragraph style to adjust line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3 // Increases space between lines by 4 points

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]

        // Apply the string with the attributes to the text storage
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: content, attributes: attributes)
        )

        // 5. Connect architecture layers and mount to view tree
        scrollView.documentView = textView
        self.view.addSubview(scrollView)
    }*/
}
