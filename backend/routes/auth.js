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
  sendSMS,
} = require("../utils/emailService");
const { registerToken, removeToken } = require("../services/fcm_service");

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
        role: role || "customer",
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
    const validRoles = ["customer", "restaurant", "rider", "admin"];
    const receivedRole = req.body.role || role; // Try both ways
    const userRole =
      receivedRole && validRoles.includes(String(receivedRole).toLowerCase())
        ? String(receivedRole).toLowerCase()
        : "customer";

    const userData = {
      username,
      email,
      password,
      DateOfBirth,
      phone,
      profilePicture,
      role: userRole,
    };

    // Don't generate OTP during registration - it will be generated when user requests it on verify email page
    // This prevents unnecessary OTP generation and ensures email is only sent when user explicitly requests it
    const user = await User.create(userData);

    const token = generateToken(user._id);

    res.status(201).json({
      message:
        "User registered successfully. Please verify your email to continue.",
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
          role: req.body.role || "customer",
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

// @route   GET /api/users/me
// @desc    Get current user profile from token
// @access  Private
router.get("/me", protect, async (req, res) => {
  try {
    res.json({
      success: true,
      user: {
        _id: req.user._id,
        username: req.user.username,
        email: req.user.email,
        phone: req.user.phone,
        isPhoneVerified: req.user.isPhoneVerified,
        isEmailVerified: req.user.isEmailVerified,
        DateOfBirth: req.user.DateOfBirth,
        profilePicture: req.user.profilePicture,
        isAdmin: req.user.isAdmin,
        role: req.user.role,
        isActive: req.user.isActive,
        permissions: req.user.permissions,
        createdAt: req.user.createdAt,
      },
    });
  } catch (error) {
    console.error("Get current user error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

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
router.post(
  "/verify-email",
  [
    body("email").isEmail().withMessage("Valid email is required"),
    body("otp")
      .isLength({ min: 6, max: 6 })
      .withMessage("OTP must be 6 digits"),
  ],
  async (req, res) => {
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

      // Generate token for the verified user
      const token = generateToken(user._id);

      res.json({
        success: true,
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
      console.error("Verify email error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// @route   POST /api/users/resend-verification
// @desc    Resend email verification
// @access  Public
router.post(
  "/resend-verification",
  [body("email").isEmail().withMessage("Valid email is required")],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const { email } = req.body;

      // Find user by email
      const user = await User.findOne({ email: email.toLowerCase() });

      if (!user) {
        // Don't reveal if user exists or not for security
        return res.json({
          success: true,
          message:
            "If an account exists with this email, a verification email has been sent.",
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
      emailVerificationOTPExpires.setMinutes(
        emailVerificationOTPExpires.getMinutes() + 10
      ); // 10 minutes expiry

      user.emailVerificationOTP = emailVerificationOTP;
      user.emailVerificationOTPExpires = emailVerificationOTPExpires;
      await user.save();

      // Send verification email with OTP (non-blocking)
      sendVerificationEmail(user.email, user.username, emailVerificationOTP)
        .catch((error) => {
          console.error("Error sending verification email:", error.message);
        });

      res.json({
        success: true,
      });
    } catch (error) {
      console.error("Resend verification error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

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
    emailVerificationOTPExpires.setMinutes(
      emailVerificationOTPExpires.getMinutes() + 10
    ); // 10 minutes expiry

    user.emailVerificationOTP = emailVerificationOTP;
    user.emailVerificationOTPExpires = emailVerificationOTPExpires;
    await user.save();

    // Send verification email with OTP (non-blocking)
    const emailResult = await sendVerificationEmail(
      user.email,
      user.username,
      emailVerificationOTP
    );

    if (!emailResult.success) {
      return res.status(500).json({
        success: false,
      });
    }

    res.json({
      success: true,
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

// @route   POST /api/users/send-phone-otp
// @desc    Send OTP to phone number
// @access  Public
router.post("/send-phone-otp", async (req, res) => {
  try {
    const { phoneNumber, userId } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    // Find user by ID
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Check if phone is already verified
    if (user.isPhoneVerified) {
      return res.status(400).json({
        success: false,
        message: "Phone is already verified",
      });
    }

    // Generate OTP
    const phoneVerificationOTP = generateOTP();
    const phoneVerificationOTPExpires = new Date();
    phoneVerificationOTPExpires.setMinutes(
      phoneVerificationOTPExpires.getMinutes() + 10
    ); // 10 minutes expiry

    // Save OTP to user
    user.phoneVerificationOTP = phoneVerificationOTP;
    user.phoneVerificationOTPExpires = phoneVerificationOTPExpires;
    await user.save();

    // Send SMS with OTP (non-blocking)
    console.log(`📱 Attempting to send OTP to ${phoneNumber}: ${phoneVerificationOTP}`);
    const smsResult = await sendSMS(phoneNumber, phoneVerificationOTP);

    if (!smsResult.success) {
      console.error(`❌ Failed to send SMS:`, smsResult.error || smsResult.message);

      const isGhanaNumber = phoneNumber.includes('233') || phoneNumber.includes('+233');
      const isTwilioNotConfigured = smsResult.error?.includes('Twilio not configured') ||
        smsResult.error?.includes('TWILIO_ACCOUNT_SID') ||
        smsResult.error?.includes('TWILIO_PHONE_NUMBER');

      // In development, still return success but log the error (for testing)
      if (process.env.NODE_ENV === 'development' && !isTwilioNotConfigured) {
        const message = isGhanaNumber
          ? `OTP generated successfully. Twilio SMS failed - check server logs. OTP: ${phoneVerificationOTP}`
          : `OTP generated successfully (SMS sending failed - check server logs for OTP)`;

        console.log(`⚠️  Development mode: OTP is ${phoneVerificationOTP} (SMS sending failed)`);

        return res.json({
          success: true,
          message: message,
          // Only include OTP in development for debugging
          otp: phoneVerificationOTP,
        });
      }

      // If Twilio is not configured for Ghana numbers, return clear error
      if (isGhanaNumber && isTwilioNotConfigured) {
        return res.status(500).json({
          success: false,
          message: "SMS service not configured for Ghana numbers. Please set up Twilio (see TWILIO_SETUP.md).",
          error: process.env.NODE_ENV === 'development' ? smsResult.error : undefined,
        });
      }

      return res.status(500).json({
        success: false,
        message: "Failed to send OTP. Please try again or contact support.",
        error: process.env.NODE_ENV === 'development' ? smsResult.error : undefined,
      });
    }

    console.log(`✅ SMS sent successfully to ${phoneNumber}`);
    res.json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (error) {
    console.error("Send phone OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/verify-phone-otp
// @desc    Verify phone OTP
// @access  Public
router.post("/verify-phone-otp", async (req, res) => {
  try {
    const { phoneNumber, otp, userId } = req.body;

    if (!phoneNumber || !otp || !userId) {
      return res.status(400).json({
        success: false,
        message: "Phone number, OTP, and user ID are required",
      });
    }

    // Find user by ID
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Check if OTP matches
    if (user.phoneVerificationOTP !== otp) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP",
      });
    }

    // Check if OTP has expired
    if (user.phoneVerificationOTPExpires < new Date()) {
      return res.status(400).json({
        success: false,
        message: "OTP has expired",
      });
    }

    // Verify phone
    user.isPhoneVerified = true;
    user.phone = phoneNumber;
    user.phoneVerificationOTP = null;
    user.phoneVerificationOTPExpires = null;
    await user.save();

    // Generate token for the verified user
    const token = generateToken(user._id);

    res.json({
      success: true,
      message: "Phone verified successfully",
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
    console.error("Verify phone OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/resend-phone-otp
// @desc    Resend phone OTP
// @access  Public
router.post("/resend-phone-otp", async (req, res) => {
  try {
    const { phoneNumber, userId } = req.body;

    if (!phoneNumber || !userId) {
      return res.status(400).json({
        success: false,
        message: "Phone number and user ID are required",
      });
    }

    // Find user by ID
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Check if phone is already verified
    if (user.isPhoneVerified) {
      return res.status(400).json({
        success: false,
        message: "Phone is already verified",
      });
    }

    // Generate new OTP
    const phoneVerificationOTP = generateOTP();
    const phoneVerificationOTPExpires = new Date();
    phoneVerificationOTPExpires.setMinutes(
      phoneVerificationOTPExpires.getMinutes() + 10
    ); // 10 minutes expiry

    // Save OTP to user
    user.phoneVerificationOTP = phoneVerificationOTP;
    user.phoneVerificationOTPExpires = phoneVerificationOTPExpires;
    await user.save();

    // Send SMS with OTP (non-blocking)
    console.log(`📱 Attempting to resend OTP to ${phoneNumber}: ${phoneVerificationOTP}`);
    const smsResult = await sendSMS(phoneNumber, phoneVerificationOTP);

    if (!smsResult.success) {
      console.error(`❌ Failed to resend SMS:`, smsResult.error || smsResult.message);

      const isGhanaNumber = phoneNumber.includes('233') || phoneNumber.includes('+233');
      const isTwilioNotConfigured = smsResult.error?.includes('Twilio not configured') ||
        smsResult.error?.includes('TWILIO_ACCOUNT_SID') ||
        smsResult.error?.includes('TWILIO_PHONE_NUMBER');

      // In development, still return success but log the error (for testing)
      if (process.env.NODE_ENV === 'development' && !isTwilioNotConfigured) {
        const message = isGhanaNumber
          ? `OTP generated successfully. Twilio SMS failed - check server logs. OTP: ${phoneVerificationOTP}`
          : `OTP generated successfully (SMS sending failed - check server logs for OTP)`;

        console.log(`⚠️  Development mode: OTP is ${phoneVerificationOTP} (SMS sending failed)`);

        return res.json({
          success: true,
          message: message,
          // Only include OTP in development for debugging
          otp: phoneVerificationOTP,
        });
      }

      // If Twilio is not configured for Ghana numbers, return clear error
      if (isGhanaNumber && isTwilioNotConfigured) {
        return res.status(500).json({
          success: false,
          message: "SMS service not configured for Ghana numbers. Please set up Twilio (see TWILIO_SETUP.md).",
          error: process.env.NODE_ENV === 'development' ? smsResult.error : undefined,
        });
      }

      return res.status(500).json({
        success: false,
        message: "Failed to resend OTP. Please try again or contact support.",
        error: process.env.NODE_ENV === 'development' ? smsResult.error : undefined,
      });
    }

    console.log(`✅ SMS resent successfully to ${phoneNumber}`);

    res.json({
      success: true,
      message: "OTP resent successfully",
    });
  } catch (error) {
    console.error("Resend phone OTP error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/fcm-token
// @desc    Register or update FCM token for push notifications
// @access  Private
router.post("/fcm-token", protect, async (req, res) => {
  try {
    const { token, deviceId, platform } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "FCM token is required",
      });
    }

    const result = await registerToken(
      req.user._id,
      token,
      deviceId || null,
      platform || 'android'
    );

    if (result) {
      res.json({
        success: true,
        message: "FCM token registered successfully",
      });
    } else {
      res.status(500).json({
        success: false,
        message: "Failed to register FCM token",
      });
    }
  } catch (error) {
    console.error("FCM token registration error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   DELETE /api/users/fcm-token
// @desc    Remove FCM token (on logout)
// @access  Private
router.delete("/fcm-token", protect, async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        message: "FCM token is required",
      });
    }

    await removeToken(req.user._id, token);

    res.json({
      success: true,
      message: "FCM token removed successfully",
    });
  } catch (error) {
    console.error("FCM token removal error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   PUT /api/users/notification-settings
// @desc    Update notification preferences
// @access  Private
router.put("/notification-settings", protect, async (req, res) => {
  try {
    const { chatMessages, orderUpdates, promotions } = req.body;

    const updateFields = {};
    if (typeof chatMessages === 'boolean') {
      updateFields['notificationSettings.chatMessages'] = chatMessages;
    }
    if (typeof orderUpdates === 'boolean') {
      updateFields['notificationSettings.orderUpdates'] = orderUpdates;
    }
    if (typeof promotions === 'boolean') {
      updateFields['notificationSettings.promotions'] = promotions;
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updateFields },
      { new: true }
    ).select('notificationSettings');

    res.json({
      success: true,
      message: "Notification settings updated",
      data: user.notificationSettings,
    });
  } catch (error) {
    console.error("Update notification settings error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   POST /api/users/test-notification
// @desc    Send a test push notification to the current user
// @access  Private
router.post("/test-notification", protect, async (req, res) => {
  try {
    const { sendToUser } = require("../services/fcm_service");

    const user = await User.findById(req.user._id).select('fcmTokens username');

    if (!user.fcmTokens || user.fcmTokens.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No FCM tokens registered for this user. Please ensure the app has notification permissions and is properly initialized.",
        tokens: [],
      });
    }

    const result = await sendToUser(
      req.user._id,
      {
        title: "Test Notification 🔔",
        body: `Hello ${user.username}! This is a test notification from GrabGo.`,
      },
      {
        type: "test",
        timestamp: new Date().toISOString(),
      }
    );

    res.json({
      success: result.success,
      message: result.success
        ? "Test notification sent successfully!"
        : `Failed to send: ${result.reason}`,
      tokensCount: user.fcmTokens.length,
      result,
    });
  } catch (error) {
    console.error("Test notification error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   GET /api/users/fcm-tokens
// @desc    Get FCM tokens for current user (for debugging)
// @access  Private
router.get("/fcm-tokens", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('fcmTokens');

    res.json({
      success: true,
      tokensCount: user.fcmTokens?.length || 0,
      tokens: user.fcmTokens?.map(t => ({
        platform: t.platform,
        deviceId: t.deviceId,
        createdAt: t.createdAt,
        tokenPreview: t.token ? `${t.token.substring(0, 20)}...` : null,
      })) || [],
    });
  } catch (error) {
    console.error("Get FCM tokens error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

module.exports = router;
