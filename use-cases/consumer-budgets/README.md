# Consumer Token Budgets

Daily token limits per consumer tier using AI Rate Limiting Advanced with AWS Bedrock.

## Token Budget Tiers

| Tier | Consumer | Daily Limit | Use Case |
|------|----------|-------------|----------|
| Basic | signify-dev-team | 10,000 tokens | Development/testing |
| Premium | signify-analytics | 50,000 tokens | Analytics workloads |
| Enterprise | signify-production | 200,000 tokens | Production apps |

## How It Works

```
Request with API Key
        │
        ▼
┌───────────────────┐
│    Key Auth       │ ──► Identify Consumer
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  Consumer Group   │ ──► signify-basic / premium / enterprise
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│ AI Rate Limiting  │ ──► Check daily token budget
│    Advanced       │
└───────┬───────────┘
        │
        ├── Budget OK ──────► Forward to Bedrock (Claude 3 Haiku)
        │
        └── Budget Exceeded ─► HTTP 429 (Too Many Requests)
```

**Key features:**
- Token-based limiting (not request count)
- Counts both prompt and completion tokens
- 24-hour rolling window (`window_size: 86400`)
- Local strategy (no Redis required for POC)
- Uses Claude 3 Haiku for cost-effective usage

## Prerequisites

1. AWS account with Bedrock access enabled
2. Model access granted for Claude 3 Haiku in us-east-1
3. IAM permissions: `bedrock:InvokeModel`

## Setup

### 1. Configure AWS Credentials

```bash
export DECK_AWS_ACCESS_KEY_ID="your-access-key"
export DECK_AWS_SECRET_ACCESS_KEY="your-secret-key"
```

### 2. Deploy to Konnect

```bash
# From use-cases/consumer-budgets directory
deck gateway sync config.yaml
```

## Testing

### Get Kong endpoint

```bash
KONG_HOST=$(cd ../.. && terraform output -raw kong_endpoint)
```

### Test each tier

```bash
# Basic tier (10K daily limit)
curl -X POST "${KONG_HOST}/ai/budget" \
  -H "Content-Type: application/json" \
  -H "apikey: dev-team-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'

# Premium tier (50K daily limit)
curl -X POST "${KONG_HOST}/ai/budget" \
  -H "Content-Type: application/json" \
  -H "apikey: analytics-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'

# Enterprise tier (200K daily limit)
curl -X POST "${KONG_HOST}/ai/budget" \
  -H "Content-Type: application/json" \
  -H "apikey: production-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

Or use the test scripts:

```bash
cd ../../test
./test-budgets.sh
```

### Check rate limit headers

```bash
curl -X POST "${KONG_HOST}/ai/budget" \
  -H "Content-Type: application/json" \
  -H "apikey: dev-team-key" \
  -d '{"messages": [{"role": "user", "content": "Hello"}]}' \
  -v 2>&1 | grep -i ratelimit
```

Expected headers:
- `X-RateLimit-Limit-*` - Total budget
- `X-RateLimit-Remaining-*` - Tokens remaining
- `X-RateLimit-Reset-*` - When budget resets (epoch)

### Exhaust budget (for demo)

Use a prompt that consumes many tokens:

```bash
curl -X POST "${KONG_HOST}/ai/budget" \
  -H "Content-Type: application/json" \
  -H "apikey: dev-team-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Write a 2000 word essay about renewable energy."}
    ]
  }'
```

Repeat until you see HTTP 429 response.

## Response When Budget Exceeded

```json
{
  "message": "API rate limit exceeded"
}
```

HTTP Status: `429 Too Many Requests`

## Cleanup

```bash
deck gateway reset --select-tag signify-demo --force
```

## Notes

- **Local strategy**: Token counts are per Kong node. For distributed counting across multiple nodes, switch to Redis strategy.
- **Window reset**: Budget resets 24 hours after first request, not at midnight.
- **Token counting**: Uses standardized token counting for Bedrock models.
