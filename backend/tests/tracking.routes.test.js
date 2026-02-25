const request = require("supertest");
const express = require("express");

jest.mock("../config/prisma", () => ({
  order: {
    findUnique: jest.fn(),
  },
}));

jest.mock("../services/tracking_service", () => ({
  initializeTracking: jest.fn(),
  updateRiderLocation: jest.fn(),
  updateOrderStatus: jest.fn(),
  getTrackingInfo: jest.fn(),
}));

jest.mock("../middleware/auth", () => ({
  protect: (req, res, next) => {
    const role = req.header("x-test-role");
    const userId = req.header("x-test-user-id");

    if (!role || !userId) {
      return res.status(401).json({
        success: false,
        message: "Not authorized",
      });
    }

    req.user = { id: userId, role };
    return next();
  },
}));

const prisma = require("../config/prisma");
const trackingService = require("../services/tracking_service");
const trackingRoutes = require("../routes/tracking_routes");

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use("/api/tracking", trackingRoutes);
  return app;
};

const withAuth = (req, role, userId) =>
  req.set("x-test-role", role).set("x-test-user-id", userId);

describe("Tracking Routes", () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    trackingService.initializeTracking.mockResolvedValue({ id: "tracking-1" });
    trackingService.updateRiderLocation.mockResolvedValue({
      distanceRemaining: 1200,
      estimatedArrival: new Date().toISOString(),
      etaSeconds: 360,
      status: "in_transit",
    });
    trackingService.updateOrderStatus.mockResolvedValue({
      id: "tracking-1",
      status: "nearby",
    });
    trackingService.getTrackingInfo.mockResolvedValue({
      id: "tracking-1",
      orderId: "order-1",
      status: "in_transit",
    });
  });

  describe("POST /api/tracking/location", () => {
    test("rejects out-of-range coordinates", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "on_the_way",
        deliveryLatitude: 5.6,
        deliveryLongitude: -0.18,
      });

      const res = await withAuth(
        request(app).post("/api/tracking/location"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        latitude: 91,
        longitude: -0.18,
      });

      expect(res.statusCode).toBe(400);
      expect(res.body?.message || "").toMatch(/latitude must be between/i);
      expect(trackingService.updateRiderLocation).not.toHaveBeenCalled();
    });

    test("rejects negative speed and accuracy", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "on_the_way",
        deliveryLatitude: 5.6,
        deliveryLongitude: -0.18,
      });

      const speedRes = await withAuth(
        request(app).post("/api/tracking/location"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        latitude: 5.6,
        longitude: -0.18,
        speed: -1,
      });

      expect(speedRes.statusCode).toBe(400);
      expect(speedRes.body?.message || "").toMatch(/speed must be a non-negative/i);

      const accuracyRes = await withAuth(
        request(app).post("/api/tracking/location"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        latitude: 5.6,
        longitude: -0.18,
        accuracy: -5,
      });

      expect(accuracyRes.statusCode).toBe(400);
      expect(accuracyRes.body?.message || "").toMatch(
        /accuracy must be a non-negative/i
      );
      expect(trackingService.updateRiderLocation).not.toHaveBeenCalled();
    });

    test("blocks location updates for terminal orders", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "delivered",
        deliveryLatitude: 5.6,
        deliveryLongitude: -0.18,
      });

      const res = await withAuth(
        request(app).post("/api/tracking/location"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        latitude: 5.6,
        longitude: -0.18,
      });

      expect(res.statusCode).toBe(409);
      expect(res.body?.message || "").toMatch(/already delivered/i);
      expect(trackingService.updateRiderLocation).not.toHaveBeenCalled();
    });
  });

  describe("PATCH /api/tracking/status", () => {
    test("rejects terminal tracking status writes", async () => {
      const res = await withAuth(
        request(app).patch("/api/tracking/status"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        status: "delivered",
      });

      expect(res.statusCode).toBe(400);
      expect(res.body?.message || "").toMatch(/must be updated via \/orders/i);
      expect(prisma.order.findUnique).not.toHaveBeenCalled();
      expect(trackingService.updateOrderStatus).not.toHaveBeenCalled();
    });

    test("rejects status misaligned with lifecycle state", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "preparing",
      });

      const res = await withAuth(
        request(app).patch("/api/tracking/status"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        status: "in_transit",
      });

      expect(res.statusCode).toBe(409);
      expect(res.body?.message || "").toMatch(/not valid while order lifecycle/i);
      expect(trackingService.updateOrderStatus).not.toHaveBeenCalled();
    });

    test("accepts lifecycle-aligned tracking status update", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "on_the_way",
      });

      const res = await withAuth(
        request(app).patch("/api/tracking/status"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        status: "nearby",
      });

      expect(res.statusCode).toBe(200);
      expect(trackingService.updateOrderStatus).toHaveBeenCalledWith(
        "order-1",
        "nearby"
      );
    });
  });

  describe("POST /api/tracking/initialize", () => {
    test("blocks initialization for terminal orders", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "cancelled",
        deliveryLatitude: 5.6,
        deliveryLongitude: -0.18,
        restaurant: { latitude: 5.5, longitude: -0.19 },
        groceryStore: null,
        pharmacyStore: null,
        grabMartStore: null,
      });

      const res = await withAuth(
        request(app).post("/api/tracking/initialize"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        pickupLocation: { latitude: 1, longitude: 1 },
        destination: { latitude: 2, longitude: 2 },
      });

      expect(res.statusCode).toBe(409);
      expect(res.body?.message || "").toMatch(/tracking cannot be initialized/i);
      expect(trackingService.initializeTracking).not.toHaveBeenCalled();
    });

    test("prefers order pickup/destination over client payload", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "preparing",
        deliveryLatitude: 5.642,
        deliveryLongitude: -0.221,
        restaurant: { latitude: 5.611, longitude: -0.199 },
        groceryStore: null,
        pharmacyStore: null,
        grabMartStore: null,
      });

      const res = await withAuth(
        request(app).post("/api/tracking/initialize"),
        "rider",
        "rider-1"
      ).send({
        orderId: "order-1",
        pickupLocation: { latitude: 99, longitude: 99 },
        destination: { latitude: 88, longitude: 88 },
      });

      expect(res.statusCode).toBe(201);
      expect(trackingService.initializeTracking).toHaveBeenCalledWith(
        "order-1",
        "rider-1",
        "customer-1",
        { latitude: 5.611, longitude: -0.199 },
        { latitude: 5.642, longitude: -0.221 }
      );
    });
  });

  describe("GET /api/tracking/:orderId", () => {
    test("denies customer access for another customer's order", async () => {
      prisma.order.findUnique.mockResolvedValue({
        id: "order-1",
        customerId: "customer-1",
        riderId: "rider-1",
        status: "on_the_way",
      });

      const res = await withAuth(
        request(app).get("/api/tracking/order-1"),
        "customer",
        "customer-2"
      );

      expect(res.statusCode).toBe(403);
      expect(trackingService.getTrackingInfo).not.toHaveBeenCalled();
    });
  });
});
