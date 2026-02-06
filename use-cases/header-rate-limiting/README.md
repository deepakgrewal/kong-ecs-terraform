# Header-Based Rate Limiting

Rate limit AI requests per user per agent using a custom HTTP header.

## Concept

Standard rate limiting ties limits to a Kong consumer (API key). Header-based rate limiting adds a second dimension: a custom header (e.g., `X-User-Agent-ID`) that identifies which agent is making the request.

Each unique header value gets its own independent rate limit counter:

```
X-User-Agent-ID: agent-a  ->  Counter 1 (100 tokens/min)
X-User-Agent-ID: agent-b  ->  Counter 2 (100 tokens/min)
```

## Deploy

```bash
export DECK_AWS_ACCESS_KEY_ID="your-access-key"
export DECK_AWS_SECRET_ACCESS_KEY="your-secret-key"

deck gateway sync use-cases/header-rate-limiting/config.yaml
```

## Test

### Send request with agent header

```bash
curl -X POST http://KONG_HOST/ai/rate-limited -H "Content-Type: application/json" -H "X-User-Agent-ID: agent-a" -d '{"messages":[{"role":"user","content":"Say hello in 5 words"}]}'
```

### Verify independent counters

Send requests with different `X-User-Agent-ID` values. Each gets its own token budget. Exhausting one agent's limit doesn't affect other agents.

## Configuration

```yaml
ai-rate-limiting-advanced:
  config:
    identifier: header           # Use header value as rate limit key
    header_name: X-User-Agent-ID # Which header to use
    llm_providers:
      - name: bedrock
        limit: [100]             # 100 tokens
        window_size: [60]        # per 60 seconds
```

## Cleanup

```bash
deck gateway reset --select-tag header-rate-limiting --force
```
