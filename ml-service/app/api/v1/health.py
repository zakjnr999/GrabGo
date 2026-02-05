"""
Health check endpoints.
"""
from datetime import datetime

from fastapi import APIRouter, status
from sqlalchemy import text

from app.db import mongodb, postgres, redis

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    Health check endpoint.
    
    Returns service status and component health.
    """
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "components": {}
    }
    
    # Check PostgreSQL
    try:
        async with postgres.AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        health_status["components"]["postgres"] = "healthy"
    except Exception as e:
        health_status["components"]["postgres"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Check MongoDB
    try:
        db = mongodb.get_db()
        await db.command('ping')
        health_status["components"]["mongodb"] = "healthy"
    except Exception as e:
        health_status["components"]["mongodb"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    # Check Redis
    try:
        redis_client = redis.get_redis()
        await redis_client.ping()
        health_status["components"]["redis"] = "healthy"
    except Exception as e:
        health_status["components"]["redis"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    return health_status


@router.get("/health/ready", status_code=status.HTTP_200_OK)
async def readiness_check():
    """
    Readiness check for Kubernetes.
    
    Returns 200 if service is ready to accept traffic.
    """
    return {"status": "ready"}


@router.get("/health/live", status_code=status.HTTP_200_OK)
async def liveness_check():
    """
    Liveness check for Kubernetes.
    
    Returns 200 if service is alive.
    """
    return {"status": "alive"}
