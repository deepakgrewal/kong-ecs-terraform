# ECS Bedrock Authentication

Authenticate Kong AI Gateway to Amazon Bedrock using IAM roles instead of API keys.

## Two Approaches

| Approach | Auth | Best For |
|----------|------|----------|
| **A: ECS task role** (active) | SigV4 via AWS credential chain | Same-account — no keys to manage |
| **B: Assume role** (commented) | STS AssumeRole | Cross-account Bedrock access |

## Terraform Setup

Enable Bedrock access in `terraform.tfvars`:

```hcl
bedrock_model_arns = [
  "arn:aws:bedrock:us-east-1::foundation-model/*",
  "arn:aws:bedrock:us-west-2::foundation-model/*"
]
```

Apply: `terraform apply`

This grants `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` to the ECS task role.

## Deploy

```bash
deck gateway sync use-cases/ecs-bedrock-auth/config.yaml
```

## Test

```bash
curl -X POST http://KONG_HOST/ai/bedrock -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

## Version Requirement

Kong Gateway >= 3.13.0.0. Earlier versions have a bug where instance role credentials override plugin-level credentials.

## Cross-Account (Approach B)

Prerequisites:
- ECS task role must have `sts:AssumeRole` on the target role ARN
- Target role must trust the ECS task role
- Target role needs `bedrock:InvokeModel` permissions

Uncomment Approach B in `config.yaml` and replace the target role ARN.

## Cleanup

```bash
deck gateway reset --select-tag ecs-bedrock-auth --force
```
