const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { uploadMulterFile } = require('../config/cloudinary');

// Use memory storage for Cloudinary uploads (files are stored in memory temporarily)
const storage = multer.memoryStorage();

// File filter
const fileFilter = (req, file, cb) => {
  console.log('🔍 File filter check:', {
    originalname: file.originalname,
    mimetype: file.mimetype,
    fieldname: file.fieldname
  });

  const allowedTypes = /jpeg|jpg|png|gif|webp/;
  const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
  
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  const mimetype = allowedMimeTypes.test(file.mimetype) || allowedTypes.test(file.mimetype);

  if (mimetype && extname) {
    console.log('✅ File accepted:', file.originalname);
    return cb(null, true);
  } else {
    console.error('❌ File rejected:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      extname: path.extname(file.originalname),
      reason: !mimetype ? 'Invalid MIME type' : 'Invalid file extension'
    });
    cb(new Error('Only image files are allowed!'));
  }
};

// Configure multer
const upload = multer({
  storage: storage,
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5242880 // 5MB default
  },
  fileFilter: fileFilter,
  // Accept common image MIME types
  preservePath: false
});

// Helper function to handle single file upload
exports.uploadSingle = (fieldName) => {
  return upload.single(fieldName);
};

// Helper function to handle multiple file uploads
exports.uploadMultiple = (fieldName, maxCount = 10) => {
  return upload.array(fieldName, maxCount);
};

// Helper function to handle multiple fields
exports.uploadFields = (fields) => {
  return upload.fields(fields);
};

// Helper to get file URL (for backward compatibility)
exports.getFileUrl = (filename) => {
  if (!filename) return null;
  if (filename.startsWith('http')) return filename;
  // If it's already a Cloudinary URL, return as is
  if (filename.includes('cloudinary.com')) return filename;
  // Fallback to local uploads (for backward compatibility)
  return `/uploads/${filename}`;
};

// Middleware to upload file to Cloudinary after multer processes it
exports.uploadToCloudinary = async (req, res, next) => {
  try {
    if (!req.file) {
      return next();
    }

    // Determine folder based on route or field name
    let folder = 'grabgo';
    let subfolder = 'general';

    // Determine subfolder based on field name or route
    if (req.file.fieldname === 'profilePicture') {
      subfolder = 'profiles';
    } else if (req.file.fieldname === 'logo') {
      subfolder = 'restaurants';
    } else if (req.file.fieldname === 'image' || req.file.fieldname === 'foodImage') {
      subfolder = 'foods';
    } else if (req.file.fieldname === 'business_id_photo' || req.file.fieldname === 'owner_photo') {
      subfolder = 'documents';
    }

    // Upload to Cloudinary
    const cloudinaryResult = await uploadMulterFile(req.file, {
      folder,
      subfolder,
    });

    // Attach Cloudinary URL to req.file for use in routes
    req.file.cloudinaryUrl = cloudinaryResult.url;
    req.file.cloudinaryPublicId = cloudinaryResult.public_id;

    next();
  } catch (error) {
    console.error('❌ Cloudinary upload middleware error:', error);
    console.error('   File details:', {
      fieldname: req.file?.fieldname,
      originalname: req.file?.originalname,
      mimetype: req.file?.mimetype,
      size: req.file?.size
    });
    return res.status(500).json({
      success: false,
      message: 'Failed to upload image to Cloudinary',
      error: error.message,
      details: 'Check server logs for more information. Verify Cloudinary credentials are set correctly.'
    });
  }
};

// Middleware to upload multiple files to Cloudinary
exports.uploadMultipleToCloudinary = async (req, res, next) => {
  try {
    if (!req.files || Object.keys(req.files).length === 0) {
      return next();
    }

    // Process each file field
    for (const fieldName in req.files) {
      const files = Array.isArray(req.files[fieldName]) ? req.files[fieldName] : [req.files[fieldName]];
      
      for (const file of files) {
        // Determine subfolder based on field name
        let folder = 'grabgo';
        let subfolder = 'general';

        if (fieldName === 'profilePicture') {
          subfolder = 'profiles';
        } else if (fieldName === 'logo') {
          subfolder = 'restaurants';
        } else if (fieldName === 'image' || fieldName === 'foodImage') {
          subfolder = 'foods';
        } else if (fieldName === 'business_id_photo' || fieldName === 'owner_photo') {
          subfolder = 'documents';
        }

        // Upload to Cloudinary
        const cloudinaryResult = await uploadMulterFile(file, {
          folder,
          subfolder,
        });

        // Attach Cloudinary URL to file object
        file.cloudinaryUrl = cloudinaryResult.url;
        file.cloudinaryPublicId = cloudinaryResult.public_id;
      }
    }

    next();
  } catch (error) {
    console.error('Cloudinary multiple upload middleware error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to upload images to Cloudinary',
      error: error.message,
    });
  }
};

