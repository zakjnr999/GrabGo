"""
Security utilities for authentication and authorization.
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Security schemes
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
bearer_scheme = HTTPBearer(auto_error=False)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=24)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
    
    return encoded_jwt


def decode_access_token(token: str) -> dict:
    """Decode and verify a JWT access token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def verify_api_key(api_key: str = Security(api_key_header)) -> str:
    """Verify API key from header."""
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key is required",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    
    if api_key != settings.API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    
    return api_key


async def verify_bearer_token(
    credentials: HTTPAuthorizationCredentials = Security(bearer_scheme)
) -> dict:
    """Verify JWT bearer token."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token is required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return decode_access_token(credentials.credentials)


# Dependency for API key authentication
async def get_api_key(api_key: str = Depends(verify_api_key)) -> str:
    """Get and verify API key dependency."""
    return api_key


# Dependency for JWT authentication
async def get_current_user(token_data: dict = Depends(verify_bearer_token)) -> dict:
    """Get current user from JWT token dependency."""
    return token_data
