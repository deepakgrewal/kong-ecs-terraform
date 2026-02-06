# Kong Gateway on ECS - Variables

#------------------------------------------------------------------------------
# Project Configuration
#------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming (e.g., 'mycompany' creates 'mycompany-kong-vpc')"
  type        = string
  default     = "kong-demo"
}

variable "environment" {
  description = "Environment name (e.g., poc, dev, prod)"
  type        = string
  default     = "poc"
}

#------------------------------------------------------------------------------
# AWS Configuration
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

#------------------------------------------------------------------------------
# Konnect Configuration
#------------------------------------------------------------------------------

variable "konnect_cp_endpoint" {
  description = "Konnect control plane endpoint (e.g., abc123.eu.cp0.konghq.com:443)"
  type        = string
}

variable "konnect_cp_server_name" {
  description = "Konnect control plane server name (e.g., abc123.eu.cp0.konghq.com)"
  type        = string
}

variable "konnect_telemetry_endpoint" {
  description = "Konnect telemetry endpoint (e.g., abc123.eu.tp0.konghq.com:443)"
  type        = string
}

variable "konnect_telemetry_server_name" {
  description = "Konnect telemetry server name (e.g., abc123.eu.tp0.konghq.com)"
  type        = string
}

#------------------------------------------------------------------------------
# AWS Secrets Manager (Kong Vault Backend)
#------------------------------------------------------------------------------

variable "secrets_manager_arns" {
  description = "ARNs of AWS Secrets Manager secrets that Kong can access (for vault backend). Use wildcards for patterns, e.g., arn:aws:secretsmanager:eu-west-1:123456789:secret:kong-*"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Amazon Bedrock (AI Gateway)
#------------------------------------------------------------------------------

variable "bedrock_model_arns" {
  description = "ARNs of Bedrock models that Kong can invoke (for AI Gateway). Use wildcards for all models in a region, e.g., arn:aws:bedrock:us-east-1::foundation-model/* or specific custom imported models."
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Kong Gateway Configuration
#------------------------------------------------------------------------------

variable "kong_image_tag" {
  description = "Kong Gateway image tag"
  type        = string
  default     = "3.9.0.0"
}

#------------------------------------------------------------------------------
# ECS Configuration
#------------------------------------------------------------------------------

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory (MB) for ECS task"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of Kong data plane instances"
  type        = number
  default     = 2
}
