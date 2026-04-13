"""
Configuration settings for AMLyricsBTW server.
"""
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # API Configuration
    API_KEY: str = os.getenv("AMLYRICS_API_KEY", "your_api_key_here")
    
    # WhisperX Configuration
    WHISPER_MODEL: str = os.getenv("WHISPER_MODEL", "medium")  # "small" or "medium"
    WHISPER_DEVICE: str = "cpu"  # iMac 2015 has no GPU
    
    # Gemini API Configuration
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = "gemini-1.5-pro"
    
    # Cache Configuration
    CACHE_DIR: str = os.getenv("CACHE_DIR", "./cache")
    CACHE_RETENTION_DAYS: int = 30
    
    # Queue Configuration
    MAX_QUEUE_SIZE: int = 100
    
    # FFmpeg Configuration
    SILENCE_NOISE: str = "-35dB"
    SILENCE_DURATION: float = 0.3
    
    # yt-dlp Configuration
    AUDIO_FORMAT: str = "wav"
    AUDIO_SAMPLE_RATE: int = 16000
    AUDIO_CHANNELS: int = 1  # mono

config = Config()
