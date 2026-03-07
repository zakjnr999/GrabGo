const prisma = require("../config/prisma");
const { normalizeRatingResponse } = require("../utils/rating_calculator");

const VENDOR_TYPE_CONFIG = {
  restaurant: {
    orderField: "restaurantId",
    relationField: "restaurant",
    prismaModel: "restaurant",
  },
  grocery: {
    orderField: "groceryStoreId",
    relationField: "groceryStore",
    prismaModel: "groceryStore",
  },
  pharmacy: {
    orderField: "pharmacyStoreId",
    relationField: "pharmacyStore",
    prismaModel: "pharmacyStore",
  },
  grabmart: {
    orderField: "grabMartStoreId",
    relationField: "grabMartStore",
    prismaModel: "grabMartStore",
  },
};

const VENDOR_REVIEW_ORDER_SELECT = {
  id: true,
  customerId: true,
  status: true,
  orderType: true,
  restaurantId: true,
  groceryStoreId: true,
  pharmacyStoreId: true,
  grabMartStoreId: true,
  vendorReview: {
    select: {
      id: true,
      rating: true,
      createdAt: true,
    },
  },
  restaurant: {
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      ratingSum: true,
      totalReviews: true,
    },
  },
  groceryStore: {
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      ratingSum: true,
      totalReviews: true,
    },
  },
  pharmacyStore: {
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      ratingSum: true,
      totalReviews: true,
    },
  },
  grabMartStore: {
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      ratingSum: true,
      totalReviews: true,
    },
  },
};

class VendorRatingError extends Error {
  constructor(message, { statusCode = 400, code = "VENDOR_RATING_FAILED" } = {}) {
    super(message);
    this.name = "VendorRatingError";
    this.statusCode = statusCode;
    this.code = code;
  }
}

const roundToTwo = (value) => Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;

const normalizeFeedbackTags = (feedbackTags) => {
  if (!Array.isArray(feedbackTags)) return [];
  return [...new Set(
    feedbackTags
      .map((entry) => String(entry || "").trim())
      .filter(Boolean)
  )].slice(0, 10);
};

const normalizeComment = (comment) => {
  if (typeof comment !== "string") return null;
  const normalized = comment.trim();
  return normalized.length > 0 ? normalized.slice(0, 500) : null;
};

const resolveVendorReviewTarget = (order) => {
  if (!order || typeof order !== "object") return null;

  const candidates = Object.entries(VENDOR_TYPE_CONFIG)
    .map(([vendorType, config]) => {
      const vendorId = order[config.orderField] || order[config.relationField]?.id || null;
      const vendor = order[config.relationField] || null;
      return vendorId
        ? {
            vendorType,
            vendorId: String(vendorId),
            ...config,
            vendor,
          }
        : null;
    })
    .filter(Boolean);

  if (candidates.length !== 1) {
    return null;
  }

  return candidates[0];
};

const buildOrderVendorRatingMeta = (order, { viewerRole = "customer" } = {}) => {
  const review = order?.vendorReview || null;
  const vendorTarget = resolveVendorReviewTarget(order);
  const isDelivered = String(order?.status || "").toLowerCase() === "delivered";
  const vendorRatingSubmitted = Boolean(review);

  return {
    canRateVendor:
      viewerRole === "customer" &&
      isDelivered &&
      Boolean(vendorTarget) &&
      !vendorRatingSubmitted,
    vendorRatingSubmitted,
    vendorRatingValue: review ? Number(review.rating) : null,
    vendorRatedAt: review?.createdAt || null,
  };
};

const decorateOrderWithVendorRatingMeta = (order, options = {}) => {
  if (!order || typeof order !== "object") return order;
  const { vendorReview, ...rest } = order;
  return {
    ...rest,
    ...buildOrderVendorRatingMeta(order, options),
  };
};

const decorateOrdersWithVendorRatingMeta = (payload, options = {}) => {
  if (Array.isArray(payload)) {
    return payload.map((entry) => decorateOrderWithVendorRatingMeta(entry, options));
  }
  return decorateOrderWithVendorRatingMeta(payload, options);
};

const deriveCurrentAggregate = (vendor) => {
  const ratingCount = Math.max(
    0,
    Math.floor(Number(vendor?.ratingCount || 0)),
    Math.floor(Number(vendor?.totalReviews || 0))
  );
  const rawRating = Number(vendor?.rating || 0);
  const ratingSum =
    Number(vendor?.ratingSum || 0) > 0
      ? Number(vendor.ratingSum)
      : roundToTwo(rawRating * ratingCount);

  return {
    ratingCount,
    ratingSum,
  };
};

const validateRatingRequest = ({ rating }) => {
  const numericRating = Number(rating);
  if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5) {
    throw new VendorRatingError("rating must be an integer between 1 and 5", {
      statusCode: 400,
      code: "INVALID_VENDOR_RATING",
    });
  }
  return numericRating;
};

const submitVendorRating = async ({
  prismaClient = prisma,
  orderId,
  customerId,
  rating,
  feedbackTags = [],
  comment,
}) => {
  const normalizedRating = validateRatingRequest({ rating });
  const normalizedTags = normalizeFeedbackTags(feedbackTags);
  const normalizedComment = normalizeComment(comment);

  try {
    return await prismaClient.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        select: VENDOR_REVIEW_ORDER_SELECT,
      });

      if (!order) {
        throw new VendorRatingError("Order not found", {
          statusCode: 404,
          code: "ORDER_NOT_FOUND",
        });
      }

      if (order.customerId !== customerId) {
        throw new VendorRatingError("Not authorized to rate this order", {
          statusCode: 403,
          code: "ORDER_ACCESS_DENIED",
        });
      }

      if (String(order.status || "").toLowerCase() !== "delivered") {
        throw new VendorRatingError("Only delivered orders can be rated", {
          statusCode: 400,
          code: "ORDER_NOT_DELIVERED",
        });
      }

      if (order.vendorReview) {
        throw new VendorRatingError("Vendor rating has already been submitted for this order", {
          statusCode: 409,
          code: "VENDOR_RATING_ALREADY_SUBMITTED",
        });
      }

      const vendorTarget = resolveVendorReviewTarget(order);
      if (!vendorTarget) {
        throw new VendorRatingError("Vendor rating is only supported for single-vendor orders", {
          statusCode: 400,
          code: "VENDOR_RATING_SINGLE_VENDOR_ONLY",
        });
      }

      const vendor = vendorTarget.vendor;
      const { ratingCount: currentCount, ratingSum: currentSum } = deriveCurrentAggregate(vendor);
      const nextRatingCount = currentCount + 1;
      const nextRatingSum = roundToTwo(currentSum + normalizedRating);
      const nextRawRating = roundToTwo(nextRatingSum / nextRatingCount);

      const review = await tx.vendorReview.create({
        data: {
          orderId,
          customerId,
          vendorType: vendorTarget.vendorType,
          rating: normalizedRating,
          feedbackTags: normalizedTags,
          comment: normalizedComment,
          [vendorTarget.orderField]: vendorTarget.vendorId,
        },
        select: {
          orderId: true,
          rating: true,
          createdAt: true,
        },
      });

      const updatedVendor = await tx[vendorTarget.prismaModel].update({
        where: { id: vendorTarget.vendorId },
        data: {
          rating: nextRawRating,
          ratingCount: nextRatingCount,
          ratingSum: nextRatingSum,
          totalReviews: nextRatingCount,
        },
        select: {
          id: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
        },
      });

      const ratingMeta = normalizeRatingResponse({
        rating: updatedVendor.rating,
        ratingCount: updatedVendor.ratingCount,
        totalReviews: updatedVendor.totalReviews,
      });

      return {
        orderId: review.orderId,
        rating: review.rating,
        submittedAt: review.createdAt,
        vendor: {
          id: updatedVendor.id,
          type: vendorTarget.vendorType,
          rawRating: ratingMeta.rawRating,
          weightedRating: ratingMeta.weightedRating,
          rating: ratingMeta.rating,
          ratingCount: ratingMeta.ratingCount,
          totalReviews: ratingMeta.totalReviews,
        },
      };
    });
  } catch (error) {
    if (error instanceof VendorRatingError) {
      throw error;
    }

    const isDuplicateReview =
      error?.code === "P2002" ||
      String(error?.message || "").includes("Unique constraint");

    if (isDuplicateReview) {
      throw new VendorRatingError("Vendor rating has already been submitted for this order", {
        statusCode: 409,
        code: "VENDOR_RATING_ALREADY_SUBMITTED",
      });
    }

    throw error;
  }
};

module.exports = {
  VendorRatingError,
  VENDOR_REVIEW_ORDER_SELECT,
  buildOrderVendorRatingMeta,
  decorateOrderWithVendorRatingMeta,
  decorateOrdersWithVendorRatingMeta,
  resolveVendorReviewTarget,
  submitVendorRating,
};
