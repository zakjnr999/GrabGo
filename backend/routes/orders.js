const express = require("express");
const { body, validationResult } = require("express-validator");
const Order = require("../models/Order");
const Food = require("../models/Food");
const Restaurant = require("../models/Restaurant");
const { protect, authorize } = require("../middleware/auth");

const router = express.Router();

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
      .isIn(["cash", "card", "mobile_money", "online"])
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

      const { restaurant, items, deliveryAddress, paymentMethod, notes } =
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
      const totalAmount = subtotal + deliveryFee + tax;

      const order = await Order.create({
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

    if (req.user.role === "customer") {
      query.customer = req.user._id;
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
