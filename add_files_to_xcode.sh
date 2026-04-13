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
