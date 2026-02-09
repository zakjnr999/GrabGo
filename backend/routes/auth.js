const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
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
const {
  requestPhoneOtp,
  verifyPhoneOtp,
  consumePhoneVerificationToken,
  normalizeGhanaPhone,
} = require("../services/otp_service");
const { registerToken, removeToken } = require("../services/fcm_service");
const creditService = require("../services/credit_service");

const router = express.Router();

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || "7d",
  });
};

/**
 * Format user for response - ensures _id and DateOfBirth compatibility
 */
const formatUser = (user) => {
  if (!user) return null;
  return {
    ...user,
    _id: user.id,
    DateOfBirth: user.dateOfBirth, // Map camelCase back to PascalCase for legacy frontend
  };
};

const applySignupPromoCredits = async (userId, promoCode) => {
  if (!promoCode) return { applied: false, reason: "no_code" };

  const code = promoCode.toUpperCase();

  const promo = await prisma.promoCode.findUnique({
    where: { code },
    include: { targetedUsers: true },
  });

  if (!promo || !promo.isActive) return { applied: false, reason: "invalid" };

  const now = new Date();
  if (promo.startDate && now < promo.startDate) return { applied: false, reason: "not_active" };
  if (promo.endDate && now > promo.endDate) return { applied: false, reason: "expired" };
  if (promo.maxUses !== null && promo.currentUses >= promo.maxUses) return { applied: false, reason: "max_used" };
  if (promo.targetedUsers.length > 0) return { applied: false, reason: "targeted_only" };
  if (promo.type !== "fixed") return { applied: false, reason: "unsupported_type" };

  const amount = Number(promo.value);
  if (!Number.isFinite(amount) || amount <= 0) return { applied: false, reason: "invalid_amount" };

  await prisma.promoCode.update({
    where: { id: promo.id },
    data: { currentUses: { increment: 1 } },
  });

  await creditService.grantPromoCredits({
    userId,
    amount,
    promoName: `Promo ${promo.code}`,
  });

  return { applied: true, amount };
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
      promoCode,
      referralCode,
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
      let user = await prisma.user.findFirst({
        where: {
          OR: [{ email }, { googleId }]
        }
      });

      if (user) {
        return res.status(400).json({
          success: false,
          message: "User already exists",
        });
      }

      // Create user
      user = await prisma.user.create({
        data: {
          username: displayName,
          email,
          googleId,
          profilePicture: photoUrl,
          isEmailVerified: true,
          role: (role || "customer").toLowerCase(),
        }
      });

      const token = generateToken(user.id);

      // Apply signup promo credits if provided
      const signupPromoCode = promoCode || referralCode;
      if (signupPromoCode) {
        try {
          const result = await applySignupPromoCredits(user.id, signupPromoCode);
          if (result.applied) {
            console.log(`🎁 Promo credits granted to user ${user.id}: GHS ${result.amount}`);
          }
        } catch (promoError) {
          console.error("Failed to apply signup promo credits:", promoError.message);
        }
      }

      return res.status(201).json({
        message: "User registered successfully",
        user: formatUser(user),
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
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ email }, { username }]
      }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email or username",
      });
    }

    // Create user
    const userRole = (req.body.role || role || "customer").toLowerCase();

    // Hash password manually since Prisma doesn't have pre-save hooks
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const { phoneVerificationToken } = req.body;
    let verifiedPhone = null;
    if (phoneVerificationToken) {
      const consumedPhone = await consumePhoneVerificationToken(phoneVerificationToken);
      if (!consumedPhone) {
        return res.status(400).json({
          success: false,
          message: "Phone verification expired. Please verify your phone again.",
        });
      }
      const phoneDigits = consumedPhone.replace('+', '');
      const existingPhoneUser = await prisma.user.findFirst({
        where: { phone: phoneDigits },
      });
      if (existingPhoneUser) {
        return res.status(400).json({
          success: false,
          message: "Phone number is already in use.",
        });
      }
      verifiedPhone = phoneDigits;
    }

    const userData = {
      username,
      email,
      password: hashedPassword,
      dateOfBirth: DateOfBirth, // Map to camelCase for Prisma
      phone: verifiedPhone || (phone ? String(phone) : null),
      profilePicture,
      role: userRole,
      isPhoneVerified: verifiedPhone ? true : false,
    };

    const user = await prisma.user.create({
      data: userData
    });

    const token = generateToken(user.id);

    // Apply signup promo credits if provided
    const signupPromoCode = promoCode || referralCode;
    if (signupPromoCode) {
      try {
        const result = await applySignupPromoCredits(user.id, signupPromoCode);
        if (result.applied) {
          console.log(`🎁 Promo credits granted to user ${user.id}: GHS ${result.amount}`);
        }
      } catch (promoError) {
        console.error("Failed to apply signup promo credits:", promoError.message);
      }
    }

    res.status(201).json({
      message:
        "User registered successfully. Please verify your email to continue.",
      user: formatUser(user),
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
      let user = await prisma.user.findFirst({
        where: {
          OR: [{ email }, { googleId }]
        }
      });

      if (!user) {
        // Create new user if doesn't exist
        user = await prisma.user.create({
          data: {
            username: displayName || email.split("@")[0],
            email,
            googleId,
            profilePicture: photoUrl,
            isEmailVerified: true,
            role: (req.body.role || "customer").toLowerCase(),
          }
        });
      } else {
        // Update Google ID if not set
        if (!user.googleId) {
          user = await prisma.user.update({
            where: { id: user.id },
            data: {
              googleId,
              profilePicture: photoUrl || user.profilePicture
            }
          });
        }
      }

      if (!user.isActive) {
        return res.status(403).json({
          success: false,
          message: "Account is deactivated",
        });
      }

      const token = generateToken(user.id);

      return res.json({
        message: "Login successful",
        user: formatUser(user),
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

    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { email }
    });

    if (!user || !user.password) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
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

    const token = generateToken(user.id);

    res.json({
      message: "Login successful",
      user: formatUser(user),
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

      if (req.user.id !== userId && !req.user.isAdmin) {
        return res.status(403).json({
          success: false,
          message: "Not authorized to update this user",
        });
      }

      const user = await prisma.user.findUnique({
        where: { id: userId }
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      const updateData = {};

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

        updateData.profilePicture = req.file.cloudinaryUrl;
      } else {
        const { phoneNumber, isPhoneVerified, profilePicture, image } = req.body;

        if (phoneNumber !== undefined) {
          updateData.phone = String(phoneNumber);
        }
        if (isPhoneVerified !== undefined) {
          updateData.isPhoneVerified = isPhoneVerified;
        }

        const pictureToUse = profilePicture || image;
        if (pictureToUse !== undefined && !req.file) {
          updateData.profilePicture = pictureToUse;
        }
      }

      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: updateData
      });

      res.json({
        success: true,
        message: req.file
          ? "Profile picture uploaded successfully"
          : "User updated successfully",
        user: formatUser(updatedUser),
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

      if (req.user.id !== userId && !req.user.isAdmin) {
        return res.status(403).json({
          success: false,
          message: "Not authorized",
        });
      }

      const user = await prisma.user.findUnique({
        where: { id: userId }
      });

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

      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: { profilePicture: req.file.cloudinaryUrl }
      });

      res.json({
        success: true,
        message: "Profile picture uploaded successfully",
        user: formatUser(updatedUser),
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
      user: formatUser(req.user),
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
    const user = await prisma.user.findUnique({
      where: { id: req.params.userId }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.json({
      success: true,
      message: "User retrieved successfully",
      user: formatUser(user),
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
      const user = await prisma.user.findFirst({
        where: {
          email: email.toLowerCase(),
          emailVerificationOTP: otp,
          emailVerificationOTPExpires: { gt: new Date() },
        }
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
      const updatedUser = await prisma.user.update({
        where: { id: user.id },
        data: {
          isEmailVerified: true,
          emailVerificationOTP: null,
          emailVerificationOTPExpires: null,
        }
      });

      // Generate token for the verified user
      const token = generateToken(updatedUser.id);

      res.json({
        success: true,
        user: formatUser(updatedUser),
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
      const user = await prisma.user.findUnique({
        where: { email: email.toLowerCase() }
      });

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

      await prisma.user.update({
        where: { id: user.id },
        data: {
          emailVerificationOTP,
          emailVerificationOTPExpires
        }
      });

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
    const user = await prisma.user.findUnique({
      where: { id: req.user.id }
    });

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

    await prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerificationOTP,
        emailVerificationOTPExpires
      }
    });

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
    const { phoneNumber, userId, channel } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    let user = null;
    if (userId) {
      user = await prisma.user.findUnique({
        where: { id: userId },
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      if (user.isPhoneVerified) {
        return res.status(400).json({
          success: false,
          message: "Phone is already verified",
        });
      }
    } else {
      const normalized = normalizeGhanaPhone(phoneNumber);
      if (normalized) {
        const existingPhoneUser = await prisma.user.findFirst({
          where: { phone: normalized.e164.replace('+', '') },
        });
        if (existingPhoneUser) {
          return res.status(400).json({
            success: false,
            message: "Phone number is already in use.",
          });
        }
      }
    }

    const otpResult = await requestPhoneOtp({
      phoneNumber,
      userId,
      channel,
    });

    if (!otpResult.success) {
      return res.status(400).json({
        success: false,
        message: otpResult.message || "Failed to send OTP.",
        error:
          process.env.NODE_ENV === 'development' || process.env.OTP_DEBUG_ERRORS === 'true'
            ? otpResult.error
            : undefined,
      });
    }

    res.json({
      success: true,
      message: otpResult.message || "OTP sent successfully",
      otp: otpResult.otp,
      channel: otpResult.channel,
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

    if (!phoneNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone number and OTP are required",
      });
    }

    let user = null;
    if (userId) {
      user = await prisma.user.findUnique({
        where: { id: userId }
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }
    }

    const verifyResult = await verifyPhoneOtp({ phoneNumber, userId, otp });
    if (!verifyResult.success) {
      return res.status(400).json({
        success: false,
        message: verifyResult.message || "Invalid OTP",
      });
    }

    if (user) {
      const updatedUser = await prisma.user.update({
        where: { id: userId },
        data: {
          isPhoneVerified: true,
          phone: verifyResult.phoneE164.replace('+', ''),
          phoneVerificationOTP: null,
          phoneVerificationOTPExpires: null,
        }
      });

      const token = generateToken(updatedUser.id);

      return res.json({
        success: true,
        message: "Phone verified successfully",
        user: formatUser(updatedUser),
        token,
      });
    }

    res.json({
      success: true,
      message: "Phone verified successfully",
      phoneNumber: verifyResult.phoneE164,
      verificationToken: verifyResult.verificationToken,
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
    const { phoneNumber, userId, channel } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    let user = null;
    if (userId) {
      user = await prisma.user.findUnique({
        where: { id: userId }
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "User not found",
        });
      }

      if (user.isPhoneVerified) {
        return res.status(400).json({
          success: false,
          message: "Phone is already verified",
        });
      }
    }

    const otpResult = await requestPhoneOtp({
      phoneNumber,
      userId,
      channel,
    });

    if (!otpResult.success) {
      return res.status(400).json({
        success: false,
        message: otpResult.message || "Failed to resend OTP.",
        error:
          process.env.NODE_ENV === 'development' || process.env.OTP_DEBUG_ERRORS === 'true'
            ? otpResult.error
            : undefined,
      });
    }

    res.json({
      success: true,
      message: otpResult.message || "OTP resent successfully",
      otp: otpResult.otp,
      channel: otpResult.channel,
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
      req.user.id,
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

    await removeToken(req.user.id, token);

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

    const data = {};
    if (typeof chatMessages === 'boolean') {
      data.chatMessages = chatMessages;
    }
    if (typeof orderUpdates === 'boolean') {
      data.orderUpdates = orderUpdates;
    }
    if (typeof promotions === 'boolean') {
      data.promoNotifications = promotions;
    }

    const settings = await prisma.userNotificationSettings.upsert({
      where: { userId: req.user.id },
      update: data,
      create: {
        userId: req.user.id,
        ...data
      }
    });

    res.json({
      success: true,
      message: "Notification settings updated",
      data: settings,
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

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { fcmTokens: true }
    });

    if (!user.fcmTokens || user.fcmTokens.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No FCM tokens registered for this user. Please ensure the app has notification permissions and is properly initialized.",
        tokens: [],
      });
    }

    const result = await sendToUser(
      req.user.id,
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
    const tokens = await prisma.userFcmToken.findMany({
      where: { userId: req.user.id }
    });

    res.json({
      success: true,
      tokensCount: tokens.length,
      tokens: tokens.map(t => ({
        platform: t.platform,
        deviceId: t.deviceId,
        createdAt: t.createdAt,
        tokenPreview: t.token ? `${t.token.substring(0, 20)}...` : null,
      })),
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
