const { test, expect } = require('@playwright/test');

const expectedServiceName = process.env.EXPECTED_SERVICE_NAME || 'demo-api';

function expectJsonResponse(response, status, expectedPayload) {
  expect(response.status()).toBe(status);
  expect(response.headers()['cache-control']).toBe('no-store');
  expect(response.headers()['content-length']).toBe(
    String(Buffer.byteLength(JSON.stringify(expectedPayload))),
  );
  expect(response.headers()['content-type']).toBe('application/json; charset=utf-8');
  expect(response.headers()['referrer-policy']).toBe('no-referrer');
  expect(response.headers()['x-frame-options']).toBe('DENY');
  expect(response.headers()['x-content-type-options']).toBe('nosniff');
  expect(response.headers()['x-api-version']).toBe('1');
  expect(response.headers()['x-request-id']).toMatch(
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
  expect(response.headers()['x-service-name']).toBe(expectedServiceName);
}

test('health endpoint reports that the API is ready', async ({ request }) => {
  const response = await request.get('/health?source=playwright');
  const expectedPayload = {
    status: 'ok',
    service: expectedServiceName,
  };

  expectJsonResponse(response, 200, expectedPayload);
  expect(await response.json()).toEqual(expectedPayload);
});

test('readiness endpoint reports that the API can serve traffic', async ({ request }) => {
  const response = await request.get('/ready');
  const expectedPayload = {
    ready: true,
    service: expectedServiceName,
  };

  expectJsonResponse(response, 200, expectedPayload);
  expect(await response.json()).toEqual(expectedPayload);
});

test('returns a known test user', async ({ request }) => {
  const response = await request.get('/users/1');
  const expectedPayload = {
    id: 1,
    name: 'Ada Lovelace',
    role: 'QA Engineer',
  };

  expectJsonResponse(response, 200, expectedPayload);
  expect(await response.json()).toEqual(expectedPayload);
});

test('returns the sample users list', async ({ request }) => {
  const response = await request.get('/users');
  const expectedPayload = [
    {
      id: 1,
      name: 'Ada Lovelace',
      role: 'QA Engineer',
    },
  ];

  expectJsonResponse(response, 200, expectedPayload);
  expect(await response.json()).toEqual(expectedPayload);
});

test('supports HEAD without returning a response body', async ({ request }) => {
  const getResponse = await request.get('/health');
  const headResponse = await request.head('/health');
  const expectedPayload = {
    status: 'ok',
    service: expectedServiceName,
  };

  expectJsonResponse(getResponse, 200, expectedPayload);
  expectJsonResponse(headResponse, 200, expectedPayload);
  expect(headResponse.headers()['content-length']).toBe(
    getResponse.headers()['content-length'],
  );
  expect(await headResponse.text()).toBe('');
});

test('advertises supported methods with OPTIONS', async ({ request }) => {
  const response = await request.fetch('/health', { method: 'OPTIONS' });

  expect(response.status()).toBe(204);
  expect(response.headers()['allow']).toBe('GET, HEAD, OPTIONS');
  expect(response.headers()['cache-control']).toBe('no-store');
  expect(response.headers()['content-length']).toBe('0');
  expect(response.headers()['content-type']).toBeUndefined();
  expect(response.headers()['referrer-policy']).toBe('no-referrer');
  expect(response.headers()['x-frame-options']).toBe('DENY');
  expect(response.headers()['x-content-type-options']).toBe('nosniff');
  expect(response.headers()['x-api-version']).toBe('1');
  expect(response.headers()['x-request-id']).toMatch(
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
  );
  expect(response.headers()['x-service-name']).toBe(expectedServiceName);
  expect(await response.text()).toBe('');
});

test('returns a JSON 404 for OPTIONS on an unknown route', async ({ request }) => {
  const response = await request.fetch('/missing', { method: 'OPTIONS' });
  const expectedPayload = {
    error: 'Not found',
  };

  expectJsonResponse(response, 404, expectedPayload);
  expect(response.headers().allow).toBe('GET, HEAD, OPTIONS');
  expect(await response.json()).toEqual(expectedPayload);
});

test('assigns a unique ID to each request', async ({ request }) => {
  const firstResponse = await request.get('/health');
  const secondResponse = await request.get('/health');

  const expectedPayload = {
    status: 'ok',
    service: expectedServiceName,
  };

  expectJsonResponse(firstResponse, 200, expectedPayload);
  expectJsonResponse(secondResponse, 200, expectedPayload);
  expect(firstResponse.headers()['x-request-id']).not.toBe(
    secondResponse.headers()['x-request-id'],
  );
});

test('returns 404 for an unknown route', async ({ request }) => {
  const response = await request.get('/missing');
  const expectedPayload = {
    error: 'Not found',
  };

  expectJsonResponse(response, 404, expectedPayload);
  expect(await response.json()).toEqual(expectedPayload);
});

test('rejects unsupported HTTP methods', async ({ request }) => {
  const response = await request.post('/health');
  const expectedPayload = {
    error: 'Method not allowed',
  };

  expectJsonResponse(response, 405, expectedPayload);
  expect(response.headers().allow).toBe('GET, HEAD, OPTIONS');
  expect(await response.json()).toEqual(expectedPayload);
});
