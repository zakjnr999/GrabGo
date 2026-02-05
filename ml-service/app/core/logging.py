"""
Structured logging configuration.
"""
import logging
import sys
from typing import Any

import structlog

from app.config import settings


def get_logger(name: str) -> structlog.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def configure_logging():
    """Configure structured logging."""
    
    # Determine log level
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
    
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer() if settings.LOG_FORMAT == "json"
            else structlog.dev.ConsoleRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure standard logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )


# Configure on import
configure_logging()
