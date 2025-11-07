# GrabGo Backend API

A comprehensive RESTful API backend for the GrabGo food delivery platform built with Node.js, Express, and MongoDB.

## Features

- 🔐 **Authentication & Authorization**
  - User registration and login
  - Google OAuth integration
  - JWT token-based authentication
  - Role-based access control (Customer, Restaurant, Rider, Admin)
  - API key verification

- 🏪 **Restaurant Management**
  - Restaurant registration with document upload
  - Restaurant approval workflow
  - Restaurant listing and details

- 🍔 **Food & Categories**
  - Food item management
  - Category management
  - Image uploads

- 📦 **Order Management**
  - Order creation and tracking
  - Order status updates
  - Rider assignment
  - Order history

- 📁 **File Uploads**
  - Profile pictures
  - Restaurant logos and documents
  - Food images

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose
- **Authentication**: JWT (JSON Web Tokens)
- **File Upload**: Multer
- **Security**: Helmet, CORS, bcryptjs
- **Validation**: express-validator

## Prerequisites

- Node.js 18+ installed
- MongoDB installed and running (or MongoDB Atlas account)
- npm or yarn package manager

## Installation

1. **Clone the repository and navigate to backend folder**
   ```bash
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Create environment file**
   ```bash
   cp .env.example .env
   ```

4. **Configure environment variables**
   Edit `.env` file with your configuration:
   ```env
   PORT=5000
   NODE_ENV=development
   MONGODB_URI=mongodb://localhost:27017/grabgo
   JWT_SECRET=your_super_secret_jwt_key_change_this
   JWT_EXPIRE=7d
   API_KEY=pAuLInepisT_les
   ```

5. **Create uploads directory**
   ```bash
   mkdir uploads
   ```

6. **Start the server**
   ```bash
   # Development mode
   npm run dev

   # Production mode
   npm start
   ```

The API will be available at `http://localhost:5000/api`

## API Endpoints

### Authentication (`/api/users`)

- `POST /api/users` - Register a new user
- `POST /api/users/login` - Login user
- `POST /api/users/google-signup` - Register with Google
- `POST /api/users/google-login` - Login with Google
- `PUT /api/users/:userId` - Update user profile
- `PUT /api/users/:userId/upload` - Upload profile picture
- `GET /api/users/:userId` - Get user by ID

### Restaurants (`/api/restaurants`)

- `GET /api/restaurants` - Get all approved restaurants
- `POST /api/restaurants/register` - Register a new restaurant
- `GET /api/restaurants/:restaurantId` - Get restaurant by ID
- `PUT /api/restaurants/:restaurantId` - Update restaurant status (Admin only)

### Orders (`/api/orders`)

- `POST /api/orders` - Create a new order
- `GET /api/orders` - Get orders (filtered by user role)
- `GET /api/orders/:orderId` - Get order by ID
- `PUT /api/orders/:orderId/status` - Update order status
- `PUT /api/orders/:orderId/assign-rider` - Assign rider to order

### Categories (`/api/categories`)

- `GET /api/categories` - Get all categories
- `POST /api/categories` - Create a new category (Admin only)
- `GET /api/categories/:categoryId` - Get category by ID

### Foods (`/api/foods`)

- `GET /api/foods` - Get all foods (with optional filters)
- `POST /api/foods` - Create a new food item
- `GET /api/foods/:foodId` - Get food by ID
- `PUT /api/foods/:foodId` - Update food item

### Riders (`/api/riders`)

- `GET /api/riders/available-orders` - Get available orders for riders
- `POST /api/riders/accept-order/:orderId` - Accept an order
- `GET /api/riders/wallet` - Get rider wallet information
- `GET /api/riders/earnings` - Get rider earnings (with period filter)
- `GET /api/riders/transactions` - Get rider transaction history
- `POST /api/riders/withdraw` - Request withdrawal
- `PUT /api/riders/transactions/:transactionId/status` - Update transaction status (Admin only)

## Request/Response Examples

### Register User
```bash
POST /api/users
Content-Type: application/json

{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "password123",
  "phone": 1234567890,
  "DateOfBirth": "1990-01-01"
}
```

### Login
```bash
POST /api/users/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

### Create Order
```bash
POST /api/orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "restaurant": "restaurant_id",
  "items": [
    {
      "food": "food_id",
      "quantity": 2
    }
  ],
  "deliveryAddress": {
    "street": "123 Main St",
    "city": "Accra",
    "latitude": 5.6037,
    "longitude": -0.1870
  },
  "paymentMethod": "cash",
  "notes": "Please ring the doorbell"
}
```

## Authentication

Most endpoints require authentication. Include the JWT token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

For admin endpoints, also include the API key:

```
API_KEY: pAuLInepisT_les
```

## File Uploads

File uploads are handled using multipart/form-data. Supported image formats: JPEG, JPG, PNG, GIF, WEBP.

Example for uploading profile picture:
```bash
PUT /api/users/:userId/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

profilePicture: <file>
```

## Docker Deployment

### Using Docker Compose

1. **Build and start services**
   ```bash
   docker-compose up -d
   ```

2. **View logs**
   ```bash
   docker-compose logs -f
   ```

3. **Stop services**
   ```bash
   docker-compose down
   ```

### Using Docker

1. **Build the image**
   ```bash
   docker build -t grabgo-backend .
   ```

2. **Run the container**
   ```bash
   docker run -d \
     -p 5000:5000 \
     -e MONGODB_URI=mongodb://host.docker.internal:27017/grabgo \
     -e JWT_SECRET=your_secret \
     -v $(pwd)/uploads:/app/uploads \
     --name grabgo-backend \
     grabgo-backend
   ```

## Production Deployment

### Environment Variables for Production

Make sure to set these in your production environment:

```env
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/grabgo
JWT_SECRET=<strong_random_secret>
API_KEY=<your_api_key>
ALLOWED_ORIGINS=https://yourdomain.com
```

### Recommended Platforms

- **Render**: Easy deployment with MongoDB Atlas
- **Heroku**: Simple deployment with add-ons
- **DigitalOcean**: App Platform or Droplets
- **AWS**: EC2, ECS, or Elastic Beanstalk
- **Google Cloud**: Cloud Run or Compute Engine

### MongoDB Atlas Setup

1. Create a MongoDB Atlas account
2. Create a new cluster
3. Get your connection string
4. Update `MONGODB_URI` in your environment variables

## Project Structure

```
backend/
├── config/
│   └── database.js          # Database configuration
├── middleware/
│   ├── auth.js              # Authentication middleware
│   └── upload.js            # File upload middleware
├── models/
│   ├── User.js              # User model
│   ├── Restaurant.js        # Restaurant model
│   ├── Order.js             # Order model
│   ├── Category.js          # Category model
│   └── Food.js              # Food model
├── routes/
│   ├── auth.js             # Authentication routes
│   ├── restaurants.js      # Restaurant routes
│   ├── orders.js           # Order routes
│   ├── categories.js       # Category routes
│   └── foods.js            # Food routes
├── uploads/                # Uploaded files directory
├── .env.example            # Environment variables example
├── .gitignore              # Git ignore file
├── Dockerfile              # Docker configuration
├── docker-compose.yml      # Docker Compose configuration
├── package.json            # Dependencies
├── server.js               # Main server file
└── README.md               # This file
```

## Error Handling

The API uses consistent error responses:

```json
{
  "success": false,
  "message": "Error message",
  "error": "Detailed error (development only)"
}
```

## Security Features

- Password hashing with bcrypt
- JWT token authentication
- API key verification for admin endpoints
- Helmet.js for security headers
- CORS configuration
- Input validation with express-validator
- File type validation for uploads

## Development

### Running in Development Mode

```bash
npm run dev
```

This uses nodemon to automatically restart the server on file changes.

### Testing the API

You can use tools like:
- Postman
- Insomnia
- curl
- Thunder Client (VS Code extension)

## Troubleshooting

### MongoDB Connection Issues
- Ensure MongoDB is running
- Check connection string format
- Verify network access for MongoDB Atlas

### Port Already in Use
- Change PORT in .env file
- Or kill the process using the port

### File Upload Issues
- Ensure uploads directory exists
- Check file size limits
- Verify file type is supported

## Support

For issues and questions, please check:
- API documentation
- Error logs in console
- MongoDB connection status

## License

ISC

