const cloudinary = require('cloudinary').v2;
require('dotenv').config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

const uploadToCloudinary = async (file, options = {}) => {
  try {
    const {
      folder = 'grabgo',
      public_id = null,
      transformation = [],
      resource_type = 'image',
    } = options;

    const uploadOptions = {
      folder,
      resource_type,
      ...(public_id && { public_id }),
      ...(transformation.length > 0 && { transformation }),
    };

    let uploadResult;
    if (Buffer.isBuffer(file)) {
      uploadResult = await cloudinary.uploader.upload(
        `data:image/jpeg;base64,${file.toString('base64')}`,
        uploadOptions
      );
    } else if (typeof file === 'string') {
      uploadResult = await cloudinary.uploader.upload(file, uploadOptions);
    } else {
      throw new Error('Invalid file type. Expected Buffer or String.');
    }

    return {
      url: uploadResult.secure_url,
      public_id: uploadResult.public_id,
      width: uploadResult.width,
      height: uploadResult.height,
      format: uploadResult.format,
      bytes: uploadResult.bytes,
    };
  } catch (error) {
    console.error('Cloudinary upload error:', error);
    throw new Error(`Failed to upload to Cloudinary: ${error.message}`);
  }
};

const deleteFromCloudinary = async (publicId) => {
  try {
    if (!publicId) return null;

    const id = publicId.includes('/')
      ? publicId.split('/').pop().split('.')[0]
      : publicId;

    const result = await cloudinary.uploader.destroy(id);
    return result;
  } catch (error) {
    console.error('Cloudinary delete error:', error);
    throw new Error(`Failed to delete from Cloudinary: ${error.message}`);
  }
};

const uploadMulterFile = async (file, options = {}) => {
  if (!file) {
    throw new Error('No file provided');
  }

  const {
    folder = 'grabgo',
    subfolder = null,
    transformation = [],
  } = options;

  const uploadFolder = subfolder ? `${folder}/${subfolder}` : folder;

  const base64Data = file.buffer.toString('base64');
  const dataUri = `data:${file.mimetype};base64,${base64Data}`;

  try {
    const result = await cloudinary.uploader.upload(dataUri, {
      folder: uploadFolder,
      transformation: [
        { width: 800, height: 800, crop: 'limit', quality: 'auto' },
        ...transformation,
      ],
    });

    return {
      url: result.secure_url,
      public_id: result.public_id,
      width: result.width,
      height: result.height,
      format: result.format,
      bytes: result.bytes,
    };
  } catch (error) {
    console.error('Cloudinary uploadMulterFile error:', error);
    throw new Error(`Failed to upload file to Cloudinary: ${error.message}`);
  }
};

const uploadAudioFile = async (file, options = {}) => {
  if (!file) {
    throw new Error('No file provided');
  }

  const {
    folder = 'grabgo',
    subfolder = 'voice_messages',
  } = options;

  const uploadFolder = subfolder ? `${folder}/${subfolder}` : folder;

  const base64Data = file.buffer.toString('base64');
  const dataUri = `data:${file.mimetype};base64,${base64Data}`;

  try {
    const result = await cloudinary.uploader.upload(dataUri, {
      folder: uploadFolder,
      resource_type: 'video',
      format: 'ogg',
    });

    return {
      url: result.secure_url,
      public_id: result.public_id,
      format: result.format,
      bytes: result.bytes,
      duration: result.duration || 0,
    };
  } catch (error) {
    console.error('Cloudinary uploadAudioFile error:', error);
    throw new Error(`Failed to upload audio file to Cloudinary: ${error.message}`);
  }
};

module.exports = {
  cloudinary,
  uploadToCloudinary,
  deleteFromCloudinary,
  uploadMulterFile,
  uploadAudioFile,
};

