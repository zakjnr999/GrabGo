const prisma = require('../config/prisma');
const { calculateDistance } = require('../utils/distance');

const toNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
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

const calculateTotal = ({ subtotal, deliveryFee, serviceFee, tax }) => {
    return roundCurrency(subtotal + deliveryFee + serviceFee + tax);
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
        return { baseFee: 0, vendorLocation: null };
    }

    const vendorId = resolveVendorId(cart);
    if (!vendorId) return { baseFee: 0, vendorLocation: null };

    if (cart.cartType === 'food') {
        const restaurant = await prisma.restaurant.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true }
        });
        return {
            baseFee: roundCurrency(toNumber(restaurant?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(restaurant)
        };
    }

    if (cart.cartType === 'grocery') {
        const store = await prisma.groceryStore.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true }
        });
        return {
            baseFee: roundCurrency(toNumber(store?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(store)
        };
    }

    if (cart.cartType === 'pharmacy') {
        const store = await prisma.pharmacyStore.findUnique({
            where: { id: vendorId },
            select: { deliveryFee: true, latitude: true, longitude: true }
        });
        return {
            baseFee: roundCurrency(toNumber(store?.deliveryFee, 0)),
            vendorLocation: normalizeLocation(store)
        };
    }

    return { baseFee: 0, vendorLocation: null };
};

const calculateCartPricing = async (cart, options = {}) => {
    if (!cart || !cart.items || cart.items.length === 0) {
        return {
            subtotal: 0,
            deliveryFee: 0,
            serviceFee: 0,
            tax: 0,
            total: 0,
            itemCount: 0,
            deliveryDistanceKm: 0
        };
    }

    const { userId, deliveryLocation } = options;
    const subtotal = calculateSubtotal(cart.items);
    const { baseFee, vendorLocation } = await getVendorDeliveryContext(cart);
    const resolvedDeliveryLocation = normalizeLocation(deliveryLocation) || await getUserDeliveryLocation(userId);
    const distanceKm = calculateDistanceKm(vendorLocation, resolvedDeliveryLocation);
    const deliveryFee = calculateDeliveryFee({ baseFee, distanceKm });
    const serviceFee = calculateServiceFee(subtotal);
    const tax = calculateTax(subtotal);
    const total = calculateTotal({ subtotal, deliveryFee, serviceFee, tax });
    const itemCount = cart.items.reduce((sum, item) => sum + toNumber(item.quantity, 0), 0);

    return {
        subtotal,
        deliveryFee,
        serviceFee,
        tax,
        total,
        itemCount,
        deliveryDistanceKm: distanceKm ?? 0
    };
};

const calculateOrderPricing = async ({ subtotal, baseDeliveryFee, userId, deliveryLocation, vendorLocation }) => {
    const normalizedSubtotal = roundCurrency(toNumber(subtotal, 0));
    const normalizedVendorLocation = normalizeLocation(vendorLocation);
    const resolvedDeliveryLocation = normalizeLocation(deliveryLocation) || await getUserDeliveryLocation(userId);
    const distanceKm = calculateDistanceKm(normalizedVendorLocation, resolvedDeliveryLocation);
    const normalizedDeliveryFee = calculateDeliveryFee({
        baseFee: roundCurrency(toNumber(baseDeliveryFee, 0)),
        distanceKm
    });
    const serviceFee = calculateServiceFee(normalizedSubtotal);
    const tax = calculateTax(normalizedSubtotal);
    const total = calculateTotal({
        subtotal: normalizedSubtotal,
        deliveryFee: normalizedDeliveryFee,
        serviceFee,
        tax
    });

    return {
        subtotal: normalizedSubtotal,
        deliveryFee: normalizedDeliveryFee,
        serviceFee,
        tax,
        total,
        deliveryDistanceKm: distanceKm ?? 0
    };
};

module.exports = {
    calculateCartPricing,
    calculateOrderPricing
};
