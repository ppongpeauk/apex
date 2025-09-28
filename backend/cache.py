"""Caching functionality for the backend using SQLite."""

import asyncio
import hashlib
import json
from pathlib import Path
from typing import Any, Dict, Optional

import aiosqlite


class Cache:
    """SQLite-based cache for storing Vega-Lite outputs."""

    def __init__(self, db_path: str = "cache.db"):
        self.db_path = Path(db_path)
        self._db: Optional[aiosqlite.Connection] = None

    async def __aenter__(self):
        await self._init_db()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def _init_db(self):
        """Initialize the SQLite database and create tables."""
        self._db = await aiosqlite.connect(self.db_path)
        await self._db.execute(
            """
            CREATE TABLE IF NOT EXISTS cache (
                file_hash TEXT PRIMARY KEY,
                vega_lite TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """
        )
        await self._db.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_created_at ON cache(created_at)
        """
        )
        await self._db.commit()

    async def close(self):
        """Close the database connection."""
        if self._db:
            await self._db.close()
            self._db = None

    def _hash_parquet_content(self, parquet_content: bytes) -> str:
        """Generate a SHA-256 hash of the Parquet content."""
        return hashlib.sha256(parquet_content).hexdigest()

    async def get(self, parquet_content: bytes) -> Optional[Dict[str, Any]]:
        """Get cached Vega-Lite output for the given Parquet content."""
        if not self._db:
            await self._init_db()

        parquet_hash = self._hash_parquet_content(parquet_content)

        async with self._db.execute(
            "SELECT vega_lite FROM cache WHERE file_hash = ?", (parquet_hash,)
        ) as cursor:
            row = await cursor.fetchone()

        if row:
            return json.loads(row[0])
        return None

    async def set(self, parquet_content: bytes, vega_lite: Dict[str, Any]):
        """Cache the Vega-Lite output for the given Parquet content."""
        if not self._db:
            await self._init_db()

        parquet_hash = self._hash_parquet_content(parquet_content)
        vega_lite_json = json.dumps(vega_lite)

        await self._db.execute(
            "INSERT OR REPLACE INTO cache (file_hash, vega_lite) VALUES (?, ?)",
            (parquet_hash, vega_lite_json),
        )
        await self._db.commit()

    async def clear_old_entries(self, days: int = 30):
        """Clear cache entries older than the specified number of days."""
        if not self._db:
            await self._init_db()

        await self._db.execute(
            "DELETE FROM cache WHERE created_at < datetime('now', '-' || ? || ' days')",
            (days,),
        )
        await self._db.commit()


# Global cache instance
_cache_instance: Optional[Cache] = None


async def get_cache() -> Cache:
    """Get the global cache instance."""
    global _cache_instance
    if _cache_instance is None:
        _cache_instance = Cache()
        await _cache_instance._init_db()
    return _cache_instance


def hash_parquet_content(parquet_content: bytes) -> str:
    """Generate a SHA-256 hash of the Parquet content."""
    return hashlib.sha256(parquet_content).hexdigest()
