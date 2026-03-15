class OrderItemResolutionError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = "OrderItemResolutionError";
    this.status = status;
  }
}

const createOrderItemResolutionHelpers = ({ prisma, resolveFoodCustomization }) => {
  const normalizeItemType = (itemType) => {
    if (!itemType) return null;
    const normalized = String(itemType).toLowerCase();
    if (normalized === "food") return "Food";
    if (normalized === "groceryitem" || normalized === "grocery") return "GroceryItem";
    if (normalized === "pharmacyitem" || normalized === "pharmacy") return "PharmacyItem";
    if (normalized === "grabmartitem" || normalized === "grabmart" || normalized === "convenience") {
      return "GrabMartItem";
    }
    return null;
  };

  const itemIdFromPayload = (item) =>
    item.food || item.groceryItem || item.pharmacyItem || item.grabMartItem || item.itemId || item.id;

  const resolveCatalogItem = async ({ payloadItemId, payloadType, quantity }) => {
    const lookupOrder = payloadType
      ? [payloadType]
      : ["Food", "GroceryItem", "PharmacyItem", "GrabMartItem"];

    for (const type of lookupOrder) {
      if (type === "Food") {
        const food = await prisma.food.findUnique({ where: { id: payloadItemId } });
        if (!food) continue;
        if (food.isAvailable !== true) {
          throw new OrderItemResolutionError(`${food.name || "This item"} is currently unavailable`);
        }
        return {
          itemType: "Food",
          orderType: "food",
          vendorId: food.restaurantId,
          price: food.price,
          name: food.name,
          image: food.foodImage,
          prepTimeMinutes: food.prepTimeMinutes,
          idField: "foodId",
          idValue: food.id,
          sourceItem: food,
        };
      }

      if (type === "GroceryItem") {
        const groceryItem = await prisma.groceryItem.findUnique({ where: { id: payloadItemId } });
        if (!groceryItem) continue;
        if (groceryItem.isAvailable !== true) {
          throw new OrderItemResolutionError(`${groceryItem.name || "This item"} is currently unavailable`);
        }
        if (Number.isFinite(groceryItem.stock) && quantity > groceryItem.stock) {
          throw new OrderItemResolutionError(`Not enough stock for ${groceryItem.name || "this item"}`);
        }
        return {
          itemType: "GroceryItem",
          orderType: "grocery",
          vendorId: groceryItem.storeId,
          price: groceryItem.price,
          name: groceryItem.name,
          image: groceryItem.thumbnailImage || null,
          prepTimeMinutes: groceryItem.prepTimeMinutes,
          idField: "groceryItemId",
          idValue: groceryItem.id,
        };
      }

      if (type === "PharmacyItem") {
        const pharmacyItem = await prisma.pharmacyItem.findUnique({ where: { id: payloadItemId } });
        if (!pharmacyItem) continue;
        if (pharmacyItem.isAvailable !== true) {
          throw new OrderItemResolutionError(`${pharmacyItem.name || "This item"} is currently unavailable`);
        }
        if (Number.isFinite(pharmacyItem.stock) && quantity > pharmacyItem.stock) {
          throw new OrderItemResolutionError(`Not enough stock for ${pharmacyItem.name || "this item"}`);
        }
        return {
          itemType: "PharmacyItem",
          orderType: "pharmacy",
          vendorId: pharmacyItem.storeId,
          price: pharmacyItem.price,
          name: pharmacyItem.name,
          image: pharmacyItem.image,
          prepTimeMinutes: pharmacyItem.prepTimeMinutes,
          idField: "pharmacyItemId",
          idValue: pharmacyItem.id,
        };
      }

      if (type === "GrabMartItem") {
        const grabMartItem = await prisma.grabMartItem.findUnique({ where: { id: payloadItemId } });
        if (!grabMartItem) continue;
        if (grabMartItem.isAvailable !== true) {
          throw new OrderItemResolutionError(`${grabMartItem.name || "This item"} is currently unavailable`);
        }
        if (Number.isFinite(grabMartItem.stock) && quantity > grabMartItem.stock) {
          throw new OrderItemResolutionError(`Not enough stock for ${grabMartItem.name || "this item"}`);
        }
        return {
          itemType: "GrabMartItem",
          orderType: "grabmart",
          vendorId: grabMartItem.storeId,
          price: grabMartItem.price,
          name: grabMartItem.name,
          image: grabMartItem.image,
          prepTimeMinutes: 0,
          idField: "grabMartItemId",
          idValue: grabMartItem.id,
        };
      }
    }

    throw new OrderItemResolutionError(`Item ${payloadItemId} not found`, 404);
  };

  const resolveOrderItemsForCreateOrder = async ({ items }) => {
    let subtotal = 0;
    let maxItemPrepMinutes = 0;
    const orderItemsData = [];
    let resolvedOrderType = null;
    let resolvedVendorId = null;

    for (const item of items) {
      const payloadItemId = itemIdFromPayload(item);
      const payloadType = normalizeItemType(item.itemType);
      const quantity = Number(item.quantity) || 1;

      if (!payloadItemId) {
        throw new OrderItemResolutionError("Each order item must include a valid item id");
      }

      if (quantity < 1) {
        throw new OrderItemResolutionError(`Invalid quantity for item ${payloadItemId}`);
      }

      const matchedItem = await resolveCatalogItem({
        payloadItemId,
        payloadType,
        quantity,
      });

      if (resolvedOrderType && resolvedOrderType !== matchedItem.orderType) {
        throw new OrderItemResolutionError("Orders can only contain items from one service type");
      }

      if (resolvedVendorId && resolvedVendorId !== matchedItem.vendorId) {
        throw new OrderItemResolutionError("Orders can only contain items from one store/restaurant");
      }

      resolvedOrderType = matchedItem.orderType;
      resolvedVendorId = matchedItem.vendorId;

      let itemCustomization = {
        selectedPortion: null,
        selectedPreferences: null,
        itemNote: null,
        customizationKey: null,
      };

      if (matchedItem.itemType === "Food") {
        try {
          const customization = resolveFoodCustomization({
            food: matchedItem.sourceItem,
            selectedPortionId: item.selectedPortionId,
            selectedPreferenceOptionIds: item.selectedPreferenceOptionIds,
            itemNote: item.itemNote,
            basePrice: matchedItem.price,
          });
          matchedItem.price = customization.unitPrice;
          itemCustomization = customization;
        } catch (error) {
          throw new OrderItemResolutionError(
            error?.message || "Invalid item customization"
          );
        }
      } else if (item.selectedPortionId || item.selectedPreferenceOptionIds || item.itemNote) {
        throw new OrderItemResolutionError("Item customizations are only supported for food items");
      }

      const itemTotal = matchedItem.price * quantity;
      subtotal += itemTotal;
      if (Number.isFinite(matchedItem.prepTimeMinutes) && matchedItem.prepTimeMinutes > maxItemPrepMinutes) {
        maxItemPrepMinutes = matchedItem.prepTimeMinutes;
      }

      const orderItemData = {
        itemType: matchedItem.itemType,
        name: matchedItem.name,
        quantity,
        price: matchedItem.price,
        image: matchedItem.image,
        selectedPortion: itemCustomization.selectedPortion,
        selectedPreferences:
          Array.isArray(itemCustomization.selectedPreferences) && itemCustomization.selectedPreferences.length > 0
            ? itemCustomization.selectedPreferences
            : null,
        itemNote: itemCustomization.itemNote,
        customizationKey: itemCustomization.customizationKey,
      };
      orderItemData[matchedItem.idField] = matchedItem.idValue;
      orderItemsData.push(orderItemData);
    }

    return {
      subtotal,
      maxItemPrepMinutes,
      orderItemsData,
      resolvedOrderType,
      resolvedVendorId,
    };
  };

  return {
    normalizeItemType,
    itemIdFromPayload,
    resolveOrderItemsForCreateOrder,
  };
};

module.exports = {
  OrderItemResolutionError,
  createOrderItemResolutionHelpers,
};
