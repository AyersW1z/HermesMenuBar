# HermesMenuBar

[中文说明 / Chinese README](README_CN.md)

HermesMenuBar is a native macOS menu bar chat client that connects directly to the local Hermes AI assistant.

## Features

- 🚀 **Always in the menu bar** - Open the chat window instantly from the macOS menu bar
- 💬 **Streaming responses** - See replies appear in real time
- 📁 **Session management** - Search, pin, archive, delete, and rename conversations
- 🖼️ **Image attachments** - Attach images and let Hermes inspect screenshots and visual references
- 📝 **Markdown rendering** - Better readability for code blocks, lists, and longer replies
- 💾 **File-based persistence** - Sessions are stored in Application Support and restored automatically
- 🔗 **ACP integration** - Connect directly to the local Hermes CLI process
- ⚡ **Native Swift UI** - Built with SwiftUI for a lightweight macOS-native experience

## Requirements

- macOS 14.0+
- Hermes CLI installed, typically at `~/.local/bin/hermes`

## Installation

### Option 1: Run directly
```bash
cd ~/Documents/HermesMenuBar
./start.sh
```
This script builds the latest source and opens `build/HermesMenuBar.app`.

### Option 2: Install to Applications
```bash
cd ~/Documents/HermesMenuBar
./install.sh
```
This script builds the latest source and installs the app into `~/Applications`.

### Option 3: Drag-install from a packaged archive
1. Download `HermesMenuBar-1.0.0.zip`
2. Extract it anywhere
3. Drag `HermesMenuBar.app` into the Applications folder

## Usage

### Basic actions

| Action | Description |
|------|------|
| Open / Close | Click the 💬 menu bar icon |
| Send a message | Type in the composer and click `Send` or press `Enter` |
| Insert a newline | Press `Shift + Enter` |
| Attach an image | Click `Image` in the composer or drag an image into the input area |
| Create a session | `New Session` |
| Switch sessions | Click a session in the left sidebar |
| Search sessions | Use the search field in the left sidebar |
| Pin / Archive | Use the session card action icons |
| Delete a session | Use the trash icon on the session card |
| Rename a session | Use the pencil icon on the session card |
| Clear messages | `Clear Messages` |
| Cancel generation | Click the red `Stop` button |
| Quit the app | `Quit` |

### Session model

Each session stores its own conversation history and can be independently pinned, archived, synced with ACP, or deleted.

## Technical Overview

### ACP flow

The app talks to Hermes through ACP (Agent Communication Protocol):

1. Start a local `hermes acp` subprocess
2. Initialize the ACP connection
3. Send prompts through `session/prompt`
4. Stream JSON-RPC updates back into the UI
5. Optionally sync GUI sessions with Hermes ACP sessions

### Storage

- Sessions and messages are stored as JSON files in Application Support
- Attached images are copied into the app data directory
- The app restores previous state automatically on launch

## Troubleshooting

### The app will not open
**Problem:** macOS says the developer cannot be verified.

**Fix:**
1. Open `System Settings`
2. Go to `Privacy & Security`
3. Find the HermesMenuBar warning
4. Choose `Open Anyway`

### Hermes does not respond
**Problem:** Sending a message produces no reply.

**Checks:**
```bash
# Verify Hermes is installed
which hermes

# Verify ACP support exists
hermes acp --help

# Send a minimal initialize request
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocol_version":1}}' | hermes acp
```

### The menu bar icon is missing
**Problem:** The app is running but you cannot see the icon.

**Fix:**
- Check whether other menu bar icons pushed it out of view
- Click empty menu bar space to reflow icons
- Check `System Settings > Control Center` to make sure HermesMenuBar is not hidden

## Development

### Build
```bash
swift build -c release
```

### Project layout
```text
HermesMenuBar/
├── HermesMenuBar/           # Source code
│   ├── HermesMenuBarApp.swift
│   ├── Models/              # Data models
│   ├── Views/               # SwiftUI views
│   ├── ViewModels/          # View models
│   └── Services/            # Service layer
│       └── ACPClient.swift  # ACP client
├── Package.swift            # Swift Package configuration
└── README.md
```

## Changelog

### v1.0.0
- Initial release
- Native menu bar app
- Session management
- ACP support
- Streaming responses

## License

MIT License
