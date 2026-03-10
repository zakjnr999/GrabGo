const { Prisma } = require('@prisma/client');
const prisma = require('../config/prisma');
const { formatFoodResponse, FOOD_INCLUDE_RELATIONS } = require('../utils/food_helpers');
const { formatRestaurantCard } = require('../utils/vendor_card_formatter');
const { validateLocationParams, getBoundingBox } = require('../utils/vendor_distance_filter');
const { calculateDistance } = require('../utils/distance');
const { isRestaurantOpen } = require('../utils/restaurant');
const { createScopedLogger } = require('../utils/logger');

const logger = createScopedLogger('event_campaign_service');

const DEFAULT_DISCOVERY_DISTANCE_KM = 15;
const DEFAULT_VENDOR_LIMIT = 20;
const DEFAULT_ITEM_LIMIT = 20;
const PHASES = {
  PRE_EVENT: 'pre_event',
  SAME_DAY: 'same_day',
  LAST_CALL: 'last_call',
};

const EVENT_CAMPAIGN_SELECT = {
  id: true,
  name: true,
  slug: true,
  eventType: true,
  description: true,
  startsAt: true,
  endsAt: true,
  eventDate: true,
  isActive: true,
  heroTitle: true,
  heroSubtitle: true,
  heroImageUrl: true,
  bannerImageUrl: true,
  bannerBackgroundColor: true,
  ctaLabel: true,
  preEventNotifyDays: true,
  preEventNotifyHour: true,
  sameDayNotifyHour: true,
  lastCallNotifyHour: true,
  recentOrderLookbackDays: true,
  orderWindowStartHour: true,
  orderWindowEndHour: true,
  promotionalBannerId: true,
  createdById: true,
  createdAt: true,
  updatedAt: true,
  promotionalBanner: {
    select: {
      id: true,
      title: true,
      subtitle: true,
      imageUrl: true,
      backgroundColor: true,
      targetUrl: true,
      startDate: true,
      endDate: true,
      isActive: true,
      priority: true,
    },
  },
};

const PUBLIC_EVENT_RESTAURANT_SELECT = {
  id: true,
  restaurantName: true,
  email: true,
  phone: true,
  ownerFullName: true,
  ownerContactNumber: true,
  businessIdNumber: true,
  logo: true,
  businessIdPhoto: true,
  ownerPhoto: true,
  foodType: true,
  description: true,
  averageDeliveryTime: true,
  averagePreparationTime: true,
  deliveryFee: true,
  minOrder: true,
  paymentMethods: true,
  bannerImages: true,
  isVerified: true,
  verifiedAt: true,
  featured: true,
  featuredUntil: true,
  features: true,
  tags: true,
  whatsappNumber: true,
  totalReviews: true,
  isAcceptingOrders: true,
  isGrabGoExclusive: true,
  isGrabGoExclusiveUntil: true,
  lastOnlineAt: true,
  status: true,
  rating: true,
  ratingCount: true,
  isOpen: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
  facebookUrl: true,
  instagramUrl: true,
  twitterUrl: true,
  websiteUrl: true,
  openingHours: {
    select: {
      dayOfWeek: true,
      openTime: true,
      closeTime: true,
      isClosed: true,
    },
  },
  createdAt: true,
  updatedAt: true,
};

class EventCampaignError extends Error {
  constructor(message, { status = 400, code = 'EVENT_CAMPAIGN_ERROR', meta = null } = {}) {
    super(message);
    this.name = 'EventCampaignError';
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const toBoolean = (value, fallback = false) => {
  if (value === undefined || value === null) return fallback;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  return fallback;
};

const toInteger = (value, fallback = null) => {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

const toNullableString = (value) => {
  if (value === undefined) return undefined;
  if (value === null) return null;
  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : null;
};

const toDateOrThrow = (value, fieldName) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new EventCampaignError(`${fieldName} must be a valid ISO datetime`, {
      status: 400,
      code: 'EVENT_CAMPAIGN_INVALID_DATE',
      meta: { fieldName },
    });
  }
  return date;
};

const slugify = (value) =>
  String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');

const isUniqueConstraintError = (error) => error?.code === 'P2002';

const isCampaignPubliclyActive = (campaign, now = new Date()) => {
  if (!campaign || !campaign.isActive) return false;
  return new Date(campaign.startsAt) <= now && new Date(campaign.endsAt) >= now;
};

const getCampaignPhaseSchedule = (campaign) => {
  const eventDate = new Date(campaign.eventDate);
  const buildAtHour = (daysOffset, hour) => {
    const scheduled = new Date(eventDate);
    scheduled.setUTCDate(scheduled.getUTCDate() + daysOffset);
    scheduled.setUTCHours(hour, 0, 0, 0);
    return scheduled;
  };

  return {
    [PHASES.PRE_EVENT]: buildAtHour(-Math.max(campaign.preEventNotifyDays || 0, 0), campaign.preEventNotifyHour ?? 18),
    [PHASES.SAME_DAY]: buildAtHour(0, campaign.sameDayNotifyHour ?? 12),
    [PHASES.LAST_CALL]: buildAtHour(0, campaign.lastCallNotifyHour ?? 17),
  };
};

const buildNotificationCopy = (campaign, phase) => {
  const titleBase = campaign.heroTitle || campaign.name;
  switch (phase) {
    case PHASES.PRE_EVENT:
      return {
        title: `${titleBase}`,
        message: `Pre-order now from top restaurants near you for ${campaign.name}.`,
      };
    case PHASES.SAME_DAY:
      return {
        title: `${campaign.name} specials are live`,
        message: `Tonight's special is here. Order from participating restaurants near you now.`,
      };
    case PHASES.LAST_CALL:
      return {
        title: `${campaign.name} last call`,
        message: `Pre-orders close soon. Grab your seasonal favorites before the rush ends.`,
      };
    default:
      return {
        title: titleBase,
        message: campaign.heroSubtitle || campaign.description || 'Seasonal event campaign is live.',
      };
  }
};

const pickUserLocation = (user) => {
  const addresses = Array.isArray(user.addresses) ? user.addresses : [];
  const defaultAddress = addresses.find((address) => address.isDefault) || addresses[0];
  if (defaultAddress?.latitude != null && defaultAddress?.longitude != null) {
    return {
      latitude: Number(defaultAddress.latitude),
      longitude: Number(defaultAddress.longitude),
      source: 'address',
      formattedAddress: defaultAddress.formattedAddress || null,
    };
  }

  const orders = Array.isArray(user.orders) ? user.orders : [];
  const recentOrder = orders.find(
    (order) => order.deliveryLatitude != null && order.deliveryLongitude != null,
  );
  if (recentOrder) {
    return {
      latitude: Number(recentOrder.deliveryLatitude),
      longitude: Number(recentOrder.deliveryLongitude),
      source: 'order',
      formattedAddress: null,
    };
  }

  return null;
};

const hourFallsInWindow = (hour, startHour, endHour) => {
  if (startHour == null || endHour == null) return true;
  if (startHour === endHour) return true;
  if (endHour > startHour) {
    return hour >= startHour && hour < endHour;
  }
  return hour >= startHour || hour < endHour;
};

const userMatchesCampaignWindow = (campaign, user) => {
  const startHour = campaign.orderWindowStartHour;
  const endHour = campaign.orderWindowEndHour;
  if (startHour == null || endHour == null) return true;

  const recentOrders = Array.isArray(user.orders) ? user.orders : [];
  if (recentOrders.length < 3) {
    return true;
  }

  const hourFrequency = recentOrders.reduce((acc, order) => {
    const hour = new Date(order.orderDate).getUTCHours();
    acc[hour] = (acc[hour] || 0) + 1;
    return acc;
  }, {});

  const preferredHour = Object.entries(hourFrequency)
    .sort((a, b) => Number(b[1]) - Number(a[1]))
    .map(([hour]) => Number(hour))[0];

  return hourFallsInWindow(preferredHour, startHour, endHour);
};

const createCampaignWhereInput = ({ activeOnly = false } = {}) => {
  const now = new Date();
  if (!activeOnly) {
    return {
      isActive: true,
      endsAt: { gte: now },
    };
  }

  return {
    isActive: true,
    startsAt: { lte: now },
    endsAt: { gte: now },
  };
};

const buildCampaignPayload = async ({ data, existingCampaignId = null, tx = prisma }) => {
  const name = String(data.name || '').trim();
  if (!name) {
    throw new EventCampaignError('name is required', {
      status: 400,
      code: 'EVENT_CAMPAIGN_NAME_REQUIRED',
    });
  }

  const startsAt = toDateOrThrow(data.startsAt, 'startsAt');
  const endsAt = toDateOrThrow(data.endsAt, 'endsAt');
  const eventDate = toDateOrThrow(data.eventDate, 'eventDate');
  if (startsAt >= endsAt) {
    throw new EventCampaignError('startsAt must be before endsAt', {
      status: 400,
      code: 'EVENT_CAMPAIGN_INVALID_WINDOW',
    });
  }
  if (eventDate < startsAt || eventDate > endsAt) {
    throw new EventCampaignError('eventDate must fall within the campaign window', {
      status: 400,
      code: 'EVENT_CAMPAIGN_EVENT_DATE_OUT_OF_RANGE',
    });
  }

  const requestedSlug = slugify(data.slug || name);
  if (!requestedSlug) {
    throw new EventCampaignError('slug is required', {
      status: 400,
      code: 'EVENT_CAMPAIGN_SLUG_REQUIRED',
    });
  }

  let slug = requestedSlug;
  let suffix = 1;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const conflict = await tx.eventCampaign.findFirst({
      where: {
        slug,
        ...(existingCampaignId
          ? {
              NOT: { id: existingCampaignId },
            }
          : {}),
      },
      select: { id: true },
    });

    if (!conflict) break;
    suffix += 1;
    slug = `${requestedSlug}-${suffix}`;
  }

  return {
    name,
    slug,
    eventType: String(data.eventType || 'seasonal').trim(),
    description: toNullableString(data.description),
    startsAt,
    endsAt,
    eventDate,
    isActive: toBoolean(data.isActive, true),
    heroTitle: toNullableString(data.heroTitle) ?? name,
    heroSubtitle: toNullableString(data.heroSubtitle),
    heroImageUrl: toNullableString(data.heroImageUrl),
    bannerImageUrl: toNullableString(data.bannerImageUrl),
    bannerBackgroundColor: toNullableString(data.bannerBackgroundColor) || '#FFFFFF',
    ctaLabel: toNullableString(data.ctaLabel) || 'View event',
    preEventNotifyDays: Math.max(toInteger(data.preEventNotifyDays, 3), 0),
    preEventNotifyHour: Math.min(Math.max(toInteger(data.preEventNotifyHour, 18), 0), 23),
    sameDayNotifyHour: Math.min(Math.max(toInteger(data.sameDayNotifyHour, 12), 0), 23),
    lastCallNotifyHour: Math.min(Math.max(toInteger(data.lastCallNotifyHour, 17), 0), 23),
    recentOrderLookbackDays: Math.max(toInteger(data.recentOrderLookbackDays, 30), 1),
    orderWindowStartHour:
      data.orderWindowStartHour === undefined || data.orderWindowStartHour === null || data.orderWindowStartHour === ''
        ? null
        : Math.min(Math.max(toInteger(data.orderWindowStartHour, null), 0), 23),
    orderWindowEndHour:
      data.orderWindowEndHour === undefined || data.orderWindowEndHour === null || data.orderWindowEndHour === ''
        ? null
        : Math.min(Math.max(toInteger(data.orderWindowEndHour, null), 0), 23),
  };
};

const syncPromotionalBannerForCampaign = async ({ tx, campaign, existingBannerId = null }) => {
  const imageUrl = campaign.bannerImageUrl || campaign.heroImageUrl;
  if (!imageUrl) {
    if (existingBannerId) {
      await tx.promotionalBanner.update({
        where: { id: existingBannerId },
        data: {
          isActive: false,
          targetUrl: null,
          endDate: new Date(),
        },
        select: { id: true },
      });
    }
    return null;
  }

  const bannerPayload = {
    title: campaign.heroTitle || campaign.name,
    subtitle: campaign.heroSubtitle,
    imageUrl,
    backgroundColor: campaign.bannerBackgroundColor || '#FFFFFF',
    targetUrl: `/events/${campaign.slug}`,
    startDate: campaign.startsAt,
    endDate: campaign.endsAt,
    isActive: campaign.isActive,
    priority: 50,
    targetAudience: 'all',
  };

  if (existingBannerId) {
    const banner = await tx.promotionalBanner.update({
      where: { id: existingBannerId },
      data: bannerPayload,
      select: { id: true },
    });
    return banner.id;
  }

  const banner = await tx.promotionalBanner.create({
    data: bannerPayload,
    select: { id: true },
  });
  return banner.id;
};

const getRestaurantForVendorUser = async (user) => {
  if (!user?.email) {
    throw new EventCampaignError('Restaurant user email is required', {
      status: 400,
      code: 'EVENT_CAMPAIGN_VENDOR_CONTEXT_INVALID',
    });
  }

  const restaurant = await prisma.restaurant.findUnique({
    where: { email: user.email },
    select: {
      id: true,
      email: true,
      restaurantName: true,
      status: true,
      isDeleted: true,
    },
  });

  if (!restaurant || restaurant.isDeleted) {
    throw new EventCampaignError('Restaurant account not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_RESTAURANT_NOT_FOUND',
    });
  }

  if (restaurant.status !== 'approved') {
    throw new EventCampaignError('Restaurant must be approved before joining campaigns', {
      status: 403,
      code: 'EVENT_CAMPAIGN_RESTAURANT_NOT_APPROVED',
    });
  }

  return restaurant;
};

const getPublicCampaignBySlug = async (slug) => {
  const campaign = await prisma.eventCampaign.findUnique({
    where: { slug },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!campaign || !isCampaignPubliclyActive(campaign)) {
    throw new EventCampaignError('Event campaign not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  }

  return campaign;
};

const buildPublicCampaignPayload = (campaign, extra = {}) => ({
  ...campaign,
  targetUrl: `/events/${campaign.slug}`,
  isLive: isCampaignPubliclyActive(campaign),
  countdownMs: Math.max(new Date(campaign.eventDate).getTime() - Date.now(), 0),
  ...extra,
});

const getActiveEventCampaigns = async () => {
  const campaigns = await prisma.eventCampaign.findMany({
    where: createCampaignWhereInput({ activeOnly: true }),
    select: EVENT_CAMPAIGN_SELECT,
    orderBy: [{ eventDate: 'asc' }, { createdAt: 'desc' }],
  });

  return Promise.all(
    campaigns.map(async (campaign) => {
      const [participations, eventItems] = await Promise.all([
        prisma.restaurantEventParticipation.findMany({
          where: {
            eventCampaignId: campaign.id,
            isApproved: true,
            isActive: true,
            restaurant: {
              status: 'approved',
              isDeleted: false,
            },
          },
          select: { id: true },
        }),
        prisma.food.findMany({
          where: {
            eventCampaignId: campaign.id,
            isEventItem: true,
            isAvailable: true,
            restaurant: {
              status: 'approved',
              isDeleted: false,
              eventParticipations: {
                some: {
                  eventCampaignId: campaign.id,
                  isApproved: true,
                  isActive: true,
                },
              },
            },
          },
          select: { id: true },
        }),
      ]);

      return buildPublicCampaignPayload(campaign, {
        participatingRestaurantCount: participations.length,
        eventItemCount: eventItems.length,
      });
    }),
  );
};

const getEventCampaignDetailBySlug = async ({ slug }) => {
  const campaign = await getPublicCampaignBySlug(slug);
  const [participationStats, eventItemStats] = await Promise.all([
    prisma.restaurantEventParticipation.findMany({
      where: {
        eventCampaignId: campaign.id,
        isApproved: true,
        isActive: true,
        restaurant: {
          status: 'approved',
          isDeleted: false,
        },
      },
      select: {
        isFeatured: true,
        supportsPreorder: true,
      },
    }),
    prisma.food.findMany({
      where: {
        eventCampaignId: campaign.id,
        isEventItem: true,
        isAvailable: true,
        restaurant: {
          status: 'approved',
          isDeleted: false,
          eventParticipations: {
            some: {
              eventCampaignId: campaign.id,
              isApproved: true,
              isActive: true,
            },
          },
        },
      },
      select: {
        isEventBundle: true,
        isAvailable: true,
      },
    }),
  ]);

  return buildPublicCampaignPayload(campaign, {
    participatingRestaurantCount: participationStats.length,
    featuredRestaurantCount: participationStats.filter((entry) => entry.isFeatured).length,
    preorderRestaurantCount: participationStats.filter((entry) => entry.supportsPreorder).length,
    eventItemCount: eventItemStats.filter((entry) => entry.isAvailable).length,
    eventBundleCount: eventItemStats.filter((entry) => entry.isAvailable && entry.isEventBundle).length,
  });
};

const fetchPublicParticipatingRestaurants = async ({ campaignId, userLat, userLng, maxDistanceKm = DEFAULT_DISCOVERY_DISTANCE_KM, includeLocationFilter = true }) => {
  const validatedLocation = includeLocationFilter
    ? validateLocationParams(userLat, userLng, maxDistanceKm)
    : null;

  const bbox = validatedLocation
    ? getBoundingBox(validatedLocation.userLatitude, validatedLocation.userLongitude, validatedLocation.maxDistanceKm)
    : null;

  const participations = await prisma.restaurantEventParticipation.findMany({
    where: {
      eventCampaignId: campaignId,
      isApproved: true,
      isActive: true,
      restaurant: {
        isDeleted: false,
        status: 'approved',
        ...(bbox
          ? {
              latitude: { gte: bbox.minLat, lte: bbox.maxLat },
              longitude: { gte: bbox.minLng, lte: bbox.maxLng },
            }
          : {}),
      },
    },
    select: {
      supportsPreorder: true,
      isFeatured: true,
      restaurant: {
        select: PUBLIC_EVENT_RESTAURANT_SELECT,
      },
    },
  });

  const restaurants = participations
    .map((participation) => {
      if (!participation.restaurant) return null;
      const restaurant = participation.restaurant;
      const isOpen = isRestaurantOpen(restaurant);
      const distance =
        validatedLocation && restaurant.latitude != null && restaurant.longitude != null
          ? calculateDistance(
              restaurant.latitude,
              restaurant.longitude,
              validatedLocation.userLatitude,
              validatedLocation.userLongitude,
            )
          : null;

      if (validatedLocation && distance != null && distance > validatedLocation.maxDistanceKm) {
        return null;
      }

      const formatted = formatRestaurantCard({
        ...restaurant,
        _distance: distance,
      });

      return {
        ...formatted,
        supportsPreorder: participation.supportsPreorder,
        isFeaturedForEvent: participation.isFeatured,
        preorderAvailable: participation.supportsPreorder,
        eventAvailabilityState: isOpen ? 'open' : participation.supportsPreorder ? 'preorder' : 'closed',
      };
    })
    .filter(Boolean)
    .filter((restaurant) => restaurant.isOpen || restaurant.supportsPreorder);

  restaurants.sort((left, right) => {
    const leftOpenScore = left.isOpen ? 0 : left.supportsPreorder ? 1 : 2;
    const rightOpenScore = right.isOpen ? 0 : right.supportsPreorder ? 1 : 2;

    if (left.isFeaturedForEvent !== right.isFeaturedForEvent) {
      return left.isFeaturedForEvent ? -1 : 1;
    }
    if (leftOpenScore !== rightOpenScore) {
      return leftOpenScore - rightOpenScore;
    }
    if ((left.distance ?? Number.POSITIVE_INFINITY) !== (right.distance ?? Number.POSITIVE_INFINITY)) {
      return (left.distance ?? Number.POSITIVE_INFINITY) - (right.distance ?? Number.POSITIVE_INFINITY);
    }
    if ((right.weightedRating ?? right.rating ?? 0) !== (left.weightedRating ?? left.rating ?? 0)) {
      return (right.weightedRating ?? right.rating ?? 0) - (left.weightedRating ?? left.rating ?? 0);
    }
    if ((right.featured ? 1 : 0) !== (left.featured ? 1 : 0)) {
      return (right.featured ? 1 : 0) - (left.featured ? 1 : 0);
    }
    return String(left.restaurantName || '').localeCompare(String(right.restaurantName || ''));
  });

  return restaurants;
};

const getEventCampaignVendorsBySlug = async ({ slug, userLat, userLng, maxDistanceKm = DEFAULT_DISCOVERY_DISTANCE_KM, limit = DEFAULT_VENDOR_LIMIT }) => {
  const campaign = await getPublicCampaignBySlug(slug);
  const restaurants = await fetchPublicParticipatingRestaurants({
    campaignId: campaign.id,
    userLat,
    userLng,
    maxDistanceKm,
  });

  return {
    campaign: buildPublicCampaignPayload(campaign),
    vendors: restaurants.slice(0, Math.max(toInteger(limit, DEFAULT_VENDOR_LIMIT), 1)),
  };
};

const getEventCampaignItemsBySlug = async ({ slug, userLat, userLng, maxDistanceKm = DEFAULT_DISCOVERY_DISTANCE_KM, limit = DEFAULT_ITEM_LIMIT }) => {
  const campaign = await getPublicCampaignBySlug(slug);
  const validatedLocation = validateLocationParams(userLat, userLng, maxDistanceKm);
  const bbox = validatedLocation
    ? getBoundingBox(validatedLocation.userLatitude, validatedLocation.userLongitude, validatedLocation.maxDistanceKm)
    : null;

  const foods = await prisma.food.findMany({
    where: {
      eventCampaignId: campaign.id,
      isEventItem: true,
      isAvailable: true,
      restaurant: {
        status: 'approved',
        isDeleted: false,
        eventParticipations: {
          some: {
            eventCampaignId: campaign.id,
            isApproved: true,
            isActive: true,
          },
        },
        ...(bbox
          ? {
              latitude: { gte: bbox.minLat, lte: bbox.maxLat },
              longitude: { gte: bbox.minLng, lte: bbox.maxLng },
            }
          : {}),
      },
    },
    include: {
      ...FOOD_INCLUDE_RELATIONS,
      eventCampaign: {
        select: {
          id: true,
          name: true,
          slug: true,
        },
      },
      restaurant: {
        select: {
          ...FOOD_INCLUDE_RELATIONS.restaurant.select,
          eventParticipations: {
            where: {
              eventCampaignId: campaign.id,
              isApproved: true,
              isActive: true,
            },
            select: {
              supportsPreorder: true,
              isFeatured: true,
            },
            take: 1,
          },
        },
      },
    },
  });

  const formattedFoods = formatFoodResponse(foods, userLat, userLng)
    .map((food) => {
      const participation = food.restaurant?.eventParticipations?.[0] || null;
      const restaurantOpen = Boolean(food.isRestaurantOpen);
      const supportsPreorder = Boolean(participation?.supportsPreorder);
      const distance =
        validatedLocation && food.restaurant?.latitude != null && food.restaurant?.longitude != null
          ? calculateDistance(
              Number(food.restaurant.latitude),
              Number(food.restaurant.longitude),
              validatedLocation.userLatitude,
              validatedLocation.userLongitude,
            )
          : null;

      if (validatedLocation && distance != null && distance > validatedLocation.maxDistanceKm) {
        return null;
      }
      if (!restaurantOpen && !supportsPreorder) {
        return null;
      }

      return {
        ...food,
        distance,
        isEventItem: true,
        isEventBundle: Boolean(food.isEventBundle),
        preorderAvailable: supportsPreorder,
        eventAvailabilityState: restaurantOpen ? 'open' : supportsPreorder ? 'preorder' : 'closed',
      };
    })
    .filter(Boolean);

  formattedFoods.sort((left, right) => {
    if (left.isEventBundle !== right.isEventBundle) {
      return left.isEventBundle ? -1 : 1;
    }
    if ((right.discountPercentage ?? 0) !== (left.discountPercentage ?? 0)) {
      return (right.discountPercentage ?? 0) - (left.discountPercentage ?? 0);
    }
    if ((right.weightedRating ?? right.rating ?? 0) !== (left.weightedRating ?? left.rating ?? 0)) {
      return (right.weightedRating ?? right.rating ?? 0) - (left.weightedRating ?? left.rating ?? 0);
    }
    return (left.distance ?? Number.POSITIVE_INFINITY) - (right.distance ?? Number.POSITIVE_INFINITY);
  });

  return {
    campaign: buildPublicCampaignPayload(campaign),
    items: formattedFoods.slice(0, Math.max(toInteger(limit, DEFAULT_ITEM_LIMIT), 1)),
  };
};

const createEventCampaign = async ({ data, createdById = null }) => {
  const eventCampaign = await prisma.$transaction(async (tx) => {
    const payload = await buildCampaignPayload({ data, tx });
    const promotionalBannerId = await syncPromotionalBannerForCampaign({
      tx,
      campaign: payload,
      existingBannerId: null,
    });

    return tx.eventCampaign.create({
      data: {
        ...payload,
        promotionalBannerId,
        createdById,
      },
      select: EVENT_CAMPAIGN_SELECT,
    });
  });

  return eventCampaign;
};

const updateEventCampaign = async ({ eventId, data }) => {
  const existing = await prisma.eventCampaign.findUnique({
    where: { id: eventId },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!existing) {
    throw new EventCampaignError('Event campaign not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  }

  const eventCampaign = await prisma.$transaction(async (tx) => {
    const payload = await buildCampaignPayload({ data: { ...existing, ...data }, existingCampaignId: eventId, tx });
    const promotionalBannerId = await syncPromotionalBannerForCampaign({
      tx,
      campaign: payload,
      existingBannerId: existing.promotionalBannerId,
    });

    return tx.eventCampaign.update({
      where: { id: eventId },
      data: {
        ...payload,
        promotionalBannerId,
      },
      select: EVENT_CAMPAIGN_SELECT,
    });
  });

  return eventCampaign;
};

const getAvailableEventCampaignsForVendor = async ({ user }) => {
  const restaurant = await getRestaurantForVendorUser(user);
  const campaigns = await prisma.eventCampaign.findMany({
    where: createCampaignWhereInput({ activeOnly: false }),
    select: {
      ...EVENT_CAMPAIGN_SELECT,
      participations: {
        where: { restaurantId: restaurant.id },
        select: {
          id: true,
          status: true,
          supportsPreorder: true,
          isApproved: true,
          isFeatured: true,
          isActive: true,
          optedInAt: true,
          approvedAt: true,
          rejectedAt: true,
        },
        take: 1,
      },
    },
    orderBy: [{ eventDate: 'asc' }, { createdAt: 'desc' }],
  });

  const now = new Date();
  return campaigns.map((campaign) => ({
    ...campaign,
    statusLabel:
      new Date(campaign.endsAt) < now
        ? 'ended'
        : new Date(campaign.startsAt) > now
          ? 'upcoming'
          : isCampaignPubliclyActive(campaign, now)
            ? 'live'
            : 'inactive',
    participation: campaign.participations[0] || null,
  }));
};

const upsertRestaurantEventParticipation = async ({ user, eventId, supportsPreorder = false }) => {
  const restaurant = await getRestaurantForVendorUser(user);
  const campaign = await prisma.eventCampaign.findUnique({
    where: { id: eventId },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!campaign || !campaign.isActive || new Date(campaign.endsAt) < new Date()) {
    throw new EventCampaignError('Event campaign is not open for participation', {
      status: 400,
      code: 'EVENT_CAMPAIGN_NOT_OPEN',
    });
  }

  const participation = await prisma.restaurantEventParticipation.upsert({
    where: {
      eventCampaignId_restaurantId: {
        eventCampaignId: eventId,
        restaurantId: restaurant.id,
      },
    },
    update: {
      supportsPreorder: toBoolean(supportsPreorder, false),
      status: 'pending',
      isApproved: false,
      isActive: true,
      optedInAt: new Date(),
      rejectedAt: null,
      approvedAt: null,
    },
    create: {
      eventCampaignId: eventId,
      restaurantId: restaurant.id,
      supportsPreorder: toBoolean(supportsPreorder, false),
      status: 'pending',
      isApproved: false,
      isActive: true,
    },
    include: {
      restaurant: {
        select: {
          id: true,
          restaurantName: true,
        },
      },
      eventCampaign: {
        select: {
          id: true,
          name: true,
          slug: true,
        },
      },
    },
  });

  return participation;
};

const updateRestaurantEventParticipation = async ({ user, eventId, data }) => {
  const restaurant = await getRestaurantForVendorUser(user);
  const existing = await prisma.restaurantEventParticipation.findUnique({
    where: {
      eventCampaignId_restaurantId: {
        eventCampaignId: eventId,
        restaurantId: restaurant.id,
      },
    },
  });

  if (!existing) {
    throw new EventCampaignError('Campaign participation not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_PARTICIPATION_NOT_FOUND',
    });
  }

  const updateData = {};
  if (data.supportsPreorder !== undefined) {
    updateData.supportsPreorder = toBoolean(data.supportsPreorder, existing.supportsPreorder);
  }
  if (data.isActive !== undefined) {
    updateData.isActive = toBoolean(data.isActive, existing.isActive);
  }
  if (toBoolean(data.withdraw, false) || data.status === 'withdrawn') {
    updateData.status = 'withdrawn';
    updateData.isActive = false;
    updateData.isApproved = false;
    updateData.approvedAt = null;
    updateData.rejectedAt = null;
  }

  return prisma.restaurantEventParticipation.update({
    where: {
      eventCampaignId_restaurantId: {
        eventCampaignId: eventId,
        restaurantId: restaurant.id,
      },
    },
    data: updateData,
    include: {
      restaurant: {
        select: {
          id: true,
          restaurantName: true,
        },
      },
      eventCampaign: {
        select: {
          id: true,
          name: true,
          slug: true,
        },
      },
    },
  });
};

const updateFoodEventConfig = async ({ user, foodId, data }) => {
  const restaurant = await getRestaurantForVendorUser(user);
  const food = await prisma.food.findUnique({
    where: { id: foodId },
    select: {
      id: true,
      restaurantId: true,
      eventCampaignId: true,
      isEventItem: true,
      isEventBundle: true,
    },
  });

  if (!food || food.restaurantId !== restaurant.id) {
    throw new EventCampaignError('Food item not found for this restaurant', {
      status: 404,
      code: 'EVENT_CAMPAIGN_FOOD_NOT_FOUND',
    });
  }

  const requestedEventCampaignId = data.eventCampaignId ?? null;
  if (requestedEventCampaignId) {
    const campaign = await prisma.eventCampaign.findUnique({
      where: { id: requestedEventCampaignId },
      select: { id: true, endsAt: true, isActive: true },
    });
    if (!campaign || !campaign.isActive || new Date(campaign.endsAt) < new Date()) {
      throw new EventCampaignError('Selected event campaign is not available', {
        status: 400,
        code: 'EVENT_CAMPAIGN_INVALID_TARGET',
      });
    }

    const participation = await prisma.restaurantEventParticipation.findUnique({
      where: {
        eventCampaignId_restaurantId: {
          eventCampaignId: requestedEventCampaignId,
          restaurantId: restaurant.id,
        },
      },
      select: {
        id: true,
        status: true,
        isActive: true,
      },
    });

    if (!participation || !participation.isActive || ['rejected', 'withdrawn'].includes(participation.status)) {
      throw new EventCampaignError('Restaurant must opt into the campaign before tagging items', {
        status: 400,
        code: 'EVENT_CAMPAIGN_PARTICIPATION_REQUIRED',
      });
    }
  }

  const eventCampaignId = requestedEventCampaignId || null;
  const isEventItem = Boolean(eventCampaignId) ? toBoolean(data.isEventItem, true) : false;
  const isEventBundle = Boolean(eventCampaignId) ? toBoolean(data.isEventBundle, false) : false;

  return prisma.food.update({
    where: { id: foodId },
    data: {
      eventCampaignId,
      isEventItem,
      isEventBundle,
    },
    select: {
      id: true,
      name: true,
      eventCampaignId: true,
      isEventItem: true,
      isEventBundle: true,
    },
  });
};

const listEventParticipants = async ({ eventId }) => {
  const campaign = await prisma.eventCampaign.findUnique({
    where: { id: eventId },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!campaign) {
    throw new EventCampaignError('Event campaign not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  }

  const participants = await prisma.restaurantEventParticipation.findMany({
    where: { eventCampaignId: eventId },
    include: {
      restaurant: {
        select: {
          id: true,
          restaurantName: true,
          logo: true,
          rating: true,
          ratingCount: true,
          city: true,
          area: true,
          latitude: true,
          longitude: true,
        },
      },
    },
    orderBy: [{ isFeatured: 'desc' }, { optedInAt: 'asc' }],
  });

  return {
    campaign,
    participants,
  };
};

const updateEventParticipantStatus = async ({ eventId, restaurantId, data }) => {
  const participation = await prisma.restaurantEventParticipation.findUnique({
    where: {
      eventCampaignId_restaurantId: {
        eventCampaignId: eventId,
        restaurantId,
      },
    },
    include: {
      restaurant: {
        select: { id: true, restaurantName: true },
      },
      eventCampaign: {
        select: { id: true, name: true, slug: true },
      },
    },
  });

  if (!participation) {
    throw new EventCampaignError('Campaign participation not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_PARTICIPATION_NOT_FOUND',
    });
  }

  const updateData = {};
  const action = String(data.action || '').trim().toLowerCase();
  if (action === 'approve') {
    updateData.status = 'approved';
    updateData.isApproved = true;
    updateData.approvedAt = new Date();
    updateData.rejectedAt = null;
    updateData.isActive = true;
  } else if (action === 'reject') {
    updateData.status = 'rejected';
    updateData.isApproved = false;
    updateData.isActive = false;
    updateData.approvedAt = null;
    updateData.rejectedAt = new Date();
  }

  if (data.isFeatured !== undefined) {
    updateData.isFeatured = toBoolean(data.isFeatured, participation.isFeatured);
  }
  if (data.supportsPreorder !== undefined) {
    updateData.supportsPreorder = toBoolean(data.supportsPreorder, participation.supportsPreorder);
  }
  if (data.isActive !== undefined) {
    updateData.isActive = toBoolean(data.isActive, participation.isActive);
  }

  return prisma.restaurantEventParticipation.update({
    where: {
      eventCampaignId_restaurantId: {
        eventCampaignId: eventId,
        restaurantId,
      },
    },
    data: updateData,
    include: {
      restaurant: {
        select: { id: true, restaurantName: true },
      },
      eventCampaign: {
        select: { id: true, name: true, slug: true },
      },
    },
  });
};

const buildAudienceForCampaign = async ({ campaign }) => {
  const lookbackDays = Math.max(campaign.recentOrderLookbackDays || 30, 1);
  const lookbackThreshold = new Date(Date.now() - lookbackDays * 24 * 60 * 60 * 1000);
  const participatingRestaurants = await prisma.restaurantEventParticipation.findMany({
    where: {
      eventCampaignId: campaign.id,
      isApproved: true,
      isActive: true,
    },
    select: {
      supportsPreorder: true,
      restaurant: {
        select: {
          id: true,
          restaurantName: true,
          latitude: true,
          longitude: true,
        },
      },
    },
  });

  const eventRestaurants = participatingRestaurants
    .map((entry) => entry.restaurant)
    .filter((restaurant) => restaurant?.latitude != null && restaurant?.longitude != null);

  if (eventRestaurants.length === 0) {
    return {
      users: [],
      stats: {
        candidateUsers: 0,
        locationMatchedUsers: 0,
        timeMatchedUsers: 0,
        selectedUsers: 0,
      },
    };
  }

  const users = await prisma.user.findMany({
    where: {
      role: 'customer',
      isActive: true,
      lastOrderDate: { gte: lookbackThreshold },
      orders: {
        some: {
          orderType: 'food',
          orderDate: { gte: lookbackThreshold },
          status: { not: 'cancelled' },
        },
      },
      fcmTokens: { some: {} },
    },
    select: {
      id: true,
      username: true,
      email: true,
      lastOrderDate: true,
      mealTimePreferences: {
        select: {
          enabled: true,
          breakfast: true,
          lunch: true,
          dinner: true,
        },
      },
      addresses: {
        orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
        take: 3,
        select: {
          latitude: true,
          longitude: true,
          formattedAddress: true,
          isDefault: true,
        },
      },
      orders: {
        where: {
          orderType: 'food',
          orderDate: { gte: lookbackThreshold },
          status: { not: 'cancelled' },
        },
        orderBy: { orderDate: 'desc' },
        take: 10,
        select: {
          orderDate: true,
          deliveryLatitude: true,
          deliveryLongitude: true,
        },
      },
    },
  });

  let locationMatchedUsers = 0;
  let timeMatchedUsers = 0;
  const selectedUsers = [];

  for (const user of users) {
    const location = pickUserLocation(user);
    if (!location) continue;

    const nearestDistance = eventRestaurants.reduce((best, restaurant) => {
      const distance = calculateDistance(
        Number(location.latitude),
        Number(location.longitude),
        Number(restaurant.latitude),
        Number(restaurant.longitude),
      );
      return Math.min(best, distance);
    }, Number.POSITIVE_INFINITY);

    if (!Number.isFinite(nearestDistance) || nearestDistance > DEFAULT_DISCOVERY_DISTANCE_KM) {
      continue;
    }
    locationMatchedUsers += 1;

    if (!userMatchesCampaignWindow(campaign, user)) {
      continue;
    }
    timeMatchedUsers += 1;

    selectedUsers.push({
      id: user.id,
      username: user.username,
      email: user.email,
      lastOrderDate: user.lastOrderDate,
      nearestDistanceKm: Number(nearestDistance.toFixed(2)),
      location,
      recentOrderCount: user.orders.length,
    });
  }

  return {
    users: selectedUsers,
    stats: {
      candidateUsers: users.length,
      locationMatchedUsers,
      timeMatchedUsers,
      selectedUsers: selectedUsers.length,
    },
  };
};

const getEventAudiencePreview = async ({ eventId }) => {
  const campaign = await prisma.eventCampaign.findUnique({
    where: { id: eventId },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!campaign) {
    throw new EventCampaignError('Event campaign not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  }

  const audience = await buildAudienceForCampaign({ campaign });
  return {
    campaign,
    phases: getCampaignPhaseSchedule(campaign),
    stats: audience.stats,
    users: audience.users.slice(0, 25),
  };
};

const scheduleEventNotifications = async ({ eventId }) => {
  const campaign = await prisma.eventCampaign.findUnique({
    where: { id: eventId },
    select: EVENT_CAMPAIGN_SELECT,
  });

  if (!campaign) {
    throw new EventCampaignError('Event campaign not found', {
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  }

  const audience = await buildAudienceForCampaign({ campaign });
  const phaseSchedule = getCampaignPhaseSchedule(campaign);
  const now = new Date();
  const counts = {
    queued: 0,
    skippedExisting: 0,
    skippedPastPhase: 0,
  };

  for (const user of audience.users) {
    for (const [phase, scheduledFor] of Object.entries(phaseSchedule)) {
      if (scheduledFor <= now) {
        counts.skippedPastPhase += 1;
        continue;
      }

      const copy = buildNotificationCopy(campaign, phase);
      try {
        await prisma.$transaction(async (tx) => {
          const scheduledNotification = await tx.scheduledNotification.create({
            data: {
              userId: user.id,
              scheduledAt: scheduledFor,
              type: 'promo',
              title: copy.title,
              message: copy.message,
              data: {
                route: `/events/${campaign.slug}`,
                eventCampaignId: campaign.id,
                eventCampaignSlug: campaign.slug,
                phase,
              },
            },
            select: { id: true },
          });

          await tx.eventCampaignNotificationDispatch.create({
            data: {
              eventCampaignId: campaign.id,
              userId: user.id,
              phase,
              scheduledNotificationId: scheduledNotification.id,
              scheduledFor,
            },
          });
        });

        counts.queued += 1;
      } catch (error) {
        if (isUniqueConstraintError(error)) {
          counts.skippedExisting += 1;
          continue;
        }
        logger.error('event_campaign_schedule_failed', {
          eventId: campaign.id,
          userId: user.id,
          phase,
          error,
        });
        throw error;
      }
    }
  }

  return {
    campaign,
    phases: phaseSchedule,
    audienceStats: audience.stats,
    counts,
  };
};

module.exports = {
  EventCampaignError,
  PHASES,
  createEventCampaign,
  updateEventCampaign,
  getActiveEventCampaigns,
  getEventCampaignDetailBySlug,
  getEventCampaignVendorsBySlug,
  getEventCampaignItemsBySlug,
  getAvailableEventCampaignsForVendor,
  upsertRestaurantEventParticipation,
  updateRestaurantEventParticipation,
  updateFoodEventConfig,
  listEventParticipants,
  updateEventParticipantStatus,
  getEventAudiencePreview,
  scheduleEventNotifications,
};
