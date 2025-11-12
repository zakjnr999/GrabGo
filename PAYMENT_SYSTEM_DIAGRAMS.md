# GrabGo Payment System - Visual Diagrams

## System Architecture Overview

```mermaid
graph TB
    subgraph "Flutter Frontend"
        A[Cart] --> B[Checkout]
        B --> C[Order Summary]
        C --> D[Payment Dialog]
        D --> E[Payment Success]
    end
    
    subgraph "Node.js Backend"
        F[Order API] --> G[Payment API]
        G --> H[MTN MOMO Service]
        H --> I[Database]
    end
    
    subgraph "External Services"
        J[MTN MOMO API]
        K[MongoDB]
    end
    
    C --> F
    G --> J
    I --> K
    D <--> G
    
    style A fill:#e1f5fe
    style E fill:#e8f5e8
    style F fill:#fff3e0
    style G fill:#fff3e0
    style J fill:#fce4ec
```

## Order Creation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant App as Flutter App
    participant OrderAPI as Order API
    participant PayAPI as Payment API
    participant MOMO as MTN MOMO
    participant DB as Database

    U->>App: Add items to cart
    U->>App: Select delivery & payment
    U->>App: Tap "Confirm & Pay"
    
    App->>App: Generate orderNumber
    Note over App: ORD-{timestamp}-{random}
    
    App->>OrderAPI: POST /orders
    Note over OrderAPI: Include orderNumber in request
    
    OrderAPI->>DB: Save order with orderNumber
    DB-->>OrderAPI: Order saved successfully
    OrderAPI-->>App: Return orderId
    
    App->>PayAPI: POST /payments/mtn-momo/initiate
    PayAPI->>DB: Create payment record
    PayAPI->>MOMO: Request payment
    MOMO-->>PayAPI: Return reference ID
    PayAPI-->>App: Payment initiated
    
    App->>App: Show payment dialog
    App->>App: Start status polling
    
    loop Every 3 seconds
        App->>PayAPI: GET /payments/status/:id
        PayAPI->>MOMO: Check payment status
        MOMO-->>PayAPI: Status update
        PayAPI-->>App: Return status
        
        alt Payment Successful
            App->>App: Show success
            App->>U: Navigate to tracking
        else Payment Failed
            App->>App: Show error
            App->>U: Retry option
        else Still Pending
            App->>App: Continue polling
        end
    end
```

## MTN MOMO Integration Flow

```mermaid
flowchart TD
    A[User enters phone number] --> B{Valid Ghana number?}
    B -->|No| C[Show validation error]
    B -->|Yes| D[Format phone number]
    
    D --> E[Get MTN MOMO access token]
    E --> F[Create payment request]
    F --> G[Send to MTN MOMO API]
    
    G --> H{API Response}
    H -->|Success| I[Store reference ID]
    H -->|Error| J[Show error message]
    
    I --> K[User receives USSD prompt]
    K --> L[User enters PIN]
    
    L --> M{Payment Status}
    M -->|Successful| N[Update order status]
    M -->|Failed| O[Show failure message]
    M -->|Pending| P[Continue monitoring]
    
    N --> Q[Send confirmation]
    O --> R[Allow retry]
    P --> S[Check status again]
    S --> M
    
    style A fill:#e3f2fd
    style N fill:#e8f5e8
    style O fill:#ffebee
    style K fill:#fff9c4
```

## Payment Status State Machine

```mermaid
stateDiagram-v2
    [*] --> Initiating
    
    Initiating --> Processing : MTN MOMO request sent
    Initiating --> Failed : API error
    
    Processing --> WaitingForPin : User receives USSD
    Processing --> Failed : Network timeout
    
    WaitingForPin --> Successful : User enters correct PIN
    WaitingForPin --> Failed : Wrong PIN or cancelled
    WaitingForPin --> Timeout : 5 minute timeout
    
    Successful --> [*] : Order confirmed
    Failed --> [*] : Show retry option
    Timeout --> [*] : Allow new attempt
    
    Failed --> Initiating : User retries
    Timeout --> Initiating : User tries again
```

## Database Relationships

```mermaid
erDiagram
    USER ||--o{ ORDER : creates
    ORDER ||--|| PAYMENT : has
    ORDER }|--|| RESTAURANT : "ordered from"
    ORDER ||--o{ ORDER_ITEM : contains
    ORDER_ITEM }|--|| FOOD : references
    PAYMENT ||--o{ TRANSACTION : "generates"
    
    USER {
        ObjectId _id PK
        string email
        string username
        string phone
        string role
    }
    
    ORDER {
        ObjectId _id PK
        string orderNumber UK
        ObjectId customer FK
        ObjectId restaurant FK
        array items
        number totalAmount
        object deliveryAddress
        string paymentMethod
        string paymentStatus
        string status
        date createdAt
    }
    
    PAYMENT {
        ObjectId _id PK
        ObjectId order FK
        ObjectId customer FK
        string paymentMethod
        string provider
        number amount
        string referenceId
        string externalReferenceId
        string status
        date createdAt
    }
    
    RESTAURANT {
        ObjectId _id PK
        string restaurant_name
        string email
        object address
        number delivery_fee
    }
    
    FOOD {
        ObjectId _id PK
        ObjectId restaurant FK
        string name
        number price
        string description
        string image
    }
```

## Error Handling Flow

```mermaid
flowchart TD
    A[Payment Request] --> B{Validation}
    B -->|Invalid| C[Return 400 Error]
    B -->|Valid| D[Process Payment]
    
    D --> E{MTN MOMO API}
    E -->|Network Error| F[Retry Logic]
    E -->|Invalid Response| G[Log & Return Error]
    E -->|Success| H[Monitor Status]
    
    F --> I{Retry Count < 3}
    I -->|Yes| D
    I -->|No| J[Return Service Unavailable]
    
    H --> K{Status Check}
    K -->|Successful| L[Update Order]
    K -->|Failed| M[Mark Payment Failed]
    K -->|Pending| N[Continue Monitoring]
    
    N --> O{Timeout?}
    O -->|Yes| P[Mark as Timeout]
    O -->|No| Q[Wait 3 seconds]
    Q --> K
    
    style C fill:#ffcdd2
    style G fill:#ffcdd2
    style J fill:#ffcdd2
    style M fill:#ffcdd2
    style P fill:#fff3e0
    style L fill:#c8e6c9
```

## Security Architecture

```mermaid
flowchart LR
    subgraph "Client Security"
        A[JWT Token Storage]
        B[Input Validation]
        C[HTTPS Only]
    end
    
    subgraph "API Security"
        D[JWT Verification]
        E[Rate Limiting]
        F[Input Sanitization]
        G[CORS Configuration]
    end
    
    subgraph "Payment Security"
        H[Order Ownership Check]
        I[Phone Number Validation]
        J[Reference ID Generation]
        K[API Key Protection]
    end
    
    subgraph "Database Security"
        L[MongoDB Injection Protection]
        M[Data Encryption]
        N[Access Controls]
    end
    
    A --> D
    B --> F
    C --> G
    D --> H
    E --> I
    F --> J
    H --> L
    I --> M
    J --> N
    
    style A fill:#e8eaf6
    style D fill:#e8f5e8
    style H fill:#fff3e0
    style L fill:#fce4ec
```

## Performance Optimization Points

```mermaid
mindmap
    root((Performance))
        Frontend
            Image Caching
            State Management
            Network Requests
                Request Batching
                Connection Pooling
                Timeout Handling
        Backend
            Database
                Connection Pooling
                Query Optimization
                Indexing
            Caching
                Redis Cache
                MTN MOMO Tokens
                User Sessions
        Monitoring
            Response Times
            Error Rates
            Payment Success Rates
            Database Performance
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "Mobile Apps"
        A[iOS App]
        B[Android App]
    end
    
    subgraph "CDN/Load Balancer"
        C[CloudFlare/AWS ALB]
    end
    
    subgraph "Application Tier"
        D[Node.js Server 1]
        E[Node.js Server 2]
        F[Node.js Server N]
    end
    
    subgraph "Database Tier"
        G[MongoDB Primary]
        H[MongoDB Secondary]
        I[Redis Cache]
    end
    
    subgraph "External Services"
        J[MTN MOMO API]
        K[SMS Gateway]
        L[Email Service]
    end
    
    A --> C
    B --> C
    C --> D
    C --> E
    C --> F
    
    D --> G
    E --> G
    F --> G
    
    G --> H
    D --> I
    E --> I
    F --> I
    
    D --> J
    E --> J
    F --> J
    
    D --> K
    D --> L
    
    style A fill:#e1f5fe
    style B fill:#e8f5e8
    style C fill:#fff3e0
    style G fill:#fce4ec
    style J fill:#f3e5f5
```

## API Request/Response Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant LB as Load Balancer
    participant API as API Server
    participant AUTH as Auth Middleware
    participant VAL as Validation
    participant CTRL as Controller
    participant SVC as Service
    participant DB as Database
    participant EXT as External API

    C->>LB: HTTPS Request
    LB->>API: Forward Request
    API->>AUTH: Verify JWT Token
    AUTH-->>API: Token Valid
    API->>VAL: Validate Input
    VAL-->>API: Input Valid
    API->>CTRL: Route to Controller
    CTRL->>SVC: Business Logic
    SVC->>DB: Database Query
    DB-->>SVC: Query Result
    SVC->>EXT: External API Call
    EXT-->>SVC: API Response
    SVC-->>CTRL: Service Result
    CTRL-->>API: Controller Response
    API-->>LB: HTTP Response
    LB-->>C: Final Response
    
    Note over C,EXT: End-to-End Request Flow
```

---

*These diagrams provide visual representations of the GrabGo payment system architecture, flows, and relationships. Use them for system understanding, debugging, and planning future enhancements.*