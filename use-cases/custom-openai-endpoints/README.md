# Custom OpenAI-Compatible Endpoints

Route traffic through Kong to any OpenAI-compatible endpoint, with failover to a standard Bedrock model.

## Use Cases

| Scenario | What It Is | Auth |
|----------|-----------|------|
| **Custom Model Import** | Fine-tuned models imported into Bedrock | Bedrock API keys |
| **Bedrock Access Gateway** | AWS open-source proxy wrapping Bedrock in OpenAI-compat API | API key or IAM |
| **Bedrock native OpenAI API** | Bedrock's built-in OpenAI-compatible endpoint | Bedrock API keys or SigV4 |

All use the same Kong config pattern: `provider: openai` with a custom `upstream_url`.

## Setup

Edit `config.yaml` and replace:

| Placeholder | Description |
|-------------|-------------|
| `REPLACE_WITH_API_KEY` | API key for the endpoint |
| `REPLACE_WITH_MODEL_NAME` | Model name |
| `REPLACE_WITH_ENDPOINT` | Full endpoint URL |

## Deploy

```bash
export DECK_AWS_ACCESS_KEY_ID="your-access-key"
export DECK_AWS_SECRET_ACCESS_KEY="your-secret-key"

deck gateway sync use-cases/custom-openai-endpoints/config.yaml
```

## Test

```bash
curl -X POST http://KONG_HOST/ai/custom -H "Content-Type: application/json" -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

## Cleanup

```bash
deck gateway reset --select-tag custom-openai-endpoints --force
```
