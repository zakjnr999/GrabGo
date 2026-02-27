const MAX_ITEM_NOTE_LENGTH = 200;

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

const normalizeSelectedPreferenceOptionIds = (value) => {
  const parsed = parseJsonIfString(value);

  if (Array.isArray(parsed)) {
    return parsed
      .map((entry) => normalizeId(entry))
      .filter(Boolean);
  }

  if (parsed && typeof parsed === 'object') {
    const ids = [];
    Object.values(parsed).forEach((entry) => {
      if (Array.isArray(entry)) {
        entry.forEach((item) => {
          const id = normalizeId(item);
          if (id) ids.push(id);
        });
      } else {
        const id = normalizeId(entry);
        if (id) ids.push(id);
      }
    });
    return ids;
  }

  const one = normalizeId(parsed);
  return one ? [one] : [];
};

const normalizePortionOptions = (portionOptions) => {
  return asArray(portionOptions)
    .map((option) => {
      if (!option || typeof option !== 'object') return null;

      const id = normalizeId(option.id || option.code || option.value);
      if (!id) return null;

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
};

const normalizePreferenceGroups = (preferenceGroups) => {
  return asArray(preferenceGroups)
    .map((group) => {
      if (!group || typeof group !== 'object') return null;

      const groupId = normalizeId(group.id || group.code || group.key);
      if (!groupId) return null;

      const groupLabel = normalizeText(group.label || group.name || group.title || groupId) || groupId;
      const required = group.required === true;
      const maxSelections = Math.max(1, Number.parseInt(group.maxSelections, 10) || (group.multiSelect ? 99 : 1));

      const options = asArray(group.options)
        .map((option) => {
          if (!option || typeof option !== 'object') return null;
          const id = normalizeId(option.id || option.code || option.value);
          if (!id) return null;
          const label = normalizeText(option.label || option.name || option.title || id) || id;
          const isActive = option.isActive !== false;
          const priceDelta = toSafeNumber(option.priceDelta ?? option.additionalPrice ?? option.price, 0);

          return {
            id,
            label,
            isActive,
            isDefault: option.isDefault === true,
            priceDelta,
          };
        })
        .filter(Boolean);

      return {
        id: groupId,
        label: groupLabel,
        required,
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
  const portionOptions = normalizePortionOptions(food?.portionOptions);
  const preferenceGroups = normalizePreferenceGroups(food?.preferenceGroups);

  const normalizedPortionId = normalizeId(selectedPortionId);
  const normalizedPreferenceIds = normalizeSelectedPreferenceOptionIds(selectedPreferenceOptionIds);
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

  const selectedEntries = normalizedPreferenceIds.map((id) => {
    const option = optionById.get(id);
    if (!option) {
      throw new Error(`Selected preference option '${id}' is invalid for this item`);
    }
    if (option.isActive === false) {
      throw new Error(`Selected preference option '${id}' is currently unavailable`);
    }
    return option;
  });

  const selectedByGroup = new Map();
  selectedEntries.forEach((entry) => {
    const list = selectedByGroup.get(entry.groupId) || [];
    list.push(entry);
    selectedByGroup.set(entry.groupId, list);
  });

  preferenceGroups.forEach((group) => {
    const selectedInGroup = selectedByGroup.get(group.id) || [];

    if (group.required && selectedInGroup.length === 0) {
      throw new Error(`Please choose an option for ${group.label}`);
    }

    if (selectedInGroup.length > group.maxSelections) {
      throw new Error(`You can select up to ${group.maxSelections} option(s) for ${group.label}`);
    }
  });

  const selectedPreferences = selectedEntries
    .map((entry) => ({
      groupId: entry.groupId,
      groupLabel: entry.groupLabel,
      optionId: entry.id,
      optionLabel: entry.label,
      priceDelta: toSafeNumber(entry.priceDelta, 0),
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

module.exports = {
  MAX_ITEM_NOTE_LENGTH,
  normalizeSelectedPreferenceOptionIds,
  buildCustomizationKey,
  resolveFoodCustomization,
};
