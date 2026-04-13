"""
Spotify Lyrics API integration for AMLyricsBTW.
Fetches lyrics from Spotify using the spotify-lyrics-api approach.
"""
import aiohttp
import asyncio
from typing import Optional, Dict, Any, List
from dataclasses import dataclass


@dataclass
class SpotifyLyricsLine:
    startTimeMs: int
    words: str
    syllables: List[Dict[str, Any]]
    endTimeMs: Optional[int] = None


@dataclass
class SpotifyLyricsResponse:
    lyrics: Dict[str, Any]
    colors: Dict[str, Any]
    hasVocalRemoval: bool
    lines: List[SpotifyLyricsLine]


class SpotifyLyricsClient:
    """Client for fetching lyrics from Spotify."""
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.base_url = "https://spotify-lyrics-api.akashrchandran.vercel.app"
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def get_lyrics_by_track_id(self, track_id: str) -> Optional[SpotifyLyricsResponse]:
        """Fetch lyrics by Spotify track ID."""
        if not self.session:
            self.session = aiohttp.ClientSession()
        
        url = f"{self.base_url}/?trackid={track_id}"
        
        try:
            async with self.session.get(url) as response:
                if response.status != 200:
                    return None
                
                data = await response.json()
                return self._parse_response(data)
        except Exception as e:
            print(f"Error fetching lyrics: {e}")
            return None
    
    async def search_and_get_lyrics(self, title: str, artist: str) -> Optional[SpotifyLyricsResponse]:
        """Search for a track and fetch its lyrics."""
        # First, search for the track using Spotify's search
        # Note: This requires a separate search endpoint
        # For now, we'll use the query parameter approach
        
        query = f"{title} {artist}"
        
        # Try to get lyrics using search query
        # The API might support ?q= parameter for search
        if not self.session:
            self.session = aiohttp.ClientSession()
        
        # Try with search query parameter
        url = f"{self.base_url}/?q={query}"
        
        try:
            async with self.session.get(url) as response:
                if response.status != 200:
                    # Try alternative endpoint
                    url = f"{self.base_url}/?track={title}&artist={artist}"
                    async with self.session.get(url) as alt_response:
                        if alt_response.status != 200:
                            return None
                        data = await alt_response.json()
                        return self._parse_response(data)
                
                data = await response.json()
                return self._parse_response(data)
        except Exception as e:
            print(f"Error searching lyrics: {e}")
            return None
    
    def _parse_response(self, data: Dict[str, Any]) -> Optional[SpotifyLyricsResponse]:
        """Parse the API response into SpotifyLyricsResponse."""
        if not data or "lines" not in data:
            return None
        
        lines = []
        for line_data in data.get("lines", []):
            line = SpotifyLyricsLine(
                startTimeMs=line_data.get("startTimeMs", 0),
                words=line_data.get("words", ""),
                syllables=line_data.get("syllables", []),
                endTimeMs=line_data.get("endTimeMs")
            )
            lines.append(line)
        
        return SpotifyLyricsResponse(
            lyrics=data.get("lyrics", {}),
            colors=data.get("colors", {}),
            hasVocalRemoval=data.get("hasVocalRemoval", False),
            lines=lines
        )


# Singleton instance
spotify_lyrics_client = SpotifyLyricsClient()
