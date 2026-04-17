# HermesMenuBar Development Summary

## Overview

HermesMenuBar is a native macOS menu bar chat application built to communicate directly with the local Hermes AI assistant.

## Core Features

- Native menu bar app with quick popover access
- Streaming AI responses
- Session creation, switching, deletion, renaming, pinning, and archiving
- Persistent local chat history
- Cancel in-flight replies
- ACP (Agent Communication Protocol) support through the local Hermes CLI

## Technical Stack

- **Language:** Swift 5.9
- **UI Framework:** SwiftUI
- **Architecture:** MVVM
- **Persistence:** JSON files in Application Support
- **Protocol:** ACP over stdio

## ACP Implementation Summary

The app communicates with Hermes through ACP in the following flow:

1. Launch a local `hermes acp` subprocess
2. Initialize the ACP connection
3. Send prompts through `session/prompt`
4. Stream JSON-RPC updates back into the UI
5. Sync local GUI sessions with ACP sessions when needed

## Project Structure

```text
HermesMenuBar/
├── HermesMenuBar/
│   ├── HermesMenuBarApp.swift
│   ├── Info.plist
│   ├── Models/
│   │   ├── ChatSession.swift
│   │   ├── Message.swift
│   │   ├── MessageAttachment.swift
│   │   ├── MessageDisplayKind.swift
│   │   └── SessionRuntimeState.swift
│   ├── Views/
│   │   ├── ChatView.swift
│   │   ├── MessageBubble.swift
│   │   ├── MarkdownTextView.swift
│   │   ├── ComposerTextView.swift
│   │   ├── DiagnosticsView.swift
│   │   ├── ACPSessionPickerView.swift
│   │   └── SessionPickerView.swift
│   ├── ViewModels/
│   │   └── ChatViewModel.swift
│   └── Services/
│       ├── SessionManager.swift
│       ├── SessionStore.swift
│       ├── HermesClient.swift
│       ├── ACPClient.swift
│       ├── HermesImagePreprocessor.swift
│       └── DebugLogger.swift
├── Package.swift
├── README.md
├── README_CN.md
├── build_app.sh
├── install.sh
├── start.sh
└── package.sh
```

## Build and Distribution

- `./start.sh` builds the latest source and opens the new app bundle
- `./install.sh` builds and installs the app into `~/Applications`
- `./package.sh` builds a release bundle and creates a distributable ZIP archive

## Troubleshooting Notes

- If Hermes does not respond, verify that `hermes acp --help` works locally
- If the app cannot be opened, macOS may require manually allowing the unsigned binary
- If the menu bar icon is missing, check Control Center and other crowded menu bar items

## Future Work

- Better packaging with code signing and notarization
- Optional DMG generation when `create-dmg` is installed
- Additional UI polish and richer tool/trace presentation
- Automated regression coverage once the local toolchain supports it cleanly
