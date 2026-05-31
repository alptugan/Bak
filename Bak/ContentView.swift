//
//  ContentView.swift
//  Bak
//
//  Created by alp tugan on 20.02.2026.
//

import SwiftUI
import ServiceManagement
internal import Combine

struct ContentView: View {
    @State private var launchAtLogin: Bool = false
    @State private var cacheResetStatus: String = ""
    @State private var isExtensionActive: Bool = false

    @AppStorage("fontSize", store: UserDefaults(suiteName: "group.com.alptugan.Bak")) private var fontSize: Double = 12.0
    @AppStorage("syntaxTheme", store: UserDefaults(suiteName: "group.com.alptugan.Bak")) private var syntaxTheme: String = "xcode-dark"

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    let syntaxThemes = [
        "a11y-dark", "a11y-light", "atom-one-dark", "atom-one-light", "color-brewer",
        "darcula", "dark", "default", "docco", "dracula", "github", "github-dark", "github-dark-dimmed",
        "github-gist", "intellij-light", "monokai", "night-owl", "nord", "obsidian", "ocean",
        "shades-of-purple", "srcery", "stackoverflow-dark", "vs-dark", "vs-light", "vs2015", "xcode", "xcode-dark"
    ]

    var body: some View {
        VStack(spacing: 20) {

            // MARK: - Header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Bak")
                        .font(.largeTitle.bold())
                    Text("Quick Look Extension for Source Files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }


                // MARK: - Status
                GroupBox {

                    Spacer()
                    HStack() {
                        Label("Quick Look Extension", systemImage: "puzzlepiece.extension")
                        Spacer()
                        if isExtensionActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Disabled", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }.padding(.horizontal, 10).padding(.vertical, 2)

                    Divider()

                    VStack(alignment: .center, spacing: 12) {
                        Text("If previews stop working, reset the Quick Look cache.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(action: resetCache) {
                            Label("Reset Cache", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .focusable(false)
                        .padding(.bottom, 10)

                        if !cacheResetStatus.isEmpty {
                            Text(cacheResetStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // MARK: - Preferences
                GroupBox(label: Text("Preferences").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Font Size: \(Int(fontSize))")
                            Slider(value: $fontSize, in: 8...36, step: 1)
                            .focusable(false)
                        }

                        HStack {
                            Text("Theme:")
                            Picker("", selection: $syntaxTheme) {
                                ForEach(syntaxThemes, id: \.self) { theme in
                                    Text(theme).tag(theme)
                                }
                            }
                            .focusable(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            checkExtensionStatus()
        }
        .onReceive(timer) { _ in
            checkExtensionStatus()
        }
    }

    private func resetCache() {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "pluginkit -e use -i com.alptugan.Bak.Gor >/dev/null 2>&1; qlmanage -r >/dev/null 2>&1; qlmanage -r cache >/dev/null 2>&1"]
        do {
            try task.run()
            task.waitUntilExit()
            withAnimation {
                cacheResetStatus = task.terminationStatus == 0 ? "Cache reset ✅" : "Failed ❌"
            }
            checkExtensionStatus()
        } catch {
            withAnimation { cacheResetStatus = "Failed ❌" }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { cacheResetStatus = "" }
        }
    }

    private func checkExtensionStatus() {
        let task = Process()
        task.launchPath = "/usr/bin/pluginkit"
        task.arguments = ["-m", "-i", "com.alptugan.Bak.Gor"]

        let pipe = Pipe()
        let errorPipe = Pipe() // Pipe for standard error to prevent console spam

        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), let _ = String(data: errorData, encoding: .utf8) {
                // Determine active state by checking if any line starts with + or !
                let lines = output.components(separatedBy: .newlines)
                let isActive = lines.contains { line in
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    // Ensure the line is actually referencing our plugin
                    guard trimmedLine.contains("com.alptugan.Bak.Gor") else { return false }
                    return trimmedLine.hasPrefix("+") || trimmedLine.hasPrefix("!")
                }

                if self.isExtensionActive != isActive {
                    withAnimation {
                        self.isExtensionActive = isActive
                    }
                }
            }
        } catch {
            print("Failed to run pluginkit: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
