const prisma = require("../config/prisma");
const { normalizeRatingResponse } = require("../utils/rating_calculator");

const ITEM_TYPE_CONFIG = {
  food: {
    routeType: "food",
    orderItemType: "Food",
    orderField: "foodId",
    relationField: "food",
    prismaModel: "food",
    countField: "totalReviews",
    nameField: "name",
    imageField: "foodImage",
  },
  grocery: {
    routeType: "grocery",
    orderItemType: "GroceryItem",
    orderField: "groceryItemId",
    relationField: "groceryItem",
    prismaModel: "groceryItem",
    countField: "reviewCount",
    nameField: "name",
    imageField: "image",
  },
  pharmacy: {
    routeType: "pharmacy",
    orderItemType: "PharmacyItem",
    orderField: "pharmacyItemId",
    relationField: "pharmacyItem",
    prismaModel: "pharmacyItem",
    countField: "reviewCount",
    nameField: "name",
    imageField: "image",
  },
  grabmart: {
    routeType: "grabmart",
    orderItemType: "GrabMartItem",
    orderField: "grabMartItemId",
    relationField: "grabMartItem",
    prismaModel: "grabMartItem",
    countField: "reviewCount",
    nameField: "name",
    imageField: "image",
  },
};

const ORDER_ITEM_TYPE_LOOKUP = Object.values(ITEM_TYPE_CONFIG).reduce(
  (acc, config) => {
    acc[config.orderItemType.toLowerCase()] = config;
    return acc;
  },
  {}
);

const ITEM_REVIEW_ORDER_SELECT = {
  id: true,
  customerId: true,
  status: true,
  items: {
    select: {
      id: true,
      itemType: true,
      name: true,
      image: true,
      quantity: true,
      foodId: true,
      groceryItemId: true,
      pharmacyItemId: true,
      grabMartItemId: true,
      itemReview: {
        select: {
          id: true,
          rating: true,
          createdAt: true,
        },
      },
      food: {
        select: {
          id: true,
          name: true,
          foodImage: true,
          rating: true,
          ratingSum: true,
          totalReviews: true,
        },
      },
      groceryItem: {
        select: {
          id: true,
          name: true,
          image: true,
          rating: true,
          ratingSum: true,
          reviewCount: true,
        },
      },
      pharmacyItem: {
        select: {
          id: true,
          name: true,
          image: true,
          rating: true,
          ratingSum: true,
          reviewCount: true,
        },
      },
      grabMartItem: {
        select: {
          id: true,
          name: true,
          image: true,
          rating: true,
          ratingSum: true,
          reviewCount: true,
        },
      },
    },
  },
};

class ItemReviewError extends Error {
  constructor(message, { statusCode = 400, code = "ITEM_REVIEW_FAILED" } = {}) {
    super(message);
    this.name = "ItemReviewError";
    this.statusCode = statusCode;
    this.code = code;
  }
}

const roundToTwo = (value) =>
  Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;

const normalizeFeedbackTags = (feedbackTags) => {
  if (!Array.isArray(feedbackTags)) return [];
  return [...new Set(feedbackTags.map((entry) => String(entry || "").trim()).filter(Boolean))].slice(0, 10);
};

const normalizeComment = (comment) => {
  if (typeof comment !== "string") return null;
  const normalized = comment.trim();
  return normalized.length > 0 ? normalized.slice(0, 500) : null;
};

const resolvePublicItemType = (itemType) => {
  const normalized = String(itemType || "").trim().toLowerCase();
  return ITEM_TYPE_CONFIG[normalized] || null;
};

const resolveOrderItemReviewTarget = (orderItem) => {
  if (!orderItem || typeof orderItem !== "object") return null;

  const enumConfig = ORDER_ITEM_TYPE_LOOKUP[String(orderItem.itemType || "").toLowerCase()];
  if (enumConfig) {
    const itemId = orderItem[enumConfig.orderField] || orderItem[enumConfig.relationField]?.id;
    if (itemId) {
      return {
        itemType: enumConfig.routeType,
        itemId: String(itemId),
        ...enumConfig,
        item: orderItem[enumConfig.relationField] || null,
      };
    }
  }

  const candidates = Object.values(ITEM_TYPE_CONFIG)
    .map((config) => {
      const itemId = orderItem[config.orderField] || orderItem[config.relationField]?.id;
      if (!itemId) return null;
      return {
        itemType: config.routeType,
        itemId: String(itemId),
        ...config,
        item: orderItem[config.relationField] || null,
      };
    })
    .filter(Boolean);

  if (candidates.length !== 1) return null;
  return candidates[0];
};

const buildOrderItemReviewMeta = (orderItem, { orderStatus, viewerRole = "customer" } = {}) => {
  const review = orderItem?.itemReview || null;
  const target = resolveOrderItemReviewTarget(orderItem);
  const isDelivered = String(orderStatus || "").toLowerCase() === "delivered";
  const itemRatingSubmitted = Boolean(review);

  return {
    canRateItem:
      viewerRole === "customer" &&
      isDelivered &&
      Boolean(target) &&
      !itemRatingSubmitted,
    itemRatingSubmitted,
    itemRatingValue: review ? Number(review.rating) : null,
    itemRatedAt: review?.createdAt || null,
    itemReviewType: target?.itemType || null,
    reviewableItemId: target?.itemId || null,
  };
};

const decorateOrderWithItemReviewMeta = (order, options = {}) => {
  if (!order || typeof order !== "object") return order;

  const items = Array.isArray(order.items) ? order.items : [];
  const decoratedItems = items.map((item) => {
    if (!item || typeof item !== "object") return item;
    const { itemReview, ...rest } = item;
    return {
      ...rest,
      ...buildOrderItemReviewMeta(item, {
        orderStatus: order.status,
        viewerRole: options.viewerRole,
      }),
    };
  });

  const pendingItemReviewCount = decoratedItems.filter((item) => item?.canRateItem).length;
  const submittedItemReviewCount = decoratedItems.filter((item) => item?.itemRatingSubmitted).length;
  const itemReviewableCount = decoratedItems.filter(
    (item) => item?.reviewableItemId != null
  ).length;

  return {
    ...order,
    items: decoratedItems,
    canRateItems: options.viewerRole === "customer" && pendingItemReviewCount > 0,
    pendingItemReviewCount,
    submittedItemReviewCount,
    itemReviewableCount,
  };
};

const decorateOrdersWithItemReviewMeta = (payload, options = {}) => {
  if (Array.isArray(payload)) {
    return payload.map((entry) => decorateOrderWithItemReviewMeta(entry, options));
  }
  return decorateOrderWithItemReviewMeta(payload, options);
};

const validateRating = (rating) => {
  const numericRating = Number(rating);
  if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5) {
    throw new ItemReviewError("rating must be an integer between 1 and 5", {
      statusCode: 400,
      code: "INVALID_ITEM_RATING",
    });
  }
  return numericRating;
};

const normalizeReviewDrafts = (reviews) => {
  if (!Array.isArray(reviews) || reviews.length === 0) {
    throw new ItemReviewError("reviews must be a non-empty array", {
      statusCode: 400,
      code: "ITEM_REVIEWS_REQUIRED",
    });
  }

  return reviews.map((entry) => {
    const orderItemId = String(entry?.orderItemId || "").trim();
    if (!orderItemId) {
      throw new ItemReviewError("orderItemId is required for each review", {
        statusCode: 400,
        code: "ITEM_REVIEW_ORDER_ITEM_REQUIRED",
      });
    }

    return {
      orderItemId,
      rating: validateRating(entry?.rating),
      feedbackTags: normalizeFeedbackTags(entry?.feedbackTags),
      comment: normalizeComment(entry?.comment),
    };
  });
};

const deriveCurrentAggregate = (item, countField) => {
  const ratingCount = Math.max(
    0,
    Math.floor(Number(item?.[countField] || 0))
  );
  const rawRating = Number(item?.rating || 0);
  const ratingSum =
    Number(item?.ratingSum || 0) > 0
      ? Number(item.ratingSum)
      : roundToTwo(rawRating * ratingCount);

  return { ratingCount, ratingSum };
};

const buildSubmittedItemSnapshot = ({ target, updatedItem }) => {
  const countValue = Number(updatedItem?.[target.countField] || 0);
  const ratingMeta = normalizeRatingResponse({
    rating: updatedItem?.rating,
    reviewCount: countValue,
    totalReviews: countValue,
  });

  return {
    id: updatedItem.id,
    type: target.itemType,
    name: updatedItem[target.nameField] || "",
    image: updatedItem[target.imageField] || null,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    rating: ratingMeta.rating,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
  };
};

const submitItemReviews = async ({
  prismaClient = prisma,
  orderId,
  customerId,
  reviews,
}) => {
  const normalizedReviews = normalizeReviewDrafts(reviews);
  const seenOrderItemIds = new Set();
  for (const review of normalizedReviews) {
    if (seenOrderItemIds.has(review.orderItemId)) {
      throw new ItemReviewError("Duplicate orderItemId in reviews payload", {
        statusCode: 400,
        code: "ITEM_REVIEW_DUPLICATE_ORDER_ITEM",
      });
    }
    seenOrderItemIds.add(review.orderItemId);
  }

  try {
    return await prismaClient.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        select: ITEM_REVIEW_ORDER_SELECT,
      });

      if (!order) {
        throw new ItemReviewError("Order not found", {
          statusCode: 404,
          code: "ORDER_NOT_FOUND",
        });
      }

      if (order.customerId !== customerId) {
        throw new ItemReviewError("Not authorized to rate items for this order", {
          statusCode: 403,
          code: "ORDER_ACCESS_DENIED",
        });
      }

      if (String(order.status || "").toLowerCase() !== "delivered") {
        throw new ItemReviewError("Only delivered orders can be reviewed", {
          statusCode: 400,
          code: "ORDER_NOT_DELIVERED",
        });
      }

      const orderItemsById = new Map(
        (order.items || []).map((item) => [String(item.id), item])
      );
      const aggregateState = new Map();
      const submittedReviews = [];

      for (const reviewDraft of normalizedReviews) {
        const orderItem = orderItemsById.get(reviewDraft.orderItemId);
        if (!orderItem) {
          throw new ItemReviewError("Review item does not belong to this order", {
            statusCode: 400,
            code: "ITEM_REVIEW_ORDER_ITEM_NOT_FOUND",
          });
        }

        if (orderItem.itemReview) {
          throw new ItemReviewError("This order item has already been reviewed", {
            statusCode: 409,
            code: "ITEM_REVIEW_ALREADY_SUBMITTED",
          });
        }

        const target = resolveOrderItemReviewTarget(orderItem);
        if (!target || !target.item) {
          throw new ItemReviewError("Unable to resolve the purchased item for review", {
            statusCode: 400,
            code: "ITEM_REVIEW_TARGET_INVALID",
          });
        }

        const aggregateKey = `${target.itemType}:${target.itemId}`;
        const aggregate =
          aggregateState.get(aggregateKey) ||
          deriveCurrentAggregate(target.item, target.countField);
        const nextRatingCount = aggregate.ratingCount + 1;
        const nextRatingSum = roundToTwo(aggregate.ratingSum + reviewDraft.rating);
        const nextRawRating = roundToTwo(nextRatingSum / nextRatingCount);

        const createdReview = await tx.itemReview.create({
          data: {
            orderId,
            orderItemId: reviewDraft.orderItemId,
            customerId,
            itemType: target.itemType,
            rating: reviewDraft.rating,
            feedbackTags: reviewDraft.feedbackTags,
            comment: reviewDraft.comment,
            [target.orderField]: target.itemId,
          },
          select: {
            orderItemId: true,
            rating: true,
            createdAt: true,
          },
        });

        const updatedItem = await tx[target.prismaModel].update({
          where: { id: target.itemId },
          data: {
            rating: nextRawRating,
            ratingSum: nextRatingSum,
            [target.countField]: nextRatingCount,
          },
          select: {
            id: true,
            [target.nameField]: true,
            [target.imageField]: true,
            rating: true,
            ratingSum: true,
            [target.countField]: true,
          },
        });

        aggregateState.set(aggregateKey, {
          ratingCount: nextRatingCount,
          ratingSum: nextRatingSum,
        });

        submittedReviews.push({
          orderItemId: createdReview.orderItemId,
          rating: createdReview.rating,
          submittedAt: createdReview.createdAt,
          item: buildSubmittedItemSnapshot({ target, updatedItem }),
        });
      }

      const alreadySubmittedCount = (order.items || []).filter((item) => Boolean(item.itemReview)).length;
      const totalReviewableCount = (order.items || []).filter((item) =>
        Boolean(resolveOrderItemReviewTarget(item))
      ).length;

      return {
        orderId,
        submittedCount: submittedReviews.length,
        pendingItemReviewCount: Math.max(
          0,
          totalReviewableCount - alreadySubmittedCount - submittedReviews.length
        ),
        reviews: submittedReviews,
      };
    });
  } catch (error) {
    if (error instanceof ItemReviewError) {
      throw error;
    }

    const isDuplicateReview =
      error?.code === "P2002" ||
      String(error?.message || "").includes("Unique constraint");

    if (isDuplicateReview) {
      throw new ItemReviewError("This order item has already been reviewed", {
        statusCode: 409,
        code: "ITEM_REVIEW_ALREADY_SUBMITTED",
      });
    }

    throw error;
  }
};

const buildReviewerDisplay = (customer) => {
  const username = String(customer?.username || "").trim();
  if (username) return username;

  const email = String(customer?.email || "").trim();
  if (email.includes("@")) {
    return email.split("@")[0];
  }

  return "GrabGo customer";
};

const buildReviewBreakdown = (groupedRatings) => {
  const breakdown = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  for (const row of groupedRatings || []) {
    const rating = Number(row?.rating || 0);
    if (breakdown[rating] !== undefined) {
      breakdown[rating] = Number(row?._count?._all || 0);
    }
  }
  return breakdown;
};

const getItemReviews = async ({
  prismaClient = prisma,
  itemType,
  itemId,
  sort = "popular",
  page = 1,
  limit = 20,
}) => {
  const target = resolvePublicItemType(itemType);
  if (!target) {
    throw new ItemReviewError("Unsupported item type", {
      statusCode: 400,
      code: "ITEM_REVIEW_UNSUPPORTED_TYPE",
    });
  }

  const pageValue = Math.max(1, Number.parseInt(page, 10) || 1);
  const limitValue = Math.min(50, Math.max(1, Number.parseInt(limit, 10) || 20));
  const normalizedSort = String(sort || "popular").toLowerCase() === "latest" ? "latest" : "popular";

  const item = await prismaClient[target.prismaModel].findUnique({
    where: { id: itemId },
    select: {
      id: true,
      [target.nameField]: true,
      [target.imageField]: true,
      rating: true,
      ratingSum: true,
      [target.countField]: true,
    },
  });

  if (!item) {
    throw new ItemReviewError("Item not found", {
      statusCode: 404,
      code: "ITEM_REVIEW_ITEM_NOT_FOUND",
    });
  }

  const where = { [target.orderField]: itemId };
  const orderBy =
    normalizedSort === "latest"
      ? [{ createdAt: "desc" }]
      : [{ rating: "desc" }, { createdAt: "desc" }];

  const [reviews, groupedRatings] = await Promise.all([
    prismaClient.itemReview.findMany({
      where,
      orderBy,
      skip: (pageValue - 1) * limitValue,
      take: limitValue,
      select: {
        id: true,
        rating: true,
        feedbackTags: true,
        comment: true,
        createdAt: true,
        customer: {
          select: {
            id: true,
            username: true,
            email: true,
            profilePicture: true,
          },
        },
      },
    }),
    prismaClient.itemReview.groupBy({
      by: ["rating"],
      where,
      _count: {
        _all: true,
      },
    }),
  ]);

  const reviewCount = Number(item[target.countField] || 0);
  const ratingMeta = normalizeRatingResponse({
    rating: item.rating,
    reviewCount,
    totalReviews: reviewCount,
  });

  return {
    item: {
      id: item.id,
      type: target.routeType,
      name: item[target.nameField] || "",
      image: item[target.imageField] || null,
      rawRating: ratingMeta.rawRating,
      weightedRating: ratingMeta.weightedRating,
      rating: ratingMeta.rating,
      ratingCount: ratingMeta.ratingCount,
      totalReviews: ratingMeta.totalReviews,
    },
    sort: normalizedSort,
    page: pageValue,
    limit: limitValue,
    breakdown: buildReviewBreakdown(groupedRatings),
    reviews: reviews.map((review) => ({
      id: review.id,
      rating: review.rating,
      feedbackTags: review.feedbackTags || [],
      comment: review.comment,
      createdAt: review.createdAt,
      reviewer: {
        id: review.customer?.id || "",
        name: buildReviewerDisplay(review.customer),
        profilePicture: review.customer?.profilePicture || null,
      },
    })),
  };
};

module.exports = {
  ItemReviewError,
  ITEM_REVIEW_ORDER_SELECT,
  resolveOrderItemReviewTarget,
  buildOrderItemReviewMeta,
  decorateOrderWithItemReviewMeta,
  decorateOrdersWithItemReviewMeta,
  submitItemReviews,
  getItemReviews,
};
