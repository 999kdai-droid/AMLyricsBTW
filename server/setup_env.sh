#!/bin/bash
# Server Environment Setup Script for AMLyricsBTW
# Run this on the iMac 2015 (server)

set -e

echo "=== AMLyricsBTW Server Environment Setup ==="
echo ""

# Check if .env exists
if [ -f .env ]; then
    echo ".env file already exists. Backing up..."
    cp .env .env.backup
    echo "Backup saved to .env.backup"
fi

# Create .env file with current configuration
echo "Creating .env file with current configuration..."
cat > .env << 'EOF'
# API Configuration
AMLYRICS_API_KEY=AMlyrics_API_SUPER

# WhisperX Configuration
WHISPER_MODEL=medium
WHISPER_DEVICE=cpu

# Gemini API Configuration
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-1.5-pro

# Cache Configuration
CACHE_DIR=./cache
CACHE_RETENTION_DAYS=30

# Queue Configuration
MAX_QUEUE_SIZE=100

# FFmpeg Configuration
SILENCE_NOISE=-35dB
SILENCE_DURATION=0.3

# yt-dlp Configuration
AUDIO_FORMAT=wav
AUDIO_SAMPLE_RATE=16000
AUDIO_CHANNELS=1
EOF

echo ""
echo ".env file created successfully."
echo ""
echo "⚠️  IMPORTANT: You need to add your Gemini API key!"
echo ""
echo "Edit .env and replace 'your_gemini_api_key_here' with your actual Gemini API key."
echo ""
echo "Get your Gemini API key from: https://aistudio.google.com/"
echo ""
echo "To edit .env:"
echo "  nano .env"
echo ""
echo "After editing, start the server:"
echo "  source venv/bin/activate"
echo "  python main.py"
