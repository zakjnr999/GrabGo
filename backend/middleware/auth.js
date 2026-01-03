const jwt = require('jsonwebtoken');
const User = require('../models/User');

exports.verifyApiKey = (req, res, next) => {
  const apiKey = req.headers['api_key'] || req.headers['x-api-key'];
  
  if (!apiKey) {
    return res.status(401).json({
      success: false,
      message: 'API key is required'
    });
  }

  if (apiKey !== process.env.API_KEY) {
    return res.status(403).json({
      success: false,
      message: 'Invalid API key'
    });
  }

  next();
};

exports.protect = async (req, res, next) => {
  let token;

  // Debug auth headers
  console.log('\n🔑 AUTHENTICATION DEBUG:');
  console.log('  Endpoint:', req.method, req.path);
  console.log('  Authorization header:', req.headers.authorization ? 'Present' : 'Missing');
  
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
    console.log('  Token extracted:', token ? `${token.substring(0, 20)}...` : 'Failed to extract');
  }

  if (!token) {
    console.log('  ❌ AUTH FAILED: No token provided');
    return res.status(401).json({
      success: false,
      message: 'Not authorized, no token provided'
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('  ✅ Token verified for user:', decoded.id);
    
    req.user = await User.findById(decoded.id).select('-password');
    
    if (!req.user) {
      console.log('  ❌ AUTH FAILED: User not found for ID:', decoded.id);
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }

    if (!req.user.isActive) {
      console.log('  ❌ AUTH FAILED: User account deactivated');
      return res.status(403).json({
        success: false,
        message: 'Account is deactivated'
      });
    }

    console.log('  ✅ Authentication successful for:', req.user.email || req.user.username);
    next();
  } catch (error) {
    console.log('  ❌ AUTH FAILED: Token verification error:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Not authorized, token failed'
    });
  }
};

exports.admin = (req, res, next) => {
  if (!req.user || !req.user.isAdmin) {
    return res.status(403).json({
      success: false,
      message: 'Access denied. Admin privileges required.'
    });
  }
  next();
};

exports.authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role: ${roles.join(' or ')}`
      });
    }
    next();
  };
};

