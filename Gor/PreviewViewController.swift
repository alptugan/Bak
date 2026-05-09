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
        // Do any additional setup after loading the view.
    }

    /*
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?) async throws {
        // Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.

        // Perform any setup necessary in order to prepare the view.
        // Quick Look will display a loading spinner until this returns.
    }
   
v1*/
    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            // 1. Load the text from the file
            let text = try String(contentsOf: url, encoding: .utf8)
            
            // 2. Create a basic text view
            let textView = NSTextView(frame: self.view.bounds)
            textView.string = text
            textView.isEditable = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            
            // 3. Wrap it in a scroll view so you can read long files
            let scrollView = NSScrollView(frame: self.view.bounds)
            scrollView.hasVerticalScroller = true
            scrollView.documentView = textView
            scrollView.autoresizingMask = [.width, .height]
            
            // 4. Add to the main view
            self.view.addSubview(scrollView)
            
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
     
    /*func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        // 1. Mandatory for Sandbox: Access the file safely
        let isScoped = url.startAccessingSecurityScopedResource()

        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            // 2. Load data first, then decode to String
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard let content = String(data: data, encoding: .utf8) else {
                throw NSError(
                    domain: "com.alptugan.Bak",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to decode file content"]
                )
            }

            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

            // 3. UI - Gutter
            let lineCount = content.components(separatedBy: .newlines).count
            let lineNumbers = (1...max(1, lineCount)).map { "\($0)" }.joined(separator: "\n")

            let gutter = NSTextView()
            gutter.string = lineNumbers
            gutter.font = font
            gutter.alignment = .right
            gutter.textColor = .secondaryLabelColor
            gutter.backgroundColor = .clear
            gutter.isEditable = false
            gutter.isSelectable = false
            gutter.translatesAutoresizingMaskIntoConstraints = false
            gutter.widthAnchor.constraint(equalToConstant: 45).isActive = true

            // 4. UI - Main Text View
            let textView = NSTextView()
            textView.string = content
            textView.font = font
            textView.textColor = .labelColor
            textView.isEditable = false
            textView.backgroundColor = .clear
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            // 5. Layout - StackView
            let stackView = NSStackView(views: [gutter, textView])
            stackView.orientation = .horizontal
            stackView.spacing = 10
            stackView.alignment = .top
            stackView.edgeInsets = NSEdgeInsets(top: 20, left: 10, bottom: 20, right: 20)

            // 6. Layout - ScrollView
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.documentView = stackView
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false

            self.view.addSubview(scrollView)

            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])

            // 7. UI - Copy Button
            let copyButton = NSButton(title: "Copy Text", target: self, action: #selector(copyToClipboard(_:)))
            copyButton.bezelStyle = .rounded
            copyButton.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(copyButton)

            NSLayoutConstraint.activate([
                copyButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
                copyButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -20),
                copyButton.widthAnchor.constraint(equalToConstant: 100)
            ])

            self.representedObject = content
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    @objc func copyToClipboard(_ sender: Any) {
        if let text = self.representedObject as? String {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }*/
}
