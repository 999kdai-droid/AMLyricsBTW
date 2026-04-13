#!/bin/bash
# Git Repository Setup and GitHub Sync Script for AMLyricsBTW

set -e

echo "=== Git Repository Setup ==="
echo ""

# Initialize git repository
echo "Initializing git repository..."
git init

# Create .gitignore
echo "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Python
server/venv/
server/__pycache__/
server/*.pyc
server/.env
server/cache/

# macOS
.DS_Store
*.dmg

# Xcode
xcode_project/
*.xcodeproj/
*.xcworkspace/
DerivedData/

# Swift
*.swiftpm/
.build/

# Temporary files
*.tmp
*.log
EOF

# Add all files
echo "Adding files to git..."
git add .

# Create initial commit
echo "Creating initial commit..."
git commit -m "Initial commit: AMLyricsBTW implementation

- Server: Python/FastAPI with WhisperX, Gemini API, job queue
- Client: SwiftUI with karaoke lyrics, MusicKit, SwiftData
- Documentation: README, setup scripts"

echo ""
echo "=== Git Repository Setup Complete ==="
echo ""
echo "Next steps to sync to GitHub:"
echo ""
echo "1. Create a new repository on GitHub (https://github.com/new)"
echo "2. Run the following commands (replace YOUR_USERNAME and REPO_NAME):"
echo ""
echo "   git branch -M main"
echo "   git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git"
echo "   git push -u origin main"
echo ""
echo "Or use GitHub CLI (if installed):"
echo ""
echo "   gh repo create AMLyricsBTW --public --source=. --remote=origin"
echo "   git branch -M main"
echo "   git push -u origin main"
