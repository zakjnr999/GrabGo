"""
Configuration management for GrabGo ML Service.
"""
from functools import lru_cache
from typing import List, Optional

from pydantic import Field, validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    # Environment
    ENV: str = Field(default="development", description="Environment: development, staging, production")
    DEBUG: bool = Field(default=False, description="Debug mode")

    # API
    API_V1_PREFIX: str = Field(default="/api/v1", description="API v1 prefix")
    API_TITLE: str = Field(default="GrabGo ML Service", description="API title")
    API_VERSION: str = Field(default="1.0.0", description="API version")
    SECRET_KEY: str = Field(..., description="Secret key for JWT")
    API_KEY: str = Field(..., description="API key for backend integration")

    # Server
    HOST: str = Field(default="0.0.0.0", description="Server host")
    PORT: int = Field(default=8000, description="Server port")
    WORKERS: int = Field(default=4, description="Number of workers")
    RELOAD: bool = Field(default=False, description="Auto-reload on code changes")

    # PostgreSQL
    POSTGRES_HOST: str = Field(default="localhost", description="PostgreSQL host")
    POSTGRES_PORT: int = Field(default=5432, description="PostgreSQL port")
    POSTGRES_DB: str = Field(default="grabgo", description="PostgreSQL database")
    POSTGRES_USER: str = Field(default="postgres", description="PostgreSQL user")
    POSTGRES_PASSWORD: str = Field(..., description="PostgreSQL password")
    DATABASE_URL: Optional[str] = Field(default=None, description="Full database URL")

    @validator("DATABASE_URL", pre=True, always=True)
    def assemble_db_url(cls, v: Optional[str], values: dict) -> str:
        """Assemble database URL if not provided."""
        if v:
            return v
        return (
            f"postgresql+asyncpg://{values.get('POSTGRES_USER')}:"
            f"{values.get('POSTGRES_PASSWORD')}@{values.get('POSTGRES_HOST')}:"
            f"{values.get('POSTGRES_PORT')}/{values.get('POSTGRES_DB')}"
        )

    # MongoDB
    MONGODB_URL: str = Field(default="mongodb://localhost:27017", description="MongoDB URL")
    MONGODB_DB: str = Field(default="grabgo", description="MongoDB database")

    # Redis
    REDIS_HOST: str = Field(default="localhost", description="Redis host")
    REDIS_PORT: int = Field(default=6379, description="Redis port")
    REDIS_DB: int = Field(default=0, description="Redis database")
    REDIS_PASSWORD: Optional[str] = Field(default=None, description="Redis password")
    REDIS_URL: Optional[str] = Field(default=None, description="Full Redis URL")

    @validator("REDIS_URL", pre=True, always=True)
    def assemble_redis_url(cls, v: Optional[str], values: dict) -> str:
        """Assemble Redis URL if not provided."""
        if v:
            return v
        password = values.get("REDIS_PASSWORD")
        if password:
            return (
                f"redis://:{password}@{values.get('REDIS_HOST')}:"
                f"{values.get('REDIS_PORT')}/{values.get('REDIS_DB')}"
            )
        return (
            f"redis://{values.get('REDIS_HOST')}:"
            f"{values.get('REDIS_PORT')}/{values.get('REDIS_DB')}"
        )

    # Model Settings
    MODEL_DIR: str = Field(default="./ml_models", description="Model directory")
    MODEL_UPDATE_INTERVAL: int = Field(default=3600, description="Model update interval in seconds")
    RECOMMENDATION_CACHE_TTL: int = Field(default=300, description="Recommendation cache TTL in seconds")
    PREDICTION_CACHE_TTL: int = Field(default=60, description="Prediction cache TTL in seconds")

    # Feature Flags
    ENABLE_RECOMMENDATIONS: bool = Field(default=True, description="Enable recommendations")
    ENABLE_FRAUD_DETECTION: bool = Field(default=True, description="Enable fraud detection")
    ENABLE_DEMAND_FORECASTING: bool = Field(default=True, description="Enable demand forecasting")
    ENABLE_SENTIMENT_ANALYSIS: bool = Field(default=True, description="Enable sentiment analysis")

    # Logging
    LOG_LEVEL: str = Field(default="INFO", description="Log level")
    LOG_FORMAT: str = Field(default="json", description="Log format: json or text")

    # Monitoring
    ENABLE_METRICS: bool = Field(default=True, description="Enable Prometheus metrics")
    METRICS_PORT: int = Field(default=9090, description="Metrics port")

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = Field(default=True, description="Enable rate limiting")
    RATE_LIMIT_PER_MINUTE: int = Field(default=60, description="Rate limit per minute")

    # CORS
    CORS_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:5000"],
        description="CORS allowed origins"
    )
    CORS_ALLOW_CREDENTIALS: bool = Field(default=True, description="CORS allow credentials")

    @validator("CORS_ORIGINS", pre=True)
    def parse_cors_origins(cls, v):
        """Parse CORS origins from string or list."""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v

    # ML Model Hyperparameters
    RECOMMENDATION_TOP_N: int = Field(default=10, description="Top N recommendations")
    RECOMMENDATION_MIN_SCORE: float = Field(default=0.3, description="Minimum recommendation score")
    FRAUD_THRESHOLD: float = Field(default=0.7, description="Fraud detection threshold")
    CHURN_THRESHOLD: float = Field(default=0.6, description="Churn prediction threshold")

    # External Services
    GOOGLE_MAPS_API_KEY: Optional[str] = Field(default=None, description="Google Maps API key")
    WEATHER_API_KEY: Optional[str] = Field(default=None, description="Weather API key")

    # Node.js Backend Integration
    BACKEND_URL: str = Field(default="http://localhost:5000", description="Backend URL")
    BACKEND_API_KEY: Optional[str] = Field(default=None, description="Backend API key")

    class Config:
        """Pydantic config."""
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Export settings instance
settings = get_settings()
