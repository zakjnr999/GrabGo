const prisma = require('../../config/prisma');
const hasDelegate = (name) => Boolean(prisma?.[name] && typeof prisma[name] === 'object');

const createCase = async ({ actorType, actorId, severity = 'p3', queue = 'default', openedReason, reasonCodes = [], evidence = null }) => {
  if (!hasDelegate('fraudCase')) return null;
  try {
    return await prisma.fraudCase.create({
      data: {
        actorType,
        actorId,
        severity,
        queue,
        openedReason,
        reasonCodes,
        evidence,
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudCase')) {
      return null;
    }
    throw error;
  }
};

const listCases = async ({ status, severity, actorType, from, to, take = 50, skip = 0 }) => {
  if (!hasDelegate('fraudCase')) return [];
  const where = {
    ...(status ? { status } : {}),
    ...(severity ? { severity } : {}),
    ...(actorType ? { actorType } : {}),
  };

  if (from || to) {
    where.openedAt = {
      ...(from ? { gte: new Date(from) } : {}),
      ...(to ? { lte: new Date(to) } : {}),
    };
  }

  try {
    return await prisma.fraudCase.findMany({
      where,
      orderBy: { openedAt: 'desc' },
      take,
      skip,
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudCase')) {
      return [];
    }
    throw error;
  }
};

const getCaseById = async (id) => {
  if (!hasDelegate('fraudCase')) return null;
  try {
    return await prisma.fraudCase.findUnique({ where: { id } });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudCase')) {
      return null;
    }
    throw error;
  }
};

const assignCase = async ({ id, assignee }) => {
  if (!hasDelegate('fraudCase')) return null;
  try {
    return await prisma.fraudCase.update({
      where: { id },
      data: {
        assignedTo: assignee,
        acknowledgedAt: new Date(),
        status: 'investigating',
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudCase')) {
      return null;
    }
    throw error;
  }
};

const resolveCase = async ({ id, resolutionStatus, resolutionNote }) => {
  if (!hasDelegate('fraudCase')) return null;
  try {
    return await prisma.fraudCase.update({
      where: { id },
      data: {
        status: resolutionStatus,
        resolutionNote: resolutionNote || null,
        closedAt: new Date(),
      },
    });
  } catch (error) {
    if (String(error.message || '').includes('prisma.fraudCase')) {
      return null;
    }
    throw error;
  }
};

module.exports = {
  createCase,
  listCases,
  getCaseById,
  assignCase,
  resolveCase,
};
