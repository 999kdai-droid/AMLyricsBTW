#!/bin/bash
# Xcode Project Setup Script for AMLyricsBTW

set -e

PROJECT_NAME="AMLyricsBTW"
BUNDLE_ID="com.example.amlyricsbtw"
PROJECT_DIR="$(pwd)"

echo "=== AMLyricsBTW Xcode Project Setup ==="
echo ""

# Check if Xcode command line tools are installed
echo "Checking Xcode command line tools..."
if ! command -v xcodebuild &> /dev/null; then
    echo "xcodebuild not found. Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Create Xcode project using command line
echo "Creating Xcode project..."
mkdir -p xcode_project
cd xcode_project

# Create project structure
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create Info.plist
cat > Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSAppleMusicUsageDescription</key>
    <string>This app needs access to Apple Music to display synchronized lyrics.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
</dict>
</plist>
EOF

# Create main app file
mkdir -p "$PROJECT_NAME"
cat > "$PROJECT_NAME/App.swift" << 'EOF'
import SwiftUI
import MusicKit
import SwiftData

@main
struct AMLyricsBTWApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CachedLyrics.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct ContentView: View {
    var body: some View {
        Text("AMLyricsBTW")
            .font(.largeTitle)
    }
}
EOF

# Copy client files
echo "Copying client files..."
CLIENT_DIR="$PROJECT_DIR/client"
if [ -d "$CLIENT_DIR" ]; then
    cp -r "$CLIENT_DIR/Models" ./
    cp -r "$CLIENT_DIR/Views" ./
    cp -r "$CLIENT_DIR/Managers" ./
    cp -r "$CLIENT_DIR/Utilities" ./
    cp -r "$CLIENT_DIR/SwiftData" ./
    echo "Client files copied successfully."
else
    echo "Warning: client directory not found at $CLIENT_DIR"
fi

cd ..

echo ""
echo "=== Xcode Project Setup Complete ==="
echo ""
echo "Project created at: $PROJECT_DIR/xcode_project/$PROJECT_NAME"
echo ""
echo "Next steps:"
echo "1. Open Xcode and create a new macOS App project"
echo "2. Copy the files from xcode_project/$PROJECT_NAME to your Xcode project"
echo "3. Add MusicKit and SwiftData capabilities in Signing & Capabilities"
echo "4. Set deployment target to macOS 15.0"
echo "5. Set Swift Language Version to Swift 6"
