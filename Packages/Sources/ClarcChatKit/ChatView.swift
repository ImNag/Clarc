import Combine
import SwiftUI
import ClarcCore

public struct ChatView<InputAccessory: View>: View {
    @Environment(WindowState.self) private var windowState
    @Environment(ChatBridge.self) private var chatBridge
    @State private var shortcuts: [ChatShortcut] = []

    private let inputAccessory: InputAccessory

    public init(@ViewBuilder inputAccessory: () -> InputAccessory) {
        self.inputAccessory = inputAccessory()
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageScrollView

            if chatBridge.isReadOnly {
                readOnlyBanner
            } else {
                InputBarView(accessory: inputAccessory) {
                    if windowState.selectedProject != nil && !shortcuts.isEmpty {
                        shortcutBar
                    }
                }
            }

            StatusLineView()
        }
        .background(ClaudeTheme.background)
        .onKeyPress(.escape, phases: .down) { _ in
            if !windowState.messageQueue.isEmpty {
                windowState.messageQueue.removeLast()
                return .handled
            }
            guard chatBridge.isStreaming else { return .ignored }
            Task { await chatBridge.cancelStreaming() }
            return .handled
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatShortcutsDidChange)) { _ in
            shortcuts = ChatShortcutRegistry.currentShortcuts
        }
        .onAppear {
            shortcuts = ChatShortcutRegistry.currentShortcuts
        }
    }

    // MARK: - Shortcut Bar

    private var shortcutBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    Button {
                        executeShortcut(shortcut)
                    } label: {
                        HStack(spacing: 5) {
                            if shortcut.isTerminalCommand {
                                Image(systemName: "terminal").font(.system(size: ClaudeTheme.size(10), weight: .medium))
                            }
                            Text(shortcut.name).font(.system(size: ClaudeTheme.size(12), weight: .medium))
                        }
                        .foregroundStyle(ClaudeTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ClaudeTheme.accentSubtle, in: Capsule())
                        .overlay(Capsule().strokeBorder(ClaudeTheme.accent.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(shortcut.isTerminalCommand ? "⌨ \(shortcut.message)" : shortcut.message)
                    .disabled(chatBridge.isStreaming)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(ClaudeTheme.background)
    }

    // MARK: - Read-only Banner

    private var readOnlyBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: ClaudeTheme.size(13), weight: .semibold))
                .foregroundStyle(ClaudeTheme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Read-only session", bundle: .module))
                    .font(.system(size: ClaudeTheme.size(13), weight: .semibold))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text(String(localized: "This session was created before CLI sync and can't be continued. Start a new chat to keep the conversation in sync with the CLI.", bundle: .module))
                    .font(.system(size: ClaudeTheme.size(11)))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClaudeTheme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }

    private func executeShortcut(_ shortcut: ChatShortcut) {
        guard !chatBridge.isStreaming else { return }
        if shortcut.isTerminalCommand {
            Task { await chatBridge.runTerminalCommand(shortcut.message) }
        } else {
            windowState.inputText = shortcut.message
            Task { await chatBridge.send() }
        }
    }

    // MARK: - Messages

    private var messageScrollView: some View {
        MessageListView(onTapBackground: { windowState.requestInputFocus = true })
    }
}

public extension ChatView where InputAccessory == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
