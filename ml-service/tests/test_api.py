"""
Test suite for ML service endpoints.
"""
import pytest
from httpx import AsyncClient

from app.main import app


@pytest.fixture
async def client():
    """Create test client."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def api_key():
    """API key for testing."""
    return "test-api-key"


@pytest.mark.asyncio
async def test_health_check(client):
    """Test health check endpoint."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert "components" in data


@pytest.mark.asyncio
async def test_food_recommendations(client, api_key):
    """Test food recommendations endpoint."""
    response = await client.post(
        "/api/v1/recommendations/food",
        json={
            "user_id": "test-user-123",
            "limit": 10
        },
        headers={"X-API-Key": api_key}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "data" in data
    assert isinstance(data["data"], list)


@pytest.mark.asyncio
async def test_delivery_time_prediction(client, api_key):
    """Test delivery time prediction endpoint."""
    response = await client.post(
        "/api/v1/predictions/delivery-time",
        json={
            "restaurant_location": {
                "latitude": 5.6037,
                "longitude": -0.187
            },
            "delivery_location": {
                "latitude": 5.6100,
                "longitude": -0.190
            },
            "preparation_time": 15
        },
        headers={"X-API-Key": api_key}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "estimated_minutes" in data
    assert "confidence" in data


@pytest.mark.asyncio
async def test_sentiment_analysis(client, api_key):
    """Test sentiment analysis endpoint."""
    response = await client.post(
        "/api/v1/analytics/sentiment",
        json={
            "text": "The food was amazing and delivery was fast!",
            "context": "review"
        },
        headers={"X-API-Key": api_key}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "sentiment" in data
    assert data["sentiment"] in ["positive", "negative", "neutral"]


@pytest.mark.asyncio
async def test_fraud_check(client, api_key):
    """Test fraud detection endpoint."""
    response = await client.post(
        "/api/v1/analytics/fraud-check",
        json={
            "user_id": "test-user-123",
            "order_data": {
                "total_amount": 50.0,
                "items_count": 3
            }
        },
        headers={"X-API-Key": api_key}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "is_suspicious" in data
    assert "risk_score" in data


@pytest.mark.asyncio
async def test_unauthorized_access(client):
    """Test API without authentication."""
    response = await client.post(
        "/api/v1/recommendations/food",
        json={"user_id": "test-user-123", "limit": 10}
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_invalid_request(client, api_key):
    """Test with invalid request data."""
    response = await client.post(
        "/api/v1/recommendations/food",
        json={
            "user_id": "test-user-123",
            "limit": 1000  # Exceeds max limit
        },
        headers={"X-API-Key": api_key}
    )
    assert response.status_code == 422  # Validation error
