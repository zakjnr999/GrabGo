const express = require("express");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
const { protect, authorize } = require("../middleware/auth");
const { uploadSingle, uploadToCloudinary } = require("../middleware/upload");
const dispatchService = require("../services/dispatch_service");
const OrderReservation = require("../models/OrderReservation");

const router = express.Router();

/**
 * Helper to update rider wallet balance
 */
const updateWalletBalance = async (userId) => {
  const wallet = await prisma.riderWallet.findUnique({
    where: { userId }
  });

  if (!wallet) return null;

  const transactions = await prisma.transaction.findMany({
    where: {
      walletId: wallet.id,
      status: "completed"
    }
  });

  const totals = transactions.reduce((acc, tx) => {
    if (["delivery", "tip", "bonus"].includes(tx.type)) {
      acc.earnings += tx.amount;
    } else if (tx.type === "withdrawal") {
      acc.withdrawals += tx.amount;
    }
    return acc;
  }, { earnings: 0, withdrawals: 0 });

  const pendingWithdrawalsSum = await prisma.transaction.aggregate({
    where: {
      walletId: wallet.id,
      type: "withdrawal",
      status: "pending"
    },
    _sum: { amount: true }
  });

  return await prisma.riderWallet.update({
    where: { id: wallet.id },
    data: {
      totalEarnings: totals.earnings,
      totalWithdrawals: totals.withdrawals,
      pendingWithdrawal: pendingWithdrawalsSum._sum.amount || 0,
      balance: totals.earnings - totals.withdrawals,
      updatedAt: new Date()
    }
  });
};

router.get(
  "/available-orders",
  protect,
  authorize("rider", "admin"),
  async (req, res) => {
    try {
      const availableOrders = await prisma.order.findMany({
        where: {
          riderId: null,
          status: { in: ["confirmed", "preparing", "ready"] },
        },
        select: {
          id: true,
          orderNumber: true,
          orderType: true,
          totalAmount: true,
          paymentMethod: true,
          status: true,
          notes: true,
          createdAt: true,
          // Delivery address
          deliveryStreet: true,
          deliveryCity: true,
          deliveryState: true,
          deliveryLatitude: true,
          deliveryLongitude: true,
          // Customer info
          customer: {
            select: {
              id: true,
              username: true,
              email: true,
              phone: true,
              profilePicture: true
            }
          },
          // Restaurant info
          restaurant: {
            select: {
              restaurantName: true,
              logo: true,
              address: true,
              city: true,
              area: true,
              longitude: true,
              latitude: true
            }
          },
          // Grocery store info (for grocery orders)
          groceryStore: {
            select: {
              storeName: true,
              logo: true,
              address: true,
              city: true,
              longitude: true,
              latitude: true
            }
          },
          // Pharmacy store info (for pharmacy orders)
          pharmacyStore: {
            select: {
              storeName: true,
              logo: true,
              address: true,
              city: true,
              longitude: true,
              latitude: true
            }
          },
          // Order items
          items: {
            select: {
              id: true,
              name: true,
              quantity: true,
              price: true
            }
          }
        },
        orderBy: { createdAt: 'desc' },
        take: 50
      });

      // Calculate rider earnings for each order
      const { calculateRiderEarnings, calculateDistance } = require('../utils/riderEarningsCalculator');

      const ordersWithEarnings = availableOrders.map(order => {
        const earnings = calculateRiderEarnings(order, 0); // No tip yet

        return {
          ...order,
          distance: earnings.distance,
          riderEarnings: earnings.riderEarnings,
          earningsBreakdown: {
            baseFee: earnings.riderBaseFee,
            distanceFee: earnings.riderDistanceFee,
            tip: earnings.riderTip,
            platformFee: earnings.platformFee,
            total: earnings.riderEarnings
          }
        };
      });

      // Location-based filtering (optional)
      const riderLat = parseFloat(req.query.lat);
      const riderLon = parseFloat(req.query.lon);
      let radius = parseFloat(req.query.radius) || 10; // Default 10 km

      let filteredOrders = ordersWithEarnings;
      let filterApplied = false;
      let expandedRadius = false;

      if (!isNaN(riderLat) && !isNaN(riderLon)) {
        filterApplied = true;

        // Calculate distance from rider to each restaurant/store
        const ordersWithRiderDistance = ordersWithEarnings.map(order => {
          const pickupLat = order.restaurant?.latitude || order.groceryStore?.latitude || order.pharmacyStore?.latitude;
          const pickupLon = order.restaurant?.longitude || order.groceryStore?.longitude || order.pharmacyStore?.longitude;

          const distanceToPickup = calculateDistance(riderLat, riderLon, pickupLat, pickupLon);

          return {
            ...order,
            distanceToPickup: distanceToPickup
          };
        });

        // Filter by radius
        filteredOrders = ordersWithRiderDistance.filter(order => order.distanceToPickup <= radius);

        // Smart radius expansion if too few orders
        if (filteredOrders.length < 5 && radius === 10) {
          radius = 15;
          filteredOrders = ordersWithRiderDistance.filter(order => order.distanceToPickup <= radius);
          expandedRadius = true;
        }
        if (filteredOrders.length < 5 && radius === 15) {
          radius = 20;
          filteredOrders = ordersWithRiderDistance.filter(order => order.distanceToPickup <= radius);
          expandedRadius = true;
        }

        // Sort by distance to pickup (closest first)
        filteredOrders.sort((a, b) => a.distanceToPickup - b.distanceToPickup);

        console.log(`📍 Filtered ${filteredOrders.length} orders within ${radius} km of rider`);
      }

      // Calculate aggregate statistics
      const statistics = {
        totalOrders: filteredOrders.length,
        totalDropPoints: filteredOrders.length,
        totalEarnings: parseFloat(filteredOrders.reduce((sum, o) => sum + (o.riderEarnings || 0), 0).toFixed(2)),
        totalTips: parseFloat(filteredOrders.reduce((sum, o) => sum + (o.earningsBreakdown?.tip || 0), 0).toFixed(2)),
        totalDistance: parseFloat(filteredOrders.reduce((sum, o) => sum + (o.distance || 0), 0).toFixed(2)),
        averageEarningsPerOrder: filteredOrders.length > 0
          ? parseFloat((filteredOrders.reduce((sum, o) => sum + (o.riderEarnings || 0), 0) / filteredOrders.length).toFixed(2))
          : 0,
        averageDistance: filteredOrders.length > 0
          ? parseFloat((filteredOrders.reduce((sum, o) => sum + (o.distance || 0), 0) / filteredOrders.length).toFixed(2))
          : 0,
        filterApplied: filterApplied,
        radius: radius,
        expandedRadius: expandedRadius
      };

      res.json({
        success: true,
        message: "Available orders retrieved successfully",
        data: {
          orders: filteredOrders,
          statistics: statistics
        }
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

// ==================== ORDER RESERVATION ENDPOINTS ====================

/**
 * @route   GET /riders/active-reservation
 * @desc    Get rider's active order reservation (if any)
 * @access  Private (Rider only)
 */
router.get(
  "/active-reservation",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const reservation = await dispatchService.getActiveReservationForRider(req.user.id);

      if (!reservation) {
        return res.json({
          success: true,
          hasReservation: false,
          data: null
        });
      }

      // Calculate remaining time
      const now = new Date();
      const expiresAt = new Date(reservation.expiresAt);
      const remainingMs = Math.max(0, expiresAt - now);

      res.json({
        success: true,
        hasReservation: true,
        data: {
          reservationId: reservation._id,
          orderId: reservation.orderId,
          orderNumber: reservation.orderNumber,
          expiresAt: reservation.expiresAt,
          remainingMs,
          timeoutMs: reservation.timeoutMs,
          attemptNumber: reservation.attemptNumber,
          estimatedEarnings: reservation.estimatedEarnings,
          distanceToPickup: reservation.distanceToPickup,
          order: reservation.orderSnapshot
        }
      });
    } catch (error) {
      console.error("Get active reservation error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/reservation/:reservationId/accept
 * @desc    Accept an order reservation
 * @access  Private (Rider only)
 */
router.post(
  "/reservation/:reservationId/accept",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const { reservationId } = req.params;
      const riderId = req.user.id;

      // Accept the reservation
      const acceptResult = await dispatchService.acceptReservation(reservationId, riderId);

      if (!acceptResult.success) {
        return res.status(400).json({
          success: false,
          message: acceptResult.error
        });
      }

      // Now actually assign the order to the rider (same logic as accept-order)
      const orderId = acceptResult.orderId;

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found"
        });
      }

      if (order.riderId && order.riderId !== riderId) {
        return res.status(400).json({
          success: false,
          message: "Order already assigned to another rider"
        });
      }

      // Calculate rider earnings and lock them in
      const { calculateRiderEarnings } = require('../utils/riderEarningsCalculator');

      const fullOrder = await prisma.order.findUnique({
        where: { id: orderId },
        include: {
          restaurant: { select: { restaurantName: true, latitude: true, longitude: true } },
          groceryStore: { select: { storeName: true, latitude: true, longitude: true } },
          pharmacyStore: { select: { storeName: true, latitude: true, longitude: true } }
        }
      });

      const earnings = calculateRiderEarnings(fullOrder, 0);

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          riderId: riderId,
          status: order.status === "ready" ? "picked_up" : order.status,
          riderBaseFee: earnings.riderBaseFee,
          riderDistanceFee: earnings.riderDistanceFee,
          riderTip: earnings.riderTip,
          platformFee: earnings.platformFee,
          riderEarnings: earnings.riderEarnings
        },
        include: {
          items: { select: { id: true, name: true, quantity: true, price: true } },
          customer: { select: { username: true, email: true, phone: true, profilePicture: true } },
          restaurant: { select: { restaurantName: true, logo: true, address: true, latitude: true, longitude: true } },
          groceryStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
          pharmacyStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
          rider: { select: { username: true, email: true, phone: true } }
        }
      });

      // Create chat between customer and rider
      try {
        const existingChat = await prisma.chat.findUnique({
          where: { orderId: updatedOrder.id }
        });

        if (!existingChat) {
          await prisma.chat.create({
            data: {
              orderId: updatedOrder.id,
              customerId: updatedOrder.customerId,
              riderId: updatedOrder.riderId,
            }
          });
        }
      } catch (chatError) {
        console.error("Ensure chat for accepted order error:", chatError);
      }

      // Initialize tracking
      try {
        const OrderTracking = require('../models/OrderTracking');
        const trackingService = require('../services/tracking_service');

        await OrderTracking.findOneAndDelete({ orderId: updatedOrder.id });

        const pickupLat = updatedOrder.restaurant?.latitude || updatedOrder.groceryStore?.latitude || updatedOrder.pharmacyStore?.latitude;
        const pickupLon = updatedOrder.restaurant?.longitude || updatedOrder.groceryStore?.longitude || updatedOrder.pharmacyStore?.longitude;

        if (pickupLat && pickupLon && updatedOrder.deliveryLatitude && updatedOrder.deliveryLongitude) {
          await trackingService.initializeTracking(
            updatedOrder.id,
            riderId,
            updatedOrder.customerId,
            { lat: pickupLat, lon: pickupLon },
            { lat: updatedOrder.deliveryLatitude, lon: updatedOrder.deliveryLongitude }
          );
        }
      } catch (trackingError) {
        console.error("Initialize tracking error:", trackingError);
      }

      // Notify customer
      const socketService = require('../services/socket_service');
      socketService.emitToUserRoom(updatedOrder.customerId, 'order_accepted', {
        orderId: updatedOrder.id,
        orderNumber: updatedOrder.orderNumber,
        rider: {
          id: riderId,
          name: updatedOrder.rider?.username,
          phone: updatedOrder.rider?.phone
        }
      });

      // Broadcast that order is taken
      socketService.broadcastOrderTaken(orderId, riderId);

      res.json({
        success: true,
        message: "Order accepted successfully via reservation",
        data: updatedOrder
      });

    } catch (error) {
      console.error("Accept reservation error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/reservation/:reservationId/decline
 * @desc    Decline an order reservation
 * @access  Private (Rider only)
 */
router.post(
  "/reservation/:reservationId/decline",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const { reservationId } = req.params;
      const { reason } = req.body; // Optional: 'too_far', 'busy', 'low_pay', 'other'
      const riderId = req.user.id;

      const result = await dispatchService.declineReservation(reservationId, riderId, reason);

      if (!result.success) {
        return res.status(400).json({
          success: false,
          message: result.error
        });
      }

      res.json({
        success: true,
        message: "Reservation declined",
        nextDispatch: result.nextDispatch?.success ? {
          riderId: result.nextDispatch.riderId,
          riderName: result.nextDispatch.riderName,
          attemptNumber: result.nextDispatch.attemptNumber
        } : null
      });

    } catch (error) {
      console.error("Decline reservation error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message
      });
    }
  }
);

/**
 * @route   GET /riders/reservation-history
 * @desc    Get rider's reservation history (for stats)
 * @access  Private (Rider only)
 */
router.get(
  "/reservation-history",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const riderId = req.user.id;
      const { limit = 20, status } = req.query;

      const query = { riderId };
      if (status) {
        query.status = status;
      }

      const reservations = await OrderReservation.find(query)
        .sort({ createdAt: -1 })
        .limit(parseInt(limit));

      // Calculate stats
      const allReservations = await OrderReservation.find({ riderId });
      const stats = {
        total: allReservations.length,
        accepted: allReservations.filter(r => r.status === 'accepted').length,
        declined: allReservations.filter(r => r.status === 'declined').length,
        expired: allReservations.filter(r => r.status === 'expired').length,
        acceptanceRate: allReservations.length > 0 
          ? (allReservations.filter(r => r.status === 'accepted').length / allReservations.length * 100).toFixed(1)
          : 0
      };

      res.json({
        success: true,
        data: {
          reservations,
          stats
        }
      });
    } catch (error) {
      console.error("Get reservation history error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/go-online
 * @desc    Set rider as online (registers in RiderStatus for dispatch)
 * @access  Private (Rider)
 */
router.post(
  "/go-online",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const userId = req.user.id;
      const { latitude, longitude } = req.body;
      
      // Get rider profile
      const rider = await prisma.rider.findUnique({
        where: { userId },
        include: { user: true }
      });
      
      if (!rider) {
        return res.status(404).json({
          success: false,
          message: "Rider profile not found"
        });
      }
      
      if (rider.verificationStatus !== 'approved') {
        return res.status(400).json({
          success: false,
          message: "Rider must be verified to go online"
        });
      }
      
      // Use provided location or default to Accra
      // Note: GeoJSON uses [longitude, latitude] order
      const lat = latitude || 5.6037;
      const lon = longitude || -0.187;
      
      // Set rider online in MongoDB RiderStatus
      // goOnline expects (riderId, longitude, latitude)
      const RiderStatus = require('../models/RiderStatus');
      const status = await RiderStatus.goOnline(userId, lon, lat);
      
      console.log(`🟢 [Rider Online] ${rider.user.username} (${userId}) is now online at (${lat}, ${lon})`);
      
      res.json({
        success: true,
        message: "You are now online and visible for orders",
        data: {
          riderId: userId,
          isOnline: true,
          location: { latitude: lat, longitude: lon },
          statusId: status._id
        }
      });
      
    } catch (error) {
      console.error("Go online error:", error);
      res.status(500).json({
        success: false,
        message: "Failed to go online",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/go-offline
 * @desc    Set rider as offline (removes from dispatch pool)
 * @access  Private (Rider)
 */
router.post(
  "/go-offline",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const userId = req.user.id;
      
      const RiderStatus = require('../models/RiderStatus');
      await RiderStatus.goOffline(userId);
      
      console.log(`🔴 [Rider Offline] ${userId} is now offline`);
      
      res.json({
        success: true,
        message: "You are now offline"
      });
      
    } catch (error) {
      console.error("Go offline error:", error);
      res.status(500).json({
        success: false,
        message: "Failed to go offline",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/location
 * @desc    Update rider's current location
 * @access  Private (Rider)
 */
router.post(
  "/location",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const userId = req.user.id;
      const { latitude, longitude } = req.body;
      
      if (!latitude || !longitude) {
        return res.status(400).json({
          success: false,
          message: "Latitude and longitude are required"
        });
      }
      
      const RiderStatus = require('../models/RiderStatus');
      const status = await RiderStatus.findOneAndUpdate(
        { riderId: userId },
        { 
          location: {
            type: 'Point',
            coordinates: [parseFloat(longitude), parseFloat(latitude)]
          },
          lastActiveAt: new Date()
        },
        { new: true, upsert: true }
      );
      
      console.log(`📍 [Rider Location] ${userId} updated to (${latitude}, ${longitude})`);
      
      res.json({
        success: true,
        message: "Location updated",
        data: {
          location: { latitude, longitude },
          lastActiveAt: status.lastActiveAt
        }
      });
      
    } catch (error) {
      console.error("Location update error:", error);
      res.status(500).json({
        success: false,
        message: "Failed to update location",
        error: error.message
      });
    }
  }
);

/**
 * @route   GET /riders/debug-status
 * @desc    [DEV/TEST] Check rider status in MongoDB
 * @access  Private (Rider)
 */
router.get(
  "/debug-status",
  protect,
  authorize("rider"),
  async (req, res) => {
    try {
      const userId = req.user.id;
      const RiderStatus = require('../models/RiderStatus');
      
      // Get the rider's status from MongoDB
      const status = await RiderStatus.findOne({ riderId: userId });
      
      // Also check all online riders
      const allOnlineRiders = await RiderStatus.find({ isOnline: true });
      const allApprovedOnlineRiders = await RiderStatus.find({ isOnline: true, isApproved: true });
      
      // Try a simple geospatial query to verify index works
      let nearbyRiders = [];
      try {
        nearbyRiders = await RiderStatus.find({
          isOnline: true,
          isOnDelivery: false,
          isApproved: true,
          location: {
            $near: {
              $geometry: {
                type: 'Point',
                coordinates: [-0.187, 5.6037] // Accra coordinates
              },
              $maxDistance: 50000 // 50km
            }
          }
        }).limit(10);
      } catch (geoError) {
        console.error('Geospatial query error:', geoError.message);
      }
      
      res.json({
        success: true,
        yourStatus: status ? {
          riderId: status.riderId,
          isOnline: status.isOnline,
          isApproved: status.isApproved,
          isOnDelivery: status.isOnDelivery,
          location: status.location,
          lastActiveAt: status.lastActiveAt
        } : null,
        debug: {
          totalOnlineRiders: allOnlineRiders.length,
          totalApprovedOnlineRiders: allApprovedOnlineRiders.length,
          onlineRiderIds: allOnlineRiders.map(r => ({
            riderId: r.riderId,
            isApproved: r.isApproved,
            isOnDelivery: r.isOnDelivery,
            location: r.location?.coordinates
          })),
          nearbyRidersFound: nearbyRiders.length,
          nearbyRiders: nearbyRiders.map(r => r.riderId)
        }
      });
      
    } catch (error) {
      console.error("Debug status error:", error);
      res.status(500).json({
        success: false,
        message: "Failed to get debug status",
        error: error.message
      });
    }
  }
);

/**
 * @route   POST /riders/test-dispatch/:orderId
 * @desc    [DEV/TEST] Manually trigger dispatch for an order
 * @access  Private (Admin or Rider for testing)
 */
router.post(
  "/test-dispatch/:orderId",
  protect,
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { clearPrevious } = req.query; // ?clearPrevious=true to reset
      
      console.log(`🧪 [Test Dispatch] Manually triggering dispatch for order: ${orderId}`);
      
      // Clear previous reservations if requested (for testing)
      if (clearPrevious === 'true') {
        const OrderReservation = require('../models/OrderReservation');
        await OrderReservation.deleteMany({ orderId });
        console.log(`🧹 [Test Dispatch] Cleared previous reservations for order: ${orderId}`);
      }
      
      // Verify order exists
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        include: { restaurant: true }
      });
      
      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found"
        });
      }
      
      if (order.riderId) {
        return res.status(400).json({
          success: false,
          message: "Order already has a rider assigned"
        });
      }
      
      // Trigger dispatch
      const result = await dispatchService.dispatchOrder(orderId);
      
      res.json({
        success: result.success,
        message: result.success 
          ? `Dispatch triggered! Reservation sent to rider ${result.riderName}`
          : `Dispatch failed: ${result.error}`,
        data: result
      });
      
    } catch (error) {
      console.error("Test dispatch error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message
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

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found",
        });
      }

      if (order.riderId) {
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

      // Calculate rider earnings and lock them in
      const { calculateRiderEarnings } = require('../utils/riderEarningsCalculator');

      // Fetch full order with restaurant/store info for calculation
      const fullOrder = await prisma.order.findUnique({
        where: { id: orderId },
        include: {
          restaurant: {
            select: {
              restaurantName: true,
              latitude: true,
              longitude: true
            }
          },
          groceryStore: {
            select: {
              storeName: true,
              latitude: true,
              longitude: true
            }
          },
          pharmacyStore: {
            select: {
              storeName: true,
              latitude: true,
              longitude: true
            }
          }
        }
      });

      const earnings = calculateRiderEarnings(fullOrder, 0);

      console.log('💰 Locking in earnings for order:', fullOrder.orderNumber);
      console.log('   Distance:', earnings.distance, 'km');
      console.log('   Rider will earn: GHS', earnings.riderEarnings);

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          riderId: req.user.id,
          status: order.status === "ready" ? "picked_up" : order.status,
          // Lock in the calculated earnings
          riderBaseFee: earnings.riderBaseFee,
          riderDistanceFee: earnings.riderDistanceFee,
          riderTip: earnings.riderTip,
          platformFee: earnings.platformFee,
          riderEarnings: earnings.riderEarnings
        },
        include: {
          items: {
            select: {
              id: true,
              name: true,
              quantity: true,
              price: true
            }
          },
          customer: {
            select: {
              username: true,
              email: true,
              phone: true,
              profilePicture: true
            }
          },
          restaurant: {
            select: {
              restaurantName: true,
              logo: true,
              address: true,
              latitude: true,
              longitude: true
            }
          },
          groceryStore: {
            select: {
              storeName: true,
              logo: true,
              address: true,
              latitude: true,
              longitude: true
            }
          },
          pharmacyStore: {
            select: {
              storeName: true,
              logo: true,
              address: true,
              latitude: true,
              longitude: true
            }
          },
          rider: { select: { username: true, email: true, phone: true } }
        }
      });

      // Ensure chat exists between customer and rider for this order
      try {
        const existingChat = await prisma.chat.findUnique({
          where: { orderId: updatedOrder.id }
        });

        if (!existingChat) {
          await prisma.chat.create({
            data: {
              orderId: updatedOrder.id,
              customerId: updatedOrder.customerId,
              riderId: updatedOrder.riderId,
            }
          });
        }
      } catch (chatError) {
        console.error("Ensure chat for accepted order error:", chatError);
      }


      // Initialize tracking for the order
      try {
        const OrderTracking = require('../models/OrderTracking');
        const trackingService = require('../services/tracking_service');

        // Delete any existing tracking (in case order was previously cancelled)
        await OrderTracking.findOneAndDelete({ orderId: updatedOrder.id });

        // Initialize fresh tracking
        await trackingService.initializeTracking(
          updatedOrder.id,
          updatedOrder.riderId,
          updatedOrder.customerId,
          {
            latitude: updatedOrder.restaurant.latitude,
            longitude: updatedOrder.restaurant.longitude
          },
          {
            latitude: updatedOrder.deliveryLatitude,
            longitude: updatedOrder.deliveryLongitude
          }
        );
        console.log(`📍 Tracking initialized for order ${updatedOrder.id}`);
      } catch (trackingError) {
        console.error("Initialize tracking for accepted order error:", trackingError);
        // Don't fail the order acceptance if tracking init fails
      }

      res.json({
        success: true,
        message: "Order accepted successfully",
        data: updatedOrder,
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

// Cancel order endpoint - Rider cancels an accepted order
router.post(
  "/cancel-order/:orderId",
  protect,
  authorize("rider", "admin"),
  async (req, res) => {
    try {
      const { orderId } = req.params;
      const { reason, notes } = req.body;

      console.log(`🚫 Rider ${req.user.id} attempting to cancel order ${orderId}`);
      console.log(`   Reason: ${reason}${notes ? ` - ${notes}` : ''}`);

      // Find the order and verify it belongs to this rider
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          riderId: true,
          customerId: true,
          status: true,
          orderNumber: true,
        }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: "Order not found"
        });
      }

      // Verify the order is assigned to this rider
      if (order.riderId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "You are not assigned to this order"
        });
      }

      // Prevent cancellation if order is already delivered or cancelled
      if (order.status === 'delivered' || order.status === 'cancelled') {
        return res.status(400).json({
          success: false,
          message: `Cannot cancel order with status: ${order.status}`
        });
      }

      // Release the order back to available pool
      // Preserve the original status (preparing, ready, etc.) before rider accepted
      const resetStatus = order.status === 'picked_up' ? 'ready' : order.status;

      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          riderId: null,
          status: resetStatus, // Restore to pre-acceptance status
          riderBaseFee: 5.0, // Reset to default
          riderDistanceFee: 0,
          riderTip: 0,
          platformFee: 0,
          riderEarnings: 0,
          cancelledDate: new Date(),
          cancellationReason: notes
            ? `${reason || 'rider_cancelled'}: ${notes}`
            : (reason || 'rider_cancelled'),
        },
        include: {
          customer: { select: { username: true, email: true, phone: true } },
          restaurant: { select: { restaurantName: true } }
        }
      });

      console.log(`✅ Order ${order.orderNumber} released back to available pool`);

      // Delete tracking record so it can be re-initialized if order is accepted again
      try {
        const OrderTracking = require('../models/OrderTracking');
        await OrderTracking.findOneAndDelete({ orderId: orderId });
        console.log(`�️ Tracking deleted for cancelled order ${orderId}`);
      } catch (trackingError) {
        console.error("Delete tracking on cancellation error:", trackingError);
        // Don't fail the cancellation if tracking deletion fails
      }

      // TODO: Notify customer about cancellation
      // TODO: Send push notification to nearby riders about available order

      res.json({
        success: true,
        message: "Order cancelled successfully. It has been released for other riders.",
        data: {
          orderId: updatedOrder.id,
          orderNumber: updatedOrder.orderNumber,
          status: updatedOrder.status,
          reason: reason,
        }
      });
    } catch (error) {
      console.error("Cancel order error:", error);
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
    let wallet = await prisma.riderWallet.findUnique({
      where: { userId: req.user.id }
    });

    if (!wallet) {
      wallet = await prisma.riderWallet.create({
        data: { userId: req.user.id }
      });
    } else {
      wallet = await updateWalletBalance(req.user.id);
    }

    res.json({
      success: true,
      message: "Wallet retrieved successfully",
      data: {
        balance: wallet.balance,
        totalEarnings: wallet.totalEarnings,
        totalWithdrawals: wallet.totalWithdrawals,
        pendingWithdrawals: wallet.pendingWithdrawal,
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

    let where = {
      userId: req.user.id,
      type: { in: ["delivery", "tip", "bonus"] },
      status: "completed",
    };

    if (startDate) {
      where.createdAt = { gte: startDate };
    }

    const earnings = await prisma.transaction.findMany({
      where,
      orderBy: { createdAt: 'desc' }
    });

    // Calculate totals using aggregation
    const totals = await prisma.transaction.groupBy({
      by: ['type'],
      where,
      _sum: { amount: true },
    });

    const summary = {
      total: 0,
      delivery: 0,
      tip: 0,
      bonus: 0,
    };

    totals.forEach((item) => {
      summary[item.type] = item._sum.amount || 0;
      summary.total += item._sum.amount || 0;
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

    let where = { userId: req.user.id };

    if (startDate) {
      where.createdAt = { gte: startDate };
    }

    if (type) {
      where.type = type;
    }

    if (status) {
      where.status = status;
    }

    const transactions = await prisma.transaction.findMany({
      where,
      orderBy: { createdAt: 'desc' }
    });

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

      const { amount, withdrawalMethod, withdrawalAccount, description } = req.body;

      const wallet = await prisma.riderWallet.findUnique({
        where: { userId: req.user.id }
      });

      if (!wallet || wallet.balance < parseFloat(amount)) {
        return res.status(400).json({
          success: false,
          message: "Insufficient balance",
        });
      }

      const transaction = await prisma.transaction.create({
        data: {
          walletId: wallet.id,
          userId: req.user.id,
          type: "withdrawal",
          amount: parseFloat(amount),
          description: description || `Withdrawal to ${withdrawalMethod.replace("_", " ")}`,
          status: "pending",
        }
      });

      await updateWalletBalance(req.user.id);

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

      const transaction = await prisma.transaction.findUnique({
        where: { id: transactionId }
      });

      if (!transaction) {
        return res.status(404).json({
          success: false,
          message: "Transaction not found",
        });
      }

      await prisma.transaction.update({
        where: { id: transactionId },
        data: {
          status,
          ...(status === "completed" ? { updatedAt: new Date() } : {})
        }
      });

      await updateWalletBalance(transaction.userId);

      const updatedTransaction = await prisma.transaction.findUnique({
        where: { id: transactionId }
      });

      res.json({
        success: true,
        message: "Transaction status updated successfully",
        data: updatedTransaction,
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

      // Validate enums against Prisma schema
      const validVehicleTypes = ["motorcycle", "bicycle", "car", "scooter"];
      const validIdTypes = ["national_id", "passport", "drivers_license"];
      const validMobileMoneyProviders = ["mtn", "vodafone", "airtel", "tigo"];

      if (vehicleType && !validVehicleTypes.includes(vehicleType.toLowerCase())) {
        return res.status(400).json({
          success: false,
          message: `Invalid vehicle type.`,
        });
      }

      if (nationalIdType && !validIdTypes.includes(nationalIdType.toLowerCase())) {
        return res.status(400).json({
          success: false,
          message: `Invalid ID type.`,
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

      if (mobileMoneyProvider && !validMobileMoneyProviders.includes(mobileMoneyProvider.toLowerCase())) {
        return res.status(400).json({
          success: false,
          message: `Invalid mobile money provider.`,
        });
      }

      const existingRider = await prisma.rider.findUnique({
        where: { userId: req.user.id }
      });

      if (existingRider && existingRider.verificationStatus === "approved") {
        return res.status(400).json({
          success: false,
          message: "Verification already approved.",
        });
      }

      const riderData = {
        userId: req.user.id,
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
        mobileMoneyProvider: mobileMoneyProvider ? mobileMoneyProvider.toLowerCase() : null,
        mobileMoneyNumber,
        agreedToTerms: agreedToTerms === "true" || agreedToTerms === true,
        agreedToLocationAccess: agreedToLocationAccess === "true" || agreedToLocationAccess === true,
        agreedToAccuracy: agreedToAccuracy === "true" || agreedToAccuracy === true,
        verificationStatus: "pending",
      };

      if (req.file && req.file.cloudinaryUrl) {
        riderData.vehicleImage = req.file.cloudinaryUrl;
      }

      const rider = await prisma.rider.upsert({
        where: { userId: req.user.id },
        update: riderData,
        create: riderData
      });

      res.status(201).json({
        success: true,
        message: "Verification data submitted successfully.",
        data: rider,
      });
    } catch (error) {
      console.error("Submit verification error:", error);

      // Handle Prisma validation errors (e.g., enum mismatch)
      if (error.code === 'P2007') { // Prisma validation error code
        return res.status(400).json({
          success: false,
          message: "Validation error",
          errors: error.message,
        });
      }
      // Handle duplicate key errors (Prisma P2002)
      if (error.code === 'P2002') {
        const field = error.meta.target.join(', ');
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
    const rider = await prisma.rider.findUnique({
      where: { userId: req.user.id }
    });

    if (!rider) {
      return res.status(404).json({
        success: false,
        message: "Verification data not found",
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
      const rider = await prisma.rider.findUnique({
        where: { userId: req.user.id }
      });

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

      const updateData = {};
      allowedUpdates.forEach((field) => {
        if (req.body[field] !== undefined) {
          if (field.includes("agreed")) {
            updateData[field] = req.body[field] === "true" || req.body[field] === true;
          } else if (
            field === "vehicleType" ||
            field === "nationalIdType" ||
            field === "paymentMethod" ||
            field === "mobileMoneyProvider"
          ) {
            updateData[field] = req.body[field] ? req.body[field].toLowerCase() : req.body[field];
          } else {
            updateData[field] = req.body[field];
          }
        }
      });

      if (req.file && req.file.cloudinaryUrl) {
        updateData.vehicleImage = req.file.cloudinaryUrl;
      }

      if (rider.verificationStatus === "rejected") {
        updateData.verificationStatus = "pending";
        updateData.rejectionReason = null;
      }

      const updatedRider = await prisma.rider.update({
        where: { id: rider.id },
        data: updateData
      });

      res.json({
        success: true,
        message: "Verification data updated successfully",
        data: updatedRider,
      });
    } catch (error) {
      console.error("Update verification error:", error);
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

      const rider = await prisma.rider.upsert({
        where: { userId: req.user.id },
        update: {},
        create: { userId: req.user.id }
      });

      const updateData = {};
      if (imageType === "front") {
        updateData.idFrontImage = req.file.cloudinaryUrl;
      } else if (imageType === "back") {
        updateData.idBackImage = req.file.cloudinaryUrl;
      } else if (imageType === "selfie") {
        updateData.selfiePhoto = req.file.cloudinaryUrl;
      }

      const updatedRider = await prisma.rider.update({
        where: { id: rider.id },
        data: updateData
      });

      res.json({
        success: true,
        message: "ID image uploaded successfully",
        data: {
          imageType,
          imageUrl: req.file.cloudinaryUrl,
          rider: updatedRider
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

      const rider = await prisma.rider.findUnique({
        where: { id: riderId }
      });
      if (!rider) {
        return res.status(404).json({
          success: false,
          message: "Rider verification not found",
        });
      }

      const updateData = {
        verificationStatus: status,
        updatedAt: new Date()
      };

      if (status === "approved") {
        updateData.verifiedAt = new Date();
        updateData.rejectionReason = null;
      } else if (status === "rejected" && rejectionReason) {
        updateData.rejectionReason = rejectionReason;
      }

      const updatedRider = await prisma.rider.update({
        where: { id: riderId },
        data: updateData
      });

      res.json({
        success: true,
        message: "Verification status updated successfully",
        data: updatedRider,
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
