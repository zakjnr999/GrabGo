"""
PostgreSQL database connection using SQLAlchemy async.
"""
from typing import AsyncGenerator
import ssl

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Clean DATABASE_URL (remove sslmode parameter if present)
database_url = settings.DATABASE_URL
if "?" in database_url:
    # Remove query parameters like sslmode
    base_url = database_url.split("?")[0]
else:
    base_url = database_url

# Create async engine with SSL support for Supabase
engine = create_async_engine(
    base_url,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    connect_args={
        "ssl": "require",  # For Supabase SSL connections
        "server_settings": {
            "application_name": "grabgo_ml_service"
        }
    }
)

# Create async session factory
AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# Base class for models
Base = declarative_base()


async def init_db():
    """Initialize database connection."""
    try:
        async with engine.begin() as conn:
            # Test connection
            await conn.execute("SELECT 1")
        logger.info("PostgreSQL connection established", url=settings.POSTGRES_HOST)
    except Exception as e:
        logger.error("Failed to connect to PostgreSQL", error=str(e))
        raise


async def close_db():
    """Close database connection."""
    await engine.dispose()
    logger.info("PostgreSQL connection closed")


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Get database session dependency."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
