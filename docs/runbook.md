# Runbook

## Health check

- **Alarms**: `terraform output alarms_url` — the 3 alarms (DLQ not empty,
  processOrder errors, API 5xx). No standing dashboard (it's the one resource
  in this stack billed as a flat fee regardless of usage — see
  [cost.md](cost.md)); for a visual view, each service's own CloudWatch console
  page works fine: Lambda's "Monitor" tab, the SQS queue's "Monitoring" tab,
  API Gateway's built-in dashboard.
- **Quick CLI check**:
  ```bash
  aws sqs get-queue-attributes --queue-url <orders_dlq_url> \
    --attribute-names ApproximateNumberOfMessages
  ```
  Non-zero means something is stuck and failing permanently.

## Investigating a problem

1. Find the order: `GET /orders/{orderId}` — check `status`, `attempts`, `error`.
2. Pull logs for the relevant Lambda:
   ```bash
   aws logs tail /aws/lambda/palona-order-svc-process-order --since 1h --follow
   ```
3. X-Ray tracing is enabled on the API-facing and worker Lambdas (`tracing_config { mode = "Active" }`)
   for tracing a single request through API Gateway → Lambda → downstream calls.
4. Check the CloudWatch alarms (`dlq-not-empty`, `process-order-errors`, `api-5xx`) —
   they email `alert_email` via SNS when tripped.

## Failure + recovery demo

This walks through the exact scenario the exercise asks for: a meaningful failure,
followed by recovery.

**1. Submit an order that will fail:**

```bash
API_URL=$(terraform -chdir=infra output -raw api_url)
ORDER_ID=$(uuidgen | tr 'A-Z' 'a-z')

curl -X POST "$API_URL/orders" -H 'content-type: application/json' -d "{
  \"orderId\": \"$ORDER_ID\",
  \"restaurantId\": \"restaurant-1\",
  \"items\": [{\"name\": \"Burger\", \"quantity\": 1}],
  \"simulateFailure\": true
}"
```

**2. Watch it fail and land in the DLQ** (takes ~90s: 3 receive attempts × 30s
visibility timeout):

```bash
watch -n 5 "curl -s $API_URL/orders/$ORDER_ID"
```

Status moves `PENDING` → `PROCESSING` (repeated, once per retry) → `FAILED`, with
`error: "Exhausted retries; moved to dead-letter queue"`.

**3. Recover it.** Flip the failure flag on the record directly (the SQS message body
only ever carried the `orderId`, so the worker will re-read this on redrive):

```bash
aws dynamodb update-item \
  --table-name palona-order-svc-orders \
  --key "{\"orderId\": {\"S\": \"$ORDER_ID\"}}" \
  --update-expression "SET simulateFailure = :f" \
  --expression-attribute-values '{":f": {"BOOL": false}}'
```

**4. Redrive the DLQ message back onto the main queue:**

```bash
aws sqs start-message-move-task \
  --source-arn "$(aws sqs get-queue-attributes \
      --queue-url <orders_dlq_url> --attribute-names QueueArn \
      --query 'Attributes.QueueArn' --output text)"
```

**5. Confirm recovery:**

```bash
curl -s "$API_URL/orders/$ORDER_ID"
# status: COMPLETED
```

## Known limitations

- `handleFailedOrder` marks an order `FAILED` but doesn't page anyone by itself —
  the `dlq-not-empty` CloudWatch alarm is what notifies a human.
- No automatic retry-with-backoff beyond SQS's own redelivery — a permanently
  failing downstream dependency needs a human to redrive (by design, so a bad
  deploy can't silently retry-loop forever on someone else's system).
- Redrive replays the original message as-is; if the record was deleted between
  failure and redrive, `processOrder` logs and drops it rather than erroring.
