const MAX_ITEM_NOTE_LENGTH = 200;
const MAX_SELECTIONS_PER_GROUP = 99;
const PREFERENCE_SELECTION_DELIMITER = '::';

const normalizeText = (value) => {
  if (value === null || value === undefined) return '';
  return String(value).trim();
};

const normalizeId = (value) => {
  const text = normalizeText(value);
  return text.length > 0 ? text : null;
};

const toSafeNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const toSafeInt = (value, fallback = 0) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const parseJsonIfString = (value) => {
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    return value;
  }
};

const asArray = (value) => {
  const parsed = parseJsonIfString(value);
  if (Array.isArray(parsed)) return parsed;
  if (parsed === null || parsed === undefined) return [];
  return [parsed];
};

const buildPreferenceSelectionToken = (optionId, sizeOptionId = null) => {
  const normalizedOptionId = normalizeId(optionId);
  if (!normalizedOptionId) return null;

  const normalizedSizeId = normalizeId(sizeOptionId);
  if (!normalizedSizeId) return normalizedOptionId;

  return `${normalizedOptionId}${PREFERENCE_SELECTION_DELIMITER}${normalizedSizeId}`;
};

const parseSelectedPreferenceToken = (token) => {
  const normalizedToken = normalizeId(token);
  if (!normalizedToken) return null;

  const delimiterIndex = normalizedToken.indexOf(PREFERENCE_SELECTION_DELIMITER);
  if (delimiterIndex <= 0) {
    return {
      rawToken: normalizedToken,
      optionId: normalizedToken,
      sizeOptionId: null,
    };
  }

  const optionId = normalizeId(normalizedToken.slice(0, delimiterIndex));
  const sizeOptionId = normalizeId(
    normalizedToken.slice(delimiterIndex + PREFERENCE_SELECTION_DELIMITER.length)
  );
  if (!optionId) return null;

  return {
    rawToken: normalizedToken,
    optionId,
    sizeOptionId,
  };
};

const normalizeSelectedPreferenceOptionIds = (value) => {
  const parsed = parseJsonIfString(value);
  const collected = [];

  const collectSelectionTokens = (entry) => {
    if (entry === null || entry === undefined) return;

    if (Array.isArray(entry)) {
      entry.forEach((item) => collectSelectionTokens(item));
      return;
    }

    if (typeof entry === 'object') {
      const optionId = normalizeId(
        entry.optionId ?? entry.id ?? entry.option ?? entry.value
      );
      if (optionId) {
        const sizeOptionId = normalizeId(
          entry.sizeOptionId ?? entry.sizeId ?? entry.tierId ?? entry.variantId
        );
        const token = buildPreferenceSelectionToken(optionId, sizeOptionId);
        if (token) {
          collected.push(token);
        }
        return;
      }

      Object.values(entry).forEach((item) => collectSelectionTokens(item));
      return;
    }

    const id = normalizeId(entry);
    if (id) {
      collected.push(id);
    }
  };

  collectSelectionTokens(parsed);
  return [...new Set(collected)];
};

const normalizePreferenceSizeOptions = (sizeOptions, { strict = false, optionId } = {}) => {
  const seenIds = new Set();

  const normalized = asArray(sizeOptions)
    .map((sizeOption) => {
      if (!sizeOption || typeof sizeOption !== 'object') return null;

      const id = normalizeId(sizeOption.id || sizeOption.code || sizeOption.value);
      if (!id) return null;
      if (seenIds.has(id)) {
        if (strict) {
          throw new Error(`size options for '${optionId}' contain duplicate id '${id}'`);
        }
        return null;
      }
      seenIds.add(id);

      const label = normalizeText(sizeOption.label || sizeOption.name || sizeOption.title || id) || id;
      const isActive = sizeOption.isActive !== false;
      const priceDelta = toSafeNumber(sizeOption.priceDelta ?? sizeOption.additionalPrice ?? sizeOption.price, 0);

      return {
        id,
        label,
        isActive,
        isDefault: sizeOption.isDefault === true,
        priceDelta,
      };
    })
    .filter(Boolean);

  if (strict && normalized.length > 0) {
    const activeOptions = normalized.filter((entry) => entry.isActive);
    const activeDefaultCount = activeOptions.filter((entry) => entry.isDefault).length;

    if (activeOptions.length === 0) {
      throw new Error(`size options for '${optionId}' must include at least one active option`);
    }
    if (activeDefaultCount > 1) {
      throw new Error(`size options for '${optionId}' can only have one default active option`);
    }
  }

  return normalized;
};

const normalizePortionOptions = (portionOptions, { strict = false } = {}) => {
  const seenIds = new Set();

  const normalized = asArray(portionOptions)
    .map((option) => {
      if (!option || typeof option !== 'object') return null;

      const id = normalizeId(option.id || option.code || option.value);
      if (!id) return null;
      if (seenIds.has(id)) {
        if (strict) {
          throw new Error(`portionOptions contains duplicate option id '${id}'`);
        }
        return null;
      }
      seenIds.add(id);

      const label = normalizeText(option.label || option.name || option.title || id);
      const quantityLabel = normalizeText(option.quantityLabel || option.quantity || option.size || '');
      const isActive = option.isActive !== false;

      let resolvedPrice = null;
      if (option.price !== undefined && option.price !== null && option.price !== '') {
        resolvedPrice = toSafeNumber(option.price, null);
      }

      const priceDelta = toSafeNumber(option.priceDelta ?? option.additionalPrice, 0);

      return {
        id,
        label: label || id,
        quantityLabel: quantityLabel || null,
        isActive,
        isDefault: option.isDefault === true,
        price: resolvedPrice,
        priceDelta,
      };
    })
    .filter(Boolean);

  if (strict && normalized.length > 0) {
    const activeOptions = normalized.filter((entry) => entry.isActive);
    const activeDefaultCount = activeOptions.filter((entry) => entry.isDefault).length;

    if (activeOptions.length === 0) {
      throw new Error('portionOptions must include at least one active option');
    }
    if (activeDefaultCount > 1) {
      throw new Error('portionOptions can only have one default active option');
    }
    if (activeOptions.length > 1 && activeDefaultCount === 0) {
      throw new Error('portionOptions must define one default active option when multiple options are active');
    }
  }

  return normalized;
};

const normalizePreferenceGroups = (preferenceGroups, { strict = false } = {}) => {
  const seenGroupIds = new Set();

  return asArray(preferenceGroups)
    .map((group) => {
      if (!group || typeof group !== 'object') return null;

      const groupId = normalizeId(group.id || group.code || group.key);
      if (!groupId) return null;
      if (seenGroupIds.has(groupId)) {
        if (strict) {
          throw new Error(`preferenceGroups contains duplicate group id '${groupId}'`);
        }
        return null;
      }
      seenGroupIds.add(groupId);

      const groupLabel = normalizeText(group.label || group.name || group.title || groupId) || groupId;
      const required = group.required === true;
      const maxSelectionsInput = toSafeInt(group.maxSelections, group.multiSelect ? MAX_SELECTIONS_PER_GROUP : 1);
      let maxSelections = Math.max(1, Math.min(MAX_SELECTIONS_PER_GROUP, maxSelectionsInput));

      const hasExplicitMin = group.minSelections !== undefined && group.minSelections !== null && group.minSelections !== '';
      const defaultMin = required ? 1 : 0;
      const minSelectionsInput = toSafeInt(group.minSelections, defaultMin);
      let minSelections = Math.max(0, Math.min(MAX_SELECTIONS_PER_GROUP, minSelectionsInput));
      if (required && minSelections === 0) {
        minSelections = 1;
      }

      const seenOptionIds = new Set();
      const options = asArray(group.options)
        .map((option) => {
          if (!option || typeof option !== 'object') return null;
          const id = normalizeId(option.id || option.code || option.value);
          if (!id) return null;
          if (seenOptionIds.has(id)) {
            if (strict) {
              throw new Error(`preferenceGroups.${groupId} contains duplicate option id '${id}'`);
            }
            return null;
          }
          seenOptionIds.add(id);
          const label = normalizeText(option.label || option.name || option.title || id) || id;
          const isActive = option.isActive !== false;
          const priceDelta = toSafeNumber(option.priceDelta ?? option.additionalPrice ?? option.price, 0);
          const sizeOptions = normalizePreferenceSizeOptions(
            option.sizeOptions ?? option.sizes ?? option.priceTiers ?? option.variants,
            { strict, optionId: id }
          );

          return {
            id,
            label,
            isActive,
            isDefault: option.isDefault === true,
            priceDelta,
            sizeOptions,
          };
        })
        .filter(Boolean);

      const activeOptionCount = options.filter((option) => option.isActive).length;

      if (strict) {
        if (options.length === 0) {
          throw new Error(`preferenceGroups.${groupId} must include at least one option`);
        }
        if (activeOptionCount === 0) {
          throw new Error(`preferenceGroups.${groupId} must include at least one active option`);
        }
        if (minSelections > maxSelections) {
          throw new Error(`preferenceGroups.${groupId} minSelections cannot exceed maxSelections`);
        }
        if (minSelections > activeOptionCount) {
          throw new Error(`preferenceGroups.${groupId} minSelections cannot exceed active options`);
        }
      } else {
        if (activeOptionCount === 0) {
          return null;
        }
        if (minSelections > maxSelections) {
          minSelections = maxSelections;
        }
        if (minSelections > activeOptionCount) {
          minSelections = activeOptionCount;
        }
      }

      return {
        id: groupId,
        label: groupLabel,
        required,
        minSelections: hasExplicitMin || required ? minSelections : 0,
        maxSelections,
        options,
      };
    })
    .filter(Boolean);
};

const normalizeItemNote = (itemNote) => {
  const normalized = normalizeText(itemNote);
  if (!normalized) return null;
  return normalized.substring(0, MAX_ITEM_NOTE_LENGTH);
};

const buildCustomizationKey = ({ foodId, portionId, preferenceOptionIds = [], itemNote }) => {
  const normalizedPreferenceIds = [...new Set(preferenceOptionIds.map((id) => normalizeText(id)).filter(Boolean))].sort();
  const normalizedNote = normalizeText(itemNote).replace(/\s+/g, ' ').toLowerCase();

  const hasCustomization = Boolean(portionId) || normalizedPreferenceIds.length > 0 || normalizedNote.length > 0;
  if (!hasCustomization) return null;

  return [
    `food:${normalizeText(foodId)}`,
    `portion:${portionId || '-'}`,
    `prefs:${normalizedPreferenceIds.join(',') || '-'}`,
    `note:${normalizedNote || '-'}`,
  ].join('|');
};

const resolveFoodCustomization = ({
  food,
  selectedPortionId,
  selectedPreferenceOptionIds,
  itemNote,
  basePrice,
}) => {
  const portionOptions = normalizePortionOptions(food?.portionOptions, { strict: false });
  const preferenceGroups = normalizePreferenceGroups(food?.preferenceGroups, { strict: false });

  const normalizedPortionId = normalizeId(selectedPortionId);
  const normalizedPreferenceSelections = normalizeSelectedPreferenceOptionIds(selectedPreferenceOptionIds)
    .map((entry) => parseSelectedPreferenceToken(entry))
    .filter(Boolean);
  const normalizedNote = normalizeItemNote(itemNote);

  const resolvedBasePrice = toSafeNumber(basePrice ?? food?.price, 0);

  let selectedPortion = null;
  let priceAfterPortion = resolvedBasePrice;

  if (portionOptions.length > 0) {
    let chosen = null;

    if (normalizedPortionId) {
      chosen = portionOptions.find((option) => option.id === normalizedPortionId && option.isActive);
      if (!chosen) {
        throw new Error('Selected portion is invalid for this item');
      }
    } else {
      chosen = portionOptions.find((option) => option.isDefault && option.isActive)
        || (portionOptions.length === 1 && portionOptions[0].isActive ? portionOptions[0] : null);
      if (!chosen) {
        throw new Error('Please select a portion size');
      }
    }

    const optionPrice = Number.isFinite(chosen.price) ? chosen.price : (resolvedBasePrice + chosen.priceDelta);
    priceAfterPortion = toSafeNumber(optionPrice, resolvedBasePrice);

    selectedPortion = {
      id: chosen.id,
      label: chosen.label,
      quantityLabel: chosen.quantityLabel,
      price: priceAfterPortion,
      priceDelta: chosen.priceDelta,
    };
  } else if (normalizedPortionId) {
    throw new Error('This item does not support portion selection');
  }

  const optionById = new Map();
  const groupById = new Map();
  preferenceGroups.forEach((group) => {
    groupById.set(group.id, group);
    group.options.forEach((option) => {
      optionById.set(option.id, { ...option, groupId: group.id, groupLabel: group.label });
    });
  });

  const selectedEntries = normalizedPreferenceSelections.map((selection) => {
    const option = optionById.get(selection.optionId);
    if (!option) {
      throw new Error(`Selected preference option '${selection.optionId}' is invalid for this item`);
    }
    if (option.isActive === false) {
      throw new Error(`Selected preference option '${selection.optionId}' is currently unavailable`);
    }

    const hasSizeOptions = Array.isArray(option.sizeOptions) && option.sizeOptions.length > 0;
    let selectedSizeOption = null;
    let resolvedSelectionToken = selection.rawToken;
    let resolvedPriceDelta = toSafeNumber(option.priceDelta, 0);

    if (hasSizeOptions) {
      const activeSizeOptions = option.sizeOptions.filter((entry) => entry.isActive);

      if (activeSizeOptions.length === 0) {
        throw new Error(`Selected preference option '${selection.optionId}' is currently unavailable`);
      }

      if (selection.sizeOptionId) {
        selectedSizeOption = activeSizeOptions.find((entry) => entry.id === selection.sizeOptionId);
        if (!selectedSizeOption) {
          throw new Error(`Selected size '${selection.sizeOptionId}' is invalid for ${option.label}`);
        }
      } else {
        selectedSizeOption = activeSizeOptions.find((entry) => entry.isDefault)
          || (activeSizeOptions.length === 1 ? activeSizeOptions[0] : null);
        if (!selectedSizeOption) {
          throw new Error(`Please choose a size for ${option.label}`);
        }
      }

      resolvedSelectionToken = buildPreferenceSelectionToken(option.id, selectedSizeOption.id);
      resolvedPriceDelta += toSafeNumber(selectedSizeOption.priceDelta, 0);
    } else if (selection.sizeOptionId) {
      throw new Error(`Selected preference option '${selection.optionId}' does not support size selection`);
    }

    return {
      ...option,
      selectedSizeOption,
      resolvedSelectionToken,
      resolvedPriceDelta,
    };
  });

  const selectedByGroup = new Map();
  selectedEntries.forEach((entry) => {
    const list = selectedByGroup.get(entry.groupId) || [];
    list.push(entry);
    selectedByGroup.set(entry.groupId, list);
  });

  preferenceGroups.forEach((group) => {
    const selectedInGroup = selectedByGroup.get(group.id) || [];
    if (selectedInGroup.length < group.minSelections) {
      if (group.minSelections <= 1) {
        throw new Error(`Please choose an option for ${group.label}`);
      }
      throw new Error(`Please choose at least ${group.minSelections} option(s) for ${group.label}`);
    }

    if (selectedInGroup.length > group.maxSelections) {
      throw new Error(`You can select up to ${group.maxSelections} option(s) for ${group.label}`);
    }
  });

  const selectedPreferences = selectedEntries
    .map((entry) => ({
      groupId: entry.groupId,
      groupLabel: entry.groupLabel,
      optionId: entry.resolvedSelectionToken,
      optionBaseId: entry.id,
      optionLabel: entry.selectedSizeOption
        ? `${entry.label} (${entry.selectedSizeOption.label})`
        : entry.label,
      sizeOptionId: entry.selectedSizeOption?.id || null,
      sizeOptionLabel: entry.selectedSizeOption?.label || null,
      basePriceDelta: toSafeNumber(entry.priceDelta, 0),
      sizePriceDelta: entry.selectedSizeOption
        ? toSafeNumber(entry.selectedSizeOption.priceDelta, 0)
        : 0,
      priceDelta: toSafeNumber(entry.resolvedPriceDelta, 0),
    }))
    .sort((a, b) => {
      if (a.groupId === b.groupId) return a.optionId.localeCompare(b.optionId);
      return a.groupId.localeCompare(b.groupId);
    });

  const preferencePriceDelta = selectedPreferences.reduce((sum, entry) => sum + toSafeNumber(entry.priceDelta, 0), 0);
  const unitPrice = toSafeNumber(priceAfterPortion + preferencePriceDelta, resolvedBasePrice);

  const customizationKey = buildCustomizationKey({
    foodId: food?.id,
    portionId: selectedPortion?.id || null,
    preferenceOptionIds: selectedPreferences.map((entry) => entry.optionId),
    itemNote: normalizedNote,
  });

  return {
    unitPrice,
    selectedPortion,
    selectedPreferences,
    itemNote: normalizedNote,
    customizationKey,
  };
};

const validateFoodCustomizationConfig = ({ portionOptions, preferenceGroups } = {}) => {
  const normalized = {};

  if (portionOptions !== undefined) {
    if (portionOptions === null) {
      normalized.portionOptions = null;
    } else {
      normalized.portionOptions = normalizePortionOptions(portionOptions, { strict: true });
    }
  }

  if (preferenceGroups !== undefined) {
    if (preferenceGroups === null) {
      normalized.preferenceGroups = null;
    } else {
      normalized.preferenceGroups = normalizePreferenceGroups(preferenceGroups, { strict: true });
    }
  }

  return normalized;
};

module.exports = {
  MAX_ITEM_NOTE_LENGTH,
  MAX_SELECTIONS_PER_GROUP,
  PREFERENCE_SELECTION_DELIMITER,
  buildPreferenceSelectionToken,
  parseSelectedPreferenceToken,
  normalizeSelectedPreferenceOptionIds,
  buildCustomizationKey,
  resolveFoodCustomization,
  validateFoodCustomizationConfig,
};
