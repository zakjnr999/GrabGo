const axios = require('axios');
const prisma = require('../config/prisma');
const creditService = require('./credit_service');
const subscriptionService = require('./subscription_service');
const { validatePromoCode } = require('./promo_service');
const { calculateDistance, estimateDeliveryTime } = require('../utils/distance');

const toNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const toBoolean = (value, fallback = false) => {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'number') return value !== 0;
    if (typeof value === 'string') {
        const normalized = value.trim().toLowerCase();
        if (['true', '1', 'yes', 'y', 'on'].includes(normalized)) return true;
        if (['false', '0', 'no', 'n', 'off'].includes(normalized)) return false;
    }
    return fallback;
};

const normalizeFulfillmentMode = (value) => {
    if (!value) return 'delivery';
    return String(value).toLowerCase() === 'pickup' ? 'pickup' : 'delivery';
};

const roundCurrency = (value) => {
    return Math.round((value + Number.EPSILON) * 100) / 100;
};

const TAX_RATE = toNumber(process.env.TAX_RATE, 0);
const SERVICE_FEE_RATE = toNumber(process.env.SERVICE_FEE_RATE, 0);
const SERVICE_FEE_MIN = toNumber(process.env.SERVICE_FEE_MIN, 0);
const SERVICE_FEE_MAX = toNumber(process.env.SERVICE_FEE_MAX, 0);
const DELIVERY_FEE_PER_KM = toNumber(process.env.DELIVERY_FEE_PER_KM, 0);
const DELIVERY_FEE_MIN = toNumber(process.env.DELIVERY_FEE_MIN, 0);
const DELIVERY_FEE_MAX = toNumber(process.env.DELIVERY_FEE_MAX, 0);
const DELIVERY_DISTANCE_MAX_KM = toNumber(process.env.DELIVERY_DISTANCE_MAX_KM, 50);
const TOMORROW_IO_API_KEY = process.env.TOMORROW_IO_API_KEY || process.env.TOMORROW_API_KEY;
const RAIN_SURGE_ENABLED = toBoolean(process.env.RAIN_SURGE_ENABLED, false);
const RAIN_SURGE_FEE = toNumber(process.env.RAIN_SURGE_FEE, 0);
const RAIN_SURGE_MIN_INTENSITY = toNumber(process.env.RAIN_SURGE_MIN_INTENSITY, 0);
const RAIN_SURGE_MIN_PROBABILITY = toNumber(process.env.RAIN_SURGE_MIN_PROBABILITY, 0);
const RAIN_SURGE_CACHE_TTL_MS = toNumber(process.env.RAIN_SURGE_CACHE_TTL_MS, 300000);
const RAIN_SURGE_REQUEST_TIMEOUT_MS = toNumber(process.env.RAIN_SURGE_REQUEST_TIMEOUT_MS, 3500);
const RAIN_SURGE_DEBUG = toBoolean(process.env.RAIN_SURGE_DEBUG, false);

const weatherCache = new Map();

const calculateSubtotal = (items = []) => {
    const subtotal = items.reduce((sum, item) => {
        const price = toNumber(item.price, 0);
        const quantity = toNumber(item.quantity, 0);
        return sum + price * quantity;
    }, 0);

    return roundCurrency(subtotal);
};

const calculateServiceFee = (subtotal) => {
    if (SERVICE_FEE_RATE <= 0) return 0;

    let fee = subtotal * SERVICE_FEE_RATE;

    if (SERVICE_FEE_MIN > 0) {
        fee = Math.max(fee, SERVICE_FEE_MIN);
    }
    if (SERVICE_FEE_MAX > 0) {
        fee = Math.min(fee, SERVICE_FEE_MAX);
    }

    return roundCurrency(fee);
};

const calculateTax = (subtotal) => {
    if (TAX_RATE <= 0) return 0;
    return roundCurrency(subtotal * TAX_RATE);
};

const calculateTotal = ({ subtotal, deliveryFee, serviceFee, tax, rainFee = 0 }) => {
    return roundCurrency(subtotal + deliveryFee + serviceFee + tax + rainFee);
};

const normalizeLocation = (location) => {
    if (!location) return null;
    const latitude = toNumber(location.latitude ?? location.lat, NaN);
    const longitude = toNumber(location.longitude ?? location.lng, NaN);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    if (Math.abs(latitude) < 0.0001 && Math.abs(longitude) < 0.0001) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
    return { latitude, longitude };
};

const calculateDistanceKm = (from, to) => {
    if (!from || !to) return null;
    const distance = roundCurrency(calculateDistance(from.latitude, from.longitude, to.latitude, to.longitude));
    if (!Number.isFinite(distance) || distance <= 0) return null;
    if (DELIVERY_DISTANCE_MAX_KM > 0 && distance > DELIVERY_DISTANCE_MAX_KM) return null;
    return distance;
};

const calculateDeliveryFee = ({ baseFee, distanceKm }) => {
    let fee = toNumber(baseFee, 0);

    if (Number.isFinite(distanceKm) && distanceKm > 0 && DELIVERY_FEE_PER_KM > 0) {
        fee += distanceKm * DELIVERY_FEE_PER_KM;
    }

    if (DELIVERY_FEE_MIN > 0) {
        fee = Math.max(fee, DELIVERY_FEE_MIN);
    }
    if (DELIVERY_FEE_MAX > 0) {
        fee = Math.min(fee, DELIVERY_FEE_MAX);
    }

    return roundCurrency(fee);
};

const normalizeProbability = (value) => {
    const normalized = toNumber(value, 0);
    if (normalized > 1) return normalized / 100;
    return normalized;
};

const shouldApplyRainFee = (rainIntensity, precipitationProbability) => {
    const intensityThreshold = Math.max(0, RAIN_SURGE_MIN_INTENSITY);
    const probabilityThreshold = Math.max(0, normalizeProbability(RAIN_SURGE_MIN_PROBABILITY));

    const intensityHit = intensityThreshold > 0 ? rainIntensity >= intensityThreshold : rainIntensity > 0;
    const probabilityHit = probabilityThreshold > 0 ? precipitationProbability >= probabilityThreshold : false;

    return intensityHit || probabilityHit;
};

const getRainFee = async ({ deliveryLocation, vendorLocation }) => {
    if (!RAIN_SURGE_ENABLED || !TOMORROW_IO_API_KEY || RAIN_SURGE_FEE <= 0) {
        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Skipped (disabled or missing config)', {
                enabled: RAIN_SURGE_ENABLED,
                hasKey: Boolean(TOMORROW_IO_API_KEY),
                fee: RAIN_SURGE_FEE
            });
        }
        return 0;
    }

    const resolvedLocation = normalizeLocation(deliveryLocation) || normalizeLocation(vendorLocation);
    if (!resolvedLocation) {
        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Skipped (no valid location)');
        }
        return 0;
    }

    const cacheKey = `${resolvedLocation.latitude.toFixed(3)},${resolvedLocation.longitude.toFixed(3)}`;
    const cached = weatherCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Cache hit', { cacheKey, value: cached.value });
        }
        return cached.value;
    }

    try {
        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Fetching Tomorrow.io', {
                location: cacheKey,
                intensityThreshold: RAIN_SURGE_MIN_INTENSITY,
                probabilityThreshold: RAIN_SURGE_MIN_PROBABILITY
            });
        }
        const response = await axios.get('https://api.tomorrow.io/v4/weather/realtime', {
            params: {
                location: `${resolvedLocation.latitude},${resolvedLocation.longitude}`,
                apikey: TOMORROW_IO_API_KEY,
                units: 'metric'
            },
            timeout: RAIN_SURGE_REQUEST_TIMEOUT_MS
        });

        const values = response?.data?.data?.values || {};
        const rainIntensity = toNumber(values.rainIntensity ?? values.precipitationIntensity, 0);
        const precipitationProbability = normalizeProbability(values.precipitationProbability);
        const shouldCharge = shouldApplyRainFee(rainIntensity, precipitationProbability);
        const rainFee = shouldCharge ? roundCurrency(RAIN_SURGE_FEE) : 0;

        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Result', {
                rainIntensity,
                precipitationProbability,
                shouldCharge,
                rainFee
            });
        }

        weatherCache.set(cacheKey, {
            value: rainFee,
            expiresAt: Date.now() + RAIN_SURGE_CACHE_TTL_MS
        });

        return rainFee;
    } catch (error) {
        if (RAIN_SURGE_DEBUG) {
            console.log('☔ [RAIN_FEE] Error', { message: error?.message });
        }
        return 0;
    }
};

const resolveVendorId = (cart) => {
    if (!cart) return null;

    if (cart.cartType === 'food') {
        return cart.restaurantId || cart.items?.find(item => item.food?.restaurantId)?.food?.restaurantId || null;
    }
    if (cart.cartType === 'grocery') {
        return cart.groceryStoreId || cart.items?.find(item => item.groceryItem?.storeId)?.groceryItem?.storeId || null;
    }
    if (cart.cartType === 'pharmacy') {
        return cart.pharmacyStoreId || cart.items?.find(item => item.pharmacyItem?.storeId)?.pharmacyItem?.storeId || null;
    }
    if (cart.cartType === 'grabmart') {
        return cart.grabMartStoreId || cart.items?.find(item => item.grabMartItem?.storeId)?.grabMartItem?.storeId || null;
    }

    return null;
};

const getUserDeliveryLocation = async (userId) => {
    if (!userId) return null;

    const defaultAddress = await prisma.userAddress.findFirst({
        where: { userId, isDefault: true },
        orderBy: { createdAt: 'desc' },
        select: { latitude: true, longitude: true }
    });

    if (Number.isFinite(defaultAddress?.latitude) && Number.isFinite(defaultAddress?.longitude)) {
        return normalizeLocation(defaultAddress);
    }

    const latestAddress = await prisma.userAddress.findFirst({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        select: { latitude: true, longitude: true }
    });

    return normalizeLocation(latestAddress);
};

const getVendorDeliveryContext = async (cart) => {
    if (!cart || !cart.items || cart.items.length === 0) {
        return { baseFee: 0, vendorLocation: null, vendorPrepTime: null, vendorDeliveryTime: null };
    }

    const vendorId = resolveVendorId(cart);
    if (!vendorId) return { baseFee: 0, vendorLocation: null, vendorPrepTime: null, vendorDeliveryTime: null };

    if (cart.cartType === 'food') {
        const restaurant = await prisma.restaurant.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true, averagePreparationTime: true, averageDeliveryTime: true }
        });
        return {
            baseFee: roundCurrency(toNumber(restaurant?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(restaurant),
            vendorPrepTime: toNumber(restaurant?.averagePreparationTime, 15),
            vendorDeliveryTime: toNumber(restaurant?.averageDeliveryTime, 30)
        };
    }

    if (cart.cartType === 'grocery') {
        const store = await prisma.groceryStore.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true, averagePreparationTime: true, averageDeliveryTime: true }
        });
        return {
            baseFee: roundCurrency(toNumber(store?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(store),
            vendorPrepTime: toNumber(store?.averagePreparationTime, 15),
            vendorDeliveryTime: toNumber(store?.averageDeliveryTime, 30)
        };
    }

    if (cart.cartType === 'pharmacy') {
        const store = await prisma.pharmacyStore.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true, averagePreparationTime: true, averageDeliveryTime: true }
        });
        return {
            baseFee: roundCurrency(toNumber(store?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(store),
            vendorPrepTime: toNumber(store?.averagePreparationTime, 15),
            vendorDeliveryTime: toNumber(store?.averageDeliveryTime, 30)
        };
    }

    if (cart.cartType === 'grabmart') {
        const store = await prisma.grabMartStore.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true }
        });
        return {
            baseFee: roundCurrency(toNumber(store?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(store),
            vendorPrepTime: 15,
            vendorDeliveryTime: 30
        };
    }

    return { baseFee: 0, vendorLocation: null, vendorPrepTime: null, vendorDeliveryTime: null };
};

const calculateEstimatedDeliveryWindow = ({ distanceKm, vendorPrepTime, vendorDeliveryTime }) => {
    const prepMinutes = toNumber(vendorPrepTime, 15);

    if (Number.isFinite(distanceKm) && distanceKm > 0) {
        const travelMinutes = estimateDeliveryTime(distanceKm);
        if (!Number.isFinite(travelMinutes) || travelMinutes <= 0) {
            return { minMinutes: null, maxMinutes: null };
        }
        const minMinutes = Math.max(5, Math.ceil(prepMinutes + travelMinutes));
        const maxMinutes = minMinutes + 10;
        return { minMinutes, maxMinutes };
    }

    // vendorDeliveryTime represents full ETA (order placed → delivered)
    if (Number.isFinite(vendorDeliveryTime) && vendorDeliveryTime > 0) {
        const minMinutes = Math.max(5, Math.ceil(vendorDeliveryTime));
        const maxMinutes = minMinutes + 10;
        return { minMinutes, maxMinutes };
    }

    return { minMinutes: null, maxMinutes: null };
};

const getMaxItemPrepMinutes = (items = []) => {
    if (!Array.isArray(items) || items.length === 0) return null;

    const prepTimes = items
        .map(item => {
            if (item?.itemType === 'Food') return toNumber(item?.food?.prepTimeMinutes, 0);
            if (item?.itemType === 'GroceryItem') return toNumber(item?.groceryItem?.prepTimeMinutes, 0);
            if (item?.itemType === 'PharmacyItem') return toNumber(item?.pharmacyItem?.prepTimeMinutes, 0);
            if (item?.itemType === 'GrabMartItem') return toNumber(item?.grabMartItem?.prepTimeMinutes, 0);
            return 0;
        })
        .filter(minutes => Number.isFinite(minutes) && minutes > 0);

    if (prepTimes.length === 0) return null;
    return Math.max(...prepTimes);
};

const normalizePromoCode = (value) => {
    if (!value) return null;
    const normalized = String(value).trim().toUpperCase();
    return normalized.length > 0 ? normalized : null;
};

const mapCartTypeToPromoOrderType = (cartType) => {
    const normalized = String(cartType || '').trim().toLowerCase();
    if (normalized === 'food') return 'food';
    if (normalized === 'grocery') return 'grocery';
    return null;
};

const isPromoSupportedOrderType = (orderType) => {
    return orderType === 'food' || orderType === 'grocery';
};

const resolvePromoDiscountForPricing = ({
    promoValidation,
    effectiveDeliveryFee,
    subtotal,
}) => {
    if (!promoValidation?.valid) {
        return {
            promoCode: null,
            promoType: null,
            promoDiscount: 0,
            promoValidationMessage: promoValidation?.error || null,
        };
    }

    const promoType = promoValidation.type || null;
    let promoDiscount = Number(promoValidation.discount || 0);

    if (promoType === 'free_delivery') {
        promoDiscount = Number(effectiveDeliveryFee || 0);
    }

    promoDiscount = roundCurrency(Math.max(0, promoDiscount));
    if (promoDiscount > subtotal && promoType !== 'free_delivery') {
        promoDiscount = roundCurrency(Math.max(0, subtotal));
    }

    return {
        promoCode: promoValidation.code || null,
        promoType,
        promoDiscount,
        promoValidationMessage: null,
    };
};

const calculateCartPricing = async (cart, options = {}) => {
    if (!cart || !cart.items || cart.items.length === 0) {
        return {
            subtotal: 0,
            deliveryFee: 0,
            serviceFee: 0,
            tax: 0,
            rainFee: 0,
            total: 0,
            totalBeforePromo: 0,
            totalBeforeCredits: 0,
            itemCount: 0,
            deliveryDistanceKm: 0,
            estimatedDeliveryMin: null,
            estimatedDeliveryMax: null,
            promoCode: null,
            promoType: null,
            promoDiscount: 0,
            promoValidationMessage: null,
            creditsApplied: 0,
            totalAfterCredits: 0
        };
    }

    const { userId, deliveryLocation, useCredits, fulfillmentMode, promoCode } = options;
    const normalizedPromoCode = normalizePromoCode(promoCode);
    const resolvedFulfillmentMode = normalizeFulfillmentMode(fulfillmentMode || cart?.fulfillmentMode);
    const subtotal = calculateSubtotal(cart.items);
    const promoOrderType = mapCartTypeToPromoOrderType(cart?.cartType);
    const { baseFee, vendorLocation, vendorPrepTime, vendorDeliveryTime } = await getVendorDeliveryContext(cart);
    const maxItemPrepMinutes = getMaxItemPrepMinutes(cart.items);
    const effectivePrepMinutes = maxItemPrepMinutes ?? vendorPrepTime;
    const resolvedDeliveryLocation = normalizeLocation(deliveryLocation) || await getUserDeliveryLocation(userId);
    const distanceKm = resolvedFulfillmentMode === 'pickup'
        ? null
        : calculateDistanceKm(vendorLocation, resolvedDeliveryLocation);
    const deliveryFee = resolvedFulfillmentMode === 'pickup'
        ? 0
        : calculateDeliveryFee({ baseFee, distanceKm });
    const serviceFee = calculateServiceFee(subtotal);
    const tax = calculateTax(subtotal);
    const rainFee = resolvedFulfillmentMode === 'pickup'
        ? 0
        : await getRainFee({ deliveryLocation: resolvedDeliveryLocation, vendorLocation });

    // ── GrabGo Pro Subscription Benefits ──
    let subscriptionDeliveryDiscount = 0;
    let subscriptionServiceFeeDiscount = 0;
    let subscriptionTier = null;
    let subscriptionId = null;

    if (userId) {
        const subBenefits = await subscriptionService.calculateSubscriptionBenefits(userId, {
            subtotal,
            deliveryFee,
            serviceFee,
        });
        if (subBenefits) {
            subscriptionDeliveryDiscount = subBenefits.deliveryDiscount;
            subscriptionServiceFeeDiscount = subBenefits.serviceFeeDiscount;
            subscriptionTier = subBenefits.tier;
            subscriptionId = subBenefits.subscriptionId;
        }
    }

    const effectiveDeliveryFee = roundCurrency(Math.max(0, deliveryFee - subscriptionDeliveryDiscount));
    const effectiveServiceFee = roundCurrency(Math.max(0, serviceFee - subscriptionServiceFeeDiscount));

    let promoCodeApplied = null;
    let promoType = null;
    let promoDiscount = 0;
    let promoValidationMessage = null;

    if (normalizedPromoCode) {
        if (!userId) {
            promoValidationMessage = 'Please sign in to use promo codes.';
        } else if (!isPromoSupportedOrderType(promoOrderType)) {
            promoValidationMessage = 'Promo codes are currently available for food and grocery orders only.';
        } else {
            const promoValidation = await validatePromoCode(
                normalizedPromoCode,
                userId,
                subtotal,
                promoOrderType
            );
            const promoResolution = resolvePromoDiscountForPricing({
                promoValidation,
                effectiveDeliveryFee,
                subtotal,
            });
            promoCodeApplied = promoResolution.promoCode;
            promoType = promoResolution.promoType;
            promoDiscount = promoResolution.promoDiscount;
            promoValidationMessage = promoResolution.promoValidationMessage;
        }
    }

    const totalBeforePromo = calculateTotal({
        subtotal,
        deliveryFee: effectiveDeliveryFee,
        serviceFee: effectiveServiceFee,
        tax,
        rainFee,
    });
    const totalBeforeCredits = roundCurrency(Math.max(0, totalBeforePromo - promoDiscount));
    const itemCount = cart.items.reduce((sum, item) => sum + toNumber(item.quantity, 0), 0);
    const estimatedDelivery = calculateEstimatedDeliveryWindow({
        distanceKm,
        vendorPrepTime: effectivePrepMinutes,
        vendorDeliveryTime: resolvedFulfillmentMode === 'pickup' ? null : vendorDeliveryTime
    });
    let creditsApplied = 0;
    let totalAfterCredits = totalBeforeCredits;
    let creditBalance = 0;
    let availableBalance = 0;
    const shouldUseCredits = useCredits !== false;

    if (userId) {
        const creditResult = await creditService.calculateCreditApplication(userId, totalBeforeCredits, shouldUseCredits);
        creditsApplied = toNumber(creditResult?.creditsApplied, 0);
        totalAfterCredits = toNumber(creditResult?.remainingPayment, totalBeforeCredits);
        creditBalance = toNumber(creditResult?.creditBalance, 0);
        availableBalance = toNumber(
            creditResult?.availableBalance,
            Number.isFinite(creditBalance) ? creditBalance : 0
        );
    }

    return {
        subtotal,
        deliveryFee: effectiveDeliveryFee,
        serviceFee: effectiveServiceFee,
        tax,
        rainFee,
        totalBeforePromo,
        totalBeforeCredits,
        total: totalAfterCredits,
        itemCount,
        deliveryDistanceKm: distanceKm ?? 0,
        estimatedDeliveryMin: estimatedDelivery.minMinutes,
        estimatedDeliveryMax: estimatedDelivery.maxMinutes,
        promoCode: promoCodeApplied,
        promoType,
        promoDiscount,
        promoValidationMessage,
        creditsApplied,
        totalAfterCredits,
        creditBalance,
        availableBalance,
        // GrabGo Pro subscription discounts
        subscriptionTier,
        subscriptionId,
        subscriptionDeliveryDiscount,
        subscriptionServiceFeeDiscount,
        originalDeliveryFee: deliveryFee,
        originalServiceFee: serviceFee,
    };
};

const calculateCartGroupsPricing = async (carts = [], options = {}) => {
    const safeCarts = Array.isArray(carts) ? carts : [];

    if (safeCarts.length === 0) {
        return {
            groups: [],
            summary: {
                subtotal: 0,
                deliveryFee: 0,
                serviceFee: 0,
                tax: 0,
                rainFee: 0,
                total: 0,
                totalBeforePromo: 0,
                totalBeforeCredits: 0,
                itemCount: 0,
                vendorCount: 0,
                estimatedDeliveryMin: null,
                estimatedDeliveryMax: null,
                estimatedDeliveryFirstMin: null,
                estimatedDeliveryFirstMax: null,
                estimatedDeliveryCompletionMin: null,
                estimatedDeliveryCompletionMax: null,
                promoCode: null,
                promoType: null,
                promoDiscount: 0,
                promoValidationMessage: null,
                creditsApplied: 0,
                totalAfterCredits: 0,
                creditBalance: 0,
                availableBalance: 0,
                subscriptionTier: null,
                subscriptionId: null,
                subscriptionDeliveryDiscount: 0,
                subscriptionServiceFeeDiscount: 0,
                originalDeliveryFee: 0,
                originalServiceFee: 0,
            },
        };
    }

    const { userId, deliveryLocation, useCredits, fulfillmentMode, promoCode } = options;
    const shouldUseCredits = useCredits !== false;
    const normalizedPromoCode = normalizePromoCode(promoCode);
    const promoForSingleVendor = safeCarts.length === 1 ? normalizedPromoCode : null;

    const groupResults = await Promise.all(
        safeCarts.map(async (cart) => {
            const pricing = await calculateCartPricing(cart, {
                userId,
                deliveryLocation,
                useCredits: false,
                fulfillmentMode,
                promoCode: promoForSingleVendor,
            });

            return { cart, pricing };
        })
    );

    let subtotal = 0;
    let deliveryFee = 0;
    let serviceFee = 0;
    let tax = 0;
    let rainFee = 0;
    let total = 0;
    let totalBeforePromo = 0;
    let itemCount = 0;
    let promoCodeApplied = null;
    let promoType = null;
    let promoDiscount = 0;
    let subscriptionTier = null;
    let subscriptionId = null;
    let subscriptionDeliveryDiscount = 0;
    let subscriptionServiceFeeDiscount = 0;
    let originalDeliveryFee = 0;
    let originalServiceFee = 0;
    let promoValidationMessage =
        normalizedPromoCode && safeCarts.length > 1
            ? 'Promo codes are currently available for single-vendor carts only.'
            : null;
    const etaGroups = [];

    const groups = groupResults.map(({ cart, pricing }) => {
        subtotal += toNumber(pricing?.subtotal, 0);
        deliveryFee += toNumber(pricing?.deliveryFee, 0);
        serviceFee += toNumber(pricing?.serviceFee, 0);
        tax += toNumber(pricing?.tax, 0);
        rainFee += toNumber(pricing?.rainFee, 0);
        total += toNumber(pricing?.total, 0);
        totalBeforePromo += toNumber(pricing?.totalBeforePromo, pricing?.total);
        itemCount += toNumber(pricing?.itemCount, 0);
        promoDiscount += toNumber(pricing?.promoDiscount, 0);
        subscriptionDeliveryDiscount += toNumber(pricing?.subscriptionDeliveryDiscount, 0);
        subscriptionServiceFeeDiscount += toNumber(pricing?.subscriptionServiceFeeDiscount, 0);
        originalDeliveryFee += toNumber(
            pricing?.originalDeliveryFee,
            toNumber(pricing?.deliveryFee, 0) + toNumber(pricing?.subscriptionDeliveryDiscount, 0)
        );
        originalServiceFee += toNumber(
            pricing?.originalServiceFee,
            toNumber(pricing?.serviceFee, 0) + toNumber(pricing?.subscriptionServiceFeeDiscount, 0)
        );
        if (!promoCodeApplied && pricing?.promoCode) {
            promoCodeApplied = pricing.promoCode;
        }
        if (!promoType && pricing?.promoType) {
            promoType = pricing.promoType;
        }
        if (!subscriptionTier && pricing?.subscriptionTier) {
            subscriptionTier = pricing.subscriptionTier;
        }
        if (!subscriptionId && pricing?.subscriptionId) {
            subscriptionId = pricing.subscriptionId;
        }
        if (!promoValidationMessage && pricing?.promoValidationMessage) {
            promoValidationMessage = pricing.promoValidationMessage;
        }
        const minMinutes = toNumber(pricing?.estimatedDeliveryMin, NaN);
        const maxMinutes = toNumber(pricing?.estimatedDeliveryMax, NaN);
        if (
            Number.isFinite(minMinutes) &&
            Number.isFinite(maxMinutes) &&
            minMinutes > 0 &&
            maxMinutes > 0
        ) {
            etaGroups.push({
                minMinutes: Math.round(minMinutes),
                maxMinutes: Math.round(maxMinutes),
            });
        }

        return {
            ...cart,
            pricing,
        };
    });

    subtotal = roundCurrency(subtotal);
    deliveryFee = roundCurrency(deliveryFee);
    serviceFee = roundCurrency(serviceFee);
    tax = roundCurrency(tax);
    rainFee = roundCurrency(rainFee);
    total = roundCurrency(total);
    totalBeforePromo = roundCurrency(totalBeforePromo);
    promoDiscount = roundCurrency(promoDiscount);
    subscriptionDeliveryDiscount = roundCurrency(subscriptionDeliveryDiscount);
    subscriptionServiceFeeDiscount = roundCurrency(subscriptionServiceFeeDiscount);
    originalDeliveryFee = roundCurrency(originalDeliveryFee);
    originalServiceFee = roundCurrency(originalServiceFee);

    let creditsApplied = 0;
    let totalBeforeCredits = total;
    let totalAfterCredits = totalBeforeCredits;
    let creditBalance = 0;
    let availableBalance = 0;

    if (userId) {
        const creditResult = await creditService.calculateCreditApplication(
            userId,
            totalBeforeCredits,
            shouldUseCredits
        );
        creditsApplied = toNumber(creditResult?.creditsApplied, 0);
        totalAfterCredits = roundCurrency(toNumber(creditResult?.remainingPayment, totalBeforeCredits));
        creditBalance = toNumber(creditResult?.creditBalance, 0);
        availableBalance = toNumber(
            creditResult?.availableBalance,
            Number.isFinite(creditBalance) ? creditBalance : 0
        );
    }

    let estimatedDeliveryFirstMin = null;
    let estimatedDeliveryFirstMax = null;
    let estimatedDeliveryCompletionMin = null;
    let estimatedDeliveryCompletionMax = null;

    if (etaGroups.length > 0 && etaGroups.length === groups.length) {
        const earliestWindow = etaGroups.reduce((best, current) => {
            if (!best) return current;
            if (current.minMinutes < best.minMinutes) return current;
            if (current.minMinutes === best.minMinutes && current.maxMinutes < best.maxMinutes) return current;
            return best;
        }, null);

        estimatedDeliveryFirstMin = earliestWindow?.minMinutes ?? null;
        estimatedDeliveryFirstMax = earliestWindow?.maxMinutes ?? null;
        estimatedDeliveryCompletionMin = Math.max(...etaGroups.map((entry) => entry.minMinutes));
        estimatedDeliveryCompletionMax = Math.max(...etaGroups.map((entry) => entry.maxMinutes));
    }

    return {
        groups,
        summary: {
            subtotal,
            deliveryFee,
            serviceFee,
            tax,
            rainFee,
            totalBeforePromo,
            totalBeforeCredits,
            total: totalAfterCredits,
            itemCount,
            vendorCount: groups.length,
            estimatedDeliveryMin: estimatedDeliveryCompletionMin,
            estimatedDeliveryMax: estimatedDeliveryCompletionMax,
            estimatedDeliveryFirstMin,
            estimatedDeliveryFirstMax,
            estimatedDeliveryCompletionMin,
            estimatedDeliveryCompletionMax,
            promoCode: promoCodeApplied,
            promoType,
            promoDiscount,
            promoValidationMessage,
            creditsApplied,
            totalAfterCredits,
            creditBalance,
            availableBalance,
            subscriptionTier,
            subscriptionId,
            subscriptionDeliveryDiscount,
            subscriptionServiceFeeDiscount,
            originalDeliveryFee,
            originalServiceFee,
        },
    };
};

const calculateOrderPricing = async ({
    subtotal,
    baseDeliveryFee,
    userId,
    deliveryLocation,
    vendorLocation,
    vendorPrepTime,
    vendorDeliveryTime,
    fulfillmentMode,
    orderType,
    promoCode,
}) => {
    const resolvedFulfillmentMode = normalizeFulfillmentMode(fulfillmentMode);
    const resolvedOrderType = String(orderType || '').trim().toLowerCase();
    const normalizedPromoCode = normalizePromoCode(promoCode);
    const normalizedSubtotal = roundCurrency(toNumber(subtotal, 0));
    const normalizedVendorLocation = normalizeLocation(vendorLocation);
    const resolvedDeliveryLocation = normalizeLocation(deliveryLocation) || await getUserDeliveryLocation(userId);
    const distanceKm = resolvedFulfillmentMode === 'pickup'
        ? null
        : calculateDistanceKm(normalizedVendorLocation, resolvedDeliveryLocation);
    const normalizedDeliveryFee = resolvedFulfillmentMode === 'pickup'
        ? 0
        : calculateDeliveryFee({
            baseFee: roundCurrency(toNumber(baseDeliveryFee, 0)),
            distanceKm
        });
    const baseServiceFee = calculateServiceFee(normalizedSubtotal);
    const tax = calculateTax(normalizedSubtotal);
    const rainFee = resolvedFulfillmentMode === 'pickup'
        ? 0
        : await getRainFee({ deliveryLocation: resolvedDeliveryLocation, vendorLocation: normalizedVendorLocation });

    let subscriptionDeliveryDiscount = 0;
    let subscriptionServiceFeeDiscount = 0;
    let subscriptionTier = null;
    let subscriptionId = null;

    if (userId) {
        const subBenefits = await subscriptionService.calculateSubscriptionBenefits(userId, {
            subtotal: normalizedSubtotal,
            deliveryFee: normalizedDeliveryFee,
            serviceFee: baseServiceFee,
        });
        if (subBenefits) {
            subscriptionDeliveryDiscount = subBenefits.deliveryDiscount;
            subscriptionServiceFeeDiscount = subBenefits.serviceFeeDiscount;
            subscriptionTier = subBenefits.tier;
            subscriptionId = subBenefits.subscriptionId;
        }
    }

    const effectiveDeliveryFee = roundCurrency(Math.max(0, normalizedDeliveryFee - subscriptionDeliveryDiscount));
    const effectiveServiceFee = roundCurrency(Math.max(0, baseServiceFee - subscriptionServiceFeeDiscount));

    let promoCodeApplied = null;
    let promoType = null;
    let promoDiscount = 0;
    let promoValidationMessage = null;

    if (normalizedPromoCode) {
        if (!userId) {
            promoValidationMessage = 'Please sign in to use promo codes.';
        } else if (!isPromoSupportedOrderType(resolvedOrderType)) {
            promoValidationMessage = 'Promo codes are currently available for food and grocery orders only.';
        } else {
            const promoValidation = await validatePromoCode(
                normalizedPromoCode,
                userId,
                normalizedSubtotal,
                resolvedOrderType
            );
            const promoResolution = resolvePromoDiscountForPricing({
                promoValidation,
                effectiveDeliveryFee,
                subtotal: normalizedSubtotal,
            });
            promoCodeApplied = promoResolution.promoCode;
            promoType = promoResolution.promoType;
            promoDiscount = promoResolution.promoDiscount;
            promoValidationMessage = promoResolution.promoValidationMessage;
        }
    }

    const totalBeforePromo = calculateTotal({
        subtotal: normalizedSubtotal,
        deliveryFee: effectiveDeliveryFee,
        serviceFee: effectiveServiceFee,
        tax,
        rainFee,
    });
    const totalBeforeCredits = roundCurrency(Math.max(0, totalBeforePromo - promoDiscount));

    const estimatedDelivery = calculateEstimatedDeliveryWindow({
        distanceKm,
        vendorPrepTime,
        vendorDeliveryTime: resolvedFulfillmentMode === 'pickup' ? null : vendorDeliveryTime
    });

    return {
        subtotal: normalizedSubtotal,
        deliveryFee: effectiveDeliveryFee,
        serviceFee: effectiveServiceFee,
        tax,
        rainFee,
        totalBeforePromo,
        totalBeforeCredits,
        total: totalBeforeCredits,
        promoCode: promoCodeApplied,
        promoType,
        promoDiscount,
        promoValidationMessage,
        subscriptionTier,
        subscriptionId,
        subscriptionDeliveryDiscount,
        subscriptionServiceFeeDiscount,
        originalDeliveryFee: normalizedDeliveryFee,
        originalServiceFee: baseServiceFee,
        deliveryDistanceKm: distanceKm ?? 0,
        estimatedDeliveryMin: estimatedDelivery.minMinutes,
        estimatedDeliveryMax: estimatedDelivery.maxMinutes
    };
};

module.exports = {
    calculateCartPricing,
    calculateCartGroupsPricing,
    calculateOrderPricing,
    calculateRainFee: getRainFee,
};
