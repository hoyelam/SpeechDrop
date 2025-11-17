# SpeechDrop

## Project Description

SpeechDrop is a macOS Speech-to-Text journal application that enables users to capture their thoughts, ideas, and notes through voice dictation. The app provides a seamless interface for converting spoken words into written text, making it easy to maintain a personal journal without the need for typing.

### Key Features

- **Voice-to-Text Conversion**: Uses WhisperKit for on-device, high-quality speech transcription with real-time streaming support
- **Journal Management**: Organize and store journal entries with timestamps
- **Native macOS Experience**: Built with Swift and SwiftUI for a modern, native macOS interface
- **Easy Access**: Quick and intuitive interface for capturing thoughts on the go

### Technology Stack

- **Language**: Swift 6
- **Framework**: SwiftUI
- **Platform**: macOS
- **Data Storage**: SQLite for local data persistence
- **Speech Recognition**: WhisperKit (https://github.com/argmaxinc/WhisperKit) - On-device ML-powered transcription with OpenAI Whisper models

---

## Build Instructions

### Prerequisites

- **Xcode**: Version 15.0 or later
- **macOS**: macOS 14.0+ (for development)
- **Swift**: Swift 6 (included with Xcode)

### Building for macOS

**Using Xcode:**
1. Open `SpeechDrop.xcodeproj` in Xcode
2. Select "My Mac" as the destination
3. Press `⌘ + B` to build, or `⌘ + R` to build and run

**Using Command Line:**
```bash
# Build for macOS (Debug)
xcodebuild -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -configuration Debug \
  -destination 'platform=macOS'

# Build for macOS (Release)
xcodebuild -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -configuration Release \
  -destination 'platform=macOS'
```

### Building for iPhone

**Using Xcode:**
1. Open `SpeechDrop.xcodeproj` in Xcode
2. Select your connected iPhone or a simulator (e.g., "iPhone 17 Pro") as the destination
3. Press `⌘ + B` to build, or `⌘ + R` to build and run

**Using Command Line:**

```bash
# Build for iPhone Simulator (iPhone 17 Pro)
xcodebuild -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build for Physical iPhone (requires code signing)
xcodebuild -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -configuration Debug \
  -destination 'platform=iOS,name=Your iPhone Name'

# Build for generic iOS device
xcodebuild -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -configuration Release \
  -destination 'generic/platform=iOS'
```

### Available Simulators

To list all available simulators:
```bash
xcrun simctl list devices available
```

Common iPhone 17 simulators:
- iPhone 17
- iPhone 17 Pro
- iPhone 17 Pro Max

### Clean Build

If you encounter build issues, clean the build folder:

**Using Xcode:**
- Press `⌘ + Shift + K` (Clean Build Folder)

**Using Command Line:**
```bash
xcodebuild clean -project SpeechDrop.xcodeproj -scheme SpeechDrop
```

### Running Tests

```bash
# Run tests on macOS
xcodebuild test -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -destination 'platform=macOS'

# Run tests on iPhone Simulator
xcodebuild test -project SpeechDrop.xcodeproj \
  -scheme SpeechDrop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Build Notes

- **First Build**: The first build will take longer as it downloads and compiles WhisperKit models and dependencies
- **Code Signing**: Building for physical iOS devices requires proper code signing configuration in Xcode
- **Model Downloads**: WhisperKit models are downloaded on first run, not during build time
- **Swift 6 Concurrency**: Ensure strict concurrency checking is enabled for Swift 6 compliance

---

## Agent Rules

The following agent rules provide guidance for working with this codebase:

@import agent-rules/modern-swift.mdc
@import agent-rules/swift6-migration.mdc
@import agent-rules/swift-testing-api.mdc
@import agent-rules/sqlite-data.md
@import agent-rules/whisperkit.mdc
