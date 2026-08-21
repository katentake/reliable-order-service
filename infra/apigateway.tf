resource "aws_apigatewayv2_api" "orders" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.orders.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLatency  = "$context.responseLatency"
      integrationError = "$context.integration.error"
    })
  }

  default_route_settings {
    # Stated peak is ~100 orders/sec; this protects the backend and cost from
    # runaway traffic beyond that without needing sustained load testing to size it.
    throttling_burst_limit = 200
    throttling_rate_limit  = 100
  }
}

resource "aws_apigatewayv2_integration" "submit_order" {
  api_id                 = aws_apigatewayv2_api.orders.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.submit_order.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "submit_order" {
  api_id    = aws_apigatewayv2_api.orders.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.submit_order.id}"
}

resource "aws_lambda_permission" "api_submit_order" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_order.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.orders.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "get_order_status" {
  api_id                 = aws_apigatewayv2_api.orders.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_order_status.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_order_status" {
  api_id    = aws_apigatewayv2_api.orders.id
  route_key = "GET /orders/{orderId}"
  target    = "integrations/${aws_apigatewayv2_integration.get_order_status.id}"
}

resource "aws_lambda_permission" "api_get_order_status" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_order_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.orders.execution_arn}/*/*"
}
