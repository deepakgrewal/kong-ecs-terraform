# Kong Gateway on AWS ECS
# Connects to Kong Konnect control plane

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "${var.project_name}-kong"
  common_tags = {
    Project     = "${var.project_name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

#------------------------------------------------------------------------------
# VPC and Networking
#------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "public"
  })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "private"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Kong ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for Kong ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Kong Proxy HTTP"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Kong Proxy HTTPS"
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Kong Status (health check)"
    from_port       = 8100
    to_port         = 8100
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (for Konnect connection)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })
}

#------------------------------------------------------------------------------
# IAM Roles
#------------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ssm_read" {
  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = [
      aws_ssm_parameter.kong_cert.arn,
      aws_ssm_parameter.kong_key.arn
    ]
  }
}

resource "aws_iam_role_policy" "ssm_read" {
  name   = "ssm-read-kong-certs"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ssm_read.json
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Secrets (SSM Parameter Store)
#------------------------------------------------------------------------------

resource "aws_ssm_parameter" "kong_cert" {
  name        = "/${local.name_prefix}/cluster_cert"
  description = "Kong Konnect data plane certificate"
  type        = "SecureString"
  value       = file("${path.module}/certs/tls.crt")

  tags = local.common_tags
}

resource "aws_ssm_parameter" "kong_key" {
  name        = "/${local.name_prefix}/cluster_key"
  description = "Kong Konnect data plane private key"
  type        = "SecureString"
  value       = file("${path.module}/certs/tls.key")

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# CloudWatch Logs
#------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "kong" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 7

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# ECS Cluster
#------------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

#------------------------------------------------------------------------------
# ECS Task Definition
#------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "kong" {
  family                   = "${local.name_prefix}-dp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "kong"
    image = "kong/kong-gateway:${var.kong_image_tag}"

    portMappings = [
      { containerPort = 8000, protocol = "tcp" },
      { containerPort = 8443, protocol = "tcp" }
    ]

    environment = [
      { name = "KONG_ROLE", value = "data_plane" },
      { name = "KONG_DATABASE", value = "off" },
      { name = "KONG_KONNECT_MODE", value = "on" },
      { name = "KONG_CLUSTER_MTLS", value = "pki" },
      { name = "KONG_CLUSTER_CONTROL_PLANE", value = var.konnect_cp_endpoint },
      { name = "KONG_CLUSTER_SERVER_NAME", value = var.konnect_cp_server_name },
      { name = "KONG_CLUSTER_TELEMETRY_ENDPOINT", value = var.konnect_telemetry_endpoint },
      { name = "KONG_CLUSTER_TELEMETRY_SERVER_NAME", value = var.konnect_telemetry_server_name },
      { name = "KONG_LUA_SSL_TRUSTED_CERTIFICATE", value = "system" },
      { name = "KONG_CLUSTER_DP_LABELS", value = "deployment:ecs,env:${var.environment},client:${var.project_name}" },
      { name = "KONG_VITALS", value = "off" },
      { name = "KONG_STATUS_LISTEN", value = "0.0.0.0:8100" }
    ]

    secrets = [
      { name = "KONG_CLUSTER_CERT", valueFrom = aws_ssm_parameter.kong_cert.arn },
      { name = "KONG_CLUSTER_CERT_KEY", valueFrom = aws_ssm_parameter.kong_key.arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.kong.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "kong"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "kong health"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Application Load Balancer
#------------------------------------------------------------------------------

resource "aws_lb" "kong" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = local.common_tags
}

resource "aws_lb_target_group" "kong" {
  name        = "${local.name_prefix}-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    path                = "/status"
    port                = "8100"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.kong.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong.arn
  }

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# ECS Service
#------------------------------------------------------------------------------

resource "aws_ecs_service" "kong" {
  name            = "${local.name_prefix}-dp"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.kong.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kong.arn
    container_name   = "kong"
    container_port   = 8000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = local.common_tags

  depends_on = [aws_lb_listener.http]
}
