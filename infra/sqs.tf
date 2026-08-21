resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${local.name_prefix}-orders-dlq"
  message_retention_seconds = 1209600 # 14 days — max window to notice and redrive a failure
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name_prefix}-orders"
  visibility_timeout_seconds = 30     # >= processOrder Lambda timeout, so a slow invoke isn't redelivered mid-flight
  message_retention_seconds  = 345600 # 4 days
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })
}
