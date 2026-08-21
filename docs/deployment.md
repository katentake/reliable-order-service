# Deployment

## One-time bootstrap (creates the Terraform remote state bucket)

```bash
cd infra/bootstrap
terraform init
terraform apply
```

Note the `init_command` output — it has the exact `terraform init` command for the
main config, including the generated state bucket name.

## Main deployment

```bash
npm ci
npm run build          # esbuild bundles app/dist/*.js used by infra/lambda.tf

cd infra
terraform init \
  -backend-config="bucket=<state_bucket from bootstrap output>" \
  -backend-config="use_lockfile=true" \
  -backend-config="region=us-east-1"

cp terraform.tfvars.example terraform.tfvars   # set alert_email
terraform plan
terraform apply
```

`terraform output api_url` gives the deployed API base URL.

## CI/CD

GitHub Actions authenticates to AWS via OIDC (`infra/github-oidc.tf`) — no long-lived
AWS keys are stored in the repo. Required repo variables (`gh variable set ...`):

- `AWS_DEPLOY_ROLE_ARN` — from `terraform output github_actions_role_arn`
- `AWS_REGION`
- `TF_STATE_BUCKET`
- `ALERT_EMAIL`

- `.github/workflows/pr-check.yml` — build, test, `terraform plan` on pull requests
- `.github/workflows/deploy.yml` — build, test, `terraform apply` on push to `main`

## Teardown

```bash
cd infra
terraform destroy

cd ../infra/bootstrap
terraform destroy   # only once nothing else references the state bucket
```
