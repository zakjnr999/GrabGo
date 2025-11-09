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
const {
  generateVerificationToken,
  generateOTP,
  sendVerificationEmail,
} = require("../utils/emailService");

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
    // Validate role if provided
    const validRoles = ['customer', 'restaurant', 'rider', 'admin'];
    const receivedRole = req.body.role || role; // Try both ways
    const userRole = receivedRole && validRoles.includes(String(receivedRole).toLowerCase()) 
      ? String(receivedRole).toLowerCase() 
      : 'customer';
    
    const userData = {
      username,
      email,
      password,
      DateOfBirth,
      phone,
      profilePicture,
      role: userRole,
    };
    
    // Generate email verification OTP
    const emailVerificationOTP = generateOTP();
    const emailVerificationOTPExpires = new Date();
    emailVerificationOTPExpires.setMinutes(emailVerificationOTPExpires.getMinutes() + 10); // 10 minutes expiry

    userData.emailVerificationOTP = emailVerificationOTP;
    userData.emailVerificationOTPExpires = emailVerificationOTPExpires;

    const user = await User.create(userData);

    // Send verification email with OTP (non-blocking)
    sendVerificationEmail(user.email, user.username, emailVerificationOTP)
      .then((result) => {
        if (result.success) {
          console.log(`✅ Verification email sent to ${user.email} with OTP: ${emailVerificationOTP}`);
        } else {
          console.error(`❌ Failed to send verification email to ${user.email}:`, result.message || result.error);
        }
      })
      .catch((error) => {
        console.error(`❌ Error sending verification email to ${user.email}:`, error);
      });

    const token = generateToken(user._id);

    res.status(201).json({
      message: "User registered successfully. Please check your email to verify your account.",
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

// @route   POST /api/users/verify-email
// @desc    Verify email address with OTP code
// @access  Public
router.post("/verify-email", [
  body("email").isEmail().withMessage("Valid email is required"),
  body("otp").isLength({ min: 6, max: 6 }).withMessage("OTP must be 6 digits"),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: "Validation failed",
        errors: errors.array(),
      });
    }

    const { email, otp } = req.body;

    // Find user with matching email and OTP, check if OTP is not expired
    const user = await User.findOne({
      email: email.toLowerCase(),
      emailVerificationOTP: otp,
      emailVerificationOTPExpires: { $gt: new Date() },
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired verification code",
      });
    }

    // Check if email is already verified
    if (user.isEmailVerified) {
      return res.status(400).json({
        success: false,
        message: "Email is already verified",
      });
    }

    // Verify email
    user.isEmailVerified = true;
    user.emailVerificationOTP = null;
    user.emailVerificationOTPExpires = null;
    await user.save();

    res.json({
      success: true,
      message: "Email verified successfully",
      user: {
        _id: user._id,
        username: user.username,
        email: user.email,
        isEmailVerified: user.isEmailVerified,
      },
    });
  } catch (error) {
    console.error("Verify email error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/resend-verification
// @desc    Resend email verification
// @access  Public
router.post("/resend-verification", [
  body("email").isEmail().withMessage("Valid email is required"),
], async (req, res) => {
  console.log('\n========================================');
  console.log('📧 RESEND VERIFICATION REQUEST RECEIVED');
  console.log('========================================');
  console.log('Request body:', req.body);
  console.log('Request headers:', req.headers);
  
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('❌ Validation errors:', errors.array());
      return res.status(400).json({
        success: false,
        message: "Validation failed",
        errors: errors.array(),
      });
    }

    const { email } = req.body;
    console.log('📧 Processing resend verification for:', email);

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });
    console.log('User found:', user ? 'Yes' : 'No');

    if (!user) {
      console.log('⚠️  User not found for email:', email);
      // Don't reveal if user exists or not for security
      return res.json({
        success: true,
        message: "If an account exists with this email, a verification email has been sent.",
      });
    }

    // Check if email is already verified
    if (user.isEmailVerified) {
      console.log('⚠️  Email already verified for:', email);
      return res.status(400).json({
        success: false,
        message: "Email is already verified",
      });
    }
    
    console.log('✅ User found and email not verified. Generating OTP...');

    // Generate new verification OTP
    const emailVerificationOTP = generateOTP();
    const emailVerificationOTPExpires = new Date();
    emailVerificationOTPExpires.setMinutes(emailVerificationOTPExpires.getMinutes() + 10); // 10 minutes expiry

    user.emailVerificationOTP = emailVerificationOTP;
    user.emailVerificationOTPExpires = emailVerificationOTPExpires;
    await user.save();

    // Send verification email with OTP (non-blocking)
    sendVerificationEmail(user.email, user.username, emailVerificationOTP)
      .then((result) => {
        if (result.success) {
          console.log(`✅ Verification email resent to ${user.email} with OTP: ${emailVerificationOTP}`);
        } else {
          console.error(`❌ Failed to resend verification email to ${user.email}:`, result.message || result.error);
        }
      })
      .catch((error) => {
        console.error(`❌ Error resending verification email to ${user.email}:`, error);
      });

    res.json({
      success: true,
      message: "Verification email sent successfully. Please check your inbox.",
    });
  } catch (error) {
    console.error("Resend verification error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/send-verification
// @desc    Send verification email (for authenticated users)
// @access  Private
router.post("/send-verification", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Check if email is already verified
    if (user.isEmailVerified) {
      return res.status(400).json({
        success: false,
        message: "Email is already verified",
      });
    }

    // Generate new verification OTP
    const emailVerificationOTP = generateOTP();
    const emailVerificationOTPExpires = new Date();
    emailVerificationOTPExpires.setMinutes(emailVerificationOTPExpires.getMinutes() + 10); // 10 minutes expiry

    user.emailVerificationOTP = emailVerificationOTP;
    user.emailVerificationOTPExpires = emailVerificationOTPExpires;
    await user.save();

    // Send verification email with OTP (non-blocking)
    const emailResult = await sendVerificationEmail(user.email, user.username, emailVerificationOTP);

    if (!emailResult.success) {
      return res.status(500).json({
        success: false,
        message: "Failed to send verification email. Please try again later.",
      });
    }

    res.json({
      success: true,
      message: "Verification email sent successfully. Please check your inbox.",
    });
  } catch (error) {
    console.error("Send verification error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

module.exports = router;
