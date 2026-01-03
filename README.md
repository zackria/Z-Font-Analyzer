# Z Font Analyzer 🔍

A premium macOS application designed to scan, analyze, and report font usage within Apple Motion templates (`.moti`, `.motn`, `.motr`, `.moef`). Built with SwiftUI and following the latest macOS design standards.

## ✨ Features

- **Standardized Pro UI**: A clean, tab-based interface inspired by Xcode and Final Cut Pro.
- **Interactive Dashboard**:
    - **Key Metrics**: Quick overview of files processed, unique fonts, and file types.
    - **Visual Insights**: Sector charts for file type distribution and bar charts for top fonts used.
- **Deep Scanning**: Efficiently parses large directories and nested folders to find `<font>` tags in Motion XML files.
- **Multilingual Support**: Supports dynamic in-app language switching (English, Spanish, etc.).
- **Data Export**: Export your analysis results to **JSON** or **CSV** for external reporting or auditing.
- **Advanced Filtering**: Real-time search and filtering of found fonts and paths.

## 🛠 Prerequisites

- **macOS**: 14.0 or later.
- **Xcode**: 15.0 or later.
- **Swift**: 5.9 or later.

## 🚀 Building and Running

### via Xcode
1. **Clone the repository**:
   ```bash
   git clone https://github.com/zackria/Z-Font-Analyzer.git
   cd Z-Font-Analyzer
   ```

2. **Open the Project**:
   Locate and open `Z Font Analyzer.xcodeproj` in Xcode.

3. **Select the Target**:
   Ensure the **Z Font Analyzer** target is selected in the Xcode scheme selector.

4. **Build and Run**:
   Press `⌘ + R` or click the **Play** button in Xcode to build and launch the application.

### via Terminal
You can also build the project using `xcodebuild`:

```bash
# Build the project
xcodebuild -project "Z Font Analyzer.xcodeproj" -scheme "Z Font Analyzer" build

# Build and run (using open)
xcodebuild -project "Z Font Analyzer.xcodeproj" -scheme "Z Font Analyzer" -configuration Debug build
open "$(xcodebuild -project "Z Font Analyzer.xcodeproj" -scheme "Z Font Analyzer" -configuration Debug -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')/Z Font Analyzer.app"
```

## 🧪 Testing

The project includes an automated test suite to ensure reliability.

### via Xcode
- **Unit & UI Tests**: Press `⌘ + U` to run all tests in the active scheme. 

### via Terminal
Run all tests from the command line:

```bash
xcodebuild -project "Z Font Analyzer.xcodeproj" -scheme "Z Font Analyzer" test
```

### via Xcode
- **Unit & UI Tests**: Press `⌘ + U` to run all tests in the active scheme. 

### via Terminal
Run all tests from the command line:

```bash
xcodebuild test -project "Z Font Analyzer.xcodeproj" -scheme "Z Analyzer" -destination 'platform=macOS' -testPlan "Z Font Analyzer" -enableCodeCoverage YES -quiet
```

## 🌍 Localization

Z Font Analyzer is ready for a global audience. You can change languages in real-time via the **Settings** menu.
Current supported languages:
- 🇺🇸 English
- 🇪🇸 Spanish (Castellano)
- *Placeholders ready for: French, German, Arabic, and Simplified Chinese.*

## 📂 Project Structure

- `Core/Models`: Data structures and document types.
- `Core/Services`: Localization, Exporter, and Search logic.
- `Views/Components`: Reusable UI elements like dashboard cards.
- `Views`: Main feature views (Dashboard, Settings, etc.).

---

Created with ❤️ for Motion Designers and Video Editors.
