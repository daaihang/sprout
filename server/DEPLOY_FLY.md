# Fly.io Deployment

1. Create a Fly app named `sprout-server` or replace the name in `../fly.toml`.
2. Create a volume named `sprout_data` mounted at `/data`.
3. Set secrets:
   - `JWT_SECRET`
   - `APPLE_AUDIENCES`
   - `APPLE_ISSUER`
   - `APPLE_JWKS_URL`
   - `AI_MODE=mock` for default local-like mode, or `AI_MODE=live`
   - `AI_PROVIDER=anthropic` or `AI_PROVIDER=openai_compatible`
   - `AI_MODEL`
   - `AI_API_KEY`
   - `AI_BASE_URL` for OpenAI-compatible backends if needed
4. Deploy from the repo root so Fly picks up `fly.toml`.
5. Verify `GET /healthz` returns `200 OK`.
