# 🔧 GrabGo Backend Tech Stack Reference

This document maps the technologies and patterns used in the GrabGo backend to help you understand what you're learning towards.

---

## 📦 Core Technologies

### Runtime & Framework
- **Node.js** (v18+) - JavaScript runtime
- **Express.js** (v4.18.2) - Web framework
- **NPM** - Package manager

### Database
- **MongoDB** - NoSQL database
- **Mongoose** (v8.0.3) - ODM (Object Document Mapper)

### Authentication & Security
- **jsonwebtoken** (v9.0.2) - JWT token generation/verification
- **bcryptjs** (v2.4.3) - Password hashing
- **helmet** (v7.1.0) - Security headers
- **cors** (v2.8.5) - Cross-Origin Resource Sharing

### File Handling
- **multer** (v1.4.5-lts.1) - File upload middleware
- **cloudinary** (v1.41.0) - Cloud image storage
- **multer-storage-cloudinary** (v4.0.0) - Cloudinary integration

### Validation & Utilities
- **express-validator** (v7.0.1) - Input validation
- **dotenv** (v16.3.1) - Environment variables
- **morgan** (v1.10.0) - HTTP request logger
- **compression** (v1.7.4) - Response compression

### Development Tools
- **nodemon** (v3.0.2) - Auto-restart on file changes

---

## 🏗️ Architecture Patterns

### Project Structure
```
backend/
├── config/          # Configuration files
├── middleware/      # Custom middleware
├── models/          # Mongoose schemas
├── routes/          # API route handlers
├── scripts/         # Utility scripts
└── server.js        # Entry point
```

### Design Patterns Used

1. **MVC Pattern** (Model-View-Controller)
   - Models: Database schemas
   - Routes: Controllers (request handling)
   - Views: JSON responses

2. **Middleware Pattern**
   - Authentication middleware
   - Upload middleware
   - Error handling middleware

3. **RESTful API Design**
   - Resource-based URLs
   - HTTP methods (GET, POST, PUT, DELETE)
   - Status codes

---

## 🔐 Security Features

### Authentication Flow
1. User registers/logs in
2. Server generates JWT token
3. Client stores token
4. Client sends token in Authorization header
5. Middleware verifies token
6. Request proceeds if valid

### Security Layers
- **Password Hashing**: bcryptjs with salt rounds
- **JWT Tokens**: Signed tokens with expiration
- **API Keys**: Additional layer for admin endpoints
- **Helmet**: Security headers (XSS, clickjacking protection)
- **CORS**: Controlled cross-origin access
- **Input Validation**: express-validator sanitization

---

## 📊 Database Models

### User Model
- Authentication fields (email, password, googleId)
- Profile fields (username, phone, profilePicture)
- Role-based access (role, isAdmin, permissions)
- Status fields (isActive, isEmailVerified)

### Restaurant Model
- Business information
- Approval workflow (isApproved)
- Location data
- Document uploads

### Order Model
- User reference
- Restaurant reference
- Items array (food references)
- Status tracking
- Delivery information
- Payment details

### Food Model
- Restaurant reference
- Category reference
- Pricing and availability
- Image uploads

### Additional Models
- Category
- RiderWallet
- Transaction

---

## 🛣️ API Endpoints Structure

### Authentication Routes (`/api/users`)
- `POST /api/users` - Register
- `POST /api/users/login` - Login
- `POST /api/users/google-signup` - Google registration
- `POST /api/users/google-login` - Google login
- `PUT /api/users/:userId` - Update profile
- `PUT /api/users/:userId/upload` - Upload profile picture

### Restaurant Routes (`/api/restaurants`)
- `GET /api/restaurants` - List restaurants
- `POST /api/restaurants/register` - Register restaurant
- `GET /api/restaurants/:id` - Get restaurant details
- `PUT /api/restaurants/:id` - Update restaurant (admin)

### Order Routes (`/api/orders`)
- `POST /api/orders` - Create order
- `GET /api/orders` - Get orders (filtered by role)
- `GET /api/orders/:id` - Get order details
- `PUT /api/orders/:id/status` - Update status
- `PUT /api/orders/:id/assign-rider` - Assign rider

### Food Routes (`/api/foods`)
- `GET /api/foods` - List foods (with filters)
- `POST /api/foods` - Create food item
- `GET /api/foods/:id` - Get food details
- `PUT /api/foods/:id` - Update food item

### Category Routes (`/api/categories`)
- `GET /api/categories` - List categories
- `POST /api/categories` - Create category (admin)
- `GET /api/categories/:id` - Get category details

### Rider Routes (`/api/riders`)
- `GET /api/riders/available-orders` - Available orders
- `POST /api/riders/accept-order/:id` - Accept order
- `GET /api/riders/wallet` - Wallet info
- `GET /api/riders/earnings` - Earnings report
- `GET /api/riders/transactions` - Transaction history
- `POST /api/riders/withdraw` - Request withdrawal

---

## 🔄 Request/Response Patterns

### Success Response
```json
{
  "success": true,
  "message": "Operation successful",
  "data": { ... }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error description",
  "error": "Detailed error (development only)"
}
```

### Authentication Header
```
Authorization: Bearer <jwt_token>
```

### API Key Header (Admin)
```
API_KEY: <api_key>
```

---

## 📁 File Upload Pattern

### Upload Flow
1. Client sends multipart/form-data
2. Multer middleware processes file
3. File validated (type, size)
4. Uploaded to Cloudinary (or local storage)
5. URL stored in database
6. URL returned to client

### Supported Formats
- Images: JPEG, JPG, PNG, GIF, WEBP
- Documents: PDF (for restaurant registration)

---

## 🚀 Deployment Configuration

### Environment Variables
```env
PORT=5000
NODE_ENV=production
MONGODB_URI=mongodb+srv://...
JWT_SECRET=<secret>
JWT_EXPIRE=7d
API_KEY=<key>
CLOUDINARY_CLOUD_NAME=<name>
CLOUDINARY_API_KEY=<key>
CLOUDINARY_API_SECRET=<secret>
ALLOWED_ORIGINS=https://...
```

### Docker Support
- Dockerfile for containerization
- docker-compose.yml for multi-container setup
- PM2 ecosystem.config.js for process management

---

## 🎯 Key Concepts to Master

### 1. Middleware Chain
```javascript
app.use(helmet());           // Security headers
app.use(compression());      // Compress responses
app.use(morgan('dev'));      // Logging
app.use(cors());             // CORS
app.use(express.json());     // Parse JSON
app.use('/api', routes);     // Routes
app.use(errorHandler);       // Error handling
```

### 2. Authentication Middleware
```javascript
// Protect route
router.get('/profile', protect, getProfile);

// Admin only
router.post('/admin', protect, admin, adminAction);

// Role-based
router.get('/orders', protect, authorize('restaurant', 'admin'), getOrders);
```

### 3. Mongoose Schema Pattern
```javascript
const schema = new mongoose.Schema({
  field: {
    type: Type,
    required: [true, 'Error message'],
    unique: true,
    default: value
  }
}, { timestamps: true });

// Pre-save hook
schema.pre('save', async function(next) {
  // Logic before save
  next();
});

// Instance method
schema.methods.methodName = function() {
  // Instance logic
};
```

### 4. Route Handler Pattern
```javascript
router.post('/endpoint', 
  protect,                    // Auth middleware
  [                            // Validation
    body('field').notEmpty()
  ],
  async (req, res) => {
    try {
      // Validation check
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }
      
      // Business logic
      const result = await Model.create(req.body);
      
      // Success response
      res.status(201).json({
        success: true,
        data: result
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }
);
```

---

## 📚 Learning Path Mapping

| GrabGo Feature | Roadmap Phase | Key Technologies |
|----------------|---------------|------------------|
| Basic server setup | Phase 1-2 | Node.js, Express |
| Database models | Phase 3 | MongoDB, Mongoose |
| User authentication | Phase 4 | JWT, bcryptjs |
| File uploads | Phase 5 | Multer, Cloudinary |
| API structure | Phase 6 | Express routing |
| Security | Phase 4, 6 | Helmet, CORS, validation |
| Deployment | Phase 8 | Docker, PM2 |

---

## 🎓 Study This Codebase

### Files to Study (in order)

1. **server.js** - Entry point, middleware setup
2. **models/User.js** - Schema definition, hooks
3. **middleware/auth.js** - Authentication patterns
4. **routes/auth.js** - Route handling, validation
5. **middleware/upload.js** - File upload handling
6. **routes/orders.js** - Complex relationships
7. **config/database.js** - Database connection

### Questions to Answer While Studying

1. How is authentication implemented?
2. How are file uploads handled?
3. How are relationships modeled?
4. How is error handling done?
5. How are routes organized?
6. How is validation implemented?
7. How are different user roles handled?

---

## 💡 Pro Tips

1. **Start Simple**: Begin with basic CRUD, then add features
2. **Security First**: Always hash passwords, validate input
3. **Error Handling**: Always use try-catch, return proper status codes
4. **Code Organization**: Keep routes, models, middleware separate
5. **Environment Variables**: Never commit secrets
6. **Validation**: Validate on both client and server
7. **Documentation**: Comment complex logic, document APIs

---

This tech stack represents a production-ready backend. Master each component through the roadmap, and you'll be able to build similar systems!

