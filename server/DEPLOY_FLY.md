# Fly.io Deployment

1. Run from the repo root (`/Users/z14/Documents/sprout`) so Fly picks up `fly.toml` and the `server/Dockerfile` build context.
2. Create a Fly app named `sprout-server` or replace the name in `../fly.toml`.
3. Create a regular Fly Volume named `sprout_data` mounted at `/data` and in the same region as the app machine. If the dashboard only shows Managed Postgres, use `fly volumes create sprout_data -r nrt -a sprout-server` instead.
4. Set secrets:
   - `JWT_SECRET`
   - `APPLE_AUDIENCES`
   - `APPLE_ISSUER`
   - `APPLE_JWKS_URL`
   - `AI_MODE=mock` for default local-like mode, or `AI_MODE=live`
   - `AI_PROVIDER=anthropic` or `AI_PROVIDER=openai_compatible`
   - `AI_MODEL`
   - `AI_API_KEY`
   - `AI_BASE_URL` for OpenAI-compatible backends if needed
5. Deploy with `fly deploy`.
6. Verify `GET /healthz` returns `200 OK`.

Notes:

- The deployed backend URL is `https://sprout-god7g.fly.dev`.
- Physical devices should point to that Fly URL instead of localhost.
- Push backend changes to `origin/main` after each server update so the deployed service can stay current.
