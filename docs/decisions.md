# Decisions, assumptions, and tradeoffs

## Assumptions

- "Downstream processing" is simulated inside `processOrder` (a `simulateFailure`
  flag on the order record) rather than calling a real external system — the
  exercise says business logic can be simple and this is what's being evaluated
  is the infra/ops behavior around that call, not the call itself.
- A client-generated `orderId` (UUID) is the idempotency key. This is the most
  common real-world pattern (client generates it once, reuses it across retries)
  and avoids needing a separate `Idempotency-Key` header.
- Single AWS account, single region (`us-east-1`), no multi-AZ discussion beyond
  what the managed services (DynamoDB, SQS, Lambda, API Gateway) already provide
  by default — explicitly out of scope per the exercise.

## Key tradeoffs

**IAM permissions are broader than strict least-privilege.** `terraform-deployer`
and the GitHub Actions deploy role both have `AdministratorAccess`; the four
Lambda execution roles are scoped tightly (only the specific DynamoDB/SQS actions
each function needs). The deploy-time identities are broad because this is a
single-purpose, throwaway AWS account and Terraform needs IAM/service permissions
across the stack to manage it — scoping those down to a custom policy would be a
lot of policy code for a security boundary that doesn't really exist here (nothing
else runs in this account). The Lambda *runtime* roles are the security boundary
that actually matters in production (they're what an attacker exploiting the
running service would have), so that's where the tightening effort went.

**No DynamoDB lock table for Terraform state** — using S3's native locking
(`use_lockfile = true`, Terraform ≥1.10) instead of the older DynamoDB-table
pattern. One fewer resource to create/secure/pay for, same guarantee.

**HTTP API (API Gateway v2), not REST API (v1).** Cheaper, lower latency, and
this service doesn't need REST API's request/response transformation, WAF
integration, or usage-plan features.

**SQS + Lambda, not Step Functions or a durable workflow engine.** The processing
here is a single step (validate → "call downstream" → record result). A workflow
orchestrator would be the right call if there were multiple sequential steps
needing individual retry/compensation logic — that's not the case here, and it
would be complexity without payoff.

**esbuild bundling instead of shipping `node_modules`.** Each Lambda zip is
~500-600KB instead of tens of MB, faster cold starts, and it pins the exact AWS
SDK version rather than depending on whatever the Lambda Node 20 runtime happens
to bundle.

## Known limitations / what's incomplete

- No authentication/authorization on the API — anyone with the URL can submit
  orders. Out of scope per the exercise, but the first thing to add before any
  real traffic (API Gateway authorizer + API keys or Cognito).
- No automated integration test hits the *deployed* API — tests mock the AWS SDK
  and run against handler code directly. A `curl`-based smoke test against the
  live endpoint (matching the manual verification done during deployment) would
  close that gap; see [testing.md](testing.md) for what's covered vs. not.
- `processOrder`'s "business logic" is a hardcoded success payload — intentionally
  simple per the exercise's scope.

## Evolving under substantially higher traffic

- **DynamoDB** is already on-demand, so it scales automatically; at sustained
  high volume, switch to provisioned capacity with auto-scaling once the traffic
  shape is predictable (cheaper at scale than on-demand).
- **Lambda concurrency**: set a reserved/provisioned concurrency floor on
  `submitOrder` and `processOrder` to avoid cold-start latency spikes under
  sustained load; watch account-level concurrent-execution limits.
- **SQS** already absorbs bursts well past 100 req/s without changes — it's
  designed for much higher throughput than this service needs.
- **API Gateway throttling** (`throttling_rate_limit`) would need raising in
  lockstep with real traffic growth, and probably per-client rate limiting
  (usage plans / API keys) once there are multiple restaurant clients sharing
  the API.
- At meaningfully higher scale, the "single Lambda per concern" model would
  start to show its cold-start tax under bursty traffic; a long-running
  container-based worker (ECS/Fargate) polling SQS directly could take over
  from `processOrder` while the API-facing Lambdas stay serverless.
