const express = require("express");
const jwt = require("jsonwebtoken");
const { body, validationResult } = require("express-validator");
const User = require("../models/User");
const { protect } = require("../middleware/auth");
const {
  uploadSingle,
  getFileUrl,
  uploadToCloudinary,
} = require("../middleware/upload");

const router = express.Router();

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || "7d",
  });
};

// @route   POST /api/users
// @desc    Register a new user (regular or Google)
// @access  Public
router.post("/", async (req, res) => {
  try {
    const {
      googleId,
      email,
      displayName,
      photoUrl,
      idToken,
      username,
      password,
      DateOfBirth,
      phone,
      profilePicture,
      role,
    } = req.body;

    // Check if it's a Google sign-up
    if (googleId) {
      // Google sign-up
      if (!email || !googleId || !displayName) {
        return res.status(400).json({
          success: false,
          message: "Google ID, email, and display name are required",
        });
      }

      // Check if user exists
      let user = await User.findOne({ $or: [{ email }, { googleId }] });

      if (user) {
        return res.status(400).json({
          success: false,
          message: "User already exists",
        });
      }

      // Create user
      user = await User.create({
        username: displayName,
        email,
        googleId,
        profilePicture: photoUrl,
        isEmailVerified: true,
        role: role || 'customer',
      });

      const token = generateToken(user._id);

      return res.status(201).json({
        message: "User registered successfully",
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          phone: user.phone,
          isPhoneVerified: user.isPhoneVerified,
          isEmailVerified: user.isEmailVerified,
          DateOfBirth: user.DateOfBirth,
          profilePicture: user.profilePicture,
          isAdmin: user.isAdmin,
          role: user.role,
          isActive: user.isActive,
          permissions: user.permissions,
          createdAt: user.createdAt,
        },
        token,
      });
    }

    // Regular sign-up
    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Username, email, and password are required",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters",
      });
    }

    // Check if user exists
    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email or username",
      });
    }

    // Create user
    console.log('📝 Registration request body:', {
      username,
      email,
      DateOfBirth,
      phone,
      profilePicture,
      role,
    });
    console.log('📝 Full req.body:', JSON.stringify(req.body, null, 2));
    console.log('📝 Role from req.body:', req.body.role);
    console.log('📝 Role type:', typeof req.body.role);
    
    // Validate role if provided
    const validRoles = ['customer', 'restaurant', 'rider', 'admin'];
    const receivedRole = req.body.role || role; // Try both ways
    const userRole = receivedRole && validRoles.includes(String(receivedRole).toLowerCase()) 
      ? String(receivedRole).toLowerCase() 
      : 'customer';
    
    console.log('📝 Role validation:', { 
      receivedRole: receivedRole, 
      roleFromDestructure: role,
      validRole: userRole 
    });
    
    const userData = {
      username,
      email,
      password,
      DateOfBirth,
      phone,
      profilePicture,
      role: userRole,
    };
    
    console.log('📝 User data to create:', JSON.stringify(userData, null, 2));
    
    const user = await User.create(userData);
    
    console.log('✅ User created with role:', user.role);

    const token = generateToken(user._id);

    res.status(201).json({
      message: "User registered successfully",
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified,
        DateOfBirth: user.DateOfBirth,
        profilePicture: user.profilePicture,
        isAdmin: user.isAdmin,
        role: user.role,
        isActive: user.isActive,
        permissions: user.permissions,
        createdAt: user.createdAt,
      },
      token,
    });
  } catch (error) {
    console.error("Register error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during registration",
      error: error.message,
    });
  }
});

// @route   POST /api/users/login
// @desc    Login user (regular or Google)
// @access  Public
router.post("/login", async (req, res) => {
  try {
    const { googleId, email, displayName, photoUrl, password } = req.body;

    // Check if it's a Google sign-in
    if (googleId) {
      if (!email || !googleId) {
        return res.status(400).json({
          success: false,
          message: "Google ID and email are required",
        });
      }

      // Find or create user
      let user = await User.findOne({ $or: [{ email }, { googleId }] });

      if (!user) {
        // Create new user if doesn't exist
        user = await User.create({
          username: displayName || email.split("@")[0],
          email,
          googleId,
          profilePicture: photoUrl,
          isEmailVerified: true,
          role: req.body.role || 'customer',
        });
      } else {
        // Update Google ID if not set
        if (!user.googleId) {
          user.googleId = googleId;
          if (photoUrl) user.profilePicture = photoUrl;
          await user.save();
        }
      }

      if (!user.isActive) {
        return res.status(403).json({
          success: false,
          message: "Account is deactivated",
        });
      }

      const token = generateToken(user._id);

      return res.json({
        message: "Login successful",
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          phone: user.phone,
          isPhoneVerified: user.isPhoneVerified,
          isEmailVerified: user.isEmailVerified,
          DateOfBirth: user.DateOfBirth,
          profilePicture: user.profilePicture,
          isAdmin: user.isAdmin,
          role: user.role,
          isActive: user.isActive,
          permissions: user.permissions,
          createdAt: user.createdAt,
        },
        token,
      });
    }

    // Regular login
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // Check if user exists and get password
    const user = await User.findOne({ email }).select("+password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Check password
    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Check if user is active
    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: "Account is deactivated",
      });
    }

    const token = generateToken(user._id);

    res.json({
      message: "Login successful",
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified,
        DateOfBirth: user.DateOfBirth,
        profilePicture: user.profilePicture,
        isAdmin: user.isAdmin,
        role: user.role,
        isActive: user.isActive,
        permissions: user.permissions,
        createdAt: user.createdAt,
      },
      token,
    });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({
      success: false,
      message: "Server error during login",
      error: error.message,
    });
  }
});

// @route   PUT /api/users/:userId
// @desc    Update user (verify phone, upload profile, etc.)
// @access  Private
// This route handles both JSON updates and multipart file uploads
router.put(
  "/:userId",
  protect,
  uploadSingle("profilePicture"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const { userId } = req.params;

      if (req.user._id.toString() !== userId && !req.user.isAdmin) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to update this user",
        });
      }

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      if (req.file && req.file.cloudinaryUrl) {
        if (
          user.profilePicture &&
          user.profilePicture.includes("cloudinary.com")
        ) {
          try {
            const { deleteFromCloudinary } = require("../config/cloudinary");
            const oldPublicId = user.profilePicture
              .split("/")
              .pop()
              .split(".")[0];
            await deleteFromCloudinary(`grabgo/profiles/${oldPublicId}`);
          } catch (error) {
            console.error("Error deleting old profile picture:", error);
            // Continue even if deletion fails
          }
        }

        user.profilePicture = req.file.cloudinaryUrl;
      } else {
        const { phoneNumber, isPhoneVerified, profilePicture, image } =
          req.body;

        if (phoneNumber !== undefined) {
          user.phone = phoneNumber;
        }
        if (isPhoneVerified !== undefined) {
          user.isPhoneVerified = isPhoneVerified;
        }

        const pictureToUse = profilePicture || image;
        if (pictureToUse !== undefined && !req.file) {
          user.profilePicture = pictureToUse;
        }
      }

      await user.save();

      res.json({
        success: true,
        message: req.file
          ? "Profile picture uploaded successfully"
          : "User updated successfully",
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          phone: user.phone,
          isPhoneVerified: user.isPhoneVerified,
          isEmailVerified: user.isEmailVerified,
          DateOfBirth: user.DateOfBirth,
          profilePicture: user.profilePicture,
          isAdmin: user.isAdmin,
          role: user.role,
          isActive: user.isActive,
          permissions: user.permissions,
          createdAt: user.createdAt,
        },
      });
    } catch (error) {
      console.error("Update user error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.put(
  "/:userId/upload",
  protect,
  uploadSingle("profilePicture"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const { userId } = req.params;

      if (req.user._id.toString() !== userId && !req.user.isAdmin) {
        return res.status(403).json({
          success: false,
          message: "Not authorized",
        });
      }

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "No file uploaded. Please select an image.",
        });
      }

      if (!req.file.cloudinaryUrl) {
        return res.status(500).json({
          success: false,
          message: "Failed to upload image to Cloudinary",
          error: "Cloudinary URL not found in request",
        });
      }

      if (
        user.profilePicture &&
        user.profilePicture.includes("cloudinary.com")
      ) {
        try {
          const { deleteFromCloudinary } = require("../config/cloudinary");
          const oldPublicId = user.profilePicture
            .split("/")
            .pop()
            .split(".")[0];
          await deleteFromCloudinary(`grabgo/profiles/${oldPublicId}`);
        } catch (error) {
          console.error("Error deleting old profile picture:", error);
        }
      }

      user.profilePicture = req.file.cloudinaryUrl;
      await user.save();

      res.json({
        success: true,
        message: "Profile picture uploaded successfully",
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          phone: user.phone,
          isPhoneVerified: user.isPhoneVerified,
          isEmailVerified: user.isEmailVerified,
          DateOfBirth: user.DateOfBirth,
          profilePicture: user.profilePicture,
          isAdmin: user.isAdmin,
          role: user.role,
          isActive: user.isActive,
          permissions: user.permissions,
          createdAt: user.createdAt,
        },
      });
    } catch (error) {
      console.error("Upload profile error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.get("/:userId", protect, async (req, res) => {
  try {
    const user = await User.findById(req.params.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      message: "User retrieved successfully",
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified,
        DateOfBirth: user.DateOfBirth,
        profilePicture: user.profilePicture,
        isAdmin: user.isAdmin,
        role: user.role,
        isActive: user.isActive,
        permissions: user.permissions,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error("Get user error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

module.exports = router;
