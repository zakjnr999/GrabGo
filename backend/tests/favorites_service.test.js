jest.mock("../config/prisma", () => ({
  user: { findUnique: jest.fn() },
  restaurant: { findUnique: jest.fn(), findMany: jest.fn() },
  groceryStore: { findUnique: jest.fn(), findMany: jest.fn() },
  pharmacyStore: { findUnique: jest.fn(), findMany: jest.fn() },
  grabMartStore: { findUnique: jest.fn(), findMany: jest.fn() },
  food: { findUnique: jest.fn(), findMany: jest.fn() },
  groceryItem: { findUnique: jest.fn(), findMany: jest.fn() },
  pharmacyItem: { findUnique: jest.fn(), findMany: jest.fn() },
  grabMartItem: { findUnique: jest.fn(), findMany: jest.fn() },
  userFavoriteRestaurant: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoriteStore: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoritePharmacy: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoriteGrabMartStore: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoriteFood: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoriteGroceryItem: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoritePharmacyItem: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  userFavoriteGrabMartItem: { upsert: jest.fn(), deleteMany: jest.fn(), count: jest.fn() },
  $transaction: jest.fn(),
}));

const prisma = require("../config/prisma");
const {
  getUserFavorites,
  addFavoritePharmacy,
  addFavoriteGrabMartStore,
  addFavoritePharmacyItem,
  addFavoriteGrabMartItem,
  syncFavorites,
} = require("../services/favorites_service");

describe("favorites_service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("returns all vendor and item favorite domains", async () => {
    prisma.user.findUnique.mockResolvedValue({
      favoriteRestaurants: [{ addedAt: new Date("2026-01-01"), restaurant: { id: "r_1" } }],
      favoriteStores: [{ addedAt: new Date("2026-01-01"), store: { id: "gs_1" } }],
      favoritePharmacies: [{ addedAt: new Date("2026-01-01"), pharmacy: { id: "ps_1" } }],
      favoriteGrabMartStores: [{ addedAt: new Date("2026-01-01"), store: { id: "gm_s_1" } }],
      favoriteFoods: [{ addedAt: new Date("2026-01-01"), food: { id: "f_1" } }],
      favoriteGroceryItems: [{ addedAt: new Date("2026-01-01"), groceryItem: { id: "g_1" } }],
      favoritePharmacyItems: [{ addedAt: new Date("2026-01-01"), pharmacyItem: { id: "p_1" } }],
      favoriteGrabMartItems: [{ addedAt: new Date("2026-01-01"), grabMartItem: { id: "gm_1" } }],
    });

    const result = await getUserFavorites("user_1");

    expect(result.restaurants).toHaveLength(1);
    expect(result.groceryStores).toHaveLength(1);
    expect(result.pharmacies).toHaveLength(1);
    expect(result.grabMartStores).toHaveLength(1);
    expect(result.foodItems).toHaveLength(1);
    expect(result.groceryItems).toHaveLength(1);
    expect(result.pharmacyItems).toHaveLength(1);
    expect(result.grabMartItems).toHaveLength(1);
    expect(result.totalCount).toBe(8);
  });

  it("adds pharmacy and grabmart favorites with target validation", async () => {
    prisma.pharmacyStore.findUnique.mockResolvedValue({ id: "ps_1" });
    prisma.grabMartStore.findUnique.mockResolvedValue({ id: "gm_s_1" });
    prisma.pharmacyItem.findUnique.mockResolvedValue({ id: "p_1" });
    prisma.grabMartItem.findUnique.mockResolvedValue({ id: "gm_i_1" });
    prisma.user.findUnique.mockResolvedValue({
      favoriteRestaurants: [],
      favoriteStores: [],
      favoritePharmacies: [],
      favoriteGrabMartStores: [],
      favoriteFoods: [],
      favoriteGroceryItems: [],
      favoritePharmacyItems: [],
      favoriteGrabMartItems: [],
    });

    await addFavoritePharmacy("user_1", "ps_1");
    await addFavoriteGrabMartStore("user_1", "gm_s_1");
    await addFavoritePharmacyItem("user_1", "p_1");
    await addFavoriteGrabMartItem("user_1", "gm_i_1");

    expect(prisma.userFavoritePharmacy.upsert).toHaveBeenCalledWith({
      where: { userId_pharmacyId: { userId: "user_1", pharmacyId: "ps_1" } },
      update: {},
      create: { userId: "user_1", pharmacyId: "ps_1" },
    });
    expect(prisma.userFavoriteGrabMartStore.upsert).toHaveBeenCalledWith({
      where: { userId_storeId: { userId: "user_1", storeId: "gm_s_1" } },
      update: {},
      create: { userId: "user_1", storeId: "gm_s_1" },
    });
    expect(prisma.userFavoritePharmacyItem.upsert).toHaveBeenCalledWith({
      where: { userId_pharmacyItemId: { userId: "user_1", pharmacyItemId: "p_1" } },
      update: {},
      create: { userId: "user_1", pharmacyItemId: "p_1" },
    });
    expect(prisma.userFavoriteGrabMartItem.upsert).toHaveBeenCalledWith({
      where: { userId_grabMartItemId: { userId: "user_1", grabMartItemId: "gm_i_1" } },
      update: {},
      create: { userId: "user_1", grabMartItemId: "gm_i_1" },
    });
  });

  it("syncs all service domains and deduplicates IDs", async () => {
    prisma.restaurant.findMany.mockResolvedValue([{ id: "r_1" }]);
    prisma.groceryStore.findMany.mockResolvedValue([{ id: "gs_1" }]);
    prisma.pharmacyStore.findMany.mockResolvedValue([{ id: "ps_1" }]);
    prisma.grabMartStore.findMany.mockResolvedValue([{ id: "gms_1" }]);
    prisma.food.findMany.mockResolvedValue([{ id: "f_1" }]);
    prisma.groceryItem.findMany.mockResolvedValue([{ id: "gi_1" }]);
    prisma.pharmacyItem.findMany.mockResolvedValue([{ id: "pi_1" }]);
    prisma.grabMartItem.findMany.mockResolvedValue([{ id: "gmi_1" }]);
    prisma.$transaction.mockResolvedValue([]);
    prisma.user.findUnique.mockResolvedValue({
      favoriteRestaurants: [],
      favoriteStores: [],
      favoritePharmacies: [],
      favoriteGrabMartStores: [],
      favoriteFoods: [],
      favoriteGroceryItems: [],
      favoritePharmacyItems: [],
      favoriteGrabMartItems: [],
    });

    await syncFavorites("user_1", {
      restaurants: ["r_1", "r_1"],
      stores: ["gs_1"],
      pharmacies: ["ps_1"],
      grabMartStores: ["gms_1"],
      foodItems: ["f_1", "f_1"],
      groceryItems: ["gi_1"],
      pharmacyItems: ["pi_1"],
      grabMartItems: ["gmi_1"],
    });

    expect(prisma.$transaction).toHaveBeenCalled();
    const transactionCalls = prisma.$transaction.mock.calls[0][0];
    expect(transactionCalls).toHaveLength(8);
  });
});
