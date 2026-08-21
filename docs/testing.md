# Testing

## What's covered

**Unit tests** (`npm test`, Vitest + `aws-sdk-client-mock`) — 10 tests across the
three handlers with meaningful logic:

- `submitOrder`: new order accepted + enqueued; duplicate `orderId` returns the
  existing status without re-enqueueing (the idempotency contract); invalid
  payload rejected (400); malformed JSON body rejected (400).
- `getOrderStatus`: found (200), not found (404), missing `orderId` (400).
- `processOrder`: success path updates DynamoDB to `COMPLETED`; `simulateFailure`
  causes a reported batch item failure (so SQS retries just that message); a
  record that no longer exists is dropped rather than retried forever.

**Infra validation** (in `pr-check.yml`, runs on every PR):

- `terraform fmt -check -recursive` — formatting.
- `terraform validate` (implicit in `plan`) — internal consistency, provider
  schema conformance.
- `terraform plan` against the real backend — catches anything that wouldn't
  actually apply (bad references, missing permissions, provider errors) before
  merge.

**End-to-end, done manually against the live deployment** (documented in
[runbook.md](runbook.md)): submit → idempotent retry → status COMPLETED; the
full failure → DLQ → `FAILED` → redrive → `COMPLETED` recovery path.

## What's not covered, and why

- **No automated integration test against the deployed API.** The manual `curl`
  verification in the runbook covers the same paths, but isn't wired into CI.
  Given more time this would be a small script run as a post-deploy CI step
  (submit → poll status → assert `COMPLETED`; submit with `simulateFailure` →
  poll → assert `FAILED`), rather than expanding scope with a full E2E framework
  for a handful of assertions.
- **No load testing at the stated 100 req/s peak** — explicitly out of scope per
  the exercise. SQS and DynamoDB on-demand are both rated well beyond this
  service's stated peak by default, so the risk this would catch is low relative
  to the effort of standing up a load-testing setup for a take-home.
- **No IAM policy linting (e.g. checkov/tfsec)** — the four Lambda roles are
  small and hand-reviewable; a policy scanner would be worth adding once the
  IAM surface grows past what's easy to eyeball.
- **No chaos/fault-injection testing beyond the one deliberate `simulateFailure`
  scenario** — one meaningful failure/recovery path is what the exercise asks
  for; more failure modes (e.g. DynamoDB throttling, Lambda timeout mid-write)
  would be the next things to cover, not the first.
