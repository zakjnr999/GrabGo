const mongoose = require('mongoose');

const dayScheduleSchema = new mongoose.Schema({
    open: { type: String, default: '09:00' },
    close: { type: String, default: '21:00' },
    isClosed: { type: Boolean, default: false }
}, { _id: false });

const openingHoursSchema = new mongoose.Schema({
    monday: { type: dayScheduleSchema, default: () => ({}) },
    tuesday: { type: dayScheduleSchema, default: () => ({}) },
    wednesday: { type: dayScheduleSchema, default: () => ({}) },
    thursday: { type: dayScheduleSchema, default: () => ({}) },
    friday: { type: dayScheduleSchema, default: () => ({}) },
    saturday: { type: dayScheduleSchema, default: () => ({}) },
    sunday: { type: dayScheduleSchema, default: () => ({}) }
}, { _id: false });

const socialsSchema = new mongoose.Schema({
    facebook: { type: String, default: null },
    instagram: { type: String, default: null },
    twitter: { type: String, default: null },
    website: { type: String, default: null }
}, { _id: false });

const pharmacyStoreSchema = new mongoose.Schema(
    {
        storeName: {
            type: String,
            required: [true, 'Pharmacy name is required'],
            trim: true,
        },
        logo: {
            type: String,
            required: [true, 'Pharmacy logo is required'],
        },
        description: {
            type: String,
            default: '',
        },
        phone: {
            type: String,
            required: [true, 'Phone number is required'],
        },
        email: {
            type: String,
            required: [true, 'Email is required'],
            lowercase: true,
            unique: true
        },
        location: {
            type: {
                type: String,
                enum: ['Point'],
                default: 'Point'
            },
            coordinates: {
                type: [Number], // [longitude, latitude]
                required: [true, 'Coordinates are required'],
                validate: {
                    validator: function (coords) {
                        return coords.length === 2 &&
                            coords[0] >= -180 && coords[0] <= 180 && // Longitude
                            coords[1] >= -90 && coords[1] <= 90;    // Latitude
                    },
                    message: 'Invalid coordinates. Longitude must be between -180 and 180, and Latitude between -90 and 90.'
                }
            },
            address: {
                type: String,
                required: [true, 'Address is required'],
            },
            city: {
                type: String,
                required: [true, 'City is required'],
            },
            area: {
                type: String,
                required: [true, 'Area/neighborhood is required'],
            }
        },
        ownerFullName: {
            type: String,
            default: null,
        },
        ownerContactNumber: {
            type: String,
            default: null,
        },
        businessIdNumber: {
            type: String,
            default: null,
            unique: true,
            sparse: true
        },
        password: {
            type: String,
            minlength: 6,
            select: false,
        },
        businessIdPhoto: {
            type: String,
            default: null,
        },
        ownerPhoto: {
            type: String,
            default: null,
        },
        isOpen: {
            type: Boolean,
            default: true,
        },
        isAcceptingOrders: {
            type: Boolean,
            default: true,
        },
        deliveryFee: {
            type: Number,
            required: [true, 'Delivery fee is required'],
            min: [0, 'Delivery fee cannot be negative'],
        },
        minOrder: {
            type: Number,
            required: [true, 'Minimum order is required'],
            min: [0, 'Minimum order cannot be negative'],
        },
        rating: {
            type: Number,
            default: 0,
            min: [0, 'Rating cannot be negative'],
            max: [5, 'Rating cannot exceed 5'],
            set: v => Math.round(v * 10) / 10
        },
        ratingSum: {
            type: Number,
            default: 0
        },
        totalReviews: {
            type: Number,
            default: 0,
        },
        priorityScore: {
            type: Number,
            default: 0,
            index: true
        },
        orderAcceptanceRate: {
            type: Number,
            default: 100,
            min: 0,
            max: 100
        },
        orderCancellationRate: {
            type: Number,
            default: 0,
            min: 0,
            max: 100
        },
        categories: [{
            type: String,
        }],
        licenseNumber: {
            type: String,
            required: [true, 'Pharmacy license number is required'],
            unique: true,
        },
        pharmacistName: {
            type: String,
            required: [true, 'Pharmacist name is required'],
        },
        pharmacistLicense: {
            type: String,
            required: [true, 'Pharmacist license is required'],
        },
        prescriptionRequired: {
            type: Boolean,
            default: false,
        },
        emergencyService: {
            type: Boolean,
            default: false,
        },
        insuranceAccepted: [{
            type: String,
        }],
        averagePreparationTime: {
            type: Number, // In minutes
            default: 15,
            min: [0, 'Preparation time cannot be negative'],
        },
        averageDeliveryTime: {
            type: Number, // In minutes
            default: 30,
        },
        deliveryRadius: {
            type: Number, // In km
            default: 5,
            min: [0, 'Delivery radius cannot be negative'],
        },
        features: [{
            type: String,
            enum: ['wifi', 'parking', 'wheelchair_accessible', 'outdoor_seating',
                'takeaway', 'dine_in', 'halal', 'vegan_options', 'alcohol_served',
                'live_music', 'air_conditioned', 'pet_friendly'],
        }],
        tags: [{
            type: String,
        }],
        featured: {
            type: Boolean,
            default: false,
        },
        featuredUntil: {
            type: Date,
            default: null,
        },
        isVerified: {
            type: Boolean,
            default: false,
        },
        verifiedAt: {
            type: Date,
            default: null,
        },
        whatsappNumber: {
            type: String,
            default: null,
        },
        timezone: {
            type: String,
            default: 'Africa/Accra'
        },
        utcOffset: {
            type: Number,
            default: 0
        },
        totalOrders: {
            type: Number,
            default: 0
        },
        totalCancelledOrders: {
            type: Number,
            default: 0
        },
        totalRevenue: {
            type: Number,
            default: 0
        },
        monthlyRevenue: {
            type: Number,
            default: 0
        },
        last30DaysRevenue: {
            type: Number,
            default: 0
        },
        averageOrderValue: {
            type: Number,
            default: 0
        },
        monthlyOrders: {
            type: Number,
            default: 0
        },
        parentVendorId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'PharmacyStore',
            default: null
        },
        paymentMethods: [{
            type: String,
            enum: ['cash', 'card', 'mobile_money']
        }],
        bannerImages: [{
            type: String,
        }],
        status: {
            type: String,
            enum: ['pending', 'approved', 'rejected', 'suspended'],
            default: 'approved',
        },
        openingHours: {
            type: openingHoursSchema,
            default: () => ({})
        },
        isGrabGoExclusive: {
            type: Boolean,
            default: false,
        },
        isGrabGoExclusiveUntil: {
            type: Date,
            default: null,
        },
        socials: {
            type: socialsSchema,
            default: () => ({})
        },
        vendorType: {
            type: String,
            enum: ['restaurant', 'grocery', 'pharmacy', 'grabmart'],
            default: 'pharmacy'
        },
        isDeleted: {
            type: Boolean,
            default: false
        },
        lastOnlineAt: {
            type: Date,
            default: Date.now
        },
    },
    {
        timestamps: true,
        toJSON: { virtuals: true },
        toObject: { virtuals: true },
    }
);

// Soft-deletion middleware
pharmacyStoreSchema.pre(/^find/, function (next) {
    this.find({ isDeleted: { $ne: true } });
    next();
});

pharmacyStoreSchema.pre('aggregate', function (next) {
    const pipeline = this.pipeline();
    const firstStage = pipeline[0];

    if (firstStage && firstStage.$geoNear) {
        firstStage.$geoNear.query = { ...firstStage.$geoNear.query, isDeleted: { $ne: true } };
    } else {
        pipeline.unshift({ $match: { isDeleted: { $ne: true } } });
    }
    next();
});
// Production Indexes
pharmacyStoreSchema.index({ "location.coordinates": "2dsphere" });
pharmacyStoreSchema.index({ status: 1, isOpen: 1, isDeleted: 1, rating: -1 });
pharmacyStoreSchema.index({ vendorType: 1, status: 1, isDeleted: 1 });
pharmacyStoreSchema.index({ storeName: 1 });
pharmacyStoreSchema.index({ email: 1 });
pharmacyStoreSchema.index({ licenseNumber: 1 });

// Virtuals for legacy support (snake_case and top-level location)
pharmacyStoreSchema.virtual('store_name').get(function () { return this.storeName; });
pharmacyStoreSchema.virtual('is_open').get(function () { return this.isOpen; });
pharmacyStoreSchema.virtual('total_reviews').get(function () { return this.totalReviews; });
pharmacyStoreSchema.virtual('delivery_fee').get(function () { return this.deliveryFee; });
pharmacyStoreSchema.virtual('min_order').get(function () { return this.minOrder; });
pharmacyStoreSchema.virtual('latitude').get(function () { return this.location?.coordinates?.[1]; });
pharmacyStoreSchema.virtual('longitude').get(function () { return this.location?.coordinates?.[0]; });
pharmacyStoreSchema.virtual('address').get(function () { return this.location?.address; });
pharmacyStoreSchema.virtual('city').get(function () { return this.location?.city; });

pharmacyStoreSchema.virtual('isActive').get(function () {
    return !this.isDeleted && this.status === 'approved' && this.isAcceptingOrders;
});

// Automatic isOpen logic based on schedule
pharmacyStoreSchema.virtual('isScheduledOpen').get(function () {
    if (!this.openingHours) return false;

    const now = new Date();
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    const today = days[now.getDay()];
    const schedule = this.openingHours[today];

    if (!schedule || schedule.isClosed) return false;

    const [openHours, openMinutes] = schedule.open.split(':').map(Number);
    const [closeHours, closeMinutes] = schedule.close.split(':').map(Number);

    const openTime = openHours * 60 + openMinutes;
    let closeTime = closeHours * 60 + closeMinutes;

    if (closeTime < openTime) {
        closeTime += 24 * 60;
    }

    // Get current time in vendor's timezone
    // Priority: 1. utcOffset (Fastest) 2. Intl API (Accurate Fallback)
    let localNow;
    if (typeof this.utcOffset === 'number') {
        localNow = new Date(now.getTime() + this.utcOffset * 60000);
    } else {
        try {
            const formatter = new Intl.DateTimeFormat('en-US', {
                timeZone: this.timezone || 'Africa/Accra',
                hour: 'numeric',
                minute: 'numeric',
                hour12: false
            });
            const parts = formatter.formatToParts(now);
            const hour = parseInt(parts.find(p => p.type === 'hour').value);
            const minute = parseInt(parts.find(p => p.type === 'minute').value);
            localNow = new Date();
            localNow.setHours(hour, minute, 0, 0);
        } catch (err) {
            localNow = now;
        }
    }

    const currentTimeInTZ = localNow.getHours() * 60 + localNow.getMinutes();
    return currentTimeInTZ >= openTime && currentTimeInTZ <= closeTime;
});

pharmacyStoreSchema.methods.updateRating = async function (newScore) {
    this.ratingSum += newScore;
    this.totalReviews += 1;
    this.rating = Math.round((this.ratingSum / this.totalReviews) * 10) / 10;
    return this.save();
};

const PharmacyStore = mongoose.model('PharmacyStore', pharmacyStoreSchema);

module.exports = PharmacyStore;
