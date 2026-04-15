import SwiftUI
import ClarcCore

/// File preview with syntax highlighting
struct FilePreviewView: View {
    let filePath: String
    let fileName: String
    @State private var content: String?
    @State private var highlightedContent: AttributedString?
    @State private var lineCount = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCopied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ClaudeThemeDivider()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let content {
                codeContentView(content)
            }
        }
        .frame(minWidth: 900, idealWidth: 1200, maxWidth: 1600, minHeight: 600, idealHeight: 900, maxHeight: 1200)
        .background(ClaudeTheme.background)
        .focusable(false)
        .task { await loadFile() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForExtension)
                .font(.system(size: 14))
                .foregroundStyle(iconColorForExtension)

            Text(fileName)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .lineLimit(1)

            Text(languageLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ClaudeTheme.surfaceSecondary, in: Capsule())

            Spacer()

            if let content {
                Text("\(lineCount) lines")
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)

                Button {
                    copyToClipboard(content, feedback: $isCopied)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "copied" : "copy")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(isCopied ? ClaudeTheme.statusSuccess : ClaudeTheme.textTertiary)
                }
                .buttonStyle(.borderless)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(ClaudeTheme.surfaceSecondary, in: Circle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ClaudeTheme.surfacePrimary)
    }

    // MARK: - Content

    private func codeContentView(_ text: String) -> some View {
        let lineNumberWidth = max(String(lineCount).count * 9 + 16, 36)
        let highlighted = highlightedContent ?? AttributedString(text)

        return GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(0..<lineCount, id: \.self) { index in
                            Text("\(index + 1)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(ClaudeTheme.textTertiary.opacity(0.6))
                                .frame(height: 19)
                        }
                    }
                    .frame(width: CGFloat(lineNumberWidth))
                    .padding(.top, 12)
                    .padding(.trailing, 8)
                    .background(ClaudeTheme.codeBackground.opacity(0.5))

                    Rectangle()
                        .fill(ClaudeTheme.border.opacity(0.5))
                        .frame(width: 1)

                    // Code content
                    Text(highlighted)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.leading, 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .background(ClaudeTheme.codeBackground)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("loading...")
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(ClaudeTheme.statusWarning)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - File Loading

    private func loadFile() async {
        do {
            let data = try await Task.detached { [filePath] in
                let url = URL(fileURLWithPath: filePath)
                let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                let size = (attr[.size] as? Int) ?? 0
                if size > 1_000_000 {
                    throw FilePreviewError.tooLarge
                }
                return try Data(contentsOf: url)
            }.value

            if let text = String(data: data, encoding: .utf8) {
                let ext = fileExtension
                let highlighted = await Task.detached {
                    SyntaxHighlighter.highlight(text, language: ext)
                }.value
                content = text
                highlightedContent = highlighted
                lineCount = text.components(separatedBy: "\n").count
            } else {
                errorMessage = "binary file -- preview unavailable"
            }
        } catch is FilePreviewError {
            errorMessage = "file too large to preview (>1MB)"
        } catch {
            errorMessage = "failed to read: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Helpers

    private var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    private var languageLabel: String {
        switch fileExtension {
        case "swift": return "Swift"
        case "js": return "JavaScript"
        case "jsx": return "JSX"
        case "ts": return "TypeScript"
        case "tsx": return "TSX"
        case "json": return "JSON"
        case "md": return "Markdown"
        case "html": return "HTML"
        case "css": return "CSS"
        case "scss": return "SCSS"
        case "py": return "Python"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "rs": return "Rust"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        case "sh", "bash", "zsh": return "Shell"
        case "sql": return "SQL"
        case "xml": return "XML"
        case "txt": return "Plain Text"
        case "gitignore": return "gitignore"
        case "plist": return "Plist"
        case "entitlements": return "Entitlements"
        case "pbxproj": return "Xcode Project"
        default: return fileExtension.isEmpty ? "File" : fileExtension.uppercased()
        }
    }

    private var iconForExtension: String {
        FileNode(id: "", name: fileName, isDirectory: false, children: []).icon
    }

    private var iconColorForExtension: Color {
        FileNode(id: "", name: fileName, isDirectory: false, children: []).iconColor
    }
}

// MARK: - Error

private enum FilePreviewError: Error {
    case tooLarge
}

#Preview {
    FilePreviewView(
        filePath: "/Users/jmlee/workspace/Clarc/Clarc/Views/Sidebar/FileTreeView.swift",
        fileName: "FileTreeView.swift"
    )
}
