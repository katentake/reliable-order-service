# Deployment packages are built by `npm run build` (esbuild output in app/dist/)
# before `terraform apply` runs — see docs/deployment.md.

data "archive_file" "submit_order" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/submitOrder.js"
  output_path = "${path.module}/build/submitOrder.zip"
}

data "archive_file" "get_order_status" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/getOrderStatus.js"
  output_path = "${path.module}/build/getOrderStatus.zip"
}

data "archive_file" "process_order" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/processOrder.js"
  output_path = "${path.module}/build/processOrder.zip"
}

data "archive_file" "handle_failed_order" {
  type        = "zip"
  source_file = "${path.module}/../app/dist/handleFailedOrder.js"
  output_path = "${path.module}/build/handleFailedOrder.zip"
}

resource "aws_cloudwatch_log_group" "submit_order" {
  name              = "/aws/lambda/${local.name_prefix}-submit-order"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "get_order_status" {
  name              = "/aws/lambda/${local.name_prefix}-get-order-status"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "process_order" {
  name              = "/aws/lambda/${local.name_prefix}-process-order"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "handle_failed_order" {
  name              = "/aws/lambda/${local.name_prefix}-handle-failed-order"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "submit_order" {
  function_name    = "${local.name_prefix}-submit-order"
  role             = aws_iam_role.submit_order.arn
  handler          = "submitOrder.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.submit_order.output_path
  source_code_hash = data.archive_file.submit_order.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
      ORDERS_QUEUE_URL  = aws_sqs_queue.orders.url
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.submit_order]
}

resource "aws_lambda_function" "get_order_status" {
  function_name    = "${local.name_prefix}-get-order-status"
  role             = aws_iam_role.get_order_status.arn
  handler          = "getOrderStatus.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.get_order_status.output_path
  source_code_hash = data.archive_file.get_order_status.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.get_order_status]
}

resource "aws_lambda_function" "process_order" {
  function_name    = "${local.name_prefix}-process-order"
  role             = aws_iam_role.process_order.arn
  handler          = "processOrder.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.process_order.output_path
  source_code_hash = data.archive_file.process_order.output_base64sha256
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.process_order]
}

resource "aws_lambda_function" "handle_failed_order" {
  function_name    = "${local.name_prefix}-handle-failed-order"
  role             = aws_iam_role.handle_failed_order.arn
  handler          = "handleFailedOrder.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.handle_failed_order.output_path
  source_code_hash = data.archive_file.handle_failed_order.output_base64sha256
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.handle_failed_order]
}

resource "aws_lambda_event_source_mapping" "process_order" {
  event_source_arn        = aws_sqs_queue.orders.arn
  function_name           = aws_lambda_function.process_order.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "handle_failed_order" {
  event_source_arn = aws_sqs_queue.orders_dlq.arn
  function_name    = aws_lambda_function.handle_failed_order.arn
  batch_size       = 5
}
