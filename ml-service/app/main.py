"""
Main FastAPI application for GrabGo ML Service.
"""
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Histogram, make_asgi_app

from app.api.v1 import analytics, health, predictions, recommendations
from app.config import settings
from app.core.logging import get_logger
from app.db import mongodb, postgres, redis

logger = get_logger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info("Starting GrabGo ML Service", env=settings.ENV, version=settings.API_VERSION)
    
    # Initialize database connections
    await postgres.init_db()
    await mongodb.init_db()
    await redis.init_redis()
    
    logger.info("Database connections initialized")
    
    # Load ML models
    # TODO: Load pre-trained models from MODEL_DIR
    logger.info("ML models loaded", model_dir=settings.MODEL_DIR)
    
    yield
    
    # Shutdown
    logger.info("Shutting down GrabGo ML Service")
    
    # Close database connections
    await postgres.close_db()
    await mongodb.close_db()
    await redis.close_redis()
    
    logger.info("Database connections closed")


# Create FastAPI app
app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    description="Production-ready ML service for GrabGo delivery platform",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_ALLOW_CREDENTIALS,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request timing middleware
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    """Add request processing time header and metrics."""
    start_time = time.time()
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        response.headers["X-Process-Time"] = str(process_time)
        
        # Record metrics
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=response.status_code
        ).inc()
        
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(process_time)
        
        return response
    except Exception as e:
        logger.error("Request failed", error=str(e), path=request.url.path)
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status=500
        ).inc()
        raise


# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler."""
    logger.error(
        "Unhandled exception",
        error=str(exc),
        path=request.url.path,
        method=request.method,
        exc_info=True
    )
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "Internal server error",
            "error": str(exc) if settings.DEBUG else "An error occurred"
        }
    )


# Include routers
app.include_router(health.router, tags=["Health"])
app.include_router(
    recommendations.router,
    prefix=f"{settings.API_V1_PREFIX}/recommendations",
    tags=["Recommendations"]
)
app.include_router(
    predictions.router,
    prefix=f"{settings.API_V1_PREFIX}/predictions",
    tags=["Predictions"]
)
app.include_router(
    analytics.router,
    prefix=f"{settings.API_V1_PREFIX}/analytics",
    tags=["Analytics"]
)

# Mount Prometheus metrics
if settings.ENABLE_METRICS:
    metrics_app = make_asgi_app()
    app.mount("/metrics", metrics_app)


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": settings.API_TITLE,
        "version": settings.API_VERSION,
        "status": "running",
        "docs": "/docs" if settings.DEBUG else "disabled",
        "health": "/health"
    }


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.RELOAD,
        workers=settings.WORKERS if not settings.RELOAD else 1,
        log_level=settings.LOG_LEVEL.lower()
    )
