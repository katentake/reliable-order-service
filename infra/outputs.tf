output "api_url" {
  description = "Base URL for the order API"
  value       = aws_apigatewayv2_api.orders.api_endpoint
}

output "orders_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "orders_queue_url" {
  value = aws_sqs_queue.orders.url
}

output "orders_dlq_url" {
  value = aws_sqs_queue.orders_dlq.url
}

output "alarms_url" {
  description = "CloudWatch alarms list — the three alarms wired to the alerts@ email"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#alarmsV2:"
}
