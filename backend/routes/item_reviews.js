const express = require("express");
const { query, param, validationResult } = require("express-validator");
const {
  ItemReviewError,
  getItemReviews,
} = require("../services/item_review_service");

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

      return res.json({
        success: true,
        message: "Item reviews retrieved successfully",
        data: result,
      });
    } catch (error) {
      if (error instanceof ItemReviewError) {
        return res.status(error.statusCode || 400).json({
          success: false,
          message: error.message,
          code: error.code,
        });
      }

      console.error("Get item reviews error:", error);
      return res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

module.exports = router;
