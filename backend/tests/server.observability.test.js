const request = require('supertest');

jest.mock('../bootstrap/dependencies', () => ({
  bootstrapDependencies: jest.fn().mockResolvedValue(undefined),
  getReadinessReport: jest.fn(),
}));

jest.mock('../bootstrap/background_jobs', () => ({
  startBackgroundJobs: jest.fn(),
  stopBackgroundJobs: jest.fn(),
  areBackgroundJobsRunning: jest.fn(),
}));

jest.mock('../utils/emailService', () => ({
  verifyEmailService: jest.fn(),
}));

const { getReadinessReport } = require('../bootstrap/dependencies');
const { areBackgroundJobsRunning } = require('../bootstrap/background_jobs');
const { verifyEmailService } = require('../utils/emailService');
const metrics = require('../utils/metrics');
const { app } = require('../server');

describe('Server Observability Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    getReadinessReport.mockResolvedValue({
      status: 'ok',
      dependencies: {
        postgres: 'ok',
        mongodb: 'ok',
        redis: 'ok',
      },
    });
    areBackgroundJobsRunning.mockReturnValue(false);
    verifyEmailService.mockResolvedValue({ success: true, provider: 'smtp' });
  });

  test('GET /api/health/live returns liveness response', async () => {
    const response = await request(app).get('/api/health/live');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });

  test('GET /api/health/ready returns 200 when dependencies are ready', async () => {
    const response = await request(app).get('/api/health/ready');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      status: 'ok',
      dependencies: {
        postgres: 'ok',
        mongodb: 'ok',
        redis: 'ok',
      },
    });
  });

  test('GET /api/health returns 503 when readiness is degraded', async () => {
    getReadinessReport.mockResolvedValue({
      status: 'degraded',
      dependencies: {
        postgres: 'error',
        mongodb: 'ok',
        redis: 'degraded',
      },
    });

    const response = await request(app).get('/api/health');

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      status: 'degraded',
      dependencies: {
        postgres: 'error',
        mongodb: 'ok',
        redis: 'degraded',
      },
    });
  });

  test('GET /api/metrics returns prometheus-style metrics output', async () => {
    areBackgroundJobsRunning.mockReturnValue(true);
    metrics.recordCheckoutSessionEvent({ action: 'create', result: 'success' });

    const response = await request(app).get('/api/metrics');

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toContain('text/plain');
    expect(response.text).toContain('grabgo_dependency_health{dependency="postgres"} 1');
    expect(response.text).toContain('grabgo_dependency_health{dependency="mongodb"} 1');
    expect(response.text).toContain('grabgo_background_jobs_enabled 1');
    expect(response.text).toContain(
      'grabgo_checkout_session_events_total{action="create",result="success"}'
    );
  });

  test('GET /api/health/email returns provider health payload', async () => {
    verifyEmailService.mockResolvedValue({
      success: false,
      provider: 'smtp',
      message: 'connection refused',
    });

    const response = await request(app).get('/api/health/email');

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      status: 'error',
      service: 'smtp',
      success: false,
      provider: 'smtp',
      message: 'Email service unavailable',
    });
  });
});
