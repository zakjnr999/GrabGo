"""
MongoDB database connection using Motor (async).
"""
from typing import Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Global MongoDB client
_client: Optional[AsyncIOMotorClient] = None
_db: Optional[AsyncIOMotorDatabase] = None


async def init_db():
    """Initialize MongoDB connection."""
    global _client, _db
    
    try:
        _client = AsyncIOMotorClient(settings.MONGODB_URL)
        _db = _client[settings.MONGODB_DB]
        
        # Test connection
        await _client.admin.command('ping')
        
        logger.info("MongoDB connection established", db=settings.MONGODB_DB)
    except Exception as e:
        logger.error("Failed to connect to MongoDB", error=str(e))
        raise


async def close_db():
    """Close MongoDB connection."""
    global _client
    
    if _client:
        _client.close()
        logger.info("MongoDB connection closed")


def get_db() -> AsyncIOMotorDatabase:
    """Get MongoDB database instance."""
    if _db is None:
        raise RuntimeError("MongoDB not initialized. Call init_db() first.")
    return _db


def get_collection(name: str):
    """Get MongoDB collection."""
    db = get_db()
    return db[name]
