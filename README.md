# Kong Gateway on AWS ECS

Deploy Kong Gateway data plane on AWS ECS Fargate, connected to Kong Konnect.

## Architecture

```
                    ┌─────────────────────────────────────────────────────┐
                    │                   Kong Konnect                       │
                    │              (Control Plane - Demo)                  │
                    └─────────────────────────┬───────────────────────────┘
                                              │ mTLS
                    ┌─────────────────────────┼───────────────────────────┐
                    │                   AWS VPC                            │
                    │                                                      │
                    │  ┌──────────────────────────────────────────────┐   │
                    │  │            Public Subnets (2 AZs)             │   │
                    │  │  ┌────────────────────────────────────────┐  │   │
Internet ──────────►│  │  │     Application Load Balancer          │  │   │
        :80/:443    │  │  └────────────────────┬───────────────────┘  │   │
                    │  └───────────────────────┼──────────────────────┘   │
                    │                          │ :8000                     │
                    │  ┌───────────────────────┼──────────────────────┐   │
                    │  │           Private Subnets (2 AZs)            │   │
                    │  │  ┌────────────────────▼───────────────────┐  │   │
                    │  │  │          ECS Fargate Service           │  │   │
                    │  │  │  ┌────────────┐  ┌────────────┐        │  │   │
                    │  │  │  │ Kong DP #1 │  │ Kong DP #2 │        │  │   │
                    │  │  │  └────────────┘  └────────────┘        │  │   │
                    │  │  └────────────────────────────────────────┘  │   │
                    │  └──────────────────────────────────────────────┘   │
                    └─────────────────────────────────────────────────────┘
```

## Use Cases

Once your Kong Gateway is running on ECS, you can deploy these AI Gateway configurations:

| Use Case | Description |
|----------|-------------|
| [AI Gateway Failover](use-cases/ai-gateway-failover/) | Bedrock Claude 3.5 Sonnet (us-east-1) with cross-region failover to Claude 3 Haiku (us-west-2) |
| [Consumer Token Budgets](use-cases/consumer-budgets/) | Daily token limits per consumer tier using Bedrock |
| [Header Rate Limiting](use-cases/header-rate-limiting/) | Per-user, per-agent rate limiting via custom header |
| [AWS Secrets Manager](use-cases/aws-secrets-manager/) | Store API keys in AWS Secrets Manager with vault references |
| [Custom OpenAI Endpoints](use-cases/custom-openai-endpoints/) | Route to OpenAI-compatible endpoints (Bedrock Access Gateway, etc.) |
| [ECS Bedrock Auth](use-cases/ecs-bedrock-auth/) | IAM-based Bedrock authentication (task role or cross-account) |

Each use case includes a `config.yaml` that can be deployed with `deck gateway sync`.

### Deploy Use Cases

```bash
# Set AWS credentials for deck
export DECK_AWS_ACCESS_KEY_ID="your-access-key"
export DECK_AWS_SECRET_ACCESS_KEY="your-secret-key"

# Deploy failover config
deck gateway sync use-cases/ai-gateway-failover/config.yaml

# Deploy budget config
deck gateway sync use-cases/consumer-budgets/config.yaml
```

### Test Scripts

Test scripts are in the `test/` directory:

```bash
cd test

# Get Kong endpoint from terraform
export KONG_HOST=$(cd .. && terraform output -raw kong_endpoint)

# Test failover
./test-failover.sh

# Test all budget tiers
./test-budgets.sh

# Show rate limit headers
./test-rate-limits.sh

# Exhaust budget (trigger 429)
./test-exhaust-budget.sh
```

## Prerequisites

1. AWS account with permissions for VPC, ECS, ALB, IAM, SSM
2. Terraform >= 1.0
3. Kong Konnect account

## Setup

### 1. Get Konnect Certificates

The easiest way to generate certificates is through the Konnect UI:

1. Log in to [Kong Konnect](https://cloud.konghq.com)
2. Go to **API Gateway** > Select your Control Plane
3. Click **Data Plane Nodes** in the left sidebar
4. Click **New Data Plane Node**
5. Select your Gateway version and deployment type (e.g., Mac/Docker)
6. Click the **"Generate certificate and script"** button

![Generate Certificates in Konnect](images/konnect-generate-certificates.png)

7. Copy the generated certificate and private key
8. Save them to:
   - `certs/tls.crt` - Certificate (the `cluster_cert` value)
   - `certs/tls.key` - Private key (the `cluster_cert_key` value)

Also copy the **control plane endpoint** and **telemetry endpoint** values - you'll need these for the next step.

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Konnect endpoints (from the same Data Plane Node page).

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify

```bash
# Get the ALB URL
terraform output kong_endpoint

# Test Kong Gateway
curl $(terraform output -raw kong_endpoint)/status
```

The data plane should appear in Konnect under **Gateway Manager** > **Demo** > **Data Plane Nodes**.

## Optional: AWS Secrets Manager

Enable Kong to fetch secrets from AWS Secrets Manager at runtime.

1. Add secret ARNs to `terraform.tfvars`:
   ```hcl
   secrets_manager_arns = [
     "arn:aws:secretsmanager:eu-west-1:123456789012:secret:kong-demo/*"
   ]
   ```

2. Apply: `terraform apply`

3. See [use-cases/aws-secrets-manager/](use-cases/aws-secrets-manager/) for the Kong config.

## Optional: Amazon Bedrock

Enable Kong to call Bedrock models using the ECS task role (no API keys).

1. Add model ARNs to `terraform.tfvars`:
   ```hcl
   bedrock_model_arns = [
     "arn:aws:bedrock:us-east-1::foundation-model/*"
   ]
   ```

2. Apply: `terraform apply`

3. See [use-cases/ecs-bedrock-auth/](use-cases/ecs-bedrock-auth/) for the Kong config.

## Resources Created

| Resource | Description |
|----------|-------------|
| VPC | 10.0.0.0/16 with 2 public + 2 private subnets |
| Internet Gateway | For public subnet internet access |
| NAT Gateway | For private subnet outbound access |
| ALB | Application Load Balancer (public) |
| ECS Cluster | Fargate cluster |
| ECS Service | 2 Kong data plane tasks |
| Security Groups | ALB (80/443), ECS (8000/8443) |
| IAM Roles | Task execution + task roles |
| IAM Policy | Secrets Manager access (optional) |
| IAM Policy | Bedrock invoke (optional) |
| SSM Parameters | Certificate storage (encrypted) |
| CloudWatch Logs | /ecs/{project_name}-kong |

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### Data plane not connecting to Konnect

1. Check CloudWatch logs:
   ```bash
   aws logs tail /ecs/{project_name}-kong --follow
   ```

2. Verify certificates are correct (common issue: wrong format or expired)

3. Ensure NAT Gateway allows outbound 443 to Konnect

### Health checks failing

1. Verify security group allows ALB to reach ECS on port 8100 (status endpoint)
2. Check Kong is starting properly in logs
