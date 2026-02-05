const express = require("express");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
const { protect, authorize } = require("../middleware/auth");
const { cacheMiddleware } = require("../middleware/cache");
const cache = require("../utils/cache");
const { sendOrderNotification, sendToUser } = require("../services/fcm_service");
const { createNotification } = require("../services/notification_service");
const ReferralService = require("../services/referral_service");
const { getIO } = require("../utils/socket");
const dispatchService = require("../services/dispatch_service");

const router = express.Router();

/**
 * Helper to send order status notification to customer
 */
const notifyOrderStatusChange = async (order, status, customMessage = null, io = null) => {
  try {
    if (!order.customerId && !order.customer) return;

    const customerId = order.customerId || order.customer.id;
    const orderNumber = order.orderNumber;
    const orderId = order.id;

    // 1. Send FCM push notification
    await sendOrderNotification(
      customerId,
      orderId,
      orderNumber,
      status,
      customMessage
    );

    // 2. Create in-app notification with WebSocket delivery
    const statusMessages = {
      confirmed: 'Your order has been confirmed!',
      preparing: 'Your order is being prepared.',
      ready: 'Your order is ready for pickup!',
      picked_up: 'Your order has been picked up by the rider.',
      on_the_way: 'Your order is on the way!',
      delivered: 'Your order has been delivered. Enjoy!',
      cancelled: 'Your order has been cancelled.',
    };

    const statusEmojis = {
      confirmed: '✅',
      preparing: '🍳',
      ready: '📦',
      picked_up: '🚴',
      on_the_way: '🛣️',
      delivered: '✅',
      cancelled: '❌',
    };

    const emoji = statusEmojis[status] || '📦';
    const message = customMessage || statusMessages[status] || `Order status: ${status}`;

    const ioInstance = io || getIO();
    if (ioInstance) {
      await createNotification(
        customerId,
        'order',
        `${emoji} Order #${orderNumber}`,
        message,
        {
          orderId,
          orderNumber,
          status,
          route: `/orders/${orderId}`
        },
        ioInstance
      );
    }
  } catch (error) {
    console.error('Error sending order notification:', error.message);
  }
};

/**
 * Helper to send notification to rider when assigned
 */
const notifyRiderAssignment = async (riderId, order) => {
  try {
    await sendToUser(
      riderId,
      {
        title: '🚴 New Delivery Assignment',
        body: `Order #${order.orderNumber} has been assigned to you. Tap to view details.`,
      },
      {
        type: 'rider_assignment',
        orderId: order.id,
        orderNumber: order.orderNumber,
      }
    );
  } catch (error) {
    console.error('Error sending rider assignment notification:', error.message);
  }
};

/**
 * Helper to generate unique order number
 */
const generateOrderNumber = async () => {
  const timestamp = Date.now();
  const random = Math.floor(Math.random() * 10000);
  let orderNumber = `ORD-${timestamp}-${random}`;

  let exists = await prisma.order.findUnique({ where: { orderNumber } });
  let attempts = 0;
  while (exists && attempts < 5) {
    const newRandom = Math.floor(Math.random() * 10000);
    orderNumber = `ORD-${timestamp}-${newRandom}`;
    exists = await prisma.order.findUnique({ where: { orderNumber } });
    attempts++;
  }
  return orderNumber;
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

      const {
        restaurant,
        items,
        deliveryAddress,
        paymentMethod,
        notes,
        orderNumber: bodyOrderNumber
      } = req.body;

      const restaurantDoc = await prisma.restaurant.findUnique({
        where: { id: restaurant }
      });

      if (!restaurantDoc) {
        return res.status(404).json({
          success: false,
          message: "Restaurant not found",
        });
      }

      const orderNumber = bodyOrderNumber || await generateOrderNumber();

      let subtotal = 0;
      const orderItemsData = [];

      for (const item of items) {
        const food = await prisma.food.findUnique({
          where: { id: item.food }
        });

        if (!food) {
          return res.status(404).json({
            success: false,
            message: `Food item ${item.food} not found`,
          });
        }

        const itemTotal = food.price * item.quantity;
        subtotal += itemTotal;

        orderItemsData.push({
          itemType: 'Food',
          foodId: food.id,
          name: food.name,
          quantity: item.quantity,
          price: food.price,
          image: food.image,
        });
      }

      const deliveryFee = restaurantDoc.deliveryFee || 0;
      const tax = subtotal * 0.05;
      let totalAmount = subtotal + deliveryFee + tax;

      // Apply referral credits if available
      const creditResult = await ReferralService.applyCreditsToOrder(req.user.id, totalAmount);
      const creditApplied = creditResult.appliedAmount;
      if (creditApplied > 0) {
        totalAmount = creditResult.newTotal;
      }

      // Create order with Prisma transaction to handle nested items
      const order = await prisma.order.create({
        data: {
          orderNumber,
          orderType: 'food',
          customerId: req.user.id,
          restaurantId: restaurant,
          subtotal,
          deliveryFee,
          tax,
          totalAmount,
          deliveryStreet: deliveryAddress.street || deliveryAddress,
          deliveryCity: deliveryAddress.city || 'Unknown',
          deliveryState: deliveryAddress.state,
          deliveryZipCode: deliveryAddress.zipCode,
          deliveryLatitude: deliveryAddress.latitude,
          deliveryLongitude: deliveryAddress.longitude,
          paymentMethod,
          notes,
          status: "pending",
          items: {
            create: orderItemsData
          }
        },
        include: {
          items: {
            include: { food: true }
          },
          restaurant: {
            select: {
              restaurantName: true,
              logo: true,
              location: true,
              phone: true
            }
          },
          customer: {
            select: {
              username: true,
              email: true,
              phone: true
            }
          }
        }
      });

      // Mark credits as used and update cached balance (after order creation)
      if (creditApplied > 0 && creditResult.creditsUsed.length > 0) {
        await ReferralService.markCreditsAsUsed(creditResult.creditsUsed, order.id, req.user.id);
      }

      // Check if this is user's first order and complete referral
      const userOrderCount = await prisma.order.count({
        where: { customerId: req.user.id }
      });

      if (userOrderCount === 1) {
        const io = getIO();
        const referralResult = await ReferralService.completeReferral(
          req.user.id,
          order.id,
          subtotal + deliveryFee + tax, // Use original amount before credits
          io
        );

        if (referralResult.success) {
          console.log(`Referral completed for user ${req.user.id}`);
        }
      }

      // Update user's lastOrderDate for meal nudge targeting
      await prisma.user.update({
        where: { id: req.user.id },
        data: { lastOrderDate: new Date() }
      });

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
    let where = {};

    if (req.user.role === "customer") {
      where.customerId = req.user.id;
    } else if (req.user.role === "restaurant") {
      const restaurant = await prisma.restaurant.findFirst({
        where: { user: { email: req.user.email } }
      });
      if (restaurant) {
        where.restaurantId = restaurant.id;
      } else {
        return res.json({
          success: true,
          message: "No orders found",
          data: [],
        });
      }
    } else if (req.user.role === "rider") {
      where.riderId = req.user.id;
    }

    const orders = await prisma.order.findMany({
      where,
      include: {
        customer: { select: { id: true, username: true, email: true, phone: true, profilePicture: true } },
        restaurant: { select: { restaurantName: true, logo: true, address: true, latitude: true, longitude: true } },
        groceryStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
        pharmacyStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
        rider: { select: { username: true, email: true, phone: true } },
        items: {
          include: { food: true, groceryItem: true, pharmacyItem: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

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
 */
router.get("/recent-items", protect, cacheMiddleware(cache.CACHE_KEYS.FOOD_ITEM + ':recent', 300, true), async (req, res) => {
  try {
    console.log(`\n🔍 [DEBUG] Fetching recent items for user: ${req.user.id}`);

    // First, check what statuses this user's orders actually have
    const allUserOrders = await prisma.order.findMany({
      where: { customerId: req.user.id },
      select: { status: true, orderType: true, id: true },
      take: 10
    });

    if (allUserOrders.length > 0) {
      const statusBreakdown = {};
      allUserOrders.forEach(o => {
        const key = `${o.orderType}:${o.status}`;
        statusBreakdown[key] = (statusBreakdown[key] || 0) + 1;
      });
      console.log(`📊 [DEBUG] User's order status breakdown:`, statusBreakdown);
    } else {
      console.log(`⚠️ [DEBUG] User has NO orders in database at all`);
    }

    // Get user's recent orders (delivered or on_the_way to show what they like)
    const orders = await prisma.order.findMany({
      where: {
        customerId: req.user.id,
        status: { in: ["delivered", "on_the_way", "picked_up"] }
      },
      include: {
        items: {
          include: {
            food: { include: { restaurant: true } },
            groceryItem: { include: { store: true } },
            pharmacyItem: { include: { store: true } }
          }
        }
      },
      orderBy: { orderDate: 'desc' },
      take: 30
    });

    console.log(`📦 [DEBUG] Found ${orders.length} orders`);
    if (orders.length > 0) {
      const totalItems = orders.reduce((sum, o) => sum + o.items.length, 0);
      console.log(`📦 [DEBUG] Total order items: ${totalItems}`);

      // Log item type breakdown
      const itemTypes = {};
      orders.forEach(o => {
        o.items.forEach(item => {
          itemTypes[item.itemType] = (itemTypes[item.itemType] || 0) + 1;
        });
      });
      console.log(`📦 [DEBUG] Item types:`, itemTypes);
    }

    const itemsMap = new Map();

    orders.forEach(order => {
      order.items.forEach(item => {
        // Universal unique key based on item type and id
        let itemId, itemData, type;

        if (item.itemType === 'Food' && item.food) {
          itemId = `food_${item.food.id}`;
          itemData = item.food;
          type = 'Food';
        } else if (item.itemType === 'GroceryItem' && item.groceryItem) {
          itemId = `grocery_${item.groceryItem.id}`;
          itemData = item.groceryItem;
          type = 'GroceryItem';
        } else if (item.itemType === 'PharmacyItem' && item.pharmacyItem) {
          itemId = `pharmacy_${item.pharmacyItem.id}`;
          itemData = item.pharmacyItem;
          type = 'PharmacyItem';
        }

        if (!itemId) return;

        if (!itemsMap.has(itemId)) {
          const orderTimestamp = order.deliveredDate || order.orderDate || order.createdAt;
          const daysSince = orderTimestamp
            ? Math.floor((Date.now() - new Date(orderTimestamp).getTime()) / (1000 * 60 * 60 * 24))
            : 0;

          itemsMap.set(itemId, {
            id: itemId,
            type: type,
            item: itemData,
            lastOrderedAt: orderTimestamp,
            orderCount: 1,
            daysAgo: daysSince
          });
        } else {
          const existing = itemsMap.get(itemId);
          existing.orderCount++;
        }
      });
    });

    const recentItems = Array.from(itemsMap.values())
      .sort((a, b) => new Date(b.lastOrderedAt) - new Date(a.lastOrderedAt))
      .slice(0, 15);

    console.log(`✅ [DEBUG] Returning ${recentItems.length} unique recent items`);
    if (recentItems.length > 0) {
      console.log(`✅ [DEBUG] Sample item types:`, recentItems.slice(0, 3).map(i => i.type));
    }

    res.json({
      success: true,
      message: "Unified recent items retrieved successfully",
      count: recentItems.length,
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
    const order = await prisma.order.findUnique({
      where: { id: req.params.orderId },
      include: {
        customer: { select: { username: true, email: true, phone: true } },
        restaurant: { select: { restaurantName: true, logo: true, location: true, phone: true } },
        rider: { select: { username: true, email: true, phone: true } },
        items: {
          include: { food: true, groceryItem: true, pharmacyItem: true }
        }
      }
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    if (
      req.user.role === "customer" &&
      order.customerId !== req.user.id
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

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

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

      // Use transaction to update order and handle rider earnings if delivered
      const updatedOrder = await prisma.$transaction(async (tx) => {
        let updateData = {
          status,
          updatedAt: new Date()
        };

        if (status === "delivered") {
          updateData.deliveredDate = new Date();

          if (order.riderId) {
            // Check if transaction already exists for this order
            const existingTransaction = await tx.transaction.findFirst({
              where: {
                referenceId: order.id,
                type: "delivery",
                userId: order.riderId,
              }
            });

            if (!existingTransaction) {
              const deliveryFee = order.deliveryFee || 0;

              if (deliveryFee > 0) {
                // Find or create rider wallet
                let wallet = await tx.riderWallet.findUnique({
                  where: { userId: order.riderId }
                });

                if (!wallet) {
                  wallet = await tx.riderWallet.create({
                    data: { userId: order.riderId }
                  });
                }

                // Create transaction
                await tx.transaction.create({
                  data: {
                    walletId: wallet.id,
                    userId: order.riderId,
                    amount: deliveryFee,
                    type: "delivery",
                    description: `Delivery fee for order ${order.orderNumber}`,
                    referenceId: order.id,
                    status: "completed",
                  }
                });

                // Update wallet balance (simplified logic: incremental update)
                await tx.riderWallet.update({
                  where: { id: wallet.id },
                  data: {
                    balance: { increment: deliveryFee },
                    totalEarnings: { increment: deliveryFee }
                  }
                });
              }
            }
          }
        } else if (status === "cancelled") {
          updateData.cancelledDate = new Date();
          if (cancellationReason) {
            updateData.cancellationReason = cancellationReason;
          }
        }

        return await tx.order.update({
          where: { id: orderId },
          data: updateData,
          include: {
            customer: { select: { username: true, email: true, phone: true } },
            restaurant: { select: { restaurantName: true, logo: true, location: true } },
            rider: { select: { username: true, email: true, phone: true } }
          }
        });
      });

      // Send push notification to customer about order status change
      const io = getIO();
      notifyOrderStatusChange(updatedOrder, status, null, io);

      // Reset rider delivery status when order is delivered or cancelled
      if ((status === 'delivered' || status === 'cancelled') && order.riderId) {
        try {
          const RiderStatus = require('../models/RiderStatus');
          await RiderStatus.findOneAndUpdate(
            { riderId: order.riderId },
            { $set: { isOnDelivery: false, currentOrderId: null } }
          );
          console.log(`📍 Reset delivery status for rider ${order.riderId} (order ${status})`);
        } catch (statusError) {
          console.error("Reset rider delivery status error:", statusError);
        }
      }

      // Trigger dispatch when order is confirmed and doesn't have a rider yet
      if (['confirmed', 'preparing', 'ready'].includes(status) && !updatedOrder.riderId) {
        console.log(`🚀 Triggering dispatch for order ${updatedOrder.orderNumber} (status: ${status})`);

        // Run dispatch asynchronously to not block the response
        dispatchService.dispatchOrder(orderId).then(result => {
          if (result.success) {
            console.log(`✅ Dispatch initiated for order ${updatedOrder.orderNumber} -> rider ${result.riderName}`);
          } else {
            console.log(`⚠️ Dispatch failed for order ${updatedOrder.orderNumber}: ${result.error}`);
          }
        }).catch(err => {
          console.error(`❌ Dispatch error for order ${updatedOrder.orderNumber}:`, err.message);
        });
      }

      // Cancel reservations if order is cancelled
      if (status === 'cancelled') {
        dispatchService.cancelOrderReservations(orderId).catch(err => {
          console.error(`Error cancelling reservations for order ${orderId}:`, err.message);
        });
      }

      res.json({
        success: true,
        message: "Order status updated successfully",
        data: updatedOrder,
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

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      const rider = await prisma.user.findUnique({
        where: { id: riderId }
      });

      if (!rider || rider.role !== "rider") {
        return res.status(400).json({
          success: false,
          message: "Invalid rider",
        });
      }

      let statusUpdate = {};
      if (order.status === "ready") {
        statusUpdate = { status: "picked_up" };
      }

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          riderId: riderId,
          ...statusUpdate
        },
        include: {
          rider: { select: { username: true, email: true, phone: true } },
          customer: { select: { username: true, email: true, phone: true } }
        }
      });

      // Notify rider about new assignment
      notifyRiderAssignment(riderId, updatedOrder);

      // Notify customer that a rider has been assigned
      const io = getIO();
      const statusToNotify = updatedOrder.status === 'picked_up' ? 'picked_up' : 'confirmed';
      const customMsg = updatedOrder.status === 'picked_up'
        ? `${rider.username} is picking up your order!`
        : `${rider.username} has been assigned to your order.`;

      notifyOrderStatusChange(updatedOrder, statusToNotify, customMsg, io);

      res.json({
        success: true,
        message: "Rider assigned successfully",
        data: updatedOrder,
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
