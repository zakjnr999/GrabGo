# GrabGo ML AI Service

Production-ready Machine Learning service for GrabGo platform, built with Python and FastAPI.

## Features

### 1. **Smart Recommendations**
- Personalized food/restaurant recommendations
- Collaborative filtering + content-based filtering
- Real-time recommendation updates
- Cold-start handling for new users

### 2. **Demand Forecasting**
- Predict order volume by time/location
- Dynamic pricing suggestions
- Restaurant capacity planning
- Rider availability optimization

### 3. **Delivery Time Prediction**
- Accurate ETA estimation using ML
- Factors: traffic, weather, restaurant prep time, rider performance
- Real-time ETA updates during delivery

### 4. **Fraud Detection**
- Anomaly detection for suspicious orders
- User behavior analysis
- Payment fraud detection
- Fake review detection

### 5. **Customer Churn Prediction**
- Identify at-risk customers
- Trigger retention campaigns
- Personalized re-engagement strategies

### 6. **Sentiment Analysis**
- Analyze customer reviews
- Chat message sentiment
- Auto-categorize complaints
- Priority routing for negative sentiment

## Tech Stack

- **Framework**: FastAPI
- **ML Libraries**: scikit-learn, TensorFlow/PyTorch, XGBoost
- **Data Processing**: pandas, numpy
- **Database**: PostgreSQL (via SQLAlchemy), MongoDB (via motor)
- **Caching**: Redis
- **API Documentation**: OpenAPI/Swagger (auto-generated)
- **Monitoring**: Prometheus + Grafana
- **Logging**: structlog
- **Testing**: pytest
- **Deployment**: Docker, Kubernetes-ready

## Project Structure

```
ml-service/
├── app/
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py               # Configuration management
│   ├── dependencies.py         # Dependency injection
│   │
│   ├── api/                    # API routes
│   │   ├── v1/
│   │   │   ├── recommendations.py
│   │   │   ├── predictions.py
│   │   │   ├── analytics.py
│   │   │   └── health.py
│   │
│   ├── models/                 # ML models
│   │   ├── recommendation/
│   │   │   ├── collaborative_filter.py
│   │   │   ├── content_based.py
│   │   │   └── hybrid.py
│   │   ├── forecasting/
│   │   │   ├── demand_predictor.py
│   │   │   └── eta_predictor.py
│   │   ├── fraud/
│   │   │   └── anomaly_detector.py
│   │   └── sentiment/
│   │       └── analyzer.py
│   │
│   ├── services/               # Business logic
│   │   ├── recommendation_service.py
│   │   ├── prediction_service.py
│   │   ├── fraud_service.py
│   │   └── analytics_service.py
│   │
│   ├── db/                     # Database connections
│   │   ├── postgres.py
│   │   ├── mongodb.py
│   │   └── redis.py
│   │
│   ├── schemas/                # Pydantic models
│   │   ├── recommendation.py
│   │   ├── prediction.py
│   │   └── analytics.py
│   │
│   ├── core/                   # Core utilities
│   │   ├── security.py
│   │   ├── logging.py
│   │   └── metrics.py
│   │
│   └── utils/                  # Helper functions
│       ├── data_loader.py
│       ├── feature_engineering.py
│       └── model_utils.py
│
├── ml_models/                  # Trained model artifacts
│   ├── recommendation/
│   ├── forecasting/
│   └── fraud/
│
├── notebooks/                  # Jupyter notebooks for experimentation
│   ├── 01_data_exploration.ipynb
│   ├── 02_recommendation_model.ipynb
│   └── 03_demand_forecasting.ipynb
│
├── scripts/                    # Utility scripts
│   ├── train_models.py
│   ├── evaluate_models.py
│   └── data_sync.py
│
├── tests/                      # Test suite
│   ├── test_api/
│   ├── test_models/
│   └── test_services/
│
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── requirements.txt
├── requirements-dev.txt
├── .env.example
├── .dockerignore
└── README.md
```

## Installation

### Prerequisites
- Python 3.10+
- PostgreSQL 14+
- MongoDB 6+
- Redis 7+

### Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env
# Edit .env with your configuration

# Run database migrations (if needed)
alembic upgrade head

# Train initial models
python scripts/train_models.py

# Start development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

### Recommendations
- `POST /api/v1/recommendations/food` - Get personalized food recommendations
- `POST /api/v1/recommendations/restaurants` - Get restaurant recommendations
- `POST /api/v1/recommendations/similar-items` - Find similar items

### Predictions
- `POST /api/v1/predictions/delivery-time` - Predict delivery ETA
- `POST /api/v1/predictions/demand` - Forecast demand
- `POST /api/v1/predictions/churn` - Predict customer churn risk

### Fraud Detection
- `POST /api/v1/fraud/check-order` - Check order for fraud
- `POST /api/v1/fraud/check-user` - Analyze user behavior

### Analytics
- `GET /api/v1/analytics/insights` - Get business insights
- `POST /api/v1/analytics/sentiment` - Analyze sentiment

### Health
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

## Integration with Node.js Backend

The ML service integrates with your existing Node.js backend via REST API:

```javascript
// In your Node.js backend
const axios = require('axios');

// Get recommendations
const recommendations = await axios.post('http://ml-service:8000/api/v1/recommendations/food', {
  userId: 'user123',
  limit: 10,
  context: {
    time: 'dinner',
    location: { lat: 5.6037, lon: -0.187 }
  }
}, {
  headers: {
    'Authorization': `Bearer ${ML_SERVICE_API_KEY}`
  }
});

// Predict delivery time
const eta = await axios.post('http://ml-service:8000/api/v1/predictions/delivery-time', {
  orderId: 'order123',
  restaurantLocation: { lat: 5.6037, lon: -0.187 },
  deliveryLocation: { lat: 5.6100, lon: -0.190 },
  riderId: 'rider123'
});
```

## Model Training

Models are trained using historical data from your PostgreSQL and MongoDB databases:

```bash
# Train all models
python scripts/train_models.py --all

# Train specific model
python scripts/train_models.py --model recommendation

# Evaluate models
python scripts/evaluate_models.py
```

## Deployment

### Docker

```bash
# Build image
docker build -t grabgo-ml-service -f docker/Dockerfile .

# Run container
docker-compose up -d
```

### Production Deployment

The service is production-ready with:
- Health checks
- Graceful shutdown
- Request validation
- Rate limiting
- API authentication
- Monitoring and metrics
- Structured logging
- Error handling

## Performance

- **Response Time**: < 100ms for recommendations
- **Throughput**: 1000+ requests/second
- **Model Update**: Real-time incremental learning
- **Caching**: Redis for frequently accessed predictions

## Monitoring

Access metrics at `/metrics` endpoint for Prometheus scraping.

Key metrics:
- Request latency
- Model inference time
- Cache hit rate
- Error rate
- Model accuracy

## Security

- JWT authentication
- API key validation
- Rate limiting
- Input validation
- SQL injection prevention
- CORS configuration

## License

Proprietary - All rights reserved
