const express = require('express');
const { searchCatalog } = require('../services/catalog_search_service');

const router = express.Router();
const SUPPORTED_SERVICE_TYPES = new Set([
  'food',
  'groceries',
  'pharmacy',
  'convenience',
]);

router.get('/catalog', async (req, res) => {
  try {
    const serviceType = String(req.query.serviceType ?? '').trim();
    if (!serviceType) {
      return res.status(400).json({
        success: false,
        message: 'serviceType is required',
      });
    }
    if (!SUPPORTED_SERVICE_TYPES.has(serviceType)) {
      return res.status(400).json({
        success: false,
        message: 'Unsupported serviceType',
      });
    }

    const data = await searchCatalog(req.query);
    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('Catalog search error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to search catalog',
    });
  }
});

module.exports = router;
