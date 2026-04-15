import SwiftUI
import ClarcCore

public struct FileDiffView: View {
    public let filePath: String
    public let fileName: String
    @Environment(WindowState.self) private var windowState
    @State private var diffLines: [DiffLine] = []
    @State private var isLoading = true
    @State private var isCopied = false

    public init(filePath: String, fileName: String) {
        self.filePath = filePath
        self.fileName = fileName
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ClaudeThemeDivider()
            contentArea
        }
        .background(ClaudeTheme.background)
        .background {
            Button("") { windowState.diffFile = nil }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .allowsHitTesting(false)
        }
        .task(id: filePath) { await loadDiff() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.accent)

            Text(fileName)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("Diff", bundle: .module)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(ClaudeTheme.surfaceSecondary, in: Capsule())

            if !diffLines.isEmpty {
                Button {
                    let raw = diffLines.map(\.text).joined(separator: "\n")
                    copyToClipboard(raw, feedback: $isCopied)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(isCopied ? ClaudeTheme.statusSuccess : ClaudeTheme.textSecondary)
                }
                .buttonStyle(.borderless)
                .help(isCopied ? "Copied" : "Copy")
            }

            Button { windowState.diffFile = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(ClaudeTheme.surfaceSecondary, in: Circle())
            }
            .buttonStyle(.borderless)
            .focusable(false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ClaudeTheme.surfacePrimary)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            VStack(spacing: 8) {
                Spacer()
                ProgressView().controlSize(.small)
                Text("loading...", bundle: .module)
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(ClaudeTheme.codeBackground)
        } else if diffLines.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                Text("No changes", bundle: .module)
                    .font(.system(size: 13))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(ClaudeTheme.codeBackground)
        } else {
            diffContentView
        }
    }

    private var diffContentView: some View {
        let lineNumberWidth = CGFloat(max(String(diffLines.count).count * 8 + 12, 32))

        return GeometryReader { geometry in
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 0) {
                            Text(line.kind == .meta ? "" : "\(index + 1)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(ClaudeTheme.textTertiary.opacity(0.6))
                                .frame(width: lineNumberWidth, height: 19, alignment: .trailing)
                                .padding(.trailing, 6)
                                .background(ClaudeTheme.codeBackground.opacity(0.5))
                            Rectangle()
                                .fill(ClaudeTheme.border.opacity(0.5))
                                .frame(width: 1, height: 19)
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(line.kind.foregroundColor)
                                .frame(height: 19)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 10)
                        }
                        .padding(.trailing, 12)
                        .background(line.kind.backgroundColor)
                    }
                }
                .padding(.vertical, 10)
                .textSelection(.enabled)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .background(ClaudeTheme.codeBackground)
    }

    // MARK: - Git Diff

    private func loadDiff() async {
        isLoading = true
        defer { isLoading = false }

        let workDir = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
        let raw: String
        if let r1 = await GitHelper.run(["diff", "HEAD", "--", filePath], at: workDir) {
            raw = r1
        } else if let r2 = await GitHelper.run(["diff", "--", filePath], at: workDir) {
            raw = r2
        } else {
            raw = await GitHelper.run(["show", "HEAD", "--", filePath], at: workDir) ?? ""
        }
        diffLines = parseDiff(raw)
    }

    private func parseDiff(_ raw: String) -> [DiffLine] {
        guard !raw.isEmpty else { return [] }
        var lines = raw.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return lines.map { line in
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                return DiffLine(text: line, kind: .added)
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                return DiffLine(text: line, kind: .removed)
            } else if line.hasPrefix("@@") {
                return DiffLine(text: line, kind: .hunk)
            } else if line.hasPrefix("diff ") || line.hasPrefix("index ") || line.hasPrefix("---") || line.hasPrefix("+++") {
                return DiffLine(text: line, kind: .meta)
            } else {
                return DiffLine(text: line, kind: .context)
            }
        }
    }
}

// MARK: - Diff Line Model

struct DiffLine {
    enum Kind {
        case added, removed, hunk, meta, context

        var foregroundColor: Color {
            switch self {
            case .added:   return Color(hex: 0x3fb950)
            case .removed: return Color(hex: 0xf85149)
            case .hunk:    return Color(hex: 0x79c0ff)
            case .meta:    return ClaudeTheme.textTertiary
            case .context: return ClaudeTheme.textPrimary
            }
        }

        var backgroundColor: Color {
            switch self {
            case .added:   return Color(hex: 0x3fb950).opacity(0.12)
            case .removed: return Color(hex: 0xf85149).opacity(0.12)
            case .hunk:    return Color(hex: 0x388bfd).opacity(0.08)
            case .meta, .context: return .clear
            }
        }
    }

    let text: String
    let kind: Kind
}
