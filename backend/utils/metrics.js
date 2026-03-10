const DEFAULT_HISTOGRAM_BUCKETS = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];

const metricsRegistry = new Map();

const escapeLabelValue = (value) =>
  String(value)
    .replace(/\\/g, '\\\\')
    .replace(/\n/g, '\\n')
    .replace(/"/g, '\\"');

const buildLabelsKey = (labelNames, labels = {}) =>
  labelNames.map((labelName) => `${labelName}=${labels[labelName] ?? ''}`).join('|');

const buildLabelsString = (labelNames, labels = {}) => {
  if (!labelNames.length) return '';
  const pairs = labelNames.map(
    (labelName) => `${labelName}="${escapeLabelValue(labels[labelName] ?? '')}"`
  );
  return `{${pairs.join(',')}}`;
};

const ensureMetric = (name, config) => {
  if (!metricsRegistry.has(name)) {
    metricsRegistry.set(name, {
      ...config,
      values: new Map(),
    });
  }
  return metricsRegistry.get(name);
};

const defineCounter = (name, help, labelNames = []) =>
  ensureMetric(name, { type: 'counter', help, labelNames });

const defineGauge = (name, help, labelNames = []) =>
  ensureMetric(name, { type: 'gauge', help, labelNames });

const defineHistogram = (name, help, labelNames = [], buckets = DEFAULT_HISTOGRAM_BUCKETS) =>
  ensureMetric(name, {
    type: 'histogram',
    help,
    labelNames,
    buckets: [...buckets].sort((a, b) => a - b),
  });

const incrementCounter = (name, labels = {}, amount = 1) => {
  const metric = metricsRegistry.get(name);
  if (!metric || metric.type !== 'counter') {
    throw new Error(`Counter metric "${name}" is not defined`);
  }

  const key = buildLabelsKey(metric.labelNames, labels);
  const existing = metric.values.get(key) || { labels, value: 0 };
  existing.value += amount;
  metric.values.set(key, existing);
};

const setGauge = (name, labels = {}, value = 0) => {
  const metric = metricsRegistry.get(name);
  if (!metric || metric.type !== 'gauge') {
    throw new Error(`Gauge metric "${name}" is not defined`);
  }

  const key = buildLabelsKey(metric.labelNames, labels);
  metric.values.set(key, { labels, value });
};

const observeHistogram = (name, labels = {}, observedValue = 0) => {
  const metric = metricsRegistry.get(name);
  if (!metric || metric.type !== 'histogram') {
    throw new Error(`Histogram metric "${name}" is not defined`);
  }

  const key = buildLabelsKey(metric.labelNames, labels);
  const existing =
    metric.values.get(key) || {
      labels,
      count: 0,
      sum: 0,
      bucketCounts: metric.buckets.map(() => 0),
    };

  existing.count += 1;
  existing.sum += observedValue;
  metric.buckets.forEach((bucket, index) => {
    if (observedValue <= bucket) {
      existing.bucketCounts[index] += 1;
    }
  });
  metric.values.set(key, existing);
};

const renderMetric = (name, metric) => {
  const lines = [`# HELP ${name} ${metric.help}`, `# TYPE ${name} ${metric.type}`];

  if (metric.type === 'histogram') {
    for (const { labels, count, sum, bucketCounts } of metric.values.values()) {
      metric.buckets.forEach((bucket, index) => {
        lines.push(
          `${name}_bucket${buildLabelsString([...metric.labelNames, 'le'], {
            ...labels,
            le: bucket,
          })} ${bucketCounts[index]}`
        );
      });
      lines.push(
        `${name}_bucket${buildLabelsString([...metric.labelNames, 'le'], {
          ...labels,
          le: '+Inf',
        })} ${count}`
      );
      lines.push(`${name}_sum${buildLabelsString(metric.labelNames, labels)} ${sum}`);
      lines.push(`${name}_count${buildLabelsString(metric.labelNames, labels)} ${count}`);
    }
    return lines;
  }

  for (const { labels, value } of metric.values.values()) {
    lines.push(`${name}${buildLabelsString(metric.labelNames, labels)} ${value}`);
  }
  return lines;
};

const renderMetrics = () =>
  [...metricsRegistry.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .flatMap(([name, metric]) => renderMetric(name, metric))
    .join('\n') + '\n';

defineCounter('grabgo_http_requests_total', 'Total HTTP requests', ['method', 'route', 'status']);
defineHistogram(
  'grabgo_http_request_duration_ms',
  'HTTP request duration in milliseconds',
  ['method', 'route', 'status']
);
defineGauge('grabgo_dependency_health', 'Dependency health status (1=healthy, 0=unhealthy)', ['dependency']);
defineGauge('grabgo_background_jobs_enabled', 'Whether background jobs are enabled in this process');
defineCounter('grabgo_order_events_total', 'Order domain events', ['action', 'result']);
defineCounter('grabgo_checkout_session_events_total', 'Checkout session domain events', ['action', 'result']);
defineCounter('grabgo_review_events_total', 'Review domain events', ['review_type', 'action', 'result']);
defineCounter('grabgo_dispatch_events_total', 'Dispatch outcomes', ['result']);
defineHistogram('grabgo_dispatch_duration_ms', 'Dispatch duration in milliseconds', ['result']);
defineCounter('grabgo_notification_events_total', 'Notification delivery outcomes', ['channel', 'result']);
defineCounter('grabgo_payment_webhook_events_total', 'Payment webhook outcomes', ['event_type', 'result']);
defineHistogram(
  'grabgo_payment_webhook_duration_ms',
  'Payment webhook processing duration in milliseconds',
  ['event_type', 'result']
);

const safeRouteLabel = (route) => {
  if (!route || typeof route !== 'string') return 'unmatched';
  return route.replace(/\/+/g, '/');
};

const observeHttpRequest = ({ method, route, status, durationMs }) => {
  const labels = {
    method: String(method || 'UNKNOWN').toUpperCase(),
    route: safeRouteLabel(route),
    status: String(status || 0),
  };

  incrementCounter('grabgo_http_requests_total', labels, 1);
  observeHistogram('grabgo_http_request_duration_ms', labels, Number(durationMs || 0));
};

const setDependencyHealth = (dependencies = {}) => {
  Object.entries(dependencies).forEach(([dependency, status]) => {
    setGauge('grabgo_dependency_health', { dependency }, status === 'ok' ? 1 : 0);
  });
};

const setBackgroundJobsEnabled = (enabled) => {
  setGauge('grabgo_background_jobs_enabled', {}, enabled ? 1 : 0);
};

const recordOrderEvent = ({ action, result }) => {
  incrementCounter('grabgo_order_events_total', { action, result }, 1);
};

const recordCheckoutSessionEvent = ({ action, result }) => {
  incrementCounter('grabgo_checkout_session_events_total', { action, result }, 1);
};

const recordReviewEvent = ({ reviewType, action, result }) => {
  incrementCounter('grabgo_review_events_total', { review_type: reviewType, action, result }, 1);
};

const recordDispatchEvent = ({ result, durationMs } = {}) => {
  incrementCounter('grabgo_dispatch_events_total', { result }, 1);
  if (Number.isFinite(Number(durationMs))) {
    observeHistogram('grabgo_dispatch_duration_ms', { result }, Number(durationMs));
  }
};

const recordNotificationEvent = ({ channel, result }) => {
  incrementCounter('grabgo_notification_events_total', { channel, result }, 1);
};

const recordPaymentWebhookEvent = ({ eventType, result, durationMs } = {}) => {
  const labels = {
    event_type: String(eventType || 'unknown'),
    result: String(result || 'unknown'),
  };
  incrementCounter('grabgo_payment_webhook_events_total', labels, 1);
  if (Number.isFinite(Number(durationMs))) {
    observeHistogram('grabgo_payment_webhook_duration_ms', labels, Number(durationMs));
  }
};

module.exports = {
  defineCounter,
  defineGauge,
  defineHistogram,
  incrementCounter,
  setGauge,
  observeHistogram,
  renderMetrics,
  observeHttpRequest,
  setDependencyHealth,
  setBackgroundJobsEnabled,
  recordOrderEvent,
  recordCheckoutSessionEvent,
  recordReviewEvent,
  recordDispatchEvent,
  recordNotificationEvent,
  recordPaymentWebhookEvent,
};
