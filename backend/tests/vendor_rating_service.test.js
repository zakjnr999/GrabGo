const mockPrisma = {
  $transaction: jest.fn(),
  restaurant: {
    findUnique: jest.fn(),
  },
  vendorReview: {
    findMany: jest.fn(),
    groupBy: jest.fn(),
  },
};

jest.mock("../config/prisma", () => mockPrisma);

const {
  VendorRatingError,
  buildOrderVendorRatingMeta,
  decorateOrderWithVendorRatingMeta,
  getVendorReviews,
  resolveVendorReviewTarget,
  submitVendorRating,
} = require("../services/vendor_rating_service");

describe("vendor_rating_service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("resolveVendorReviewTarget", () => {
    test("returns the single vendor target for restaurant orders", () => {
      const target = resolveVendorReviewTarget({
        restaurantId: "rest_1",
      });

      expect(target).toEqual(
        expect.objectContaining({
          vendorType: "restaurant",
          vendorId: "rest_1",
          orderField: "restaurantId",
          relationField: "restaurant",
          prismaModel: "restaurant",
        })
      );
    });

    test("returns null when order contains zero or multiple vendor references", () => {
      expect(resolveVendorReviewTarget({})).toBeNull();
      expect(
        resolveVendorReviewTarget({
          restaurantId: "rest_1",
          groceryStoreId: "gro_1",
        })
      ).toBeNull();
    });
  });

  describe("buildOrderVendorRatingMeta", () => {
    test("marks delivered unrated customer orders as rateable", () => {
      const meta = buildOrderVendorRatingMeta(
        {
          status: "delivered",
          restaurantId: "rest_1",
        },
        { viewerRole: "customer" }
      );

      expect(meta).toEqual({
        canRateVendor: true,
        vendorRatingSubmitted: false,
        vendorRatingValue: null,
        vendorRatedAt: null,
      });
    });

    test("marks rated orders as no longer rateable", () => {
      const createdAt = new Date("2026-03-07T10:00:00.000Z");
      const meta = buildOrderVendorRatingMeta(
        {
          status: "delivered",
          restaurantId: "rest_1",
          vendorReview: {
            rating: 4,
            createdAt,
          },
        },
        { viewerRole: "customer" }
      );

      expect(meta).toEqual({
        canRateVendor: false,
        vendorRatingSubmitted: true,
        vendorRatingValue: 4,
        vendorRatedAt: createdAt,
      });
    });

    test("returns false for non-customer viewers", () => {
      const meta = buildOrderVendorRatingMeta(
        {
          status: "delivered",
          restaurantId: "rest_1",
        },
        { viewerRole: "restaurant" }
      );

      expect(meta.canRateVendor).toBe(false);
    });
  });

  describe("decorateOrderWithVendorRatingMeta", () => {
    test("removes the internal vendorReview relation and adds derived fields", () => {
      const createdAt = new Date("2026-03-07T10:00:00.000Z");
      const decorated = decorateOrderWithVendorRatingMeta(
        {
          id: "order_1",
          status: "delivered",
          restaurantId: "rest_1",
          vendorReview: {
            rating: 5,
            createdAt,
          },
        },
        { viewerRole: "customer" }
      );

      expect(decorated.vendorReview).toBeUndefined();
      expect(decorated.vendorRatingSubmitted).toBe(true);
      expect(decorated.vendorRatingValue).toBe(5);
      expect(decorated.vendorRatedAt).toBe(createdAt);
      expect(decorated.canRateVendor).toBe(false);
    });
  });

  describe("submitVendorRating", () => {
    test("creates a review and updates vendor aggregates transactionally", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "delivered",
            orderType: "food",
            restaurantId: "rest_1",
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            vendorReview: null,
            restaurant: {
              id: "rest_1",
              rating: 4.5,
              ratingCount: 10,
              ratingSum: 45,
              totalReviews: 10,
            },
            groceryStore: null,
            pharmacyStore: null,
            grabMartStore: null,
          }),
        },
        vendorReview: {
          create: jest.fn().mockResolvedValue({
            orderId: "order_1",
            rating: 5,
            createdAt: new Date("2026-03-07T12:00:00.000Z"),
          }),
        },
        restaurant: {
          update: jest.fn().mockResolvedValue({
            id: "rest_1",
            rating: 4.55,
            ratingCount: 11,
            totalReviews: 11,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      const result = await submitVendorRating({
        prismaClient: mockPrisma,
        orderId: "order_1",
        customerId: "user_1",
        rating: 5,
        feedbackTags: ["Delicious food", "Prepared on time", "Delicious food"],
        comment: "Fantastic meal.",
      });

      expect(tx.vendorReview.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          orderId: "order_1",
          customerId: "user_1",
          vendorType: "restaurant",
          restaurantId: "rest_1",
          rating: 5,
          feedbackTags: ["Delicious food", "Prepared on time"],
          comment: "Fantastic meal.",
        }),
        select: {
          orderId: true,
          rating: true,
          createdAt: true,
        },
      });

      expect(tx.restaurant.update).toHaveBeenCalledWith({
        where: { id: "rest_1" },
        data: {
          rating: 4.55,
          ratingCount: 11,
          ratingSum: 50,
          totalReviews: 11,
        },
        select: {
          id: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
        },
      });

      expect(result).toEqual({
        orderId: "order_1",
        rating: 5,
        submittedAt: new Date("2026-03-07T12:00:00.000Z"),
        vendor: {
          id: "rest_1",
          type: "restaurant",
          rawRating: 4.55,
          weightedRating: 4.3,
          rating: 4.3,
          ratingCount: 11,
          totalReviews: 11,
        },
      });
    });

    test("rejects duplicate vendor ratings", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "delivered",
            restaurantId: "rest_1",
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            vendorReview: {
              id: "review_1",
              rating: 4,
              createdAt: new Date(),
            },
            restaurant: {
              id: "rest_1",
              rating: 4.5,
              ratingCount: 10,
              ratingSum: 45,
              totalReviews: 10,
            },
            groceryStore: null,
            pharmacyStore: null,
            grabMartStore: null,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      await expect(
        submitVendorRating({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          rating: 4,
        })
      ).rejects.toMatchObject({
        name: "VendorRatingError",
        statusCode: 409,
        code: "VENDOR_RATING_ALREADY_SUBMITTED",
      });
    });

    test("maps unique-constraint races to duplicate vendor rating errors", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "delivered",
            restaurantId: "rest_1",
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            vendorReview: null,
            restaurant: {
              id: "rest_1",
              rating: 4.5,
              ratingCount: 10,
              ratingSum: 45,
              totalReviews: 10,
            },
            groceryStore: null,
            pharmacyStore: null,
            grabMartStore: null,
          }),
        },
        vendorReview: {
          create: jest.fn().mockRejectedValue({
            code: "P2002",
            message: "Unique constraint failed on the fields: (`orderId`)",
          }),
        },
        restaurant: {
          update: jest.fn(),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      await expect(
        submitVendorRating({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          rating: 5,
        })
      ).rejects.toMatchObject({
        name: "VendorRatingError",
        statusCode: 409,
        code: "VENDOR_RATING_ALREADY_SUBMITTED",
      });

      expect(tx.restaurant.update).not.toHaveBeenCalled();
    });

    test("rejects undelivered orders", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "on_the_way",
            restaurantId: "rest_1",
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            vendorReview: null,
            restaurant: {
              id: "rest_1",
              rating: 4.5,
              ratingCount: 10,
              ratingSum: 45,
              totalReviews: 10,
            },
            groceryStore: null,
            pharmacyStore: null,
            grabMartStore: null,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      await expect(
        submitVendorRating({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          rating: 4,
        })
      ).rejects.toBeInstanceOf(VendorRatingError);
    });

    test("rejects orders owned by another customer", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_2",
            status: "delivered",
            restaurantId: "rest_1",
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            vendorReview: null,
            restaurant: {
              id: "rest_1",
              rating: 4.5,
              ratingCount: 10,
              ratingSum: 45,
              totalReviews: 10,
            },
            groceryStore: null,
            pharmacyStore: null,
            grabMartStore: null,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      await expect(
        submitVendorRating({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          rating: 4,
        })
      ).rejects.toMatchObject({
        statusCode: 403,
        code: "ORDER_ACCESS_DENIED",
      });
    });
  });

  describe("getVendorReviews", () => {
    test("returns public vendor comments with normalized aggregate fields", async () => {
      mockPrisma.restaurant.findUnique.mockResolvedValue({
        id: "rest_1",
        restaurantName: "Sushi Zen",
        logo: "logo.jpg",
        rating: 4.55,
        ratingCount: 11,
        totalReviews: 11,
      });
      mockPrisma.vendorReview.findMany.mockResolvedValue([
        {
          id: "review_1",
          rating: 5,
          feedbackTags: ["Well packaged"],
          comment: "Packaging was excellent.",
          createdAt: new Date("2026-03-07T18:00:00.000Z"),
          customer: {
            id: "user_1",
            username: "Boss Zack",
            email: "boss@example.com",
            profilePicture: "avatar.jpg",
          },
        },
      ]);
      mockPrisma.vendorReview.groupBy.mockResolvedValue([
        { rating: 5, _count: { _all: 8 } },
        { rating: 4, _count: { _all: 3 } },
      ]);

      const result = await getVendorReviews({
        prismaClient: mockPrisma,
        vendorType: "restaurant",
        vendorId: "rest_1",
        sort: "latest",
      });

      expect(result.vendor).toEqual({
        id: "rest_1",
        type: "restaurant",
        name: "Sushi Zen",
        image: "logo.jpg",
        rawRating: 4.55,
        weightedRating: 4.3,
        rating: 4.3,
        ratingCount: 11,
        totalReviews: 11,
      });
      expect(result.sort).toBe("latest");
      expect(result.breakdown).toEqual({ 5: 8, 4: 3, 3: 0, 2: 0, 1: 0 });
      expect(result.reviews).toHaveLength(1);
      expect(result.reviews[0].reviewer.name).toBe("Boss Zack");
    });
  });
});
