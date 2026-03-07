const prisma = require("../config/prisma");
const {
  DEFAULT_GLOBAL_MEAN,
  normalizeRatingResponse,
} = require("../utils/rating_calculator");
const {
  assertReviewCommentAllowed,
  normalizeReportDetails,
  normalizeReportReason,
} = require("../utils/review_moderation");

const VENDOR_TYPE_CONFIG = {
  restaurant: {
    orderField: "restaurantId",
    relationField: "restaurant",
    prismaModel: "restaurant",
    nameField: "restaurantName",
    imageField: "logo",
  },
  grocery: {
    orderField: "groceryStoreId",
    relationField: "groceryStore",
    prismaModel: "groceryStore",
    nameField: "storeName",
    imageField: "logo",
  },
  pharmacy: {
    orderField: "pharmacyStoreId",
    relationField: "pharmacyStore",
    prismaModel: "pharmacyStore",
    nameField: "storeName",
    imageField: "logo",
  },
  grabmart: {
    orderField: "grabMartStoreId",
    relationField: "grabMartStore",
    prismaModel: "grabMartStore",
    nameField: "storeName",
    imageField: "logo",
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

const normalizeHiddenReason = (hiddenReason) => {
  if (typeof hiddenReason !== "string") return null;
  const normalized = hiddenReason.trim();
  return normalized.length > 0 ? normalized.slice(0, 200) : null;
};

const resolvePublicVendorType = (vendorType) => {
  const normalized = String(vendorType || "").trim().toLowerCase();
  return VENDOR_TYPE_CONFIG[normalized] || null;
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

const buildAggregateAfterVisibilityChange = ({
  currentCount,
  currentSum,
  reviewRating,
  hide,
}) => {
  const nextRatingCount = hide
    ? Math.max(0, currentCount - 1)
    : currentCount + 1;
  const nextRatingSum = hide
    ? Math.max(0, roundToTwo(currentSum - reviewRating))
    : roundToTwo(currentSum + reviewRating);
  const nextRawRating = nextRatingCount > 0
    ? roundToTwo(nextRatingSum / nextRatingCount)
    : DEFAULT_GLOBAL_MEAN;

  return {
    nextRatingCount,
    nextRatingSum,
    nextRawRating,
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
  assertReviewCommentAllowed(normalizedComment, VendorRatingError, {
    code: "VENDOR_REVIEW_COMMENT_NOT_ALLOWED",
  });

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

const getVendorReviews = async ({
  prismaClient = prisma,
  vendorType,
  vendorId,
  sort = "popular",
  page = 1,
  limit = 20,
}) => {
  const target = resolvePublicVendorType(vendorType);
  if (!target) {
    throw new VendorRatingError("Unsupported vendor type", {
      statusCode: 400,
      code: "VENDOR_REVIEW_UNSUPPORTED_TYPE",
    });
  }

  const pageValue = Math.max(1, Number.parseInt(page, 10) || 1);
  const limitValue = Math.min(50, Math.max(1, Number.parseInt(limit, 10) || 20));
  const normalizedSort = String(sort || "popular").toLowerCase() === "latest" ? "latest" : "popular";

  const vendor = await prismaClient[target.prismaModel].findUnique({
    where: { id: vendorId },
    select: {
      id: true,
      [target.nameField]: true,
      [target.imageField]: true,
      rating: true,
      ratingCount: true,
      totalReviews: true,
    },
  });

  if (!vendor) {
    throw new VendorRatingError("Vendor not found", {
      statusCode: 404,
      code: "VENDOR_REVIEW_VENDOR_NOT_FOUND",
    });
  }

  const where = { [target.orderField]: vendorId, isHidden: false };
  const orderBy =
    normalizedSort === "latest"
      ? [{ createdAt: "desc" }]
      : [{ rating: "desc" }, { createdAt: "desc" }];

  const [reviews, groupedRatings] = await Promise.all([
    prismaClient.vendorReview.findMany({
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
    prismaClient.vendorReview.groupBy({
      by: ["rating"],
      where,
      _count: {
        _all: true,
      },
    }),
  ]);

  const reviewCount = Math.max(
    0,
    Number(vendor.totalReviews || 0),
    Number(vendor.ratingCount || 0)
  );
  const ratingMeta = normalizeRatingResponse({
    rating: vendor.rating,
    ratingCount: vendor.ratingCount,
    totalReviews: reviewCount,
  });

  return {
    vendor: {
      id: vendor.id,
      type: String(vendorType || "").trim().toLowerCase(),
      name: vendor[target.nameField] || "",
      image: vendor[target.imageField] || null,
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

const reportVendorReview = async ({
  prismaClient = prisma,
  reviewId,
  reporterId,
  reason,
  details,
}) => {
  const normalizedReason = normalizeReportReason(reason);
  if (!normalizedReason) {
    throw new VendorRatingError("Invalid review report reason", {
      statusCode: 400,
      code: "VENDOR_REVIEW_REPORT_REASON_INVALID",
    });
  }

  const normalizedDetails = normalizeReportDetails(details);

  try {
    return await prismaClient.$transaction(async (tx) => {
      const review = await tx.vendorReview.findUnique({
        where: { id: reviewId },
        select: {
          id: true,
          isHidden: true,
          reportedCount: true,
        },
      });

      if (!review) {
        throw new VendorRatingError("Vendor review not found", {
          statusCode: 404,
          code: "VENDOR_REVIEW_NOT_FOUND",
        });
      }

      const report = await tx.vendorReviewReport.create({
        data: {
          vendorReviewId: reviewId,
          reporterId,
          reason: normalizedReason,
          details: normalizedDetails,
        },
        select: {
          id: true,
          createdAt: true,
        },
      });

      const updatedReview = await tx.vendorReview.update({
        where: { id: reviewId },
        data: {
          reportedCount: { increment: 1 },
          lastReportedAt: new Date(),
        },
        select: {
          id: true,
          isHidden: true,
          reportedCount: true,
          lastReportedAt: true,
        },
      });

      return {
        reviewId: updatedReview.id,
        reportId: report.id,
        isHidden: updatedReview.isHidden,
        reportedCount: updatedReview.reportedCount,
        reportedAt: report.createdAt,
      };
    });
  } catch (error) {
    if (error instanceof VendorRatingError) {
      throw error;
    }

    const isDuplicateReport =
      error?.code === "P2002" ||
      String(error?.message || "").includes("Unique constraint");

    if (isDuplicateReport) {
      throw new VendorRatingError(
        "You have already reported this vendor review",
        {
          statusCode: 409,
          code: "VENDOR_REVIEW_ALREADY_REPORTED",
        }
      );
    }

    throw error;
  }
};

const moderateVendorReview = async ({
  prismaClient = prisma,
  reviewId,
  isHidden,
  hiddenReason,
}) => {
  const shouldHide = Boolean(isHidden);
  const normalizedHiddenReason = shouldHide
    ? normalizeHiddenReason(hiddenReason)
    : null;

  return prismaClient.$transaction(async (tx) => {
    const review = await tx.vendorReview.findUnique({
      where: { id: reviewId },
      select: {
        id: true,
        rating: true,
        isHidden: true,
        hiddenReason: true,
        hiddenAt: true,
        reportedCount: true,
        restaurantId: true,
        groceryStoreId: true,
        pharmacyStoreId: true,
        grabMartStoreId: true,
      },
    });

    if (!review) {
      throw new VendorRatingError("Vendor review not found", {
        statusCode: 404,
        code: "VENDOR_REVIEW_NOT_FOUND",
      });
    }

    if (review.isHidden === shouldHide) {
      return {
        review: {
          id: review.id,
          isHidden: review.isHidden,
          hiddenReason: review.hiddenReason,
          hiddenAt: review.hiddenAt,
          reportedCount: review.reportedCount,
        },
        vendor: null,
      };
    }

    const target = resolveVendorReviewTarget(review);
    if (!target) {
      throw new VendorRatingError("Vendor review target is invalid", {
        statusCode: 400,
        code: "VENDOR_REVIEW_TARGET_INVALID",
      });
    }

    const vendor = await tx[target.prismaModel].findUnique({
      where: { id: target.vendorId },
      select: {
        id: true,
        rating: true,
        ratingCount: true,
        ratingSum: true,
        totalReviews: true,
      },
    });

    if (!vendor) {
      throw new VendorRatingError("Vendor not found", {
        statusCode: 404,
        code: "VENDOR_REVIEW_VENDOR_NOT_FOUND",
      });
    }

    const { ratingCount: currentCount, ratingSum: currentSum } =
      deriveCurrentAggregate(vendor);
    const {
      nextRatingCount,
      nextRatingSum,
      nextRawRating,
    } = buildAggregateAfterVisibilityChange({
      currentCount,
      currentSum,
      reviewRating: Number(review.rating || 0),
      hide: shouldHide,
    });

    const [updatedReview, updatedVendor] = await Promise.all([
      tx.vendorReview.update({
        where: { id: reviewId },
        data: {
          isHidden: shouldHide,
          hiddenReason: normalizedHiddenReason,
          hiddenAt: shouldHide ? new Date() : null,
        },
        select: {
          id: true,
          isHidden: true,
          hiddenReason: true,
          hiddenAt: true,
          reportedCount: true,
        },
      }),
      tx[target.prismaModel].update({
        where: { id: target.vendorId },
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
      }),
    ]);

    const ratingMeta = normalizeRatingResponse({
      rating: updatedVendor.rating,
      ratingCount: updatedVendor.ratingCount,
      totalReviews: updatedVendor.totalReviews,
    });

    return {
      review: updatedReview,
      vendor: {
        id: updatedVendor.id,
        type: target.vendorType,
        rawRating: ratingMeta.rawRating,
        weightedRating: ratingMeta.weightedRating,
        rating: ratingMeta.rating,
        ratingCount: ratingMeta.ratingCount,
        totalReviews: ratingMeta.totalReviews,
      },
    };
  });
};

module.exports = {
  VendorRatingError,
  VENDOR_REVIEW_ORDER_SELECT,
  buildOrderVendorRatingMeta,
  decorateOrderWithVendorRatingMeta,
  decorateOrdersWithVendorRatingMeta,
  getVendorReviews,
  moderateVendorReview,
  reportVendorReview,
  resolveVendorReviewTarget,
  submitVendorRating,
};
