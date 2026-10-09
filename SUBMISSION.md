# Submission — Reliable Order Processing Service

**Repository**: https://github.com/katentake/reliable-order-service

**Deployed API**: shared on request (the API has no authentication, so the URL is not published)

## Testing it

```bash
API_URL=$(terraform -chdir=infra output -raw api_url)
ORDER_ID=$(uuidgen | tr 'A-Z' 'a-z')

# Submit an order
curl -X POST "$API_URL/orders" -H 'content-type: application/json' -d "{
  \"orderId\": \"$ORDER_ID\",
  \"restaurantId\": \"restaurant-1\",
  \"items\": [{\"name\": \"Burger\", \"quantity\": 2}]
}"
# -> 202 {"orderId":"...","status":"PENDING"}

# Retry the exact same request — idempotent, not re-processed
curl -X POST "$API_URL/orders" -H 'content-type: application/json' -d "{...same body...}"
# -> 200, same order, no duplicate enqueue

# Check status a few seconds later
curl "$API_URL/orders/$ORDER_ID"
# -> {"status":"COMPLETED","result":{...}}
```

No auth required (out of scope per the exercise — see Known limitations below).
Full walkthrough, including the failure/recovery scenario, is in
[docs/runbook.md](docs/runbook.md#failure--recovery-demo).

## What's complete

- HTTPS API: `POST /orders` (submit), `GET /orders/{orderId}` (status)
- Async processing via SQS, decoupled from the API response
- Idempotent submission — retried `orderId` returns existing status, doesn't
  re-enqueue or duplicate work (DynamoDB conditional write)
- Failure handling: 3 retries → dead-letter queue → automatically marked
  `FAILED` with a reason; recoverable via DLQ redrive once the underlying issue
  is fixed (demoed in the runbook)
- Full infra as code (Terraform), reproducible from a clean checkout
- CI/CD from GitHub via OIDC (no long-lived AWS keys in the repo): PR → build,
  test, `terraform plan`; merge to `main` → build, test, `terraform apply`
- 3 CloudWatch alarms (DLQ depth, Lambda errors, API 5xx) wired to email via SNS
- Cost safeguards: AWS Budget + billing alerts, API throttling, tagged
  resources, 14-day log retention
- 10 unit tests (handler logic, mocked AWS SDK) + infra validation
  (`terraform fmt`/`validate`/`plan`) in CI
- Docs: [architecture](docs/architecture.md), [deployment](docs/deployment.md),
  [runbook](docs/runbook.md), [decisions/tradeoffs](docs/decisions.md),
  [testing](docs/testing.md), [security](docs/security.md), [cost](docs/cost.md)

## What's incomplete / out of scope

- No authentication/authorization on the API (explicitly acceptable per the
  exercise's simple-business-logic framing; flagged in
  [security.md](docs/security.md) as the first thing to add before real traffic)
- No automated integration test against the *deployed* API — covered by manual
  `curl` verification (documented in the runbook) instead; see
  [testing.md](docs/testing.md) for the full coverage rationale
- No sustained load testing at the stated 100 req/s peak (explicitly out of
  scope per the exercise)
- Business logic is intentionally a stub (`processOrder` always "confirms" the
  order unless `simulateFailure` is set) — the exercise asked for infra/ops
  quality, not real order-fulfillment logic

## Demo: normal operation

See "Testing it" above — submit, retry (idempotency), check status.

## Demo: failure + recovery

Full step-by-step with exact commands: [docs/runbook.md](docs/runbook.md#failure--recovery-demo).

Summary: submit an order with `"simulateFailure": true` → it retries 3 times
over ~90s → lands in the dead-letter queue → gets automatically marked
`FAILED`. To recover: flip `simulateFailure` to `false` on the DynamoDB record,
redrive the DLQ message back onto the main queue, and the worker completes it
successfully — `status` moves to `COMPLETED`.
