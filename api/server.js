const { randomUUID } = require('node:crypto');
const http = require('node:http');

const port = Number(process.env.PORT || 3000);
const serviceName = process.env.SERVICE_NAME || 'demo-api';
const apiVersion = '1';

const sampleUser = {
  id: 1,
  name: 'Ada Lovelace',
  role: 'QA Engineer',
};

const routes = {
  '/health': {
    status: 'ok',
    service: serviceName,
  },
  '/ready': {
    ready: true,
    service: serviceName,
  },
  '/users': [sampleUser],
  '/users/1': sampleUser,
};

const server = http.createServer((request, response) => {
  const isHeadRequest = request.method === 'HEAD';
  const isOptionsRequest = request.method === 'OPTIONS';
  const methodAllowed = request.method === 'GET' || isHeadRequest || isOptionsRequest;
  const { pathname } = new URL(request.url, 'http://localhost');
  const body = methodAllowed ? routes[pathname] : undefined;
  const statusCode = isOptionsRequest && body ? 204 : methodAllowed ? (body ? 200 : 404) : 405;
  const payload = statusCode === 204 ? undefined : body || {
    error: methodAllowed ? 'Not found' : 'Method not allowed',
  };
  const responseBody = payload ? JSON.stringify(payload) : '';

  response.writeHead(statusCode, {
    ...(isOptionsRequest || !methodAllowed ? { Allow: 'GET, HEAD, OPTIONS' } : {}),
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(responseBody),
    ...(payload ? { 'Content-Type': 'application/json; charset=utf-8' } : {}),
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-Api-Version': apiVersion,
    'X-Request-Id': randomUUID(),
    'X-Service-Name': serviceName,
  });
  response.end(isHeadRequest || statusCode === 204 ? undefined : responseBody);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Demo API is listening on port ${port}`);
});

let isShuttingDown = false;

function shutdown(signal) {
  if (isShuttingDown) {
    return;
  }

  isShuttingDown = true;
  console.log(`Received ${signal}; closing HTTP server`);

  const forceExit = setTimeout(() => {
    console.error('HTTP server did not close in time');
    process.exit(1);
  }, 8000);
  forceExit.unref();

  server.close((error) => {
    clearTimeout(forceExit);

    if (error) {
      console.error('Failed to close HTTP server', error);
      process.exit(1);
    }

    console.log('HTTP server closed');
    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
