const express = require("express");
const { body, query, param, validationResult } = require("express-validator");
const { protect, admin } = require("../middleware/auth");
const {
  ItemReviewError,
  getItemReviews,
  moderateItemReview,
  reportItemReview,
} = require("../services/item_review_service");
const logger = require("../utils/logger");
const metrics = require("../utils/metrics");

const router = express.Router();

router.get(
  "/:itemType/:itemId",
  [
    param("itemType")
      .isString()
      .notEmpty()
      .withMessage("itemType is required"),
    param("itemId")
      .isString()
      .notEmpty()
      .withMessage("itemId is required"),
    query("sort")
      .optional()
      .isIn(["popular", "latest"])
      .withMessage("sort must be popular or latest"),
    query("page")
      .optional()
      .isInt({ min: 1 })
      .withMessage("page must be a positive integer"),
    query("limit")
      .optional()
      .isInt({ min: 1, max: 50 })
      .withMessage("limit must be between 1 and 50"),
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

      const result = await getItemReviews({
        itemType: req.params.itemType,
        itemId: req.params.itemId,
        sort: req.query.sort,
        page: req.query.page,
        limit: req.query.limit,
      });
      metrics.recordReviewEvent({ reviewType: "item", action: "fetch", result: "success" });

      return res.json({
        success: true,
        message: "Item reviews retrieved successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof ItemReviewError) {
        metrics.recordReviewEvent({
          reviewType: "item",
          action: "fetch",
          result: error.code || "business_error",
        });
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      logger.error("item_reviews_fetch_failed", { error });
      metrics.recordReviewEvent({ reviewType: "item", action: "fetch", result: "failure" });
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.post(
  "/:reviewId/report",
  protect,
  [
    param("reviewId")
      .isString()
      .notEmpty()
      .withMessage("reviewId is required"),
    body("reason")
      .isIn([
        "abusive_offensive",
        "spam",
        "personal_info",
        "unrelated",
        "false_misleading",
      ])
      .withMessage("reason is invalid"),
    body("details")
      .optional({ nullable: true })
      .isString()
      .isLength({ max: 300 })
      .withMessage("details must be at most 300 characters"),
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

      const result = await reportItemReview({
        reviewId: req.params.reviewId,
        reporterId: req.user.id,
        reason: req.body.reason,
        details: req.body.details,
      });
      metrics.recordReviewEvent({ reviewType: "item", action: "report", result: "success" });

      return res.status(201).json({
        success: true,
        message: "Item review reported successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof ItemReviewError) {
        metrics.recordReviewEvent({
          reviewType: "item",
          action: "report",
          result: error.code || "business_error",
        });
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      logger.error("item_review_report_failed", { error });
      metrics.recordReviewEvent({ reviewType: "item", action: "report", result: "failure" });
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

router.patch(
  "/:reviewId/moderation",
  protect,
  admin,
  [
    param("reviewId")
      .isString()
      .notEmpty()
      .withMessage("reviewId is required"),
    body("isHidden")
      .isBoolean()
      .withMessage("isHidden must be a boolean"),
    body("hiddenReason")
      .optional({ nullable: true })
      .isString()
      .isLength({ max: 200 })
      .withMessage("hiddenReason must be at most 200 characters"),
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

      const result = await moderateItemReview({
        reviewId: req.params.reviewId,
        isHidden: req.body.isHidden,
        hiddenReason: req.body.hiddenReason,
      });
      metrics.recordReviewEvent({ reviewType: "item", action: "moderate", result: "success" });

      return res.json({
        success: true,
        message: req.body.isHidden
          ? "Item review hidden successfully"
          : "Item review restored successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof ItemReviewError) {
        metrics.recordReviewEvent({
          reviewType: "item",
          action: "moderate",
          result: error.code || "business_error",
        });
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      logger.error("item_review_moderation_failed", { error });
      metrics.recordReviewEvent({ reviewType: "item", action: "moderate", result: "failure" });
      return res.status(500).json({
        success: false,
        message: "Server error",
      });
    }
  }
);

module.exports = router;
