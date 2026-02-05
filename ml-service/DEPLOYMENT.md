# GrabGo ML Service - Deployment Guide

## Production Deployment Checklist

### 1. Environment Configuration

```bash
# Copy and configure environment variables
cp .env.example .env

# Required variables:
# - SECRET_KEY: Generate with `openssl rand -hex 32`
# - API_KEY: Generate secure API key for backend integration
# - Database credentials (PostgreSQL, MongoDB, Redis)
# - External API keys (Google Maps, Weather, etc.)
```

### 2. Database Setup

```bash
# Ensure databases are accessible
# PostgreSQL: For relational data (users, orders, products)
# MongoDB: For NoSQL data (chats, analytics, logs)
# Redis: For caching

# Test connections
psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;"
mongo $MONGODB_URL --eval "db.adminCommand('ping')"
redis-cli -h $REDIS_HOST ping
```

### 3. Docker Deployment (Recommended)

```bash
# Build image
docker build -t grabgo-ml-service:latest .

# Run with docker-compose
docker-compose up -d

# Check logs
docker-compose logs -f ml-service

# Health check
curl http://localhost:8000/health
```

### 4. Manual Deployment

```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run with production server
gunicorn app.main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --access-logfile logs/access.log \
  --error-logfile logs/error.log
```

### 5. Kubernetes Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grabgo-ml-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: grabgo-ml-service
  template:
    metadata:
      labels:
        app: grabgo-ml-service
    spec:
      containers:
      - name: ml-service
        image: grabgo-ml-service:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENV
          value: "production"
        - name: POSTGRES_HOST
          valueFrom:
            secretKeyRef:
              name: ml-service-secrets
              key: postgres-host
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: grabgo-ml-service
spec:
  selector:
    app: grabgo-ml-service
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
```

### 6. Monitoring Setup

```bash
# Prometheus metrics available at /metrics
# Configure Prometheus scraping:

# prometheus.yml
scrape_configs:
  - job_name: 'grabgo-ml-service'
    static_configs:
      - targets: ['ml-service:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s

# Grafana dashboards for:
# - Request latency
# - Error rates
# - Model inference time
# - Cache hit rates
# - Database connection pool
```

### 7. Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/ml-service
upstream ml_service {
    server localhost:8000;
}

server {
    listen 80;
    server_name ml.grabgo.com;

    location / {
        proxy_pass http://ml_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # SSL configuration (use certbot)
    # listen 443 ssl;
    # ssl_certificate /etc/letsencrypt/live/ml.grabgo.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/ml.grabgo.com/privkey.pem;
}
```

### 8. Backend Integration

Add to your Node.js backend `.env`:

```bash
# ML Service Configuration
ML_SERVICE_URL=http://ml-service:8000
ML_API_KEY=your-secure-api-key-here
```

Install ML service client in backend:

```bash
cd backend
npm install axios
```

Use the integration examples from `INTEGRATION.js`.

### 9. Model Training & Updates

```bash
# Initial model training
python scripts/train_models.py --all

# Schedule periodic retraining (cron)
0 2 * * * cd /app && python scripts/train_models.py --all

# Model versioning
# Store models with timestamps: model_v20240205.pkl
# Keep last 3 versions for rollback
```

### 10. Performance Optimization

```python
# config.py adjustments for production
WORKERS = 4  # CPU cores * 2
REDIS_POOL_SIZE = 50
POSTGRES_POOL_SIZE = 20
RECOMMENDATION_CACHE_TTL = 300  # 5 minutes
PREDICTION_CACHE_TTL = 60  # 1 minute
```

### 11. Security Hardening

```bash
# 1. Use strong API keys
openssl rand -hex 32

# 2. Enable rate limiting
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60

# 3. Restrict CORS origins
CORS_ORIGINS=https://grabgo.com,https://admin.grabgo.com

# 4. Use HTTPS only in production
# 5. Keep dependencies updated
pip list --outdated
pip install --upgrade package-name

# 6. Regular security audits
pip-audit
```

### 12. Backup & Recovery

```bash
# Backup ML models
tar -czf ml_models_backup_$(date +%Y%m%d).tar.gz ml_models/

# Backup to cloud storage
aws s3 cp ml_models_backup_*.tar.gz s3://grabgo-ml-backups/

# Restore
tar -xzf ml_models_backup_20240205.tar.gz
```

### 13. Logging & Debugging

```bash
# View logs
tail -f logs/app.log

# Structured logging in production
LOG_LEVEL=INFO
LOG_FORMAT=json

# Log aggregation (ELK Stack, CloudWatch, etc.)
# Send logs to centralized logging service
```

### 14. Testing in Production

```bash
# Health check
curl http://ml-service:8000/health

# Test recommendation endpoint
curl -X POST http://ml-service:8000/api/v1/recommendations/food \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "limit": 10}'

# Load testing
ab -n 1000 -c 10 http://ml-service:8000/health
```

### 15. Rollback Plan

```bash
# If deployment fails:
# 1. Revert to previous Docker image
docker-compose down
docker-compose up -d grabgo-ml-service:previous-version

# 2. Restore previous models
cp ml_models_backup/previous/* ml_models/

# 3. Check health
curl http://ml-service:8000/health
```

## Performance Benchmarks

Expected performance metrics:

- **Recommendations**: < 100ms response time
- **Predictions**: < 200ms response time
- **Analytics**: < 300ms response time
- **Throughput**: 1000+ requests/second
- **Cache hit rate**: > 80%
- **Uptime**: 99.9%

## Support & Maintenance

- Monitor metrics daily
- Review logs weekly
- Retrain models monthly
- Update dependencies quarterly
- Security audits bi-annually

## Troubleshooting

### Issue: High latency

```bash
# Check database connections
# Check Redis cache hit rate
# Review slow query logs
# Scale horizontally (add more workers)
```

### Issue: Out of memory

```bash
# Reduce model size
# Increase container memory
# Optimize batch processing
# Clear old cache entries
```

### Issue: Model accuracy degradation

```bash
# Retrain models with recent data
# Review feature engineering
# Check for data drift
# A/B test new models
```

## Contact

For deployment support:
- Email: zakjnr165@gmail.com
- Documentation: /docs
- Health: /health
