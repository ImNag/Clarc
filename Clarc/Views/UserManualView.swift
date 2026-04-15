import SwiftUI

struct UserManualView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: ManualTopic = .overview

    var body: some View {
        NavigationSplitView {
            topicList
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            ScrollView {
                topicDetail(selectedTopic)
                    .padding(24)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(12)
            }
        }
        .frame(width: 900, height: 680)
    }

    // MARK: - Topic List

    private var topicList: some View {
        List(ManualTopic.allCases, selection: $selectedTopic) { topic in
            Label(LocalizedStringKey(topic.title), systemImage: topic.icon)
                .tag(topic)
        }
        .listStyle(.sidebar)
        .navigationTitle("User Guide")
    }

    // MARK: - Topic Detail

    @ViewBuilder
    private func topicDetail(_ topic: ManualTopic) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: topic.icon)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                Text(LocalizedStringKey(topic.title))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Divider()

            ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
    }

    private func sectionView(_ section: ManualSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(LocalizedStringKey(title))
                    .font(.headline)
            }

            Text(LocalizedStringKey(section.body))
                .font(.body)
                .foregroundStyle(.secondary)

            if !section.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.items, id: \.key) { item in
                        ManualKeyValueRow(key: item.key, value: item.value, symbolName: item.symbolName, symbolColor: item.symbolColor)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let note = section.note {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                    Text(LocalizedStringKey(note))
                        .font(.callout)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - Key-Value Row

private struct ManualKeyValueRow: View {
    let key: String
    let value: String
    var symbolName: String? = nil
    var symbolColor: Color? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(symbolColor ?? .primary)
                    .frame(width: 28, height: 20)
            } else {
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
            }
            Text(LocalizedStringKey(value))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Data Models

struct ManualSection {
    let title: String?
    let body: String
    let items: [KeyValueItem]
    let note: String?

    init(title: String? = nil, body: String = "", items: [KeyValueItem] = [], note: String? = nil) {
        self.title = title
        self.body = body
        self.items = items
        self.note = note
    }
}

struct KeyValueItem {
    let key: String
    let value: String
    var symbolName: String? = nil
    var symbolColor: Color? = nil
}

// MARK: - Topics

enum ManualTopic: String, CaseIterable, Identifiable {
    case overview
    case projects
    case chat
    case shortcuts
    case slashCommands
    case attachments
    case customShortcuts
    case terminal
    case marketplace
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:       "About Clarc"
        case .projects:       "Project Management"
        case .chat:           "Chat Basics"
        case .shortcuts:      "Keyboard Shortcuts"
        case .slashCommands:  "Slash Commands"
        case .attachments:    "File & Image Attachments"
        case .customShortcuts:"Shortcut Buttons"
        case .terminal:       "Terminal"
        case .marketplace:    "Skill Marketplace"
        case .permissions:    "Permission Requests"
        }
    }

    var icon: String {
        switch self {
        case .overview:       "sparkle"
        case .projects:       "folder.fill"
        case .chat:           "bubble.left.and.bubble.right"
        case .shortcuts:      "keyboard"
        case .slashCommands:  "terminal.fill"
        case .attachments:    "paperclip"
        case .customShortcuts:"bolt.fill"
        case .terminal:       "apple.terminal"
        case .marketplace:    "brain.head.profile"
        case .permissions:    "checkmark.shield"
        }
    }

    var sections: [ManualSection] {
        switch self {
        case .overview:
            [
                ManualSection(
                    title: "What is Clarc?",
                    body: "A native macOS desktop client for the Claude Code CLI. Use all Claude Code features via a GUI without needing a terminal."
                ),
                ManualSection(
                    title: "Main Layout",
                    body: "The left sidebar has History and Files tabs. Project tabs are shown at the top of the chat area; click to switch projects.",
                    note: "Chat is disabled when no project is selected."
                ),
                ManualSection(
                    title: "Top Toolbar",
                    body: "The toolbar lets you start a new chat, open the terminal, access the skill marketplace, manage shortcuts and slash commands, change the theme, and open the user guide."
                ),
            ]

        case .projects:
            [
                ManualSection(
                    title: "Adding a Project",
                    body: "Click the + button at the top of the sidebar or drag a folder from Finder. Claude Code uses that folder as its working directory."
                ),
                ManualSection(
                    title: "Project Tabs",
                    body: "Project tabs appear at the top of the chat area. Click a tab to switch projects. You can switch even while streaming; the active stream continues running in the background."
                ),
                ManualSection(
                    title: "Dedicated Project Window",
                    body: "Double-click a project tab to open it in its own independent window. You can work on multiple projects simultaneously, each in its own window.",
                    note: "In a dedicated project window, only the project name is shown — there are no project tabs."
                ),
                ManualSection(
                    title: "Sidebar Tabs",
                    body: "History tab: shows previous conversations\nFiles tab: browse the project file tree",
                    items: [
                        KeyValueItem(key: "⌘1", value: "Go to History tab"),
                        KeyValueItem(key: "⌘2", value: "Go to Files tab"),
                        KeyValueItem(key: "⌘F", value: "Files tab + activate search"),
                    ]
                ),
                ManualSection(
                    title: "Git Status",
                    body: "The number of changed files is shown at the bottom of the sidebar."
                ),
            ]

        case .chat:
            [
                ManualSection(
                    title: "Sending Messages",
                    body: "Type a message in the input field and press Return or the send button.",
                    items: [
                        KeyValueItem(key: "Return", value: "Send message"),
                        KeyValueItem(key: "⌘Return", value: "Send message (alternative)"),
                        KeyValueItem(key: "⇧Return", value: "Insert line break"),
                        KeyValueItem(key: "Escape", value: "Stop streaming (cancel response generation)"),
                    ]
                ),
                ManualSection(
                    title: "Sending Messages While Streaming",
                    body: "You can send messages even while Claude is responding. The next message will be sent automatically once the current response finishes. Queued messages are shown as a badge above the input field."
                ),
                ManualSection(
                    title: "Recalling Previous Messages",
                    body: "When the input field is empty, use ↑/↓ to recall previously sent messages.",
                    items: [
                        KeyValueItem(key: "↑", value: "Recall previous message"),
                        KeyValueItem(key: "↓", value: "Next message / clear input"),
                    ]
                ),
                ManualSection(
                    title: "Changing the Model",
                    body: "Use the model dropdown at the top right of the chat area to switch Claude models."
                ),
                ManualSection(
                    title: "Skip Permissions",
                    body: "Click the shield icon at the top of the chat to automatically approve all permission prompts. Use with caution.",
                    note: "Green = permission requests active / Red = all permissions auto-approved"
                ),
            ]

        case .shortcuts:
            [
                ManualSection(
                    title: "Global Shortcuts",
                    body: "",
                    items: [
                        KeyValueItem(key: "⌘N", value: "Start new chat"),
                        KeyValueItem(key: "⌘W", value: "Close current window"),
                        KeyValueItem(key: "⌘1", value: "Sidebar — History tab"),
                        KeyValueItem(key: "⌘2", value: "Sidebar — Files tab"),
                        KeyValueItem(key: "⌘F", value: "Sidebar — Files tab + search"),
                        KeyValueItem(key: "Double-click", value: "Project tab — open in dedicated window"),
                    ]
                ),
                ManualSection(
                    title: "Input Field Shortcuts",
                    body: "",
                    items: [
                        KeyValueItem(key: "Return", value: "Send message"),
                        KeyValueItem(key: "⌘Return", value: "Send message (alternative)"),
                        KeyValueItem(key: "⇧Return", value: "Line break"),
                        KeyValueItem(key: "Escape", value: "Close popup / stop streaming"),
                        KeyValueItem(key: "↑ / ↓", value: "Select popup item or navigate message history"),
                        KeyValueItem(key: "Tab", value: "Autocomplete slash command / @ file"),
                    ]
                ),
                ManualSection(
                    title: "Slash Command Popup",
                    body: "",
                    items: [
                        KeyValueItem(key: "↑ / ↓", value: "Select item"),
                        KeyValueItem(key: "Return", value: "Execute command"),
                        KeyValueItem(key: "⌘Return", value: "View command details"),
                        KeyValueItem(key: "Tab", value: "Autocomplete command"),
                        KeyValueItem(key: "Escape", value: "Close popup"),
                    ]
                ),
                ManualSection(
                    title: "@ File Popup",
                    body: "",
                    items: [
                        KeyValueItem(key: "↑ / ↓", value: "Select item"),
                        KeyValueItem(key: "Return / Tab", value: "Insert file path"),
                        KeyValueItem(key: "Escape", value: "Close popup"),
                    ]
                ),
            ]

        case .slashCommands:
            [
                ManualSection(
                    title: "What are Slash Commands?",
                    body: "Type / in the input field to see a popup list of available commands. Quickly execute Claude Code CLI commands from here."
                ),
                ManualSection(
                    title: "How to Use",
                    body: "Type / in the input field to open the popup. Continue typing to filter results, then use ↑↓ to select and press Return or Tab to execute."
                ),
                ManualSection(
                    title: "Custom Commands",
                    body: "Click the / button in the toolbar to add, edit, or delete custom slash commands. Commands are saved per project.",
                    note: "Built-in commands can be hidden or modified, and you can also add entirely new commands."
                ),
            ]

        case .attachments:
            [
                ManualSection(
                    title: "Attaching Files",
                    body: "Click the clip icon to the left of the input field, or drag and drop files onto the input field to attach them."
                ),
                ManualSection(
                    title: "Attaching Images",
                    body: "Drag an image file or paste from the clipboard (⌘V). Screenshots can be pasted directly as well."
                ),
                ManualSection(
                    title: "Auto-converting Long Text",
                    body: "Pasting long text automatically converts it into a text attachment. Click the attachment to preview its contents."
                ),
                ManualSection(
                    title: "@ File References",
                    body: "Type @ in the input field to open a project file search popup. Selecting a file inserts its path into the message so Claude can reference it."
                ),
            ]

        case .customShortcuts:
            [
                ManualSection(
                    title: "What are Shortcut Buttons?",
                    body: "Quick-access buttons shown at the top of the chat. Run frequently used messages or terminal commands with a single click."
                ),
                ManualSection(
                    title: "Adding a Shortcut",
                    body: "Click the lightning bolt icon (⚡) in the toolbar, or press the + button on the right side of the shortcut bar. You can set a name, message/command, icon, and color."
                ),
                ManualSection(
                    title: "Terminal Command Shortcuts",
                    body: "Enable the \"Run as terminal command\" option to execute the command in the terminal instead of sending it as a chat message.",
                    note: "Shortcuts are saved per project. Import/export as JSON is also supported."
                ),
            ]

        case .terminal:
            [
                ManualSection(
                    title: "Opening the Terminal",
                    body: "Click the terminal icon in the toolbar to open an inspector panel in the sidebar, with the terminal running at the current project path."
                ),
                ManualSection(
                    title: "Interactive Terminal Popup",
                    body: "Some slash commands (/config, /permissions, etc.) open in an interactive terminal popup. Use interactive CLI tools in a separate sheet window. It closes automatically when done."
                ),
            ]

        case .marketplace:
            [
                ManualSection(
                    title: "Skill Marketplace",
                    body: "Click the brain icon in the toolbar to browse the MCP plugin catalog published on Anthropic's GitHub."
                ),
                ManualSection(
                    title: "Installing Plugins",
                    body: "Select a plugin in the marketplace to see instructions on how to install it in Claude Code. The catalog refreshes automatically every 5 minutes."
                ),
            ]

        case .permissions:
            [
                ManualSection(
                    title: "What are Permission Requests?",
                    body: "Before Claude performs actions like editing files or running commands, it asks for your approval. A popup appears where you can allow or deny the request."
                ),
                ManualSection(
                    title: "Skip Permissions Mode",
                    body: "Toggle the shield icon at the top of the chat to auto-approve all permission requests. This speeds up tasks but also auto-executes potentially dangerous operations — use with caution.",
                    items: [
                        KeyValueItem(key: "bolt.shield", value: "Permission requests active (normal mode)", symbolName: "bolt.shield", symbolColor: .green),
                        KeyValueItem(key: "bolt.shield.fill", value: "All permissions auto-approved (Skip mode)", symbolName: "bolt.shield.fill", symbolColor: .red),
                    ],
                    note: "Only use Skip Permissions on projects you trust."
                ),
            ]
        }
    }
}

#Preview {
    UserManualView()
}
