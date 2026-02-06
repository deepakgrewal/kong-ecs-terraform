# AWS Secrets Manager as Vault Backend

Store API keys in AWS Secrets Manager and reference them in Kong configuration using vault references.

## How It Works

1. **Vault entity** maps a prefix to AWS Secrets Manager
2. **Vault reference** in Kong config: `{vault://aws-vault/secret-name/key}`
3. **At runtime**: Kong DP authenticates to AWS via IAM task role, fetches the secret, injects it into the request

The Control Plane only stores the vault reference, not the actual secret.

## Prerequisites

1. Enable Secrets Manager access in terraform:
   ```hcl
   secrets_manager_arns = [
     "arn:aws:secretsmanager:eu-west-1:123456789012:secret:kong-demo/*"
   ]
   ```

2. Create the secret in AWS:
   ```bash
   aws secretsmanager create-secret --name kong-demo/openai-api-key --secret-string '{"api-key":"Bearer sk-proj-YOUR_KEY"}' --region eu-west-1
   ```

## Deploy

```bash
deck gateway sync use-cases/aws-secrets-manager/config.yaml
```

## Test

```bash
curl -X POST http://KONG_HOST/ai/vault-demo -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"What is 2+2?"}]}'
```

## Secret Rotation

Update the secret in AWS Secrets Manager. Kong picks up the new value after TTL expires (default: 60s). No config changes needed.

## TTL Settings

| Setting | Description | Value |
|---------|-------------|-------|
| `ttl` | Cache successful lookups | 60s |
| `neg_ttl` | Cache failed lookups | 10s |
| `resurrect_ttl` | Serve stale secret if AWS unreachable | 30s |

For production, use `ttl: 300` (5 min).

## Cleanup

```bash
deck gateway reset --select-tag aws-secrets-manager --force
```
