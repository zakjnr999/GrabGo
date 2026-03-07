const REVIEW_REPORT_REASONS = [
  "abusive_offensive",
  "spam",
  "personal_info",
  "unrelated",
  "false_misleading",
];

const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const PHONE_PATTERN = /(?:\+?\d[\d\s().-]{7,}\d)/;
const PROFANITY_PATTERNS = [
  /\bfuck(?:ing|ed|er|ers)?\b/i,
  /\bshit(?:ty|ting)?\b/i,
  /\bbitch(?:es|y)?\b/i,
  /\basshole(?:s)?\b/i,
  /\bbastard(?:s)?\b/i,
];

const normalizeReportReason = (reason) => {
  const normalized = String(reason || "").trim().toLowerCase();
  return REVIEW_REPORT_REASONS.includes(normalized) ? normalized : null;
};

const normalizeReportDetails = (details) => {
  if (typeof details !== "string") return null;
  const normalized = details.trim();
  return normalized.length > 0 ? normalized.slice(0, 300) : null;
};

const detectBlockedCommentFlags = (comment) => {
  if (!comment) return [];

  const flags = [];
  if (EMAIL_PATTERN.test(comment) || PHONE_PATTERN.test(comment)) {
    flags.push("personal_info");
  }

  if (PROFANITY_PATTERNS.some((pattern) => pattern.test(comment))) {
    flags.push("abusive_offensive");
  }

  return [...new Set(flags)];
};

const assertReviewCommentAllowed = (
  comment,
  ErrorClass,
  {
    code = "REVIEW_COMMENT_NOT_ALLOWED",
    statusCode = 400,
  } = {}
) => {
  const flags = detectBlockedCommentFlags(comment);
  if (flags.length === 0) {
    return {
      comment,
      flags,
    };
  }

  throw new ErrorClass(
    "Comment contains content we can't publish. Remove personal contact details or offensive language and try again.",
    {
      statusCode,
      code,
    }
  );
};

module.exports = {
  REVIEW_REPORT_REASONS,
  normalizeReportReason,
  normalizeReportDetails,
  detectBlockedCommentFlags,
  assertReviewCommentAllowed,
};
