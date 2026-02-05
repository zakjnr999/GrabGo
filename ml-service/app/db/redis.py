"""
Redis connection for caching.
"""
from typing import Any, Optional

import orjson
from redis import asyncio as aioredis

from app.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Global Redis client
_redis: Optional[aioredis.Redis] = None


async def init_redis():
    """Initialize Redis connection."""
    global _redis
    
    try:
        _redis = await aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=False,
            max_connections=50,
        )
        
        # Test connection
        await _redis.ping()
        
        logger.info("Redis connection established", url=settings.REDIS_HOST)
    except Exception as e:
        logger.error("Failed to connect to Redis", error=str(e))
        raise


async def close_redis():
    """Close Redis connection."""
    global _redis
    
    if _redis:
        await _redis.close()
        logger.info("Redis connection closed")


def get_redis() -> aioredis.Redis:
    """Get Redis client instance."""
    if _redis is None:
        raise RuntimeError("Redis not initialized. Call init_redis() first.")
    return _redis


async def get_cached(key: str) -> Optional[Any]:
    """Get value from cache."""
    redis = get_redis()
    
    try:
        value = await redis.get(key)
        if value:
            return orjson.loads(value)
        return None
    except Exception as e:
        logger.warning("Cache get failed", key=key, error=str(e))
        return None


async def set_cached(key: str, value: Any, ttl: int = 300) -> bool:
    """Set value in cache with TTL."""
    redis = get_redis()
    
    try:
        serialized = orjson.dumps(value)
        await redis.setex(key, ttl, serialized)
        return True
    except Exception as e:
        logger.warning("Cache set failed", key=key, error=str(e))
        return False


async def delete_cached(key: str) -> bool:
    """Delete value from cache."""
    redis = get_redis()
    
    try:
        await redis.delete(key)
        return True
    except Exception as e:
        logger.warning("Cache delete failed", key=key, error=str(e))
        return False


async def clear_cache_pattern(pattern: str) -> int:
    """Clear all keys matching pattern."""
    redis = get_redis()
    
    try:
        keys = await redis.keys(pattern)
        if keys:
            return await redis.delete(*keys)
        return 0
    except Exception as e:
        logger.warning("Cache clear failed", pattern=pattern, error=str(e))
        return 0
