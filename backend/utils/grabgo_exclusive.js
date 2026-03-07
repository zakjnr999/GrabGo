const isGrabGoExclusiveActive = (entity, referenceDate = new Date()) => {
  if (!entity || entity.isGrabGoExclusive !== true) {
    return false;
  }

  if (!entity.isGrabGoExclusiveUntil) {
    return true;
  }

  const exclusiveUntil = entity.isGrabGoExclusiveUntil instanceof Date
    ? entity.isGrabGoExclusiveUntil
    : new Date(entity.isGrabGoExclusiveUntil);

  if (Number.isNaN(exclusiveUntil.getTime())) {
    return false;
  }

  return exclusiveUntil > referenceDate;
};

const applyActiveExclusiveWhere = (
  where = {},
  exclusiveOnly = false,
  referenceDate = new Date(),
) => {
  if (!exclusiveOnly) {
    return where;
  }

  const andClauses = Array.isArray(where.AND) ? [...where.AND] : [];
  andClauses.push(
    { isGrabGoExclusive: true },
    {
      OR: [
        { isGrabGoExclusiveUntil: null },
        { isGrabGoExclusiveUntil: { gt: referenceDate } },
      ],
    },
  );

  return {
    ...where,
    AND: andClauses,
  };
};

module.exports = {
  isGrabGoExclusiveActive,
  applyActiveExclusiveWhere,
};
