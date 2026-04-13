"""
Audio analysis using WhisperX and ffmpeg for silence detection.
"""
import asyncio
import tempfile
import os
import subprocess
import json
from typing import Dict, Any, List, Optional
from pathlib import Path
import yt_dlp
import whisperx
from .config import config

async def download_audio(title: str, artist: str) -> str:
    """
    Download audio from YouTube using yt-dlp.
    Returns the path to the downloaded WAV file.
    """
    query = f"ytsearch1:{title} {artist} lyrics audio"
    
    ydl_opts = {
        'format': 'bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'extract_flat': False,
        'outtmpl': '%(id)s.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'wav',
            'preferredquality': '192',
        }],
        'postprocessor_args': [
            '-ar', str(config.AUDIO_SAMPLE_RATE),
            '-ac', str(config.AUDIO_CHANNELS)
        ]
    }
    
    with tempfile.TemporaryDirectory() as temp_dir:
        # Download in a thread to avoid blocking
        def _download():
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(query, download=True)
                return ydl.prepare_filename(info)
        
        filename = await asyncio.to_thread(_download)
        
        # Move to a permanent temp location
        temp_path = tempfile.mktemp(suffix='.wav', prefix='audio_')
        os.rename(filename, temp_path)
        
        return temp_path

async def detect_silence_offset(audio_path: str) -> float:
    """
    Detect silence at the beginning of the audio file using ffmpeg.
    Returns the silence_end value in seconds.
    """
    cmd = [
        'ffmpeg',
        '-i', audio_path,
        '-af', f'silencedetect=noise={config.SILENCE_NOISE}:duration={config.SILENCE_DURATION}',
        '-f', 'null',
        '-'
    ]
    
    def _run_ffmpeg():
        try:
            result = subprocess.run(
                cmd,
                stderr=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True
            )
            output = result.stderr
            
            # Parse silence_end from ffmpeg output
            for line in output.split('\n'):
                if 'silence_end' in line:
                    # Extract the value after "silence_end="
                    parts = line.split('silence_end=')
                    if len(parts) > 1:
                        value_str = parts[1].split()[0]
                        return float(value_str)
        except Exception as e:
            print(f"FFmpeg silence detection error: {e}")
        
        return 0.0
    
    return await asyncio.to_thread(_run_ffmpeg)

async def transcribe_with_whisperx(audio_path: str, is_favorite: bool) -> Dict[str, Any]:
    """
    Transcribe audio using WhisperX.
    Returns transcript with word-level timestamps if is_favorite is True.
    """
    def _transcribe():
        # Load audio
        audio = whisperx.load_audio(audio_path)
        
        # Transcribe
        model = whisperx.load_model(
            config.WHISPER_MODEL,
            device=config.WHISPER_DEVICE,
            compute_type="int8"  # Use int8 for CPU efficiency
        )
        
        result = model.transcribe(
            audio,
            batch_size=8  # Smaller batch for CPU
        )
        
        # Align timestamps
        model_a, metadata = whisperx.load_align_model(
            language_code=result["language"],
            device=config.WHISPER_DEVICE
        )
        result = whisperx.align(
            result,
            model_a,
            metadata,
            audio,
            device=config.WHISPER_DEVICE,
            return_char_alignments=False
        )
        
        # Get word timestamps only for favorite tracks
        if is_favorite:
            result = whisperx.align(
                result,
                model_a,
                metadata,
                audio,
                device=config.WHISPER_DEVICE,
                return_char_alignments=False
            )
        
        return result
    
    return await asyncio.to_thread(_transcribe)

def format_lyrics_data(whisper_result: Dict[str, Any], silence_offset: float, is_favorite: bool) -> List[Dict[str, Any]]:
    """
    Format WhisperX result into the lyrics data structure.
    """
    lyrics = []
    segments = whisper_result.get('segments', [])
    
    for i, segment in enumerate(segments):
        line = {
            "line_index": i,
            "start": max(0.0, segment['start'] - silence_offset),
            "end": max(0.0, segment['end'] - silence_offset),
            "text": segment['text'].strip(),
            "translation": "",  # Will be filled by translator
            "words": []
        }
        
        # Add word timestamps for favorite tracks
        if is_favorite and 'words' in segment:
            for word in segment['words']:
                line['words'].append({
                    "word": word['word'].strip(),
                    "start": max(0.0, word['start'] - silence_offset),
                    "end": max(0.0, word['end'] - silence_offset)
                })
        
        lyrics.append(line)
    
    return lyrics

async def analyze_track(title: str, artist: str, is_favorite: bool) -> Dict[str, Any]:
    """
    Full analysis pipeline: download audio, detect silence, transcribe with WhisperX.
    """
    audio_path = None
    
    try:
        # Download audio
        audio_path = await download_audio(title, artist)
        
        # Detect silence offset
        silence_offset = await detect_silence_offset(audio_path)
        
        # Transcribe with WhisperX
        whisper_result = await transcribe_with_whisperx(audio_path, is_favorite)
        
        # Format lyrics data
        lyrics = format_lyrics_data(whisper_result, silence_offset, is_favorite)
        
        return {
            "silence_offset": silence_offset,
            "lyrics": lyrics
        }
    
    finally:
        # Clean up temporary audio file
        if audio_path and os.path.exists(audio_path):
            os.unlink(audio_path)
