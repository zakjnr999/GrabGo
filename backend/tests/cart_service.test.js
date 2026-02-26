jest.mock("../config/prisma", () => ({
  cart: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
  },
  cartItem: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    deleteMany: jest.fn(),
    create: jest.fn(),
  },
  food: { findUnique: jest.fn() },
  groceryItem: { findUnique: jest.fn() },
  pharmacyItem: { findUnique: jest.fn() },
  grabMartItem: { findUnique: jest.fn() },
  restaurant: { findUnique: jest.fn() },
  groceryStore: { findUnique: jest.fn() },
  pharmacyStore: { findUnique: jest.fn() },
  grabMartStore: { findUnique: jest.fn() },
}));

jest.mock("../utils/restaurant", () => ({
  isRestaurantOpen: jest.fn(() => true),
}));

jest.mock("../utils/scheduled_orders", () => ({
  isVendorAcceptingScheduledOrders: jest.fn(() => true),
}));

const prisma = require("../config/prisma");
const featureFlags = require("../config/feature_flags");
const {
  addToCart,
  updateCartItem,
  removeFromCart,
  clearCart,
  getUserCart,
} = require("../services/cart_service");

describe("cart_service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    featureFlags.isMixedCartEnabled = false;
  });

  it("updates quantity using cart item ownership, not first cart", async () => {
    prisma.cartItem.findFirst.mockResolvedValue({
      id: "cart_item_2",
      cartId: "cart_b",
    });
    prisma.cartItem.update.mockResolvedValue({ id: "cart_item_2", quantity: 3 });
    prisma.cartItem.findMany.mockResolvedValue([{ quantity: 3, price: 10 }]);
    prisma.cart.update.mockResolvedValue({ id: "cart_b" });
    prisma.cart.findUnique.mockResolvedValue({ id: "cart_b", items: [] });

    const result = await updateCartItem(
      "user_1",
      "cart_item_2",
      3,
      "delivery"
    );

    expect(prisma.cartItem.findFirst).toHaveBeenCalledWith({
      where: {
        id: "cart_item_2",
        cart: {
          userId: "user_1",
          isActive: true,
          fulfillmentMode: "delivery",
        },
      },
      select: { id: true, cartId: true },
    });
    expect(prisma.cartItem.update).toHaveBeenCalledWith({
      where: { id: "cart_item_2" },
      data: { quantity: 3 },
    });
    expect(prisma.cart.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "cart_b" },
        data: expect.objectContaining({
          itemCount: 3,
          totalAmount: 30,
        }),
      })
    );
    expect(prisma.cart.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: "cart_b" } })
    );
    expect(result.id).toBe("cart_b");
  });

  it("throws item-not-found when update target does not belong to user/mode", async () => {
    prisma.cartItem.findFirst.mockResolvedValue(null);

    await expect(
      updateCartItem("user_1", "missing_item", 2, "pickup")
    ).rejects.toThrow("Item not found in cart");

    expect(prisma.cartItem.update).not.toHaveBeenCalled();
    expect(prisma.cart.update).not.toHaveBeenCalled();
  });

  it("removes item by owned cart item id and refreshes cart aggregates", async () => {
    prisma.cartItem.findFirst.mockResolvedValue({
      id: "cart_item_9",
      cartId: "cart_pickup_1",
    });
    prisma.cartItem.delete.mockResolvedValue({ id: "cart_item_9" });
    prisma.cartItem.findMany.mockResolvedValue([]);
    prisma.cart.update.mockResolvedValue({ id: "cart_pickup_1" });
    prisma.cart.findUnique.mockResolvedValue({ id: "cart_pickup_1", items: [] });

    const result = await removeFromCart("user_9", "cart_item_9", "pickup");

    expect(prisma.cartItem.findFirst).toHaveBeenCalledWith({
      where: {
        id: "cart_item_9",
        cart: {
          userId: "user_9",
          isActive: true,
          fulfillmentMode: "pickup",
        },
      },
      select: { id: true, cartId: true },
    });
    expect(prisma.cartItem.delete).toHaveBeenCalledWith({
      where: { id: "cart_item_9" },
    });
    expect(prisma.cart.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "cart_pickup_1" },
        data: expect.objectContaining({
          itemCount: 0,
          totalAmount: 0,
          restaurantId: null,
          groceryStoreId: null,
          pharmacyStoreId: null,
          grabMartStoreId: null,
        }),
      })
    );
    expect(result.id).toBe("cart_pickup_1");
  });

  it("clears all active carts for the fulfillment mode", async () => {
    prisma.cart.findMany.mockResolvedValue([{ id: "cart_1" }, { id: "cart_2" }]);
    prisma.cartItem.deleteMany.mockResolvedValue({ count: 4 });
    prisma.cart.updateMany.mockResolvedValue({ count: 2 });
    prisma.cart.findUnique.mockResolvedValue({ id: "cart_1", items: [] });

    const result = await clearCart("user_10", "delivery");

    expect(prisma.cart.findMany).toHaveBeenCalledWith({
      where: { userId: "user_10", isActive: true, fulfillmentMode: "delivery" },
      select: { id: true },
      orderBy: { lastUpdatedAt: "desc" },
    });
    expect(prisma.cartItem.deleteMany).toHaveBeenCalledWith({
      where: { cartId: { in: ["cart_1", "cart_2"] } },
    });
    expect(prisma.cart.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: { in: ["cart_1", "cart_2"] } },
        data: expect.objectContaining({
          itemCount: 0,
          totalAmount: 0,
        }),
      })
    );
    expect(prisma.cart.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: "cart_1" } })
    );
    expect(result.id).toBe("cart_1");
  });

  it("returns most relevant cart when cartType is not specified", async () => {
    prisma.cart.findMany.mockResolvedValue([
      {
        id: "cart_empty",
        cartType: "food",
        items: [],
      },
      {
        id: "cart_with_items",
        cartType: "grocery",
        items: [
          {
            id: "ci_1",
            itemType: "GroceryItem",
            groceryItem: { id: "g_1", store: { id: "store_1" } },
          },
        ],
      },
    ]);

    const cart = await getUserCart("user_77", null, "delivery");
    expect(prisma.cart.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user_77",
          isActive: true,
          fulfillmentMode: "delivery",
        },
      })
    );
    expect(prisma.cart.findFirst).not.toHaveBeenCalled();
    expect(cart.id).toBe("cart_with_items");
  });

  it("uses cartType filter path when cartType is provided", async () => {
    prisma.cart.findFirst.mockResolvedValue({
      id: "food_cart_1",
      cartType: "food",
      items: [],
    });

    const cart = await getUserCart("user_88", "food", "pickup");

    expect(prisma.cart.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user_88",
          isActive: true,
          fulfillmentMode: "pickup",
          cartType: "food",
        },
      })
    );
    expect(prisma.cart.findMany).not.toHaveBeenCalled();
    expect(cart.id).toBe("food_cart_1");
  });

  it("scopes carts by vendor when mixed cart is enabled", async () => {
    featureFlags.isMixedCartEnabled = true;

    prisma.food.findUnique.mockResolvedValue({
      id: "food_1",
      name: "Waakye",
      price: 12.5,
      foodImage: "waakye.jpg",
      isAvailable: true,
      restaurantId: "rest_2",
    });
    prisma.restaurant.findUnique.mockResolvedValue({
      id: "rest_2",
      status: "approved",
      isDeleted: false,
      isAcceptingOrders: true,
    });
    prisma.cart.findFirst.mockResolvedValue({
      id: "cart_food_rest_2",
      userId: "user_2",
      cartType: "food",
      fulfillmentMode: "delivery",
      providerScopeKey: "food:rest_2",
      restaurantId: "rest_2",
      items: [],
    });
    prisma.cart.update.mockResolvedValue({ id: "cart_food_rest_2" });
    prisma.cart.findUnique.mockResolvedValue({
      id: "cart_food_rest_2",
      items: [],
    });
    prisma.cartItem.create.mockResolvedValue({ id: "cart_item_1" });
    prisma.cartItem.findMany.mockResolvedValue([{ quantity: 1, price: 12.5 }]);

    const result = await addToCart("user_2", {
      itemId: "food_1",
      itemType: "Food",
      quantity: 1,
      restaurantId: "rest_2",
      fulfillmentMode: "delivery",
    });

    expect(prisma.cart.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: "user_2",
          cartType: "food",
          fulfillmentMode: "delivery",
          providerScopeKey: "food:rest_2",
        }),
      })
    );
    expect(prisma.cartItem.deleteMany).not.toHaveBeenCalled();
    expect(prisma.cart.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "cart_food_rest_2" },
        data: expect.objectContaining({
          restaurantId: "rest_2",
          providerScopeKey: "food:rest_2",
        }),
      })
    );
    expect(result.id).toBe("cart_food_rest_2");
  });
});
