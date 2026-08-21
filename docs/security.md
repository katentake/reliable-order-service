# Security

## Boundaries and risks considered

| Boundary | Risk | Control |
|---|---|---|
| Public API endpoint | Anyone with the URL can submit/read orders | Out of scope for this exercise (business logic is intentionally simple/public-demo-able); throttling limits abuse blast radius. Next step before real traffic: API Gateway authorizer + API keys or Cognito. |
| AWS account access | Root account compromise | Root MFA enabled, no root access keys, day-to-day work done via a separate IAM admin user (also MFA'd) |
| CI/CD credentials | Long-lived AWS keys leaking from GitHub | GitHub Actions authenticates via OIDC (`infra/github-oidc.tf`) — short-lived tokens, trust scoped to `repo:katentake/reliable-order-service:*`, no AWS access keys stored as GitHub secrets at all |
| Local deploy credentials | `terraform-deployer` access key leaking | Programmatic-only IAM user (no console password); key lives only in the local AWS CLI credential store, never committed or pasted into chat |
| Lambda execution roles | A compromised/buggy function doing more than it should | Each of the 4 Lambda functions has its own IAM role scoped to only the specific DynamoDB/SQS actions and resources it needs (see `infra/iam.tf`) — `submitOrder` can't delete items, `getOrderStatus` can't write, `handleFailedOrder` can't touch the main queue |
| Data at rest | Order data (names, items) stored unencrypted | DynamoDB server-side encryption enabled; SQS managed SSE enabled on both queues |
| Data in transit | Order data intercepted | API Gateway only exposes HTTPS (AWS-managed cert on the default `execute-api` domain) |
| Terraform state | State file (contains resource IDs/ARNs, no secrets by design) exposed | State bucket has public access fully blocked, versioning + SSE enabled |
| Deploy-time IAM | `terraform-deployer` / CI role have `AdministratorAccess` | Deliberate, documented tradeoff for a single-purpose throwaway account — see [decisions.md](decisions.md#key-tradeoffs). The boundary that matters (what a compromised *running* Lambda could do) is tightly scoped instead. |

## What's explicitly not addressed

- No WAF / rate-based blocking beyond API Gateway's built-in throttle — would add
  before handling real restaurant traffic.
- No secrets manager usage — this service has no API keys or credentials to
  store; if a real downstream integration were added, its credentials would go
  in AWS Secrets Manager or SSM Parameter Store (SecureString), not environment
  variables.
- No automated dependency vulnerability scanning (`npm audit` was run manually
  during development, not wired into CI) — would add a `npm audit --audit-level=high`
  step to `pr-check.yml` next.
