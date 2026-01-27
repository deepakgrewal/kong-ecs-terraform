# Scenario 2: AI Gateway Failover

OpenAI as primary provider with automatic failover to Azure OpenAI.

## How Failover Works

```
Request ──► Kong AI Gateway
                │
                ▼
         ┌──────────────┐
         │   OpenAI     │ weight: 1000 (primary)
         │   GPT-4o     │
         └──────┬───────┘
                │ If fails (429, 500, 502, 503, timeout)
                ▼
         ┌──────────────┐
         │ Azure OpenAI │ weight: 1 (fallback)
         │   GPT-4o     │
         └──────────────┘
```

**Failover triggers:**
- `error` - Connection/network errors
- `timeout` - Request timeout
- `http_429` - Rate limited by provider
- `http_500/502/503` - Server errors

**Behavior:**
- Primary (OpenAI) is tried first due to higher weight (1000 vs 1)
- After 2 consecutive failures (`max_fails: 2`), target marked unhealthy
- Unhealthy target reconsidered after 30 seconds (`fail_timeout: 30000`)
- Up to 3 retry attempts per request (`retries: 3`)

## Prerequisites

1. OpenAI API key
2. Azure OpenAI deployment (optional, for full failover testing)

## Setup

### 1. Configure API Keys

Edit `config.yaml` and replace:

```yaml
# OpenAI
header_value: "Bearer sk-your-openai-key"

# Azure OpenAI
header_value: "your-azure-api-key"
azure_instance: your-resource-name    # Azure OpenAI resource name
azure_deployment_id: gpt-4o           # Deployment name in Azure portal
```

### 2. Deploy to Konnect

```bash
# From project root
export KONNECT_PAT=$(grep "^KONNECT_PAT=" .konnect.env | cut -d'=' -f2 | tr -d '"')

deck gateway sync clients/signify/2-ai-gateway-failover/config.yaml
```

### 3. Test

```bash
# Basic request
curl -X POST http://localhost:8000/ai/chat \
  -H "Content-Type: application/json" \
  -H "apikey: signify-test-key" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, what is Kong Gateway?"}
    ]
  }'
```

## Testing Failover

To test failover without breaking OpenAI:

1. **Temporarily set invalid OpenAI key** in config
2. Sync config: `deck gateway sync config.yaml`
3. Send request - should fail over to Azure
4. Restore valid key and sync again

Or use Kong's debug headers to see which target was used:
```bash
curl -X POST http://localhost:8000/ai/chat \
  -H "Content-Type: application/json" \
  -H "apikey: signify-test-key" \
  -d '{"messages": [{"role": "user", "content": "test"}]}' \
  -v 2>&1 | grep -i x-kong
```

## Response Headers

Kong adds these headers to track AI usage:

| Header | Description |
|--------|-------------|
| `X-Kong-LLM-Provider` | Which provider handled request |
| `X-Kong-LLM-Model` | Model used |
| `X-Kong-Upstream-Latency` | Time to LLM provider (ms) |
| `X-Kong-Proxy-Latency` | Kong processing time (ms) |

## Cleanup

```bash
deck gateway reset --select-tag signify-demo --force
```
