# 🚀 Quick Start: Your First Backend Project

This guide will help you build your first backend API in 1-2 hours, following the GrabGo patterns.

---

## Project: Simple Todo API

We'll build a Todo API with user authentication - a perfect starting point!

---

## Step 1: Setup (10 minutes)

### 1.1 Create Project
```bash
mkdir my-todo-api
cd my-todo-api
npm init -y
```

### 1.2 Install Dependencies
```bash
npm install express mongoose dotenv bcryptjs jsonwebtoken express-validator cors helmet morgan
npm install --save-dev nodemon
```

### 1.3 Update package.json
```json
{
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  }
}
```

### 1.4 Create Folder Structure
```bash
mkdir models routes middleware config
touch server.js .env .gitignore
```

---

## Step 2: Configuration (5 minutes)

### 2.1 Create `.env` file
```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/todoapp
JWT_SECRET=your_super_secret_key_change_this
JWT_EXPIRE=7d
```

### 2.2 Create `.gitignore`
```
node_modules/
.env
uploads/
*.log
```

### 2.3 Create `config/database.js`
```javascript
const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI);
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
```

---

## Step 3: Models (15 minutes)

### 3.1 Create `models/User.js`
```javascript
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: [true, 'Please provide a username'],
    unique: true,
    trim: true
  },
  email: {
    type: String,
    required: [true, 'Please provide an email'],
    unique: true,
    lowercase: true,
    match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email']
  },
  password: {
    type: String,
    required: [true, 'Please provide a password'],
    minlength: 6,
    select: false
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare password method
userSchema.methods.matchPassword = async function(enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
```

### 3.2 Create `models/Todo.js`
```javascript
const mongoose = require('mongoose');

const todoSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Please provide a title'],
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  completed: {
    type: Boolean,
    default: false
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Todo', todoSchema);
```

---

## Step 4: Middleware (15 minutes)

### 4.1 Create `middleware/auth.js`
```javascript
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Verify JWT Token
exports.protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized, no token provided'
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id).select('-password');
    
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }

    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized, token failed'
    });
  }
};
```

---

## Step 5: Routes (30 minutes)

### 5.1 Create `routes/auth.js`
```javascript
const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');

const router = express.Router();

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '7d'
  });
};

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post('/register', [
  body('username').notEmpty().withMessage('Username is required'),
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { username, email, password } = req.body;

    // Check if user exists
    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User already exists'
      });
    }

    // Create user
    const user = await User.create({
      username,
      email,
      password
    });

    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        _id: user._id,
        username: user.username,
        email: user.email
      },
      token
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/auth/login
// @desc    Login user
// @access  Public
router.post('/login', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { email, password } = req.body;

    // Find user and include password
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check password
    const isMatch = await user.matchPassword(password);

    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    const token = generateToken(user._id);

    res.json({
      success: true,
      message: 'Login successful',
      user: {
        _id: user._id,
        username: user.username,
        email: user.email
      },
      token
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
```

### 5.2 Create `routes/todos.js`
```javascript
const express = require('express');
const { body, validationResult } = require('express-validator');
const Todo = require('../models/Todo');
const { protect } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(protect);

// @route   GET /api/todos
// @desc    Get all todos for logged in user
// @access  Private
router.get('/', async (req, res) => {
  try {
    const todos = await Todo.find({ user: req.user._id }).sort({ createdAt: -1 });
    
    res.json({
      success: true,
      count: todos.length,
      data: todos
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/todos
// @desc    Create a new todo
// @access  Private
router.post('/', [
  body('title').notEmpty().withMessage('Title is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const todo = await Todo.create({
      ...req.body,
      user: req.user._id
    });

    res.status(201).json({
      success: true,
      data: todo
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   PUT /api/todos/:id
// @desc    Update a todo
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    let todo = await Todo.findById(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found'
      });
    }

    // Make sure user owns the todo
    if (todo.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this todo'
      });
    }

    todo = await Todo.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });

    res.json({
      success: true,
      data: todo
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   DELETE /api/todos/:id
// @desc    Delete a todo
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const todo = await Todo.findById(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found'
      });
    }

    // Make sure user owns the todo
    if (todo.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this todo'
      });
    }

    await todo.deleteOne();

    res.json({
      success: true,
      message: 'Todo deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
```

---

## Step 6: Server Setup (10 minutes)

### 6.1 Create `server.js`
```javascript
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const connectDB = require('./config/database');

// Connect to database
connectDB();

const app = express();

// Middleware
app.use(helmet());
app.use(morgan('dev'));
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/todos', require('./routes/todos'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Todo API is running' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error'
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
});
```

---

## Step 7: Test Your API (15 minutes)

### 7.1 Start MongoDB
Make sure MongoDB is running:
```bash
# If installed locally
mongod

# Or use MongoDB Atlas (cloud)
```

### 7.2 Start Server
```bash
npm run dev
```

### 7.3 Test with Postman/Insomnia

#### Register User
```
POST http://localhost:5000/api/auth/register
Content-Type: application/json

{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "password123"
}
```

#### Login
```
POST http://localhost:5000/api/auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

Copy the `token` from response!

#### Create Todo
```
POST http://localhost:5000/api/todos
Authorization: Bearer <your_token>
Content-Type: application/json

{
  "title": "Learn Node.js",
  "description": "Complete the backend roadmap",
  "completed": false
}
```

#### Get All Todos
```
GET http://localhost:5000/api/todos
Authorization: Bearer <your_token>
```

#### Update Todo
```
PUT http://localhost:5000/api/todos/<todo_id>
Authorization: Bearer <your_token>
Content-Type: application/json

{
  "completed": true
}
```

#### Delete Todo
```
DELETE http://localhost:5000/api/todos/<todo_id>
Authorization: Bearer <your_token>
```

---

## 🎉 Congratulations!

You've built your first backend API with:
- ✅ User authentication (JWT)
- ✅ Password hashing (bcrypt)
- ✅ Protected routes
- ✅ CRUD operations
- ✅ Input validation
- ✅ Error handling
- ✅ Security middleware

---

## 🚀 Next Steps

1. **Add Features**:
   - Todo categories
   - Due dates
   - Search functionality
   - Pagination

2. **Improve Security**:
   - Rate limiting
   - Email verification
   - Password reset

3. **Add Testing**:
   - Unit tests
   - Integration tests

4. **Deploy**:
   - Deploy to Render/Heroku
   - Use MongoDB Atlas

---

## 📚 What You Learned

- Express.js server setup
- MongoDB connection with Mongoose
- User authentication with JWT
- Password hashing
- Protected routes
- CRUD operations
- Input validation
- Error handling
- RESTful API design

This is the foundation! Now follow the full roadmap to build more complex backends like GrabGo! 🎯

