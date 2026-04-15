# Clarc

**Native macOS desktop client for Claude Code**

Escape the terminal-based CLI and leverage all Claude Code features through an intuitive GUI.

![Platform](https://img.shields.io/badge/platform-macOS%2026.2%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-Apache%202.0-green)

---

## Screenshots

> Screenshots coming soon

---

## Features

| Feature | Description |
|---------|-------------|
| **Streaming Chat** | Real-time streaming conversation with Claude Code. Markdown rendering, tool call visualization |
| **Multi-Project** | Register multiple projects and switch freely. Per-project session history |
| **GitHub Integration** | OAuth authentication, SSH key management, repository browsing and cloning |
| **File Attachments** | Drag-and-drop image/file attachments. Auto-conversion of long text to attachments |
| **Slash Commands** | Extensible command system |
| **Permission Management** | Risk-based approve/deny UI before tool execution |
| **Skill Marketplace** | Browse and install official Anthropic plugins |
| **Model Selection** | Choose between claude-opus-4-6, claude-sonnet-4-6, and claude-haiku-4-5 |
| **Usage Tracking** | Per-session token count, cost, and duration |
| **Built-in Terminal** | SwiftTerm-based terminal emulator |
| **File Explorer** | Project file tree, Git status, file preview |

---

## Requirements

- **macOS 26.2** or later
- **[Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)** must be installed
- **Xcode 16** or later (for building)

---

## Installation

### Build from Source

```bash
git clone https://github.com/ttnear/Clarc.git
cd Clarc
open Clarc.xcodeproj
```

Build and run with `Cmd+R` in Xcode.

### CLI Build

```bash
# Debug build
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Debug build

# Release build
xcodebuild -project Clarc.xcodeproj -scheme Clarc -configuration Release build
```

---

## Architecture

```
Clarc/
├── App/              # App entry point, AppState
├── Services/         # Business logic (Actor-based)
│   ├── ClaudeService       # Claude CLI process management, NDJSON streaming
│   ├── GitHubService       # GitHub OAuth, SSH, repository management
│   ├── PersistenceService  # File-based JSON persistence
│   ├── PermissionServer    # Tool execution approval HTTP server
│   ├── MarketplaceService  # Plugin catalog management
│   └── RateLimitService    # Usage tracking, token refresh
├── Views/            # SwiftUI views
│   ├── Chat/         # Chat UI, message bubbles, input bar, marketplace
│   ├── Sidebar/      # Project list, session history, file tree, Git status
│   ├── Onboarding/   # Initial setup flow
│   ├── Permission/   # Permission approval modals
│   └── Terminal/     # Built-in terminal (SwiftTerm)
├── Packages/
│   ├── ClarcCore/    # Shared models, theme, utilities
│   └── ClarcChatKit/ # Chat UI components
├── Theme/            # Custom theme (light/dark mode)
├── Resources/        # Localization (en, ko)
└── Utilities/        # Git helper, SSH key manager, Keychain, etc.
```

**Tech stack:** Swift 6 + SwiftUI, Swift Concurrency (async/await, Actor), SwiftTerm

---

## Contributing

Contributions are welcome! Bug reports, feature requests, and PRs are all appreciated.

1. Fork this repository.
2. Create a feature branch. (`git checkout -b feat/my-feature`)
3. Commit your changes. (`git commit -m 'feat: add my feature'`)
4. Push the branch. (`git push origin feat/my-feature`)
5. Open a Pull Request.

For bug reports or feature requests, please use [GitHub Issues](https://github.com/ttnear/Clarc/issues).

---

## License

Apache License 2.0 — see the [LICENSE](LICENSE) file for details.
