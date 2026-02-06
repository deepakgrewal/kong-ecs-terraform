# AI Gateway Failover

AWS Bedrock as primary provider with automatic cross-region failover.

## How Failover Works

```
Request ──► Kong AI Gateway
                │
                ▼
         ┌──────────────┐
         │   Bedrock    │ weight: 1000 (primary)
         │ Claude 3.5   │ us-east-1
         │   Sonnet     │
         └──────┬───────┘
                │ If fails (429, 500, 502, 503, timeout)
                ▼
         ┌──────────────┐
         │   Bedrock    │ weight: 1 (fallback)
         │ Claude 3     │ us-west-2 (cross-region)
         │    Haiku     │
         └──────────────┘
```

**Failover triggers:**
- `error` - Connection/network errors
- `timeout` - Request timeout
- `http_429` - Rate limited / throttled by Bedrock
- `http_500/502/503` - Server errors

**Behavior:**
- Primary (Claude 3.5 Sonnet, us-east-1) is tried first due to higher weight (1000 vs 1)
- After 2 consecutive failures (`max_fails: 2`), target marked unhealthy
- Unhealthy target reconsidered after 30 seconds (`fail_timeout: 30000`)
- Up to 3 retry attempts per request (`retries: 3`)

## Prerequisites

1. AWS account with Bedrock access enabled
2. Model access granted for Claude models in both us-east-1 and us-west-2
3. IAM permissions: `bedrock:InvokeModel` on the model ARNs

## Setup

### 1. Configure AWS Credentials

Set environment variables for deck to use:

```bash
export DECK_AWS_ACCESS_KEY_ID="your-access-key"
export DECK_AWS_SECRET_ACCESS_KEY="your-secret-key"
```

Or if using IAM roles (recommended for ECS), the ECS task role will be used automatically.

### 2. Deploy to Konnect

```bash
# From use-cases/ai-gateway-failover directory
deck gateway sync config.yaml
```

### 3. Test

```bash
# Get ALB URL from terraform
KONG_HOST=$(cd ../.. && terraform output -raw kong_endpoint)

# Basic request
curl -X POST "${KONG_HOST}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: signify-test-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, what is Kong Gateway?"}
    ]
  }'
```

Or use the test scripts:

```bash
cd ../../test
./test-failover.sh
```

## Testing Failover

To test failover behavior:

1. **Temporarily invalidate primary region** - Modify config to use an invalid region
2. Sync config: `deck gateway sync config.yaml`
3. Send request - should fail over to us-west-2
4. Restore valid config and sync again

Or use Kong's debug headers to see which target was used:

```bash
curl -X POST "${KONG_HOST}/ai/chat" \
  -H "Content-Type: application/json" \
  -H "apikey: signify-test-key" \
  -d '{"messages": [{"role": "user", "content": "test"}]}' \
  -v 2>&1 | grep -i x-kong
```

## Response Headers

Kong adds these headers to track AI usage:

| Header | Description |
|--------|-------------|
| `X-Kong-LLM-Provider` | Which provider handled request (bedrock) |
| `X-Kong-LLM-Model` | Model used |
| `X-Kong-Upstream-Latency` | Time to LLM provider (ms) |
| `X-Kong-Proxy-Latency` | Kong processing time (ms) |

## Cleanup

```bash
deck gateway reset --select-tag signify-demo --force
```
