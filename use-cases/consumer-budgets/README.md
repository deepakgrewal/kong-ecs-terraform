# Scenario 3: Consumer Token Budgets

Daily token limits per consumer tier using AI Rate Limiting Advanced.

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
        ├── Budget OK ──────► Forward to OpenAI
        │
        └── Budget Exceeded ─► HTTP 429 (Too Many Requests)
```

**Key features:**
- Token-based limiting (not request count)
- Counts both prompt and completion tokens
- 24-hour rolling window (`window_size: 86400`)
- Local strategy (no Redis required for POC)

## Prerequisites

1. OpenAI API key
2. Kong Gateway with AI plugins enabled

## Setup

### 1. Configure API Key

Edit `config.yaml` and replace:
```yaml
header_value: "Bearer sk-your-openai-key"
```

### 2. Deploy to Konnect

```bash
# From project root
export KONNECT_PAT=$(grep "^KONNECT_PAT=" .konnect.env | cut -d'=' -f2 | tr -d '"')

deck gateway sync clients/signify/3-consumer-budgets/config.yaml
```

## Testing

### Test each tier

```bash
# Basic tier (10K daily limit)
curl -X POST http://localhost:8000/ai/budget \
  -H "Content-Type: application/json" \
  -H "apikey: dev-team-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'

# Premium tier (50K daily limit)
curl -X POST http://localhost:8000/ai/budget \
  -H "Content-Type: application/json" \
  -H "apikey: analytics-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'

# Enterprise tier (200K daily limit)
curl -X POST http://localhost:8000/ai/budget \
  -H "Content-Type: application/json" \
  -H "apikey: production-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

### Check rate limit headers

```bash
curl -X POST http://localhost:8000/ai/budget \
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
curl -X POST http://localhost:8000/ai/budget \
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
- **Token counting**: Uses OpenAI's tiktoken for accurate token estimation.
