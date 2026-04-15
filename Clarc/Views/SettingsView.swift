import SwiftUI
import ClarcCore
import ClarcChatKit

// MARK: - Settings Sheet

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(WindowState.self) private var windowState

    let projectName: String

    @State private var selectedTab = 0
    @State private var showUserManual = false

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(showUserManual: $showUserManual)
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }
                .tag(0)

            SlashCommandManagerView(projectName: projectName, isEmbedded: true)
                .tabItem {
                    Label("Slash Commands", systemImage: "terminal.fill")
                }
                .tag(1)

            ShortcutManagerView(projectName: projectName, isEmbedded: true)
                .tabItem {
                    Label("Shortcuts", systemImage: "bolt.fill")
                }
                .tag(2)
        }
        .frame(width: 680, height: 620)
        .focusable(false)
        .onAppear { selectedTab = 0 }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window.title == "Settings" else { return }
            selectedTab = 0
        }
        .onDisappear {
            windowState.registryVersion += 1
        }
        .sheet(isPresented: $showUserManual) {
            UserManualView()
        }
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @Environment(AppState.self) private var appState
    @Binding var showUserManual: Bool
    @State private var showSkillMarket = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                themeSection
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    skillMarketSection
                    helpSection
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.system(size: 13, weight: .semibold))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110))],
                spacing: 8
            ) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionButton(
                        theme: theme,
                        isSelected: appState.selectedTheme == theme
                    ) {
                        appState.selectedTheme = theme
                    }
                }
            }
        }
    }

    // MARK: - Skill Market Section

    private var skillMarketSection: some View {
        Button {
            showSkillMarket = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Skill Marketplace")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                    Text("Browse and manage Claude Code skills")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSkillMarket) {
            SkillMarketView(isEmbedded: false)
        }
    }

    // MARK: - Help Section

    private var helpSection: some View {
        Button {
            showUserManual = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text("User Guide")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Option Button

private struct ThemeOptionButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.colors.accent)
                    .frame(height: 28)

                Text(theme.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color(NSColor.separatorColor),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(projectName: "MyProject")
        .environment(AppState())
        .environment(WindowState())
}
