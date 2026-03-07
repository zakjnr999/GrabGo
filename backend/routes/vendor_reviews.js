const express = require("express");
const { body, param, query, validationResult } = require("express-validator");
const { protect, admin } = require("../middleware/auth");
const {
  VendorRatingError,
  getVendorReviews,
  moderateVendorReview,
  reportVendorReview,
} = require("../services/vendor_rating_service");

const router = express.Router();

router.get(
  "/:vendorType/:vendorId",
  [
    param("vendorType")
      .isString()
      .notEmpty()
      .withMessage("vendorType is required"),
    param("vendorId")
      .isString()
      .notEmpty()
      .withMessage("vendorId is required"),
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

      const result = await getVendorReviews({
        vendorType: req.params.vendorType,
        vendorId: req.params.vendorId,
        sort: req.query.sort,
        page: req.query.page,
        limit: req.query.limit,
      });

      return res.json({
        success: true,
        message: "Vendor reviews retrieved successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof VendorRatingError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Get vendor reviews error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
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

      const result = await reportVendorReview({
        reviewId: req.params.reviewId,
        reporterId: req.user.id,
        reason: req.body.reason,
        details: req.body.details,
      });

      return res.status(201).json({
        success: true,
        message: "Vendor review reported successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof VendorRatingError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Report vendor review error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
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

      const result = await moderateVendorReview({
        reviewId: req.params.reviewId,
        isHidden: req.body.isHidden,
        hiddenReason: req.body.hiddenReason,
      });

      return res.json({
        success: true,
        message: req.body.isHidden
          ? "Vendor review hidden successfully"
          : "Vendor review restored successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof VendorRatingError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Moderate vendor review error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

module.exports = router;
