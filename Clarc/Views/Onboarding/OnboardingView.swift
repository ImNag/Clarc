import SwiftUI
import ClarcCore

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var isCheckingCLI = false
    @State private var cliInstalled = false
    @State private var cliVersion: String?
    @State private var cliError: String?

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                cliCheckStep
                if cliInstalled {
                    sessionSyncStep(isOn: $appState.cliSessionSyncEnabled)
                }
            }
            .frame(maxWidth: 460)

            Spacer()

            navigationButtons
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 560, height: cliInstalled ? 520 : 420)
        .background(ClaudeTheme.background)
        .task {
            await checkCLI()
        }
    }

    // MARK: - CLI Check

    private var cliCheckStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: ClaudeTheme.size(48)))
                .foregroundStyle(ClaudeTheme.accent)

            Text("Claude CLI Installation Check")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudeTheme.textPrimary)

            if isCheckingCLI {
                ProgressView("Checking...")
            } else if cliInstalled {
                Label("Installed — \(cliVersion ?? "")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                    .font(.body)
            } else {
                VStack(spacing: 12) {
                    Label("Claude CLI not found", systemImage: "xmark.circle.fill")
                        .foregroundStyle(ClaudeTheme.statusError)
                        .font(.body)

                    if let error = cliError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ClaudeTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Install command:")
                            .font(.subheadline)
                            .foregroundStyle(ClaudeTheme.textSecondary)

                        HStack {
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(ClaudeTheme.textPrimary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(ClaudeTheme.codeBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    "npm install -g @anthropic-ai/claude-code",
                                    forType: .string
                                )
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Copy")
                        }
                    }
                }

                Button("Check Again") {
                    Task { await checkCLI() }
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Session Sync Step

    private func sessionSyncStep(isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync sessions with Claude Code CLI")
                        .font(.system(size: ClaudeTheme.size(13), weight: .semibold))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                    Text("Share session history with the terminal CLI in ~/.claude/projects/. Turn off to keep Clarc sessions separate. You can change this later in Settings.")
                        .font(.system(size: ClaudeTheme.size(11)))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClaudeTheme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            Spacer()
            Button("Get Started") {
                appState.skipGitHubLogin()
            }
            .buttonStyle(ClaudeAccentButtonStyle())
            .disabled(!cliInstalled)
        }
    }

    // MARK: - Helpers

    private func checkCLI() async {
        isCheckingCLI = true
        cliError = nil

        do {
            let version = try await appState.claude.checkVersion()
            cliVersion = version
            cliInstalled = true
            appState.claudeInstalled = true
        } catch {
            cliInstalled = false
            cliError = error.localizedDescription

            let binary = await appState.claude.findClaudeBinary()
            if let binary {
                cliError = "Binary found: \(binary), but version check failed"
                cliInstalled = true
                appState.claudeInstalled = true
            }
        }

        isCheckingCLI = false
    }

}

#Preview {
    OnboardingView()
        .environment(AppState())
}
