# Signify POC - Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "kong_alb_dns" {
  description = "Kong ALB DNS name (use this to access Kong Gateway)"
  value       = aws_lb.kong.dns_name
}

output "kong_endpoint" {
  description = "Kong Gateway endpoint URL"
  value       = "http://${aws_lb.kong.dns_name}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Kong logs"
  value       = aws_cloudwatch_log_group.kong.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.kong.name
}
