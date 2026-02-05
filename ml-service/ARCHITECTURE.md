# GrabGo ML Service Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GrabGo Platform Architecture                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              Client Applications                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  📱 Customer App    │  🚴 Rider App    │  🏪 Restaurant Panel  │  👨‍💼 Admin    │
│  (Flutter/Dart)    │  (Flutter/Dart)  │  (Next.js/React)      │  (Next.js)   │
└──────────────┬──────────────────┬────────────────┬─────────────────┬─────────┘
               │                  │                │                 │
               └──────────────────┼────────────────┼─────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Node.js Backend (Express)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  🔐 Authentication  │  📦 Orders  │  🍔 Restaurants  │  🚴 Riders  │  💳 Pay │
│  🔔 Notifications   │  💬 Chat    │  📊 Analytics    │  🎁 Promos  │  ⭐ Rev │
└──────────────┬──────────────────┬────────────────┬─────────────────┬─────────┘
               │                  │                │                 │
               │                  ▼                │                 │
               │    ┌──────────────────────────┐   │                 │
               │    │   🤖 ML Service (NEW!)   │   │                 │
               │    │   Python + FastAPI       │   │                 │
               │    └──────────────────────────┘   │                 │
               │                  │                │                 │
               │                  │                │                 │
┌──────────────┴──────────────────┴────────────────┴─────────────────┴─────────┐
│                              Data Layer                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │   PostgreSQL     │  │     MongoDB      │  │      Redis       │         │
│  │   (Prisma ORM)   │  │   (Mongoose)     │  │    (Caching)     │         │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤         │
│  │ • Users          │  │ • Chats          │  │ • Sessions       │         │
│  │ • Orders         │  │ • Messages       │  │ • ML Cache       │         │
│  │ • Restaurants    │  │ • Statuses       │  │ • API Cache      │         │
│  │ • Foods          │  │ • Analytics      │  │ • Rate Limits    │         │
│  │ • Riders         │  │ • Notifications  │  │                  │         │
│  │ • Payments       │  │ • Rider Status   │  │                  │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                    ML Service Internal Architecture                          │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │   FastAPI App   │
                              │   (main.py)     │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
         ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
         │  Recommendations │ │  Predictions │ │    Analytics     │
         │    Endpoints     │ │   Endpoints  │ │    Endpoints     │
         └────────┬─────────┘ └──────┬───────┘ └────────┬─────────┘
                  │                  │                  │
                  ▼                  ▼                  ▼
         ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
         │ Recommendation   │ │  Prediction  │ │   Analytics      │
         │    Service       │ │   Service    │ │    Service       │
         └────────┬─────────┘ └──────┬───────┘ └────────┬─────────┘
                  │                  │                  │
                  └──────────────────┼──────────────────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  │                  │                  │
                  ▼                  ▼                  ▼
         ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
         │  PostgreSQL  │   │   MongoDB    │   │    Redis     │
         │  Connection  │   │  Connection  │   │  Connection  │
         └──────────────┘   └──────────────┘   └──────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                         ML Service Features                                  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  1. RECOMMENDATIONS 🎯                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: user_id, context (time, location, budget)                           │
│  Output: Personalized food/restaurant recommendations                       │
│  Algorithm: Hybrid (Collaborative + Content-based + Contextual)             │
│  Cache: Redis (5 min TTL)                                                   │
│  Response Time: < 100ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  2. DELIVERY TIME PREDICTION ⏱️                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: restaurant_location, delivery_location, rider_id                    │
│  Output: Estimated delivery time (minutes), confidence score                │
│  Factors: Distance, traffic, weather, rider performance                     │
│  Algorithm: Statistical model + historical data                             │
│  Response Time: < 200ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  3. DEMAND FORECASTING 📈                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: service_type, location, forecast_hours                              │
│  Output: Hourly/daily demand forecast, peak hours                           │
│  Use Cases: Rider scheduling, inventory planning, dynamic pricing           │
│  Algorithm: Time series analysis                                            │
│  Response Time: < 300ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  4. CHURN PREDICTION 🔄                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: user_id                                                              │
│  Output: Churn risk score, risk level, retention recommendations            │
│  Factors: Order frequency, last order date, engagement metrics              │
│  Algorithm: Behavioral analysis + pattern recognition                       │
│  Response Time: < 200ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  5. FRAUD DETECTION 🔒                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: user_id, order_data                                                  │
│  Output: Risk score, suspicious flags, recommendations                      │
│  Factors: Order patterns, user behavior, payment info                       │
│  Algorithm: Anomaly detection                                               │
│  Response Time: < 150ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  6. SENTIMENT ANALYSIS 💬                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: text (review, chat message, complaint)                              │
│  Output: Sentiment (positive/negative/neutral), emotions, keywords          │
│  Use Cases: Review analysis, support prioritization                         │
│  Algorithm: NLP (keyword-based, ready for transformers)                     │
│  Response Time: < 100ms                                                     │
└─────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                         Integration Flow                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Customer App                Node.js Backend              ML Service
     │                            │                          │
     │  1. Browse Foods           │                          │
     ├───────────────────────────>│                          │
     │                            │                          │
     │                            │  2. Get Recommendations  │
     │                            ├─────────────────────────>│
     │                            │     (user_id, context)   │
     │                            │                          │
     │                            │  3. ML Predictions       │
     │                            │<─────────────────────────┤
     │                            │  (personalized foods)    │
     │                            │                          │
     │  4. Personalized Feed      │                          │
     │<───────────────────────────┤                          │
     │                            │                          │
     │  5. Place Order            │                          │
     ├───────────────────────────>│                          │
     │                            │                          │
     │                            │  6. Fraud Check          │
     │                            ├─────────────────────────>│
     │                            │                          │
     │                            │  7. Risk Assessment      │
     │                            │<─────────────────────────┤
     │                            │                          │
     │                            │  8. Predict ETA          │
     │                            ├─────────────────────────>│
     │                            │                          │
     │                            │  9. Delivery Time        │
     │                            │<─────────────────────────┤
     │                            │                          │
     │  10. Order Confirmed       │                          │
     │      (with accurate ETA)   │                          │
     │<───────────────────────────┤                          │


┌─────────────────────────────────────────────────────────────────────────────┐
│                         Deployment Options                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Option 1: Docker Compose (Development/Small Scale)
┌─────────────────────────────────────────────────────────────┐
│  docker-compose up -d                                        │
│  ├── ml-service (FastAPI)                                   │
│  ├── postgres                                               │
│  ├── mongodb                                                │
│  └── redis                                                  │
└─────────────────────────────────────────────────────────────┘

Option 2: Kubernetes (Production/Large Scale)
┌─────────────────────────────────────────────────────────────┐
│  Deployment: grabgo-ml-service (3 replicas)                 │
│  Service: LoadBalancer                                      │
│  Ingress: NGINX                                             │
│  Monitoring: Prometheus + Grafana                           │
│  Logging: ELK Stack / CloudWatch                            │
└─────────────────────────────────────────────────────────────┘

Option 3: Cloud Platform (Managed)
┌─────────────────────────────────────────────────────────────┐
│  AWS: ECS/Fargate + RDS + DocumentDB + ElastiCache         │
│  GCP: Cloud Run + Cloud SQL + MongoDB Atlas + Memorystore  │
│  Azure: Container Instances + PostgreSQL + Cosmos + Redis  │
└─────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                         Performance Metrics                                  │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┬──────────────┬──────────────┬──────────────┐
│ Endpoint             │ Avg Latency  │ Throughput   │ Cache Hit    │
├──────────────────────┼──────────────┼──────────────┼──────────────┤
│ Recommendations      │ < 100ms      │ 1000+ req/s  │ 85%          │
│ Delivery Time        │ < 200ms      │ 800+ req/s   │ 70%          │
│ Demand Forecast      │ < 300ms      │ 500+ req/s   │ 90%          │
│ Churn Prediction     │ < 200ms      │ 600+ req/s   │ 80%          │
│ Fraud Detection      │ < 150ms      │ 700+ req/s   │ 60%          │
│ Sentiment Analysis   │ < 100ms      │ 1200+ req/s  │ 50%          │
└──────────────────────┴──────────────┴──────────────┴──────────────┘

Target SLA: 99.9% uptime, < 500ms p95 latency
```
