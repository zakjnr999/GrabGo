const mockPrisma = {
  $transaction: jest.fn(),
  food: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  itemReview: {
    findMany: jest.fn(),
    groupBy: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  itemReviewReport: {
    create: jest.fn(),
  },
};

jest.mock("../config/prisma", () => mockPrisma);

const {
  ItemReviewError,
  buildOrderItemReviewMeta,
  resolveOrderItemReviewTarget,
  submitItemReviews,
  getItemReviews,
  moderateItemReview,
  reportItemReview,
} = require("../services/item_review_service");

describe("item_review_service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("resolveOrderItemReviewTarget", () => {
    test("returns the item target for food order items", () => {
      const target = resolveOrderItemReviewTarget({
        itemType: "Food",
        foodId: "food_1",
      });

      expect(target).toEqual(
        expect.objectContaining({
          itemType: "food",
          itemId: "food_1",
          orderField: "foodId",
          relationField: "food",
          prismaModel: "food",
        })
      );
    });
  });

  describe("buildOrderItemReviewMeta", () => {
    test("marks delivered unrated customer items as rateable", () => {
      const meta = buildOrderItemReviewMeta(
        {
          id: "order_item_1",
          itemType: "Food",
          foodId: "food_1",
        },
        { orderStatus: "delivered", viewerRole: "customer" }
      );

      expect(meta).toEqual({
        canRateItem: true,
        itemRatingSubmitted: false,
        itemRatingValue: null,
        itemRatedAt: null,
        itemReviewType: "food",
        reviewableItemId: "food_1",
      });
    });
  });

  describe("submitItemReviews", () => {
    test("creates item reviews and updates aggregates transactionally", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "delivered",
            items: [
              {
                id: "order_item_1",
                itemType: "Food",
                name: "Jollof Rice",
                image: "jollof.jpg",
                quantity: 1,
                foodId: "food_1",
                groceryItemId: null,
                pharmacyItemId: null,
                grabMartItemId: null,
                itemReview: null,
                food: {
                  id: "food_1",
                  name: "Jollof Rice",
                  foodImage: "jollof.jpg",
                  rating: 4.5,
                  ratingSum: 45,
                  totalReviews: 10,
                },
                groceryItem: null,
                pharmacyItem: null,
                grabMartItem: null,
              },
            ],
          }),
        },
        itemReview: {
          create: jest.fn().mockResolvedValue({
            orderItemId: "order_item_1",
            rating: 5,
            createdAt: new Date("2026-03-07T16:30:00.000Z"),
          }),
        },
        food: {
          update: jest.fn().mockResolvedValue({
            id: "food_1",
            name: "Jollof Rice",
            foodImage: "jollof.jpg",
            rating: 4.55,
            ratingSum: 50,
            totalReviews: 11,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      const result = await submitItemReviews({
        prismaClient: mockPrisma,
        orderId: "order_1",
        customerId: "user_1",
        reviews: [
          {
            orderItemId: "order_item_1",
            rating: 5,
            feedbackTags: ["Great taste", "Fresh", "Great taste"],
            comment: "Would order again.",
          },
        ],
      });

      expect(tx.itemReview.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          orderId: "order_1",
          orderItemId: "order_item_1",
          customerId: "user_1",
          itemType: "food",
          foodId: "food_1",
          rating: 5,
          feedbackTags: ["Great taste", "Fresh"],
          comment: "Would order again.",
        }),
        select: {
          orderItemId: true,
          rating: true,
          createdAt: true,
        },
      });

      expect(tx.food.update).toHaveBeenCalledWith({
        where: { id: "food_1" },
        data: {
          rating: 4.55,
          ratingSum: 50,
          totalReviews: 11,
        },
        select: {
          id: true,
          name: true,
          foodImage: true,
          rating: true,
          ratingSum: true,
          totalReviews: true,
        },
      });

      expect(result).toEqual({
        orderId: "order_1",
        submittedCount: 1,
        pendingItemReviewCount: 0,
        reviews: [
          {
            orderItemId: "order_item_1",
            rating: 5,
            submittedAt: new Date("2026-03-07T16:30:00.000Z"),
            item: {
              id: "food_1",
              type: "food",
              name: "Jollof Rice",
              image: "jollof.jpg",
              rawRating: 4.55,
              weightedRating: 4.3,
              rating: 4.3,
              ratingCount: 11,
              totalReviews: 11,
            },
          },
        ],
      });
    });

    test("rejects already reviewed order items", async () => {
      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: "order_1",
            customerId: "user_1",
            status: "delivered",
            items: [
              {
                id: "order_item_1",
                itemType: "Food",
                foodId: "food_1",
                itemReview: {
                  id: "review_1",
                  rating: 4,
                  createdAt: new Date(),
                },
                food: {
                  id: "food_1",
                  name: "Jollof Rice",
                  foodImage: "jollof.jpg",
                  rating: 4.0,
                  ratingSum: 40,
                  totalReviews: 10,
                },
                groceryItem: null,
                pharmacyItem: null,
                grabMartItem: null,
              },
            ],
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      await expect(
        submitItemReviews({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          reviews: [
            {
              orderItemId: "order_item_1",
              rating: 4,
            },
          ],
        })
      ).rejects.toMatchObject({
        name: "ItemReviewError",
        code: "ITEM_REVIEW_ALREADY_SUBMITTED",
      });
    });
  });

  describe("getItemReviews", () => {
    test("returns real comments with normalized aggregate fields", async () => {
      mockPrisma.food.findUnique.mockResolvedValue({
        id: "food_1",
        name: "Jollof Rice",
        foodImage: "jollof.jpg",
        rating: 4.55,
        ratingSum: 50,
        totalReviews: 11,
      });
      mockPrisma.itemReview.findMany.mockResolvedValue([
        {
          id: "review_1",
          rating: 5,
          feedbackTags: ["Great taste"],
          comment: "Would order again.",
          createdAt: new Date("2026-03-07T16:30:00.000Z"),
          customer: {
            id: "user_1",
            username: "Boss Zack",
            email: "boss@example.com",
            profilePicture: "avatar.jpg",
          },
        },
      ]);
      mockPrisma.itemReview.groupBy.mockResolvedValue([
        { rating: 5, _count: { _all: 8 } },
        { rating: 4, _count: { _all: 3 } },
      ]);

      const result = await getItemReviews({
        prismaClient: mockPrisma,
        itemType: "food",
        itemId: "food_1",
        sort: "latest",
      });

      expect(result.item).toEqual({
        id: "food_1",
        type: "food",
        name: "Jollof Rice",
        image: "jollof.jpg",
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

    test("filters hidden item reviews from public feeds", async () => {
      mockPrisma.food.findUnique.mockResolvedValue({
        id: "food_1",
        name: "Jollof Rice",
        foodImage: "jollof.jpg",
        rating: 4.3,
        ratingSum: 43,
        totalReviews: 10,
      });
      mockPrisma.itemReview.findMany.mockResolvedValue([]);
      mockPrisma.itemReview.groupBy.mockResolvedValue([]);

      await getItemReviews({
        prismaClient: mockPrisma,
        itemType: "food",
        itemId: "food_1",
      });

      expect(mockPrisma.itemReview.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            foodId: "food_1",
            isHidden: false,
          },
        })
      );
    });
  });

  describe("reportItemReview", () => {
    test("creates a report and increments report metadata", async () => {
      const tx = {
        itemReview: {
          findUnique: jest.fn().mockResolvedValue({
            id: "review_1",
            isHidden: false,
            reportedCount: 0,
          }),
          update: jest.fn().mockResolvedValue({
            id: "review_1",
            isHidden: false,
            reportedCount: 1,
            lastReportedAt: new Date("2026-03-07T20:10:00.000Z"),
          }),
        },
        itemReviewReport: {
          create: jest.fn().mockResolvedValue({
            id: "report_1",
            createdAt: new Date("2026-03-07T20:10:00.000Z"),
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      const result = await reportItemReview({
        prismaClient: mockPrisma,
        reviewId: "review_1",
        reporterId: "user_9",
        reason: "personal_info",
        details: "This comment contains contact details",
      });

      expect(tx.itemReviewReport.create).toHaveBeenCalledWith({
        data: {
          itemReviewId: "review_1",
          reporterId: "user_9",
          reason: "personal_info",
          details: "This comment contains contact details",
        },
        select: {
          id: true,
          createdAt: true,
        },
      });
      expect(result.reportedCount).toBe(1);
    });
  });

  describe("moderateItemReview", () => {
    test("hides a review and removes it from item aggregates", async () => {
      const tx = {
        itemReview: {
          findUnique: jest.fn().mockResolvedValue({
            id: "review_1",
            rating: 5,
            isHidden: false,
            hiddenReason: null,
            hiddenAt: null,
            reportedCount: 1,
            itemType: "food",
            foodId: "food_1",
            groceryItemId: null,
            pharmacyItemId: null,
            grabMartItemId: null,
          }),
          update: jest.fn().mockResolvedValue({
            id: "review_1",
            isHidden: true,
            hiddenReason: "Abusive language",
            hiddenAt: new Date("2026-03-07T20:15:00.000Z"),
            reportedCount: 1,
          }),
        },
        food: {
          findUnique: jest.fn().mockResolvedValue({
            id: "food_1",
            name: "Jollof Rice",
            foodImage: "jollof.jpg",
            rating: 4.55,
            ratingSum: 50,
            totalReviews: 11,
          }),
          update: jest.fn().mockResolvedValue({
            id: "food_1",
            name: "Jollof Rice",
            foodImage: "jollof.jpg",
            rating: 4.5,
            ratingSum: 45,
            totalReviews: 10,
          }),
        },
      };

      mockPrisma.$transaction.mockImplementation(async (callback) => callback(tx));

      const result = await moderateItemReview({
        prismaClient: mockPrisma,
        reviewId: "review_1",
        isHidden: true,
        hiddenReason: "Abusive language",
      });

      expect(tx.food.update).toHaveBeenCalledWith({
        where: { id: "food_1" },
        data: {
          rating: 4.5,
          ratingSum: 45,
          totalReviews: 10,
        },
        select: {
          id: true,
          name: true,
          foodImage: true,
          rating: true,
          ratingSum: true,
          totalReviews: true,
        },
      });
      expect(result.review.isHidden).toBe(true);
      expect(result.item.ratingCount).toBe(10);
    });
  });

  describe("comment moderation", () => {
    test("rejects blocked item review comments", async () => {
      await expect(
        submitItemReviews({
          prismaClient: mockPrisma,
          orderId: "order_1",
          customerId: "user_1",
          reviews: [
            {
              orderItemId: "order_item_1",
              rating: 5,
              comment: "Reach me on boss@example.com",
            },
          ],
        })
      ).rejects.toMatchObject({
        code: "ITEM_REVIEW_COMMENT_NOT_ALLOWED",
      });
    });
  });
});
