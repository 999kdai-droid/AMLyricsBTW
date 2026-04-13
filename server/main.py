"""
FastAPI server for AMLyricsBTW.
Provides endpoints for lyrics analysis, caching, and queue management.
"""
from fastapi import FastAPI, HTTPException, Header, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import uvicorn

from .config import config
from .queue_manager import queue_manager
from .cache import cache_manager
from .spotify_lyrics import spotify_lyrics_client

app = FastAPI(title="AMLyricsBTW API")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request/Response Models
class AnalyzeRequest(BaseModel):
    track_id: str
    title: str
    artist: str
    is_favorite: bool = False

class JobResponse(BaseModel):
    job_id: str
    status: str

class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: str
    updated_at: str

class QueueStatusResponse(BaseModel):
    queued: int
    processing: list
    total_jobs: int

class SpotifyLyricsRequest(BaseModel):
    title: str
    artist: str

class SpotifyLyricsLine(BaseModel):
    startTimeMs: int
    words: str

class SpotifyLyricsResponse(BaseModel):
    lines: list
    title: str
    artist: str

# API Key Authentication Middleware
async def verify_api_key(x_api_key: Optional[str] = Header(None)):
    """Verify X-API-Key header."""
    if x_api_key is None:
        raise HTTPException(status_code=401, detail="X-API-Key header is missing")
    
    if x_api_key != config.API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")

# Apply auth to all endpoints
@app.middleware("http")
async def auth_middleware(request, call_next):
    """Apply API key authentication to all endpoints except health check."""
    if request.url.path == "/health":
        return await call_next(request)
    
    x_api_key = request.headers.get("X-API-Key")
    if x_api_key is None:
        raise HTTPException(status_code=401, detail="X-API-Key header is missing")
    
    if x_api_key != config.API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")
    
    response = await call_next(request)
    return response

# Endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint (no auth required)."""
    return {"status": "ok"}

@app.post("/analyze", response_model=JobResponse)
async def analyze(request: AnalyzeRequest, background_tasks: BackgroundTasks):
    """
    Submit a track for lyrics analysis.
    Returns a job ID for tracking.
    """
    job_id = await queue_manager.enqueue(
        track_id=request.track_id,
        title=request.title,
        artist=request.artist,
        is_favorite=request.is_favorite
    )
    
    return JobResponse(job_id=job_id, status="queued")

@app.get("/status/{job_id}", response_model=JobStatusResponse)
async def get_status(job_id: str):
    """
    Get the status of an analysis job.
    """
    status = await queue_manager.get_job_status(job_id)
    
    if status is None:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return JobStatusResponse(**status)

@app.get("/cache/{track_id}")
async def get_cached_lyrics(track_id: str):
    """
    Get cached lyrics for a track.
    Returns 404 if not cached.
    """
    cached = cache_manager.get(track_id)
    
    if cached is None:
        raise HTTPException(status_code=404, detail="Lyrics not cached")
    
    return cached

@app.get("/queue", response_model=QueueStatusResponse)
async def get_queue_status():
    """
    Get the current queue status.
    """
    status = await queue_manager.get_queue_status()
    return QueueStatusResponse(**status)

@app.post("/spotify-lyrics", response_model=SpotifyLyricsResponse)
async def get_spotify_lyrics(request: SpotifyLyricsRequest):
    """
    Fetch lyrics from Spotify for a given track.
    """
    async with spotify_lyrics_client as client:
        result = await client.search_and_get_lyrics(
            title=request.title,
            artist=request.artist
        )
        
        if result is None or not result.lines:
            raise HTTPException(status_code=404, detail="Lyrics not found")
        
        return SpotifyLyricsResponse(
            lines=[{"startTimeMs": line.startTimeMs, "words": line.words} for line in result.lines],
            title=request.title,
            artist=request.artist
        )

@app.on_event("startup")
async def startup_event():
    """Start the queue worker on startup."""
    await queue_manager.start()

@app.on_event("shutdown")
async def shutdown_event():
    """Stop the queue worker on shutdown."""
    await queue_manager.stop()

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False
    )
