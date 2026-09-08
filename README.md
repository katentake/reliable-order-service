# Reliable Order Processing Service

Order-ingestion service for restaurants — built for the Palona AI take-home exercise.

Accepts orders over HTTPS, processes them asynchronously, and lets a client poll for
status — while staying available when downstream processing is slow, failing, or the
same order is retried.

**Deployed API**: `https://a0v16odgxe.execute-api.us-east-1.amazonaws.com`
(re-deploy with `terraform apply` produces a new URL if the API is ever destroyed and
recreated — check `terraform output api_url` for the current one).

## Docs

- [Architecture](docs/architecture.md) — diagram + why it's shaped this way
- [Deployment](docs/deployment.md) — bootstrap, deploy, CI/CD, teardown
- [Runbook](docs/runbook.md) — health checks, and the failure/recovery demo
- [Decisions & tradeoffs](docs/decisions.md) — assumptions, tradeoffs, known limitations, scaling
- [Testing](docs/testing.md) — what's covered, what isn't, and why
- [Cost](docs/cost.md) — expected cost, safeguards, what could cause overspend

## Try it

```bash
API_URL=https://a0v16odgxe.execute-api.us-east-1.amazonaws.com
ORDER_ID=$(uuidgen | tr 'A-Z' 'a-z')

# Submit an order
curl -X POST "$API_URL/orders" -H 'content-type: application/json' -d "{
  \"orderId\": \"$ORDER_ID\",
  \"restaurantId\": \"restaurant-1\",
  \"items\": [{\"name\": \"Burger\", \"quantity\": 2}]
}"
# -> 202 {"orderId":"...","status":"PENDING"}

# Retry the exact same request — idempotent, no duplicate processing
curl -X POST "$API_URL/orders" -H 'content-type: application/json' -d "{...same body...}"
# -> 200 (same order, current status — not re-enqueued)

# Check status
curl "$API_URL/orders/$ORDER_ID"
# -> {"orderId":"...","status":"COMPLETED","result":{...}}
```

For the failure/recovery scenario (an order that fails, lands in the dead-letter
queue, and gets recovered), see [runbook.md](docs/runbook.md#failure--recovery-demo).

## Status

Complete: order submission API, async processing worker, status lookup, idempotent
retries, DLQ + automatic FAILED-marking, CloudWatch alarms, Terraform infra,
GitHub Actions CI (test + plan on PR, test + apply on merge to main), full docs set.

Incomplete / explicitly out of scope: authentication on the API, automated
integration tests against the live deployment (manual `curl` verification only),
sustained load testing at the stated 100 req/s peak.

## Repository layout

```
app/        service source code (TypeScript / Node.js Lambda handlers)
infra/      Terraform — main stack + infra/bootstrap (remote state)
docs/       architecture, deployment, runbook, decisions, testing, cost
.github/    CI/CD workflows (PR checks, deploy on merge to main)
```

## Local development

```bash
npm ci
npm run typecheck
npm test
npm run build     # bundles app/dist/*.js for Lambda deployment
```
