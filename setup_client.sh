#!/bin/bash
# Client Setup Script for AMLyricsBTW
# This script automates the client-side setup process using local files

set -e

PROJECT_NAME="AMLyricsBTW"
BUNDLE_ID="com.example.amlyricsbtw"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== AMLyricsBTW Client Setup ==="
echo ""

# Check if Xcode is installed
echo "Checking Xcode installation..."
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found."
    echo "Please install Xcode from the App Store and run:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app"
    echo "  xcode-select --install"
    exit 1
fi

echo "Xcode found: $(xcodebuild -version | head -n 1)"
echo ""

# Install xcodegen if not present
echo "Checking xcodegen installation..."
if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "Error: Homebrew not found. Please install Homebrew first:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
else
    echo "xcodegen found: $(xcodegen version)"
fi
echo ""

# Use the script directory as the project directory
echo "Using local files at: $SCRIPT_DIR"
cd "$SCRIPT_DIR"

echo ""
echo "=== Working with local files at: $(pwd) ==="
echo ""

# Generate Xcode project using xcodegen
echo "Generating Xcode project using xcodegen..."

# Create project.yml for xcodegen
cat > project.yml << EOF
name: $PROJECT_NAME
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    macOS: "15.0"
  developmentLanguage: ja
targets:
  $PROJECT_NAME:
    type: application
    platform: macOS
    deploymentTarget: "15.0"
    sources:
      - path: client
        includes: ["**/*.swift"]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID
      SWIFT_VERSION: "6.0"
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      INFOPLIST_FILE: Info.plist
    capabilities:
      - musicKit
EOF

# Generate Xcode project
xcodegen generate
echo "Xcode project generated successfully."

# Copy client files to a convenient location
echo ""
echo "=== Preparing client files ==="
echo "Client files are located in: $(pwd)/client/"
echo ""

# Create a script to help with file addition
cat > add_files_to_xcode.sh << 'EOF'
#!/bin/bash
# Helper script to add files to Xcode project
# Usage: Run this script from the project root

PROJECT_NAME="AMLyricsBTW"
CLIENT_DIR="client"

echo "Adding client files to Xcode project..."

# Create directory structure in Xcode project
mkdir -p Models Views Managers SwiftData Utilities

# Copy files
cp -r "$CLIENT_DIR/Models/"* ./Models/
cp -r "$CLIENT_DIR/Views/"* ./Views/
cp -r "$CLIENT_DIR/Managers/"* ./Managers/
cp -r "$CLIENT_DIR/SwiftData/"* ./SwiftData/
cp -r "$CLIENT_DIR/Utilities/"* ./Utilities/

echo "Files copied. Now add them in Xcode:"
echo "1. Open Xcode project"
echo "2. Right-click on project in navigator"
echo "3. Select 'Add Files to $PROJECT_NAME'"
echo "4. Select the copied directories"
echo "5. Make sure 'Copy items if needed' is checked"
echo "6. Click Add"
EOF

chmod +x add_files_to_xcode.sh
echo "Created helper script: add_files_to_xcode.sh"
echo ""

# Create Info.plist if it doesn't exist
if [ ! -f "Info.plist" ]; then
    echo "Creating Info.plist..."
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
</dict>
</plist>
EOF
    echo "Info.plist created."
fi

# Create App.swift (main entry point)
if [ ! -f "App.swift" ]; then
    echo "Creating App.swift..."
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
    echo "App.swift created."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Open Xcode project: open $PROJECT_NAME.xcodeproj"
echo "2. Add client files using: ./add_files_to_xcode.sh"
echo "3. Configure capabilities:"
echo "   - Target → Signing & Capabilities"
echo "   - + Capability → MusicKit"
echo "   - + Capability → App Sandbox (if needed)"
echo "4. Set deployment target to macOS 15.0"
echo "5. Set Swift Language Version to Swift 6"
echo "6. Build and run (⌘R)"
echo ""
echo "Server configuration:"
echo "Add this code in your app to configure server connection:"
echo ""
echo 'UserDefaults.standard.set("http://192.168.1.100:8000", forKey: "serverBaseURL")'
echo 'UserDefaults.standard.set("your_api_key_here", forKey: "serverAPIKey")'
