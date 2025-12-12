const express = require("express");
const { body, validationResult } = require("express-validator");
const Order = require("../models/Order");
const Food = require("../models/Food");
const Restaurant = require("../models/Restaurant");
const { protect, authorize } = require("../middleware/auth");
const { sendOrderNotification } = require("../services/fcm_service");
const ReferralService = require("../services/ReferralService");

const router = express.Router();

/**
 * Helper to send order status notification to customer
 */
const notifyOrderStatusChange = async (order, status, customMessage = null) => {
  try {
    if (!order.customer) return;

    const customerId = order.customer._id?.toString() || order.customer.toString();

    await sendOrderNotification(
      customerId,
      order._id.toString(),
      order.orderNumber,
      status,
      customMessage
    );
  } catch (error) {
    console.error('Error sending order notification:', error.message);
  }
};

/**
 * Helper to send notification to rider when assigned
 */
const notifyRiderAssignment = async (riderId, order) => {
  try {
    const { sendToUser } = require("../services/fcm_service");

    await sendToUser(
      riderId,
      {
        title: '🚴 New Delivery Assignment',
        body: `Order #${order.orderNumber} has been assigned to you. Tap to view details.`,
      },
      {
        type: 'rider_assignment',
        orderId: order._id.toString(),
        orderNumber: order.orderNumber,
      }
    );
  } catch (error) {
    console.error('Error sending rider assignment notification:', error.message);
  }
};

router.post(
  "/",
  protect,
  [
    body("restaurant").notEmpty().withMessage("Restaurant is required"),
    body("items")
      .isArray({ min: 1 })
      .withMessage("At least one item is required"),
    body("deliveryAddress")
      .notEmpty()
      .withMessage("Delivery address is required"),
    body("paymentMethod")
      .isIn(["cash", "card", "mobile_money", "mtn_momo", "online"])
      .withMessage("Invalid payment method"),
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

      const { restaurant, items, deliveryAddress, paymentMethod, notes, orderNumber } =
        req.body;

      const restaurantDoc = await Restaurant.findById(restaurant);
      if (!restaurantDoc) {
        return res.status(404).json({
          success: false,
          message: "Restaurant not found",
        });
      }

      let subtotal = 0;
      const orderItems = [];

      for (const item of items) {
        const food = await Food.findById(item.food);
        if (!food) {
          return res.status(404).json({
            success: false,
            message: `Food item ${item.food} not found`,
          });
        }

        const itemTotal = food.price * item.quantity;
        subtotal += itemTotal;

        orderItems.push({
          food: food._id,
          name: food.name,
          quantity: item.quantity,
          price: food.price,
          image: food.image,
        });
      }

      const deliveryFee = restaurantDoc.delivery_fee || 0;
      const tax = subtotal * 0.05;
      let totalAmount = subtotal + deliveryFee + tax;

      // Apply referral credits if available
      const creditResult = await ReferralService.applyCreditsToOrder(req.user._id, totalAmount);
      const creditApplied = creditResult.appliedAmount;
      if (creditApplied > 0) {
        totalAmount = creditResult.newTotal;
      }

      const order = await Order.create({
        orderNumber,
        customer: req.user._id,
        restaurant: restaurant,
        items: orderItems,
        subtotal,
        deliveryFee,
        tax,
        totalAmount,
        deliveryAddress,
        paymentMethod,
        notes,
        status: "pending",
      });

      await order.populate("restaurant", "restaurant_name logo");
      await order.populate("customer", "username email phone");

      // Mark credits as used
      if (creditApplied > 0 && creditResult.creditsUsed.length > 0) {
        await ReferralService.markCreditsAsUsed(creditResult.creditsUsed, order._id);
      }

      // Check if this is user's first order and complete referral
      const userOrderCount = await Order.countDocuments({ customer: req.user._id });
      if (userOrderCount === 1) {
        // This is the first order, complete referral if exists
        const referralResult = await ReferralService.completeReferral(
          req.user._id,
          order._id,
          subtotal + deliveryFee + tax // Use original amount before credits
        );

        if (referralResult.success) {
          console.log(`Referral completed for user ${req.user._id}`);
          // Notification sent automatically by ReferralService.completeReferral()
        }
      }

      res.status(201).json({
        success: true,
        message: "Order created successfully",
        data: order,
      });
    } catch (error) {
      console.error("Create order error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.get("/", protect, async (req, res) => {
  try {
    let query = {};

    // Debug logging
    console.log("🔍 Orders API Debug:");
    console.log("- User ID:", req.user._id);
    console.log("- User role:", req.user.role);
    console.log("- User email:", req.user.email);

    if (req.user.role === "customer") {
      query.customer = req.user._id;
      console.log("- Query for customer:", query);
      console.log("- User ID type:", typeof req.user._id);
      console.log("- User ID string:", req.user._id.toString());
    } else if (req.user.role === "restaurant") {
      const restaurant = await Restaurant.findOne({ email: req.user.email });
      if (restaurant) {
        query.restaurant = restaurant._id;
      } else {
        return res.json({
          success: true,
          message: "No orders found",
          data: [],
        });
      }
    } else if (req.user.role === "rider") {
      query.rider = req.user._id;
    }

    const orders = await Order.find(query)
      .populate("customer", "username email phone")
      .populate("restaurant", "restaurant_name logo")
      .populate("rider", "username email phone")
      .populate("items.food", "name price image")
      .sort({ createdAt: -1 });

    console.log("- Orders found:", orders.length);
    if (orders.length > 0) {
      console.log("- First order:", orders[0].orderNumber, "for customer:", orders[0].customer);
    }

    res.json({
      success: true,
      message: "Orders retrieved successfully",
      data: orders,
    });
  } catch (error) {
    console.error("Get orders error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

/**
 * Get user's recent order items for "Order Again" section
 * Returns unique food items from user's completed orders
 */
router.get("/recent-items", protect, async (req, res) => {
  try {
    // Get user's completed orders with food items
    const orders = await Order.find({
      customer: req.user._id,
      status: "delivered"
    })
      .populate("items.food")
      .sort({ deliveredDate: -1 })
      .limit(50); // Last 50 orders

    // Extract unique food items with order info
    const foodItemsMap = new Map();

    orders.forEach(order => {
      order.items.forEach(item => {
        if (!item.food) return; // Skip if food was deleted

        const foodId = item.food._id.toString();
        if (!foodItemsMap.has(foodId)) {
          const daysSince = Math.floor(
            (Date.now() - order.deliveredDate) / (1000 * 60 * 60 * 24)
          );

          foodItemsMap.set(foodId, {
            foodItem: item.food,
            lastOrderedAt: order.deliveredDate,
            orderCount: 1,
            daysAgo: daysSince
          });
        } else {
          // Increment order count for this food item
          const existing = foodItemsMap.get(foodId);
          existing.orderCount++;
          // Keep the most recent order date
          if (order.deliveredDate > existing.lastOrderedAt) {
            existing.lastOrderedAt = order.deliveredDate;
            existing.daysAgo = Math.floor(
              (Date.now() - order.deliveredDate) / (1000 * 60 * 60 * 24)
            );
          }
        }
      });
    });

    // Convert to array and sort by most recent
    const recentItems = Array.from(foodItemsMap.values())
      .sort((a, b) => b.lastOrderedAt - a.lastOrderedAt)
      .slice(0, 10); // Return top 10 most recent

    res.json({
      success: true,
      message: "Recent items retrieved successfully",
      data: recentItems
    });
  } catch (error) {
    console.error("Get recent items error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
});

router.get("/:orderId", protect, async (req, res) => {
  try {
    const order = await Order.findById(req.params.orderId)
      .populate("customer", "username email phone")
      .populate("restaurant", "restaurant_name logo address phone")
      .populate("rider", "username email phone")
      .populate("items.food", "name price image description");

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (
      req.user.role === "customer" &&
      order.customer._id.toString() !== req.user._id.toString()
    ) {
      return res.status(403).json({
        success: false,
        message: "Not authorized to view this order",
      });
    }

    res.json({
      success: true,
      message: "Order retrieved successfully",
      data: order,
    });
  } catch (error) {
    console.error("Get order error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.put(
  "/:orderId/status",
  protect,
  [
    body("status")
      .isIn([
        "pending",
        "confirmed",
        "preparing",
        "ready",
        "picked_up",
        "on_the_way",
        "delivered",
        "cancelled",
      ])
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

      const { orderId } = req.params;
      const { status, cancellationReason } = req.body;

      const order = await Order.findById(orderId);
      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (req.user.role === "customer" && status !== "cancelled") {
        return res.status(403).json({
          success: false,
          message: "Customers can only cancel orders",
        });
      }

      order.status = status;

      if (status === "delivered") {
        order.deliveredDate = new Date();

        if (order.rider) {
          const Transaction = require("../models/Transaction");
          const RiderWallet = require("../models/RiderWallet");

          const existingTransaction = await Transaction.findOne({
            order: order._id,
            type: "delivery",
            rider: order.rider,
          });

          if (!existingTransaction) {
            const deliveryFee = order.deliveryFee || 0;
            const tip = 0;

            if (deliveryFee > 0) {
              await Transaction.create({
                rider: order.rider,
                order: order._id,
                type: "delivery",
                amount: deliveryFee,
                description: `Delivery fee for order ${order.orderNumber}`,
                status: "completed",
                processedAt: new Date(),
              });

              let wallet = await RiderWallet.findOne({ rider: order.rider });
              if (!wallet) {
                wallet = await RiderWallet.create({ rider: order.rider });
              }
              await wallet.updateBalance();
            }
          }
        }
      } else if (status === "cancelled") {
        order.cancelledDate = new Date();
        if (cancellationReason) {
          order.cancellationReason = cancellationReason;
        }
      }

      await order.save();

      await order.populate("customer", "username email phone");
      await order.populate("restaurant", "restaurant_name logo");
      await order.populate("rider", "username email phone");

      // Send push notification to customer about order status change
      notifyOrderStatusChange(order, status);

      res.json({
        success: true,
        message: "Order status updated successfully",
        data: order,
      });
    } catch (error) {
      console.error("Update order status error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

router.put(
  "/:orderId/assign-rider",
  protect,
  authorize("admin", "rider"),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { riderId } = req.body;

      const order = await Order.findById(orderId);
      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      const User = require("../models/User");
      const rider = await User.findById(riderId);
      if (!rider || rider.role !== "rider") {
        return res.status(400).json({
          success: false,
          message: "Invalid rider",
        });
      }

      order.rider = riderId;
      if (order.status === "ready") {
        order.status = "picked_up";
      }
      await order.save();

      await order.populate("rider", "username email phone");
      await order.populate("customer", "username email phone");

      // Notify rider about new assignment
      notifyRiderAssignment(riderId, order);

      // Notify customer that a rider has been assigned
      notifyOrderStatusChange(order, 'picked_up', `${rider.username} is picking up your order!`);

      res.json({
        success: true,
        message: "Rider assigned successfully",
        data: order,
      });
    } catch (error) {
      console.error("Assign rider error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

module.exports = router;
