const express = require("express");
const { body, validationResult } = require("express-validator");
const Order = require("../models/Order");
const Transaction = require("../models/Transaction");
const RiderWallet = require("../models/RiderWallet");
const Rider = require("../models/Rider");
const Chat = require("../models/Chat");
const { protect, authorize } = require("../middleware/auth");
const { uploadSingle, uploadToCloudinary } = require("../middleware/upload");

const router = express.Router();

router.get(
  "/available-orders",
  protect,
  authorize("rider", "admin"),
  async (req, res) => {
    try {
      const availableOrders = await Order.find({
        rider: null,
        status: { $in: ["confirmed", "preparing", "ready"] },
      })
        .populate("customer", "username email phone")
        .populate(
          "restaurant",
          "restaurantName logo location"
        )
        .sort({ createdAt: -1 })
        .limit(50);

      res.json({
        success: true,
        message: "Available orders retrieved successfully",
        data: availableOrders,
      });
    } catch (error) {
      console.error("Get available orders error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.post(
  "/accept-order/:orderId",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const { orderId } = req.params;

      const order = await Order.findById(orderId);
      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (order.rider) {
        return res.status(400).json({
          success: false,
          message: "Order already assigned to a rider",
        });
      }

      if (!["confirmed", "preparing", "ready"].includes(order.status)) {
        return res.status(400).json({
          success: false,
          message: "Order is not available for pickup",
        });
      }

      order.rider = req.user._id;
      if (order.status === "ready") {
        order.status = "picked_up";
      }
      await order.save();

      // Ensure chat exists between customer and rider for this order
      try {
        let chat = await Chat.findOne({ order: order._id });
        if (!chat) {
          chat = await Chat.create({
            order: order._id,
            customer: order.customer,
            rider: order.rider,
            messages: [],
          });
        }
      } catch (chatError) {
        console.error("Ensure chat for accepted order error:", chatError);
      }

      await order.populate("customer", "username email phone");
      await order.populate("restaurant", "restaurant_name logo address");
      await order.populate("rider", "username email phone");

      res.json({
        success: true,
        message: "Order accepted successfully",
        data: order,
      });
    } catch (error) {
      console.error("Accept order error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.get("/wallet", protect, authorize("rider"), async (req, res) => {
  try {
    let wallet = await RiderWallet.findOne({ rider: req.user._id });

    if (!wallet) {
      wallet = await RiderWallet.create({ rider: req.user._id });
    } else {
      await wallet.updateBalance();
    }

    res.json({
      success: true,
      message: "Wallet retrieved successfully",
      data: {
        balance: wallet.balance,
        totalEarnings: wallet.totalEarnings,
        totalWithdrawals: wallet.totalWithdrawals,
        pendingWithdrawals: wallet.pendingWithdrawals,
      },
    });
  } catch (error) {
    console.error("Get wallet error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.get("/earnings", protect, authorize("rider"), async (req, res) => {
  try {
    const { period = "allTime" } = req.query;

    let startDate = null;
    const now = new Date();

    switch (period) {
      case "today":
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case "thisWeek":
        const dayOfWeek = now.getDay();
        startDate = new Date(now);
        startDate.setDate(now.getDate() - dayOfWeek);
        startDate.setHours(0, 0, 0, 0);
        break;
      case "thisMonth":
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      default:
        startDate = null;
    }

    const query = {
      rider: req.user._id,
      type: { $in: ["delivery", "tip", "bonus"] },
      status: "completed",
    };

    if (startDate) {
      query.createdAt = { $gte: startDate };
    }

    const earnings = await Transaction.find(query)
      .populate("order", "orderNumber totalAmount")
      .sort({ createdAt: -1 });

    // Calculate totals
    const totals = await Transaction.aggregate([
      { $match: query },
      {
        $group: {
          _id: "$type",
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    const summary = {
      total: 0,
      delivery: 0,
      tip: 0,
      bonus: 0,
    };

    totals.forEach((item) => {
      summary[item._id] = item.total;
      summary.total += item.total;
    });

    res.json({
      success: true,
      message: "Earnings retrieved successfully",
      data: {
        earnings,
        summary,
        period,
      },
    });
  } catch (error) {
    console.error("Get earnings error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.get("/transactions", protect, authorize("rider"), async (req, res) => {
  try {
    const { period = "allTime", type, status } = req.query;

    let startDate = null;
    const now = new Date();

    switch (period) {
      case "today":
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case "thisWeek":
        const dayOfWeek = now.getDay();
        startDate = new Date(now);
        startDate.setDate(now.getDate() - dayOfWeek);
        startDate.setHours(0, 0, 0, 0);
        break;
      case "thisMonth":
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      default:
        startDate = null;
    }

    const query = { rider: req.user._id };

    if (startDate) {
      query.createdAt = { $gte: startDate };
    }

    if (type) {
      query.type = type;
    }

    if (status) {
      query.status = status;
    }

    const transactions = await Transaction.find(query)
      .populate("order", "orderNumber totalAmount")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      message: "Transactions retrieved successfully",
      data: transactions,
    });
  } catch (error) {
    console.error("Get transactions error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.post(
  "/withdraw",
  protect,
  authorize("rider"),
  [
    body("amount").isFloat({ min: 1 }).withMessage("Amount must be at least 1"),
    body("withdrawalMethod")
      .isIn(["bank_account", "mtn_mobile_money", "vodafone_cash"])
      .withMessage("Invalid withdrawal method"),
    body("withdrawalAccount")
      .notEmpty()
      .withMessage("Withdrawal account is required"),
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

      const { amount, withdrawalMethod, withdrawalAccount, description } =
        req.body;

      let wallet = await RiderWallet.findOne({ rider: req.user._id });
      if (!wallet) {
        wallet = await RiderWallet.create({ rider: req.user._id });
        await wallet.updateBalance();
      } else {
        await wallet.updateBalance();
      }

      if (wallet.balance < amount) {
        return res.status(400).json({
          success: false,
          message: "Insufficient balance",
        });
      }

      const transaction = await Transaction.create({
        rider: req.user._id,
        type: "withdrawal",
        amount: parseFloat(amount),
        description:
          description || `Withdrawal to ${withdrawalMethod.replace("_", " ")}`,
        withdrawalMethod,
        withdrawalAccount,
        status: "pending",
      });

      await wallet.updateBalance();

      res.status(201).json({
        success: true,
        message: "Withdrawal request submitted successfully",
        data: transaction,
      });
    } catch (error) {
      console.error("Withdraw error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.put(
  "/transactions/:transactionId/status",
  protect,
  authorize("admin"),
  [
    body("status")
      .isIn(["pending", "completed", "failed"])
      .withMessage("Invalid status"),
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

      const { transactionId } = req.params;
      const { status } = req.body;

      const transaction = await Transaction.findById(transactionId);
      if (!transaction) {
        return res.status(404).json({
          success: false,
          message: "Transaction not found",
        });
      }

      transaction.status = status;
      if (status === "completed") {
        transaction.processedAt = new Date();
      }
      await transaction.save();

      const wallet = await RiderWallet.findOne({ rider: transaction.rider });
      if (wallet) {
        await wallet.updateBalance();
      }

      res.json({
        success: true,
        message: "Transaction status updated successfully",
        data: transaction,
      });
    } catch (error) {
      console.error("Update transaction status error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// @route   POST /api/riders/verification
// @desc    Submit rider verification data
// @access  Private (rider only)
router.post(
  "/verification",
  protect,
  authorize("rider"),
  uploadSingle("vehicleImage"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const {
        vehicleType,
        licensePlateNumber,
        vehicleBrand,
        vehicleModel,
        nationalIdType,
        nationalIdNumber,
        paymentMethod,
        bankName,
        accountNumber,
        accountHolderName,
        mobileMoneyProvider,
        mobileMoneyNumber,
        agreedToTerms,
        agreedToLocationAccess,
        agreedToAccuracy,
      } = req.body;

      // Validate vehicle type
      const validVehicleTypes = ["motorcycle", "bicycle", "car", "scooter"];
      if (
        vehicleType &&
        !validVehicleTypes.includes(vehicleType.toLowerCase())
      ) {
        return res.status(400).json({
          success: false,
          message: `Invalid vehicle type. Must be one of: ${validVehicleTypes.join(
            ", "
          )}`,
        });
      }

      // Validate national ID type
      const validNationalIdTypes = [
        "national_id",
        "passport",
        "drivers_license",
      ];
      if (
        nationalIdType &&
        !validNationalIdTypes.includes(nationalIdType.toLowerCase())
      ) {
        return res.status(400).json({
          success: false,
          message: `Invalid national ID type. Must be one of: ${validNationalIdTypes.join(
            ", "
          )}`,
        });
      }

      // Validate payment method
      const validPaymentMethods = ["bank_account", "mobile_money"];
      if (
        paymentMethod &&
        !validPaymentMethods.includes(paymentMethod.toLowerCase())
      ) {
        return res.status(400).json({
          success: false,
          message: `Invalid payment method. Must be one of: ${validPaymentMethods.join(
            ", "
          )}`,
        });
      }

      // Validate mobile money provider
      const validMobileMoneyProviders = ["mtn", "vodafone", "airtel", "tigo"];
      if (
        mobileMoneyProvider &&
        !validMobileMoneyProviders.includes(mobileMoneyProvider.toLowerCase())
      ) {
        return res.status(400).json({
          success: false,
          message: `Invalid mobile money provider. Must be one of: ${validMobileMoneyProviders.join(
            ", "
          )}`,
        });
      }

      // Check if rider verification already exists
      let rider = await Rider.findOne({ user: req.user._id });

      if (rider && rider.verificationStatus === "approved") {
        return res.status(400).json({
          success: false,
          message:
            "Your verification has already been approved. Contact support to make changes.",
        });
      }

      // Prepare rider data with normalized values
      const riderData = {
        user: req.user._id,
        vehicleType: vehicleType ? vehicleType.toLowerCase() : null,
        licensePlateNumber,
        vehicleBrand,
        vehicleModel,
        nationalIdType: nationalIdType ? nationalIdType.toLowerCase() : null,
        nationalIdNumber,
        paymentMethod: paymentMethod ? paymentMethod.toLowerCase() : null,
        bankName,
        accountNumber,
        accountHolderName,
        mobileMoneyProvider: mobileMoneyProvider
          ? mobileMoneyProvider.toLowerCase()
          : null,
        mobileMoneyNumber,
        agreedToTerms: agreedToTerms === "true" || agreedToTerms === true,
        agreedToLocationAccess:
          agreedToLocationAccess === "true" || agreedToLocationAccess === true,
        agreedToAccuracy:
          agreedToAccuracy === "true" || agreedToAccuracy === true,
        verificationStatus: "pending",
      };

      // Handle vehicle image upload
      if (req.file && req.file.cloudinaryUrl) {
        riderData.vehicleImage = req.file.cloudinaryUrl;
      }

      // Create or update rider verification
      if (rider) {
        // Update existing verification
        Object.assign(rider, riderData);
        await rider.save();
      } else {
        // Create new verification
        rider = await Rider.create(riderData);
      }

      res.status(201).json({
        success: true,
        message:
          "Verification data submitted successfully. Your application is under review.",
        data: rider,
      });
    } catch (error) {
      console.error("Submit verification error:", error);

      // Handle Mongoose validation errors
      if (error.name === "ValidationError") {
        const errors = Object.values(error.errors).map((err) => err.message);
        return res.status(400).json({
          success: false,
          message: "Validation error",
          errors: errors,
        });
      }

      // Handle duplicate key errors
      if (error.code === 11000) {
        const field = Object.keys(error.keyPattern)[0];
        return res.status(400).json({
          success: false,
          message: `${field} already exists`,
        });
      }

      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// @route   GET /api/riders/verification
// @desc    Get rider verification data and status
// @access  Private (rider only)
router.get("/verification", protect, authorize("rider"), async (req, res) => {
  try {
    const rider = await Rider.findOne({ user: req.user._id });

    if (!rider) {
      return res.status(404).json({
        success: false,
        message:
          "Verification data not found. Please submit your verification information.",
      });
    }

    res.json({
      success: true,
      message: "Verification data retrieved successfully",
      data: rider,
    });
  } catch (error) {
    console.error("Get verification error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// @route   PUT /api/riders/verification
// @desc    Update rider verification data (only if pending or rejected)
// @access  Private (rider only)
router.put(
  "/verification",
  protect,
  authorize("rider"),
  uploadSingle("vehicleImage"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const rider = await Rider.findOne({ user: req.user._id });

      if (!rider) {
        return res.status(404).json({
          success: false,
          message:
            "Verification data not found. Please submit your verification information first.",
        });
      }

      if (rider.verificationStatus === "approved") {
        return res.status(400).json({
          success: false,
          message:
            "Cannot update approved verification. Contact support to make changes.",
        });
      }

      // Validate vehicle type if provided
      if (req.body.vehicleType) {
        const validVehicleTypes = ["motorcycle", "bicycle", "car", "scooter"];
        if (!validVehicleTypes.includes(req.body.vehicleType.toLowerCase())) {
          return res.status(400).json({
            success: false,
            message: `Invalid vehicle type. Must be one of: ${validVehicleTypes.join(
              ", "
            )}`,
          });
        }
      }

      // Validate national ID type if provided
      if (req.body.nationalIdType) {
        const validNationalIdTypes = [
          "national_id",
          "passport",
          "drivers_license",
        ];
        if (
          !validNationalIdTypes.includes(req.body.nationalIdType.toLowerCase())
        ) {
          return res.status(400).json({
            success: false,
            message: `Invalid national ID type. Must be one of: ${validNationalIdTypes.join(
              ", "
            )}`,
          });
        }
      }

      // Validate payment method if provided
      if (req.body.paymentMethod) {
        const validPaymentMethods = ["bank_account", "mobile_money"];
        if (
          !validPaymentMethods.includes(req.body.paymentMethod.toLowerCase())
        ) {
          return res.status(400).json({
            success: false,
            message: `Invalid payment method. Must be one of: ${validPaymentMethods.join(
              ", "
            )}`,
          });
        }
      }

      // Validate mobile money provider if provided
      if (req.body.mobileMoneyProvider) {
        const validMobileMoneyProviders = ["mtn", "vodafone", "airtel", "tigo"];
        if (
          !validMobileMoneyProviders.includes(
            req.body.mobileMoneyProvider.toLowerCase()
          )
        ) {
          return res.status(400).json({
            success: false,
            message: `Invalid mobile money provider. Must be one of: ${validMobileMoneyProviders.join(
              ", "
            )}`,
          });
        }
      }

      // Update allowed fields
      const allowedUpdates = [
        "vehicleType",
        "licensePlateNumber",
        "vehicleBrand",
        "vehicleModel",
        "nationalIdType",
        "nationalIdNumber",
        "paymentMethod",
        "bankName",
        "accountNumber",
        "accountHolderName",
        "mobileMoneyProvider",
        "mobileMoneyNumber",
        "agreedToTerms",
        "agreedToLocationAccess",
        "agreedToAccuracy",
      ];

      allowedUpdates.forEach((field) => {
        if (req.body[field] !== undefined) {
          if (field.includes("agreed")) {
            rider[field] =
              req.body[field] === "true" || req.body[field] === true;
          } else if (
            field === "vehicleType" ||
            field === "nationalIdType" ||
            field === "paymentMethod" ||
            field === "mobileMoneyProvider"
          ) {
            // Normalize enum fields to lowercase
            rider[field] = req.body[field]
              ? req.body[field].toLowerCase()
              : req.body[field];
          } else {
            rider[field] = req.body[field];
          }
        }
      });

      // Handle vehicle image upload
      if (req.file && req.file.cloudinaryUrl) {
        rider.vehicleImage = req.file.cloudinaryUrl;
      }

      // Reset status to pending if it was rejected
      if (rider.verificationStatus === "rejected") {
        rider.verificationStatus = "pending";
        rider.rejectionReason = null;
      }

      await rider.save();

      res.json({
        success: true,
        message: "Verification data updated successfully",
        data: rider,
      });
    } catch (error) {
      console.error("Update verification error:", error);

      // Handle Mongoose validation errors
      if (error.name === "ValidationError") {
        const errors = Object.values(error.errors).map((err) => err.message);
        return res.status(400).json({
          success: false,
          message: "Validation error",
          errors: errors,
        });
      }

      // Handle duplicate key errors
      if (error.code === 11000) {
        const field = Object.keys(error.keyPattern)[0];
        return res.status(400).json({
          success: false,
          message: `${field} already exists`,
        });
      }

      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// @route   POST /api/riders/verification/upload-id
// @desc    Upload ID images (front, back, or selfie)
// @access  Private (rider only)
router.post(
  "/verification/upload-id",
  protect,
  authorize("rider"),
  uploadSingle("idImage"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const { imageType } = req.body; // 'front', 'back', or 'selfie'

      if (!["front", "back", "selfie"].includes(imageType)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid image type. Must be "front", "back", or "selfie"',
        });
      }

      if (!req.file || !req.file.cloudinaryUrl) {
        return res.status(400).json({
          success: false,
          message: "No image uploaded",
        });
      }

      let rider = await Rider.findOne({ user: req.user._id });

      if (!rider) {
        rider = await Rider.create({ user: req.user._id });
      }

      // Update the appropriate image field
      if (imageType === "front") {
        rider.idFrontImage = req.file.cloudinaryUrl;
      } else if (imageType === "back") {
        rider.idBackImage = req.file.cloudinaryUrl;
      } else if (imageType === "selfie") {
        rider.selfiePhoto = req.file.cloudinaryUrl;
      }

      await rider.save();

      res.json({
        success: true,
        message: "ID image uploaded successfully",
        data: {
          imageType,
          imageUrl: req.file.cloudinaryUrl,
        },
      });
    } catch (error) {
      console.error("Upload ID image error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// @route   PUT /api/riders/verification/status
// @desc    Update verification status (admin only)
// @access  Private (admin only)
router.put(
  "/verification/status/:riderId",
  protect,
  authorize("admin"),
  [
    body("status")
      .isIn(["pending", "under_review", "approved", "rejected"])
      .withMessage("Invalid status"),
    body("rejectionReason").optional().isString(),
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

      const { riderId } = req.params;
      const { status, rejectionReason } = req.body;

      const rider = await Rider.findById(riderId);
      if (!rider) {
        return res.status(404).json({
          success: false,
          message: "Rider verification not found",
        });
      }

      rider.verificationStatus = status;
      if (status === "approved") {
        rider.verifiedAt = new Date();
        rider.rejectionReason = null;
      } else if (status === "rejected" && rejectionReason) {
        rider.rejectionReason = rejectionReason;
      }

      await rider.save();

      res.json({
        success: true,
        message: "Verification status updated successfully",
        data: rider,
      });
    } catch (error) {
      console.error("Update verification status error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

module.exports = router;
