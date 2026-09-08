# Cost

## Safeguards already in place

- **AWS Budget** (console, $20/month) with email alerts at 50/80/100% — set up
  during account bootstrap, before any infra existed.
- **Billing alerts** enabled at the account level.
- **API Gateway throttling** (`throttling_rate_limit = 100`, `throttling_burst_limit = 200`)
  caps how much traffic can reach — and bill for — the backend, independent of
  what's actually sent at it.
- Every resource is tagged `Project = palona-order-svc` via `default_tags`, so
  Cost Explorer can filter to exactly this exercise's spend.
- CloudWatch Logs retention is capped at 14 days on every log group (default
  Lambda-created log groups retain forever otherwise).

## Expected cost

At the stated traffic (~5 orders/min baseline, occasional bursts to 100/s, no
sustained load testing), this is effectively a **free-tier / near-$0 workload**:

| Service | Pricing model | Expected cost |
|---|---|---|
| Lambda | Free tier: 1M requests + 400,000 GB-seconds/month | $0 |
| API Gateway (HTTP API) | $1.00 / million requests | ~$0 (thousands of requests, not millions) |
| DynamoDB (on-demand) | Free tier: 25 GB storage, 2.5M read/write units/month | $0 |
| SQS | Free tier: 1M requests/month | $0 |
| CloudWatch Logs/Alarms | ~$0.30/GB ingested, first 10 alarms free | $0 |
| SNS | Free tier: 1,000 email notifications/month | $0 |
| S3 (Terraform state) | Negligible — one small file, versioned | ~$0.01 |

**Total: effectively $0/month** at this traffic level — confirmed against Cost
Explorer, actual spend since deployment has been ~$0.00. Everything stays
inside AWS free-tier allowances. The one deliberately-avoided line item: a
`aws_cloudwatch_dashboard` was in an earlier iteration ($3/month flat fee,
charged regardless of usage — the only non-usage-based cost in the whole
stack) and was removed once the takeaway traffic didn't justify it; the 3
alarms plus each service's own built-in CloudWatch console view give the same
visibility without a standing charge.

## What could cause unexpected spending

- **A retry storm or bug that loops `submitOrder`↔`processOrder`** without ever
  reaching a terminal state — bounded by the DLQ (`maxReceiveCount = 3`), so
  this caps at 3x cost per message, not unbounded.
- **Someone hammering the public API endpoint** — mitigated by the 100 req/s
  throttle, but sustained abuse at that ceiling for a long period would still
  cost real money (Lambda invocations + DynamoDB writes). Out of scope for this
  exercise, but the real fix is an API key / usage plan or WAF rate-based rule.
- **CloudWatch Logs left at infinite retention** — avoided here (14-day retention
  set explicitly on every log group), but easy to forget if new Lambdas are
  added without copying that pattern.
- **Forgetting to `terraform destroy`** after the exercise is done — this is a
  fully serverless stack with no idle compute cost, so leaving it running costs
  single-digit dollars a month rather than the $50+/month an ALB + Fargate
  approach would leave behind. Still worth tearing down; see
  [deployment.md](deployment.md#teardown).
