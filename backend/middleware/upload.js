const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { uploadMulterFile } = require('../config/cloudinary');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|gif|webp/;
  const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
  
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  
  const isValidMimeType = allowedMimeTypes.test(file.mimetype) || 
                          allowedTypes.test(file.mimetype) ||
                          (file.mimetype === 'application/octet-stream' && extname);

  if (isValidMimeType && extname) {
    return cb(null, true);
  } else {
    cb(new Error('Only image files are allowed!'));
  }
};

const upload = multer({
  storage: storage,
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5242880 // 5MB default
  },
  fileFilter: fileFilter,
  preservePath: false
});

exports.uploadSingle = (fieldName) => {
  return upload.single(fieldName);
};

exports.uploadMultiple = (fieldName, maxCount = 10) => {
  return upload.array(fieldName, maxCount);
};

exports.uploadFields = (fields) => {
  return upload.fields(fields);
};

exports.getFileUrl = (filename) => {
  if (!filename) return null;
  if (filename.startsWith('http')) return filename;
  if (filename.includes('cloudinary.com')) return filename;
  return `/uploads/${filename}`;
};

exports.uploadToCloudinary = async (req, res, next) => {
  try {
    if (!req.file) {
      return next();
    }

    let folder = 'grabgo';
    let subfolder = 'general';

    if (req.file.fieldname === 'profilePicture') {
      subfolder = 'profiles';
    } else if (req.file.fieldname === 'logo') {
      subfolder = 'restaurants';
    } else if (req.file.fieldname === 'image' || req.file.fieldname === 'foodImage') {
      subfolder = 'foods';
    } else if (req.file.fieldname === 'business_id_photo' || req.file.fieldname === 'owner_photo') {
      subfolder = 'documents';
    }

    const cloudinaryResult = await uploadMulterFile(req.file, {
      folder,
      subfolder,
    });

    req.file.cloudinaryUrl = cloudinaryResult.url;
    req.file.cloudinaryPublicId = cloudinaryResult.public_id;

    next();
  } catch (error) {
    console.error('Cloudinary upload middleware error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to upload image to Cloudinary',
      error: error.message
    });
  }
};

exports.uploadMultipleToCloudinary = async (req, res, next) => {
  try {
    if (!req.files || Object.keys(req.files).length === 0) {
      return next();
    }

    for (const fieldName in req.files) {
      const files = Array.isArray(req.files[fieldName]) ? req.files[fieldName] : [req.files[fieldName]];
      
      for (const file of files) {
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

        const cloudinaryResult = await uploadMulterFile(file, {
          folder,
          subfolder,
        });

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

