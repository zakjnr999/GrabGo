jest.mock('../config/prisma', () => ({
  $transaction: jest.fn(),
  eventCampaign: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  promotionalBanner: {
    create: jest.fn(),
    update: jest.fn(),
  },
  restaurant: {
    findUnique: jest.fn(),
  },
  restaurantEventParticipation: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    upsert: jest.fn(),
    update: jest.fn(),
  },
  food: {
    findMany: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  user: {
    findMany: jest.fn(),
  },
  scheduledNotification: {
    create: jest.fn(),
  },
}));

jest.mock('../utils/food_helpers', () => ({
  FOOD_INCLUDE_RELATIONS: {
    category: { select: { id: true, name: true } },
    restaurant: { select: { id: true } },
  },
  formatFoodResponse: jest.fn(),
}));

jest.mock('../utils/vendor_card_formatter', () => ({
  formatRestaurantCard: jest.fn((restaurant) => ({
    ...restaurant,
    weightedRating: restaurant.rating,
    rating: restaurant.rating,
    restaurant_name: restaurant.restaurantName,
    distance: restaurant._distance ?? null,
    isOpen: restaurant.isOpen,
  })),
}));

jest.mock('../utils/vendor_distance_filter', () => ({
  validateLocationParams: jest.fn(),
  getBoundingBox: jest.fn(() => ({ minLat: 0, maxLat: 10, minLng: 0, maxLng: 10 })),
}));

jest.mock('../utils/distance', () => ({
  calculateDistance: jest.fn(),
}));

jest.mock('../utils/restaurant', () => ({
  isRestaurantOpen: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  createScopedLogger: jest.fn(() => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    log: jest.fn(),
  })),
}));

const prisma = require('../config/prisma');
const { formatFoodResponse } = require('../utils/food_helpers');
const { formatRestaurantCard } = require('../utils/vendor_card_formatter');
const { validateLocationParams } = require('../utils/vendor_distance_filter');
const { calculateDistance } = require('../utils/distance');
const { isRestaurantOpen } = require('../utils/restaurant');
const {
  EventCampaignError,
  createEventCampaign,
  updateEventCampaign,
  getActiveEventCampaigns,
  getEventCampaignVendorsBySlug,
  getEventCampaignItemsBySlug,
  getAvailableEventCampaignsForVendor,
  listEventParticipants,
  updateEventParticipantStatus,
  updateFoodEventConfig,
  scheduleEventNotifications,
} = require('../services/event_campaign_service');

describe('event_campaign_service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    validateLocationParams.mockReturnValue({
      userLatitude: 5.6,
      userLongitude: -0.2,
      maxDistanceKm: 15,
    });
    calculateDistance.mockReturnValue(2.4);
    isRestaurantOpen.mockImplementation((restaurant) => restaurant.isOpen !== false);
    formatFoodResponse.mockImplementation((foods) => foods);
    prisma.$transaction.mockImplementation(async (callback) => callback(prisma));
  });

  test('createEventCampaign creates a unique slug and linked promotional banner', async () => {
    prisma.eventCampaign.findFirst
      .mockResolvedValueOnce({ id: 'existing-campaign' })
      .mockResolvedValueOnce(null);
    prisma.promotionalBanner.create.mockResolvedValue({ id: 'banner-1' });
    prisma.eventCampaign.create.mockResolvedValue({
      id: 'event-1',
      name: 'Valentine Special',
      slug: 'valentine-special-2',
      promotionalBannerId: 'banner-1',
    });

    const result = await createEventCampaign({
      data: {
        name: 'Valentine Special',
        startsAt: '2026-02-10T00:00:00.000Z',
        endsAt: '2026-02-15T00:00:00.000Z',
        eventDate: '2026-02-14T00:00:00.000Z',
        bannerImageUrl: 'https://img.test/banner.png',
      },
      createdById: 'admin-1',
    });

    expect(prisma.promotionalBanner.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          targetUrl: '/events/valentine-special-2',
        }),
      }),
    );
    expect(prisma.eventCampaign.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          slug: 'valentine-special-2',
          promotionalBannerId: 'banner-1',
          createdById: 'admin-1',
        }),
      }),
    );
    expect(result.id).toBe('event-1');
  });

  test('createEventCampaign rejects eventDate outside the campaign window', async () => {
    await expect(
      createEventCampaign({
        data: {
          name: 'Valentine Special',
          startsAt: '2026-02-10T00:00:00.000Z',
          endsAt: '2026-02-15T00:00:00.000Z',
          eventDate: '2026-02-20T00:00:00.000Z',
        },
        createdById: 'admin-1',
      }),
    ).rejects.toMatchObject({
      code: 'EVENT_CAMPAIGN_EVENT_DATE_OUT_OF_RANGE',
      status: 400,
    });
  });

  test('updateEventCampaign disables banner link when event images are removed', async () => {
    prisma.eventCampaign.findUnique.mockResolvedValue({
      id: 'event-1',
      name: 'Valentine',
      slug: 'valentine',
      eventType: 'seasonal',
      description: null,
      startsAt: new Date('2026-02-10T00:00:00.000Z'),
      endsAt: new Date('2026-02-15T00:00:00.000Z'),
      eventDate: new Date('2026-02-14T00:00:00.000Z'),
      isActive: true,
      heroTitle: 'Valentine',
      heroSubtitle: null,
      heroImageUrl: 'https://img.test/hero.png',
      bannerImageUrl: 'https://img.test/banner.png',
      bannerBackgroundColor: '#fff',
      ctaLabel: 'View event',
      preEventNotifyDays: 3,
      preEventNotifyHour: 18,
      sameDayNotifyHour: 12,
      lastCallNotifyHour: 17,
      recentOrderLookbackDays: 30,
      orderWindowStartHour: null,
      orderWindowEndHour: null,
      promotionalBannerId: 'banner-1',
      createdById: 'admin-1',
      createdAt: new Date(),
      updatedAt: new Date(),
      promotionalBanner: {
        id: 'banner-1',
        title: 'Valentine',
      },
    });
    prisma.eventCampaign.findFirst.mockResolvedValue(null);
    prisma.promotionalBanner.update.mockResolvedValue({ id: 'banner-1' });
    prisma.eventCampaign.update.mockResolvedValue({
      id: 'event-1',
      promotionalBannerId: null,
    });

    const result = await updateEventCampaign({
      eventId: 'event-1',
      data: {
        bannerImageUrl: null,
        heroImageUrl: null,
      },
    });

    expect(prisma.promotionalBanner.update).toHaveBeenCalledWith({
      where: { id: 'banner-1' },
      data: expect.objectContaining({
        isActive: false,
        targetUrl: null,
      }),
      select: { id: true },
    });
    expect(prisma.eventCampaign.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          promotionalBannerId: null,
        }),
      }),
    );
    expect(result.id).toBe('event-1');
  });

  test('getActiveEventCampaigns returns active campaigns with derived counts', async () => {
    prisma.eventCampaign.findMany.mockResolvedValue([
      {
        id: 'event-1',
        name: 'Valentine',
        slug: 'valentine',
        eventDate: new Date('2026-02-14T00:00:00.000Z'),
        startsAt: new Date('2026-02-10T00:00:00.000Z'),
        endsAt: new Date('2099-02-15T00:00:00.000Z'),
        isActive: true,
        heroTitle: 'Valentine',
        heroSubtitle: null,
        heroImageUrl: null,
        bannerImageUrl: null,
        bannerBackgroundColor: '#fff',
        ctaLabel: 'View event',
        eventType: 'seasonal',
        description: null,
        preEventNotifyDays: 3,
        preEventNotifyHour: 18,
        sameDayNotifyHour: 12,
        lastCallNotifyHour: 17,
        recentOrderLookbackDays: 30,
        orderWindowStartHour: null,
        orderWindowEndHour: null,
        promotionalBannerId: null,
        createdById: null,
        createdAt: new Date('2026-02-01T00:00:00.000Z'),
        updatedAt: new Date('2026-02-01T00:00:00.000Z'),
        promotionalBanner: null,
      },
    ]);
    prisma.restaurantEventParticipation.findMany.mockResolvedValue([{ id: 'p1' }, { id: 'p2' }]);
    prisma.food.findMany.mockResolvedValue([{ id: 'f1' }, { id: 'f2' }, { id: 'f3' }]);

    const result = await getActiveEventCampaigns();

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      participatingRestaurantCount: 2,
      eventItemCount: 3,
      targetUrl: '/events/valentine',
    });
  });

  test('getEventCampaignVendorsBySlug filters closed restaurants without preorder and sorts featured first', async () => {
    prisma.eventCampaign.findUnique.mockResolvedValue({
      id: 'event-1',
      slug: 'valentine',
      name: 'Valentine',
      eventType: 'seasonal',
      description: null,
      startsAt: new Date('2026-02-10T00:00:00.000Z'),
      endsAt: new Date('2099-02-15T00:00:00.000Z'),
      eventDate: new Date('2099-02-14T00:00:00.000Z'),
      isActive: true,
      heroTitle: 'Valentine',
      heroSubtitle: null,
      heroImageUrl: null,
      bannerImageUrl: null,
      bannerBackgroundColor: '#fff',
      ctaLabel: 'View event',
      preEventNotifyDays: 3,
      preEventNotifyHour: 18,
      sameDayNotifyHour: 12,
      lastCallNotifyHour: 17,
      recentOrderLookbackDays: 30,
      orderWindowStartHour: null,
      orderWindowEndHour: null,
      promotionalBannerId: null,
      createdById: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      promotionalBanner: null,
    });

    prisma.restaurantEventParticipation.findMany.mockResolvedValue([
      {
        supportsPreorder: false,
        isFeatured: false,
        restaurant: {
          id: 'rest-closed',
          restaurantName: 'Closed Cafe',
          rating: 4.1,
          ratingCount: 10,
          totalReviews: 10,
          isOpen: false,
          latitude: 5.6,
          longitude: -0.2,
          deliveryFee: 5,
          minOrder: 20,
          averageDeliveryTime: 25,
          openingHours: [],
        },
      },
      {
        supportsPreorder: true,
        isFeatured: false,
        restaurant: {
          id: 'rest-preorder',
          restaurantName: 'Preorder Bistro',
          rating: 4.3,
          ratingCount: 9,
          totalReviews: 9,
          isOpen: false,
          latitude: 5.61,
          longitude: -0.21,
          deliveryFee: 7,
          minOrder: 25,
          averageDeliveryTime: 30,
          openingHours: [],
        },
      },
      {
        supportsPreorder: true,
        isFeatured: true,
        restaurant: {
          id: 'rest-featured',
          restaurantName: 'Featured Kitchen',
          rating: 4.9,
          ratingCount: 50,
          totalReviews: 50,
          isOpen: true,
          latitude: 5.62,
          longitude: -0.22,
          deliveryFee: 8,
          minOrder: 30,
          averageDeliveryTime: 20,
          openingHours: [],
        },
      },
    ]);

    const result = await getEventCampaignVendorsBySlug({
      slug: 'valentine',
      userLat: '5.6',
      userLng: '-0.2',
      limit: 10,
    });

    expect(result.vendors).toHaveLength(2);
    expect(result.vendors[0].id).toBe('rest-featured');
    expect(result.vendors[1].id).toBe('rest-preorder');
    expect(formatRestaurantCard).toHaveBeenCalledTimes(3);
  });

  test('getEventCampaignItemsBySlug sorts bundles first and excludes closed non-preorder restaurants', async () => {
    prisma.eventCampaign.findUnique.mockResolvedValue({
      id: 'event-1',
      slug: 'valentine',
      name: 'Valentine',
      eventType: 'seasonal',
      description: null,
      startsAt: new Date('2026-02-10T00:00:00.000Z'),
      endsAt: new Date('2099-02-15T00:00:00.000Z'),
      eventDate: new Date('2099-02-14T00:00:00.000Z'),
      isActive: true,
      heroTitle: 'Valentine',
      heroSubtitle: null,
      heroImageUrl: null,
      bannerImageUrl: null,
      bannerBackgroundColor: '#fff',
      ctaLabel: 'View event',
      preEventNotifyDays: 3,
      preEventNotifyHour: 18,
      sameDayNotifyHour: 12,
      lastCallNotifyHour: 17,
      recentOrderLookbackDays: 30,
      orderWindowStartHour: null,
      orderWindowEndHour: null,
      promotionalBannerId: null,
      createdById: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      promotionalBanner: null,
    });

    prisma.food.findMany.mockResolvedValue([{ id: 'bundle' }, { id: 'standard' }, { id: 'closed' }]);
    formatFoodResponse.mockReturnValue([
      {
        id: 'standard',
        name: 'Pasta',
        isEventBundle: false,
        discountPercentage: 10,
        rating: 4.2,
        weightedRating: 4.2,
        isRestaurantOpen: true,
        restaurant: {
          latitude: 5.61,
          longitude: -0.21,
          eventParticipations: [{ supportsPreorder: false }],
        },
      },
      {
        id: 'bundle',
        name: 'Dinner for Two',
        isEventBundle: true,
        discountPercentage: 5,
        rating: 4.1,
        weightedRating: 4.1,
        isRestaurantOpen: true,
        restaurant: {
          latitude: 5.6,
          longitude: -0.2,
          eventParticipations: [{ supportsPreorder: true }],
        },
      },
      {
        id: 'closed',
        name: 'Closed Dish',
        isEventBundle: false,
        discountPercentage: 25,
        rating: 5,
        weightedRating: 5,
        isRestaurantOpen: false,
        restaurant: {
          latitude: 5.6,
          longitude: -0.2,
          eventParticipations: [{ supportsPreorder: false }],
        },
      },
    ]);
    calculateDistance
      .mockReturnValueOnce(3.5)
      .mockReturnValueOnce(1.0)
      .mockReturnValueOnce(0.5);

    const result = await getEventCampaignItemsBySlug({
      slug: 'valentine',
      userLat: '5.6',
      userLng: '-0.2',
      limit: 10,
    });

    expect(result.items).toHaveLength(2);
    expect(result.items[0].id).toBe('bundle');
    expect(result.items[1].id).toBe('standard');
  });

  test('updateFoodEventConfig rejects tagging when vendor has not opted into campaign', async () => {
    prisma.restaurant.findUnique.mockResolvedValue({
      id: 'rest-1',
      email: 'vendor@test.com',
      restaurantName: 'Cafe Moka',
      status: 'approved',
      isDeleted: false,
    });
    prisma.food.findUnique.mockResolvedValue({
      id: 'food-1',
      restaurantId: 'rest-1',
      eventCampaignId: null,
      isEventItem: false,
      isEventBundle: false,
    });
    prisma.eventCampaign.findUnique.mockResolvedValue({
      id: 'event-1',
      isActive: true,
      endsAt: new Date('2099-02-14T00:00:00.000Z'),
    });
    prisma.restaurantEventParticipation.findUnique.mockResolvedValue(null);

    await expect(
      updateFoodEventConfig({
        user: { email: 'vendor@test.com' },
        foodId: 'food-1',
        data: { eventCampaignId: 'event-1', isEventItem: true },
      }),
    ).rejects.toMatchObject({
      code: 'EVENT_CAMPAIGN_PARTICIPATION_REQUIRED',
    });
  });

  test('getAvailableEventCampaignsForVendor attaches participation and derived status label', async () => {
    prisma.restaurant.findUnique.mockResolvedValue({
      id: 'rest-1',
      email: 'vendor@test.com',
      restaurantName: 'Cafe Moka',
      status: 'approved',
      isDeleted: false,
    });
    prisma.eventCampaign.findMany.mockResolvedValue([
      {
        id: 'event-upcoming',
        name: 'Valentine',
        slug: 'valentine',
        eventType: 'seasonal',
        description: null,
        startsAt: new Date('2099-02-10T00:00:00.000Z'),
        endsAt: new Date('2099-02-15T00:00:00.000Z'),
        eventDate: new Date('2099-02-14T00:00:00.000Z'),
        isActive: true,
        heroTitle: 'Valentine',
        heroSubtitle: null,
        heroImageUrl: null,
        bannerImageUrl: null,
        bannerBackgroundColor: '#fff',
        ctaLabel: 'View event',
        preEventNotifyDays: 3,
        preEventNotifyHour: 18,
        sameDayNotifyHour: 12,
        lastCallNotifyHour: 17,
        recentOrderLookbackDays: 30,
        orderWindowStartHour: null,
        orderWindowEndHour: null,
        promotionalBannerId: null,
        createdById: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        promotionalBanner: null,
        participations: [
          {
            id: 'part-1',
            status: 'pending',
            supportsPreorder: true,
            isApproved: false,
            isFeatured: false,
            isActive: true,
            optedInAt: new Date('2099-02-01T00:00:00.000Z'),
            approvedAt: null,
            rejectedAt: null,
          },
        ],
      },
    ]);

    const result = await getAvailableEventCampaignsForVendor({
      user: { email: 'vendor@test.com' },
    });

    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: 'event-upcoming',
      statusLabel: 'upcoming',
      participation: expect.objectContaining({
        id: 'part-1',
        status: 'pending',
        supportsPreorder: true,
      }),
    });
  });

  test('listEventParticipants throws when campaign does not exist', async () => {
    prisma.eventCampaign.findUnique.mockResolvedValue(null);

    await expect(listEventParticipants({ eventId: 'missing-event' })).rejects.toMatchObject({
      status: 404,
      code: 'EVENT_CAMPAIGN_NOT_FOUND',
    });
  });

  test('updateEventParticipantStatus approves participant and updates flags', async () => {
    prisma.restaurantEventParticipation.findUnique.mockResolvedValue({
      eventCampaignId: 'event-1',
      restaurantId: 'rest-1',
      status: 'pending',
      isApproved: false,
      isFeatured: false,
      supportsPreorder: false,
      isActive: true,
      restaurant: { id: 'rest-1', restaurantName: 'Cafe Moka' },
      eventCampaign: { id: 'event-1', name: 'Valentine', slug: 'valentine' },
    });
    prisma.restaurantEventParticipation.update.mockResolvedValue({
      eventCampaignId: 'event-1',
      restaurantId: 'rest-1',
      status: 'approved',
      isApproved: true,
      isFeatured: true,
      supportsPreorder: true,
      isActive: true,
    });

    const result = await updateEventParticipantStatus({
      eventId: 'event-1',
      restaurantId: 'rest-1',
      data: { action: 'approve', isFeatured: true, supportsPreorder: true },
    });

    expect(prisma.restaurantEventParticipation.update).toHaveBeenCalledWith({
      where: {
        eventCampaignId_restaurantId: {
          eventCampaignId: 'event-1',
          restaurantId: 'rest-1',
        },
      },
      data: expect.objectContaining({
        status: 'approved',
        isApproved: true,
        isFeatured: true,
        supportsPreorder: true,
        isActive: true,
      }),
      include: expect.any(Object),
    });
    expect(result.status).toBe('approved');
  });

  test('scheduleEventNotifications queues notifications and deduplicates repeated phases', async () => {
    prisma.eventCampaign.findUnique.mockResolvedValue({
      id: 'event-1',
      slug: 'valentine',
      name: 'Valentine',
      eventType: 'seasonal',
      description: null,
      startsAt: new Date('2099-02-10T00:00:00.000Z'),
      endsAt: new Date('2099-02-15T00:00:00.000Z'),
      eventDate: new Date('2099-02-14T00:00:00.000Z'),
      isActive: true,
      heroTitle: 'Valentine',
      heroSubtitle: null,
      heroImageUrl: null,
      bannerImageUrl: null,
      bannerBackgroundColor: '#fff',
      ctaLabel: 'View event',
      preEventNotifyDays: 3,
      preEventNotifyHour: 18,
      sameDayNotifyHour: 12,
      lastCallNotifyHour: 17,
      recentOrderLookbackDays: 30,
      orderWindowStartHour: null,
      orderWindowEndHour: null,
      promotionalBannerId: null,
      createdById: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      promotionalBanner: null,
    });
    prisma.restaurantEventParticipation.findMany.mockResolvedValue([
      {
        restaurant: {
          id: 'rest-1',
          restaurantName: 'Cafe Moka',
          latitude: 5.61,
          longitude: -0.21,
        },
      },
    ]);
    prisma.user.findMany.mockResolvedValue([
      {
        id: 'user-1',
        username: 'Ama',
        email: 'ama@test.com',
        lastOrderDate: new Date('2099-02-01T00:00:00.000Z'),
        addresses: [{ latitude: 5.6, longitude: -0.2, isDefault: true, formattedAddress: 'Accra' }],
        orders: [
          { orderDate: new Date('2099-02-01T18:00:00.000Z'), deliveryLatitude: 5.6, deliveryLongitude: -0.2 },
          { orderDate: new Date('2099-02-02T18:00:00.000Z'), deliveryLatitude: 5.6, deliveryLongitude: -0.2 },
          { orderDate: new Date('2099-02-03T18:00:00.000Z'), deliveryLatitude: 5.6, deliveryLongitude: -0.2 },
        ],
      },
    ]);

    const scheduledCreate = jest.fn().mockResolvedValue({ id: 'sched-1' });
    const dispatchCreate = jest
      .fn()
      .mockResolvedValueOnce({ id: 'dispatch-1' })
      .mockRejectedValueOnce({ code: 'P2002' })
      .mockResolvedValue({ id: 'dispatch-x' });
    prisma.$transaction.mockImplementation(async (callback) =>
      callback({
        scheduledNotification: { create: scheduledCreate },
        eventCampaignNotificationDispatch: { create: dispatchCreate },
      }),
    );

    const result = await scheduleEventNotifications({ eventId: 'event-1' });

    expect(result.counts.queued).toBe(2);
    expect(result.counts.skippedExisting).toBe(1);
    expect(scheduledCreate).toHaveBeenCalled();
  });
});
