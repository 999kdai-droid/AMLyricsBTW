"""
Job queue management for serial processing of lyrics analysis.
"""
import asyncio
import uuid
from typing import Dict, Any, Optional
from dataclasses import dataclass, field
from datetime import datetime
from .analyzer import analyze_track
from .translator import translate_lyrics
from .cache import cache_manager
from .config import config

@dataclass
class Job:
    job_id: str
    track_id: str
    title: str
    artist: str
    is_favorite: bool
    status: str = "queued"  # queued, processing, done, error
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

class QueueManager:
    def __init__(self):
        self.queue: asyncio.Queue = asyncio.Queue(maxsize=config.MAX_QUEUE_SIZE)
        self.jobs: Dict[str, Job] = {}
        self.lock = asyncio.Lock()
        self._worker_task: Optional[asyncio.Task] = None
    
    async def start(self):
        """Start the background worker."""
        if self._worker_task is None:
            self._worker_task = asyncio.create_task(self._worker())
    
    async def stop(self):
        """Stop the background worker."""
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass
            self._worker_task = None
    
    async def _worker(self):
        """Background worker that processes jobs serially."""
        while True:
            try:
                job = await self.queue.get()
                await self._process_job(job)
                self.queue.task_done()
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Worker error: {e}")
    
    async def _process_job(self, job: Job) -> None:
        """Process a single job."""
        async with self.lock:
            job.status = "processing"
            job.updated_at = datetime.now()
        
        try:
            # Check cache first
            cached = cache_manager.get(job.track_id)
            if cached:
                async with self.lock:
                    job.status = "done"
                    job.result = cached
                    job.updated_at = datetime.now()
                return
            
            # Analyze track
            lyrics_data = await analyze_track(
                title=job.title,
                artist=job.artist,
                is_favorite=job.is_favorite
            )
            
            # Add track metadata
            lyrics_data['track_id'] = job.track_id
            lyrics_data['title'] = job.title
            lyrics_data['artist'] = job.artist
            
            # Translate lyrics
            if lyrics_data.get('lyrics'):
                texts = [line['text'] for line in lyrics_data['lyrics']]
                translations = await translate_lyrics(texts)
                
                for i, line in enumerate(lyrics_data['lyrics']):
                    if i < len(translations):
                        line['translation'] = translations[i]
            
            # Cache the result
            cache_manager.set(job.track_id, lyrics_data)
            
            async with self.lock:
                job.status = "done"
                job.result = lyrics_data
                job.updated_at = datetime.now()
        
        except Exception as e:
            async with self.lock:
                job.status = "error"
                job.error = str(e)
                job.updated_at = datetime.now()
    
    async def enqueue(self, track_id: str, title: str, artist: str, is_favorite: bool) -> str:
        """Enqueue a new job and return the job ID."""
        job_id = str(uuid.uuid4())
        job = Job(
            job_id=job_id,
            track_id=track_id,
            title=title,
            artist=artist,
            is_favorite=is_favorite
        )
        
        async with self.lock:
            self.jobs[job_id] = job
        
        await self.queue.put(job)
        return job_id
    
    async def get_job_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get the status of a job."""
        async with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                return None
            
            return {
                "job_id": job.job_id,
                "status": job.status,
                "result": job.result if job.status == "done" else None,
                "error": job.error,
                "created_at": job.created_at.isoformat(),
                "updated_at": job.updated_at.isoformat()
            }
    
    async def get_queue_status(self) -> Dict[str, Any]:
        """Get the current queue status."""
        async with self.lock:
            queued_count = self.queue.qsize()
            processing_jobs = [j for j in self.jobs.values() if j.status == "processing"]
            
            return {
                "queued": queued_count,
                "processing": [
                    {
                        "job_id": j.job_id,
                        "track_id": j.track_id,
                        "title": j.title,
                        "artist": j.artist
                    }
                    for j in processing_jobs
                ],
                "total_jobs": len(self.jobs)
            }

queue_manager = QueueManager()
