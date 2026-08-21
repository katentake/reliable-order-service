data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- submitOrder: writes new orders, enqueues them ---------------------------

resource "aws_iam_role" "submit_order" {
  name               = "${local.name_prefix}-submit-order"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "submit_order_logs" {
  role       = aws_iam_role.submit_order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "submit_order" {
  name = "submit-order-access"
  role = aws_iam_role.submit_order.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.orders.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.orders.arn
      },
    ]
  })
}

# --- getOrderStatus: read-only lookups ---------------------------------------

resource "aws_iam_role" "get_order_status" {
  name               = "${local.name_prefix}-get-order-status"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "get_order_status_logs" {
  role       = aws_iam_role.get_order_status.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "get_order_status" {
  name = "get-order-status-access"
  role = aws_iam_role.get_order_status.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = aws_dynamodb_table.orders.arn
      },
    ]
  })
}

# --- processOrder: consumes the main queue, does the "business logic" -------

resource "aws_iam_role" "process_order" {
  name               = "${local.name_prefix}-process-order"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "process_order_logs" {
  role       = aws_iam_role.process_order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "process_order" {
  name = "process-order-access"
  role = aws_iam_role.process_order.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.orders.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders.arn
      },
    ]
  })
}

# --- handleFailedOrder: consumes the DLQ, marks orders FAILED ---------------

resource "aws_iam_role" "handle_failed_order" {
  name               = "${local.name_prefix}-handle-failed-order"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "handle_failed_order_logs" {
  role       = aws_iam_role.handle_failed_order.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "handle_failed_order" {
  name = "handle-failed-order-access"
  role = aws_iam_role.handle_failed_order.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.orders.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders_dlq.arn
      },
    ]
  })
}
