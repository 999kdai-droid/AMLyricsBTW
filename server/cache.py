"""
Cache management for lyrics data.
"""
import json
import os
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from .config import config

class CacheManager:
    def __init__(self):
        self.cache_dir = Path(config.CACHE_DIR)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
    
    def get_cache_path(self, track_id: str) -> Path:
        """Get the cache file path for a track."""
        return self.cache_dir / f"{track_id}.json"
    
    def get(self, track_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve cached lyrics for a track.
        Returns None if cache doesn't exist or is expired.
        """
        cache_path = self.get_cache_path(track_id)
        
        if not cache_path.exists():
            return None
        
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Check if cache is expired
            cached_at = datetime.fromisoformat(data.get('cached_at', ''))
            if datetime.now() - cached_at > timedelta(days=config.CACHE_RETENTION_DAYS):
                self.delete(track_id)
                return None
            
            return data
        except (json.JSONDecodeError, ValueError, KeyError):
            # Invalid cache file, delete it
            self.delete(track_id)
            return None
    
    def set(self, track_id: str, data: Dict[str, Any]) -> None:
        """
        Cache lyrics data for a track.
        """
        cache_path = self.get_cache_path(track_id)
        
        # Add cache timestamp
        data['cached_at'] = datetime.now().isoformat()
        
        with open(cache_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    
    def delete(self, track_id: str) -> None:
        """
        Delete cache for a track.
        """
        cache_path = self.get_cache_path(track_id)
        if cache_path.exists():
            cache_path.unlink()
    
    def cleanup_old_cache(self) -> int:
        """
        Delete all cache entries older than CACHE_RETENTION_DAYS.
        Returns the number of deleted files.
        """
        deleted_count = 0
        cutoff_date = datetime.now() - timedelta(days=config.CACHE_RETENTION_DAYS)
        
        for cache_file in self.cache_dir.glob("*.json"):
            try:
                with open(cache_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                cached_at = datetime.fromisoformat(data.get('cached_at', ''))
                if cached_at < cutoff_date:
                    cache_file.unlink()
                    deleted_count += 1
            except (json.JSONDecodeError, ValueError, KeyError):
                # Invalid cache file, delete it
                cache_file.unlink()
                deleted_count += 1
        
        return deleted_count

cache_manager = CacheManager()
