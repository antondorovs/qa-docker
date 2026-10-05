# QA Docker Lab

A practical Docker lab for running automated QA checks in isolated
containers.

The first example starts:

- a small Node.js API container;
- a Playwright test container;
- sixteen API checks against the service over the Compose network.

## Prerequisites

- Docker Desktop, or Docker Engine with Docker Compose;
- Git Bash, WSL, or another POSIX shell to use the helper script.

Node.js is only required when running the tests without Docker.

## Run with Docker Compose

Build the images and run the complete test workflow:

```bash
docker compose up --build --abort-on-container-exit --exit-code-from tests
```

Clean up the containers and network:

```bash
docker compose down --remove-orphans
```

On Linux, macOS, Git Bash, or WSL, both commands can be run with:

```bash
sh scripts/run-tests.sh
```

On Windows PowerShell, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-tests.ps1
```

Both helper scripts return the Playwright test exit code and clean up the
Compose containers and network after the run.

The Compose project name is fixed to `qa-docker-lab`, keeping container,
image, and network names predictable across shells and launch directories.

Validate both the standard Compose configuration and the debug override
without starting containers:

```bash
sh scripts/validate-compose.sh
```

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-compose.ps1
```

The API image includes a Dockerfile `HEALTHCHECK`, so Compose waits until the
API is healthy before starting the test container.

The healthcheck allows a short startup period before counting failures, which
keeps slower local Docker starts from failing early.

When Compose stops the API, the Node.js process handles `SIGTERM`, closes the
HTTP server, and has a 10-second grace period before Docker forces shutdown.

Compose sends `SIGTERM` explicitly to the API container, keeping the shutdown
path easy to reason about during local experiments.

Both containers run with Docker's init process enabled, which keeps signal
handling predictable and reaps child processes during local practice runs.

The API process and its healthcheck run as the non-root `node` user included
in the base image.

The API container sets `NODE_ENV=production`, matching the runtime mode used
by most deployed Node.js services.

Compose also gives the API a read-only root filesystem, prevents privilege
escalation, and drops all Linux capabilities.

The API container is limited to 128 MiB of memory, half of one CPU, and 100
processes so resource constraints can be practiced locally.

Docker keeps up to three 1 MiB JSON log files per Compose service, which
prevents local practice runs from growing logs without a limit.

The test container is also capped at 200 processes, limiting runaway process
trees while leaving room for parallel Playwright workers.

The test container has a 1 GiB memory limit, which keeps local runs bounded
without constraining the small API checks.

The test container is capped at one CPU, keeping browser checks predictable
on shared local machines.

The test container uses the same explicit `SIGTERM` and 10-second stop grace
period as the API, so interrupted runs shut down predictably.

The normal test workflow uses an internal Compose network with no external
route. The debug override switches back to a regular network and publishes
the API port for host access.

Both Docker build contexts are intentionally small. The test image excludes
source files that it does not copy, and the API image uses its own
`api/.dockerignore` file.

The generated HTML report is saved in `playwright-report/`. A JUnit XML report
for CI systems is saved as `test-results/junit.xml`.

Container and CI runs cap Playwright at two workers, keeping local resource
usage predictable while still exercising parallel API checks.

They also fail fast if a focused test is left in place, which helps keep the
container workflow representative before pushing changes.

After the first failed test, container and CI runs stop early so failures are
reported quickly without spending time on the rest of the suite.

Assertions use a five-second timeout, keeping delayed API responses visible
without making successful checks wait longer than needed.

Every API response disables caching and MIME sniffing, keeping the lab's JSON
behavior explicit in both successful and error responses.

Responses also prevent embedding in frames and suppress referrer data, keeping
the sample API's browser-facing behavior restrictive by default.

Every response also includes a unique `X-Request-Id` UUID, making individual
requests easy to correlate with diagnostics.

Every response also includes `X-Service-Name`, which keeps test output and
manual checks tied to the configured API service name.

Every response declares `X-Api-Version: 1`, giving contract checks a stable
version marker without changing the JSON payload.

The sample API accepts `GET`, `HEAD`, and `OPTIONS` requests. A `HEAD` response
has the same headers as `GET`, without a response body. `OPTIONS` returns `204`
for a known route and advertises the supported methods in the `Allow` header.
For an unknown route, `OPTIONS` returns the same JSON `404 Not Found` payload as
`GET`. Other methods return `405 Method Not Allowed` with the same header.

The user fixture is available both as a collection at `/users` and as a single
resource at `/users/1`, giving the contract suite list and detail responses to
compare.

JSON responses include an explicit byte-accurate `Content-Length`. For `HEAD`,
the value describes the representation that the corresponding `GET` would
return even though no body is sent.

JSON response headers explicitly declare UTF-8, so clients can decode the API
payload consistently.

Route matching uses the request path, so query parameters do not change which
sample endpoint handles a request.

Only explicitly registered routes are served. Paths matching built-in object
properties, such as `/constructor` or `/__proto__`, return the JSON `404` response.

The `/ready` endpoint returns a lightweight readiness payload for contract tests
that need a traffic-serving signal separate from the Docker healthcheck.
Readiness checks cover query parameters, body-free `HEAD` probes, and `OPTIONS`
method discovery, so monitoring clients can use the same endpoint consistently.

When a container or CI retry is needed, Playwright records a trace on the
first retry to make the failure easier to inspect afterward.

Screenshots are captured only on failed checks, keeping successful runs clean
while preserving useful evidence when something breaks.

Failure videos are retained as well, giving another lightweight artifact for
debugging without adding noise to passing runs.

Failure artifacts are written under `test-results/artifacts/`, keeping them
next to the JUnit report while staying ignored by Git.

## Configure the test environment

Compose uses sensible defaults, so no configuration file is required. To
practice environment-based configuration, create a local `.env` file from the
included example:

```bash
cp .env.example .env
```

PowerShell:

```powershell
Copy-Item .env.example .env
```

Available values:

| Variable | Default | Purpose |
| --- | --- | --- |
| `API_PORT` | `3000` | Internal API port used by the service and tests |
| `SERVICE_NAME` | `demo-api` | Service name returned by the health endpoint |

For example:

```dotenv
API_PORT=3100
SERVICE_NAME=qa-lab-api
```

The `.env` file is ignored by Git and excluded from the Docker build context.

## Debug the API container

The normal test workflow keeps the API inside the Compose network. When you
want to inspect it from the host machine, add the debug override:

```bash
docker compose -f compose.yaml -f compose.debug.yaml up --build api
```

Then check the health endpoint from another terminal:

```bash
curl http://127.0.0.1:3000/health
```

PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health
```

If you changed `API_PORT` in `.env`, use that port in the URL. Clean up after
manual checks with:

```bash
docker compose -f compose.yaml -f compose.debug.yaml down --remove-orphans
```

## Run tests locally

Start the API:

```bash
node api/server.js
```

In another terminal, install dependencies and run the tests:

```bash
npm ci
npm test
```

The local tests use `http://127.0.0.1:3000` by default. Override it when
needed:

```bash
BASE_URL=http://example.test npm test
```

PowerShell:

```powershell
$env:BASE_URL = "http://example.test"
npm test
```

## Project structure

```text
.
|-- .env.example
|-- api/
|   |-- .dockerignore
|   |-- Dockerfile
|   `-- server.js
|-- scripts/
|   |-- run-tests.ps1
|   |-- run-tests.sh
|   |-- validate-compose.ps1
|   `-- validate-compose.sh
|-- tests/
|   `-- api.spec.js
|-- compose.yaml
|-- compose.debug.yaml
|-- Dockerfile
|-- package.json
`-- playwright.config.js
```

## Useful commands

Rebuild only the test image:

```bash
docker compose build tests
```

Run the tests again while the API container is already running:

```bash
docker compose run --rm tests
```

View service logs:

```bash
docker compose logs api
```

Inspect the generated JUnit report:

```bash
cat test-results/junit.xml
```

PowerShell:

```powershell
Get-Content test-results/junit.xml
```
