const {
  resolveFoodCustomization,
  validateFoodCustomizationConfig,
} = require("../services/food_customization_service");

describe("food_customization_service", () => {
  it("enforces minSelections when selected options are below group minimum", () => {
    const food = {
      id: "food_1",
      price: 22,
      preferenceGroups: [
        {
          id: "protein",
          label: "Choose Protein",
          minSelections: 2,
          maxSelections: 3,
          options: [
            { id: "fish", label: "Fish", priceDelta: 6, isActive: true },
            { id: "beef", label: "Beef", priceDelta: 4, isActive: true },
            { id: "egg", label: "Egg", priceDelta: 2, isActive: true },
          ],
        },
      ],
    };

    expect(() =>
      resolveFoodCustomization({
        food,
        selectedPreferenceOptionIds: ["fish"],
      })
    ).toThrow("Please choose at least 2 option(s) for Choose Protein");
  });

  it("enforces implicit minimum of 1 when group is required", () => {
    const food = {
      id: "food_2",
      price: 20,
      preferenceGroups: [
        {
          id: "protein",
          label: "Protein",
          required: true,
          maxSelections: 1,
          options: [{ id: "fish", label: "Fish", priceDelta: 5, isActive: true }],
        },
      ],
    };

    expect(() =>
      resolveFoodCustomization({
        food,
        selectedPreferenceOptionIds: [],
      })
    ).toThrow("Please choose an option for Protein");
  });

  it("calculates final unit price using portion price and preference deltas", () => {
    const food = {
      id: "food_3",
      price: 20,
      portionOptions: [
        { id: "small", label: "Small", price: 20, isDefault: true, isActive: true },
        { id: "medium", label: "Medium", price: 28, isActive: true },
      ],
      preferenceGroups: [
        {
          id: "protein",
          label: "Protein",
          required: true,
          maxSelections: 1,
          options: [
            { id: "fish", label: "Fish", priceDelta: 6, isActive: true },
            { id: "chicken", label: "Chicken", priceDelta: 4, isActive: true },
          ],
        },
      ],
    };

    const result = resolveFoodCustomization({
      food,
      selectedPortionId: "medium",
      selectedPreferenceOptionIds: ["fish"],
    });

    expect(result.unitPrice).toBe(34);
    expect(result.selectedPortion).toMatchObject({
      id: "medium",
      label: "Medium",
      price: 28,
    });
    expect(result.selectedPreferences).toHaveLength(1);
    expect(result.selectedPreferences[0]).toMatchObject({
      groupId: "protein",
      optionId: "fish",
      optionLabel: "Fish",
      priceDelta: 6,
    });
  });

  it("rejects invalid preference config when minSelections exceeds maxSelections", () => {
    expect(() =>
      validateFoodCustomizationConfig({
        preferenceGroups: [
          {
            id: "protein",
            label: "Protein",
            minSelections: 2,
            maxSelections: 1,
            options: [{ id: "fish", label: "Fish", isActive: true }],
          },
        ],
      })
    ).toThrow("minSelections cannot exceed maxSelections");
  });

  it("rejects invalid portion config when multiple active options have no default", () => {
    expect(() =>
      validateFoodCustomizationConfig({
        portionOptions: [
          { id: "small", label: "Small", price: 20, isActive: true },
          { id: "medium", label: "Medium", price: 28, isActive: true },
        ],
      })
    ).toThrow("must define one default active option");
  });

  it("supports per-protein size pricing using selection token", () => {
    const food = {
      id: "food_4",
      price: 18,
      preferenceGroups: [
        {
          id: "protein",
          label: "Choose Protein",
          required: true,
          minSelections: 1,
          maxSelections: 1,
          options: [
            {
              id: "fish",
              label: "Fish",
              priceDelta: 2,
              isActive: true,
              sizeOptions: [
                { id: "small", label: "Small", priceDelta: 3, isActive: true },
                { id: "large", label: "Large", priceDelta: 7, isActive: true },
              ],
            },
          ],
        },
      ],
    };

    const result = resolveFoodCustomization({
      food,
      selectedPreferenceOptionIds: ["fish::large"],
    });

    expect(result.unitPrice).toBe(27);
    expect(result.selectedPreferences).toHaveLength(1);
    expect(result.selectedPreferences[0]).toMatchObject({
      optionId: "fish::large",
      optionBaseId: "fish",
      optionLabel: "Fish (Large)",
      sizeOptionId: "large",
      sizeOptionLabel: "Large",
      basePriceDelta: 2,
      sizePriceDelta: 7,
      priceDelta: 9,
    });
  });

  it("requires explicit size selection when multiple sizes exist with no default", () => {
    const food = {
      id: "food_5",
      price: 18,
      preferenceGroups: [
        {
          id: "protein",
          label: "Choose Protein",
          required: true,
          minSelections: 1,
          maxSelections: 1,
          options: [
            {
              id: "fish",
              label: "Fish",
              priceDelta: 0,
              isActive: true,
              sizeOptions: [
                { id: "small", label: "Small", priceDelta: 2, isActive: true },
                { id: "large", label: "Large", priceDelta: 5, isActive: true },
              ],
            },
          ],
        },
      ],
    };

    expect(() =>
      resolveFoodCustomization({
        food,
        selectedPreferenceOptionIds: ["fish"],
      })
    ).toThrow("Please choose a size for Fish");
  });

  it("accepts object-based selected preferences with sizeOptionId payloads", () => {
    const food = {
      id: "food_6",
      price: 18,
      preferenceGroups: [
        {
          id: "protein",
          label: "Choose Protein",
          required: true,
          minSelections: 1,
          maxSelections: 1,
          options: [
            {
              id: "goat",
              label: "Goat",
              priceDelta: 1,
              isActive: true,
              sizeOptions: [
                { id: "small", label: "Small", priceDelta: 2, isActive: true, isDefault: true },
                { id: "large", label: "Large", priceDelta: 4, isActive: true },
              ],
            },
          ],
        },
      ],
    };

    const result = resolveFoodCustomization({
      food,
      selectedPreferenceOptionIds: [{ optionId: "goat", sizeOptionId: "small" }],
    });

    expect(result.unitPrice).toBe(21);
    expect(result.selectedPreferences[0].optionId).toBe("goat::small");
  });
});
