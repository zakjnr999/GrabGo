const {
  OrderItemResolutionError,
  createOrderItemResolutionHelpers,
} = require("../routes/support/order_item_resolution_helpers");

describe("order_item_resolution_helpers", () => {
  let prisma;
  let resolveFoodCustomization;
  let helpers;

  beforeEach(() => {
    prisma = {
      food: { findUnique: jest.fn() },
      groceryItem: { findUnique: jest.fn() },
      pharmacyItem: { findUnique: jest.fn() },
      grabMartItem: { findUnique: jest.fn() },
    };
    resolveFoodCustomization = jest.fn();
    helpers = createOrderItemResolutionHelpers({ prisma, resolveFoodCustomization });
  });

  it("resolves a food item with customization into order items data", async () => {
    prisma.food.findUnique.mockResolvedValue({
      id: "food-1",
      isAvailable: true,
      restaurantId: "rest-1",
      price: 20,
      name: "Jollof Rice",
      foodImage: "food.jpg",
      prepTimeMinutes: 18,
    });
    resolveFoodCustomization.mockReturnValue({
      unitPrice: 24,
      selectedPortion: { id: "portion-1", name: "Large" },
      selectedPreferences: [{ id: "pref-1", name: "Extra Chicken" }],
      itemNote: "Less spicy",
      customizationKey: "food-1:portion-1:pref-1",
    });

    const result = await helpers.resolveOrderItemsForCreateOrder({
      items: [
        {
          food: "food-1",
          itemType: "food",
          quantity: 2,
          selectedPortionId: "portion-1",
          selectedPreferenceOptionIds: ["pref-1"],
          itemNote: "Less spicy",
        },
      ],
    });

    expect(result.subtotal).toBe(48);
    expect(result.maxItemPrepMinutes).toBe(18);
    expect(result.resolvedOrderType).toBe("food");
    expect(result.resolvedVendorId).toBe("rest-1");
    expect(result.orderItemsData).toEqual([
      expect.objectContaining({
        itemType: "Food",
        foodId: "food-1",
        quantity: 2,
        price: 24,
        selectedPortion: { id: "portion-1", name: "Large" },
        selectedPreferences: [{ id: "pref-1", name: "Extra Chicken" }],
        itemNote: "Less spicy",
        customizationKey: "food-1:portion-1:pref-1",
      }),
    ]);
  });

  it("rejects mixed service types", async () => {
    prisma.food.findUnique.mockResolvedValue({
      id: "food-1",
      isAvailable: true,
      restaurantId: "rest-1",
      price: 20,
      name: "Jollof Rice",
      foodImage: "food.jpg",
      prepTimeMinutes: 18,
    });
    prisma.groceryItem.findUnique.mockResolvedValue({
      id: "grocery-1",
      isAvailable: true,
      storeId: "store-1",
      price: 8,
      name: "Milk",
      thumbnailImage: "milk.jpg",
      prepTimeMinutes: 5,
      stock: 10,
    });
    resolveFoodCustomization.mockReturnValue({
      unitPrice: 20,
      selectedPortion: null,
      selectedPreferences: null,
      itemNote: null,
      customizationKey: null,
    });

    await expect(
      helpers.resolveOrderItemsForCreateOrder({
        items: [
          { food: "food-1", itemType: "food", quantity: 1 },
          { groceryItem: "grocery-1", itemType: "grocery", quantity: 1 },
        ],
      })
    ).rejects.toMatchObject({
      name: "OrderItemResolutionError",
      message: "Orders can only contain items from one service type",
      status: 400,
    });
  });

  it("rejects non-food customizations", async () => {
    prisma.groceryItem.findUnique.mockResolvedValue({
      id: "grocery-1",
      isAvailable: true,
      storeId: "store-1",
      price: 8,
      name: "Milk",
      thumbnailImage: "milk.jpg",
      prepTimeMinutes: 5,
      stock: 10,
    });

    await expect(
      helpers.resolveOrderItemsForCreateOrder({
        items: [
          {
            groceryItem: "grocery-1",
            itemType: "grocery",
            quantity: 1,
            itemNote: "Cold please",
          },
        ],
      })
    ).rejects.toMatchObject({
      name: "OrderItemResolutionError",
      message: "Item customizations are only supported for food items",
      status: 400,
    });
  });

  it("returns a 404 error when the item cannot be found", async () => {
    prisma.food.findUnique.mockResolvedValue(null);
    prisma.groceryItem.findUnique.mockResolvedValue(null);
    prisma.pharmacyItem.findUnique.mockResolvedValue(null);
    prisma.grabMartItem.findUnique.mockResolvedValue(null);

    await expect(
      helpers.resolveOrderItemsForCreateOrder({
        items: [{ id: "missing-item", quantity: 1 }],
      })
    ).rejects.toEqual(
      expect.objectContaining({
        name: "OrderItemResolutionError",
        message: "Item missing-item not found",
        status: 404,
      })
    );
  });

  it("surfaces customization errors as typed resolution errors", async () => {
    prisma.food.findUnique.mockResolvedValue({
      id: "food-1",
      isAvailable: true,
      restaurantId: "rest-1",
      price: 20,
      name: "Jollof Rice",
      foodImage: "food.jpg",
      prepTimeMinutes: 18,
    });
    resolveFoodCustomization.mockImplementation(() => {
      throw new Error("Portion not found");
    });

    await expect(
      helpers.resolveOrderItemsForCreateOrder({
        items: [{ food: "food-1", itemType: "food", quantity: 1, selectedPortionId: "missing" }],
      })
    ).rejects.toEqual(
      expect.objectContaining({
        name: "OrderItemResolutionError",
        message: "Portion not found",
        status: 400,
      })
    );
  });

  it("exports a typed error class", () => {
    const error = new OrderItemResolutionError("Bad item", 422);
    expect(error).toBeInstanceOf(Error);
    expect(error.status).toBe(422);
    expect(error.name).toBe("OrderItemResolutionError");
  });
});
