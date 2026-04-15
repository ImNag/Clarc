import SwiftUI
import ClarcCore
import ClarcChatKit

// MARK: - FocusedValues

private struct StartNewChatKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var startNewChat: (() -> Void)? {
        get { self[StartNewChatKey.self] }
        set { self[StartNewChatKey.self] = newValue }
    }
}

// MARK: - App

@main
struct ClarcApp: App {
    @State private var appState = AppState()
    @FocusedValue(\.startNewChat) private var startNewChat
    private let updateService = UpdateService.shared

    var body: some Scene {
        WindowGroup {
            MainWindowRoot(appState: appState)
                .focusable(false)
        }
        .defaultSize(width: 1000, height: 700)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    startNewChat?()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateService.checkForUpdates()
                }
            }
            CommandMenu("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button(theme.displayName) {
                        appState.selectedTheme = theme
                    }
                    .disabled(appState.selectedTheme == theme)
                }
            }
        }

        // Dedicated project window — opened on double-click
        WindowGroup(id: "project-window", for: UUID.self) { $projectId in
            if let id = projectId {
                ProjectWindowRoot(appState: appState, projectId: id)
                    .focusable(false)
            }
        }
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsWindowRoot(appState: appState)
        }
    }
}

// MARK: - Main Window Root

struct MainWindowRoot: View {
    let appState: AppState
    @State private var windowState = WindowState()
    @State private var chatBridge = ChatBridge()

    var body: some View {
        MainView()
            .environment(appState)
            .environment(windowState)
            .environment(chatBridge)
            .task {
                await appState.initialize()
                appState.setupChatBridge(chatBridge, for: windowState)
                await appState.initializeWindow(windowState)
            }
    }
}

// MARK: - Settings Window Root

struct SettingsWindowRoot: View {
    let appState: AppState
    @State private var windowState = WindowState()

    var body: some View {
        SettingsView(projectName: "")
            .environment(appState)
            .environment(windowState)
    }
}

// MARK: - Project Window Root

struct ProjectWindowRoot: View {
    let appState: AppState
    let projectId: UUID
    @State private var windowState = WindowState()
    @State private var chatBridge = ChatBridge()

    var body: some View {
        ProjectWindowView()
            .environment(appState)
            .environment(windowState)
            .environment(chatBridge)
            .task {
                // AppState is already initialized at this point
                appState.setupChatBridge(chatBridge, for: windowState)
                await appState.initializeWindow(windowState, selectingProjectId: projectId)
            }
    }
}
