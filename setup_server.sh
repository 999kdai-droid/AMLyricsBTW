#!/bin/bash
# Server Environment Setup Script for AMLyricsBTW

set -e

cd "$(dirname "$0")/server"

echo "=== AMLyricsBTW Server Setup ==="
echo ""

# Check if Python 3.11+ is installed
echo "Checking Python version..."
python3 --version || { echo "Python 3 is required but not installed. Aborting."; exit 1; }

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Check if ffmpeg is installed
echo "Checking ffmpeg installation..."
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg is not installed. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install ffmpeg
    else
        echo "Homebrew is not installed. Please install ffmpeg manually."
        echo "Visit: https://ffmpeg.org/download.html"
    fi
else
    echo "ffmpeg is already installed."
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "Please edit .env file and add your API keys:"
    echo "  - AMLYRICS_API_KEY"
    echo "  - GEMINI_API_KEY"
else
    echo ".env file already exists."
fi

# Create cache directory
echo "Creating cache directory..."
mkdir -p cache

echo ""
echo "=== Server Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit server/.env and add your API keys"
echo "2. Start the server: cd server && source venv/bin/activate && python main.py"
