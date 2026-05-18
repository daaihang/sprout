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
   - `APNS_ENABLED=true` only after APNs credentials are installed
   - `APNS_ENVIRONMENT=sandbox` for TestFlight/debug builds, `production` for App Store production tokens
   - `APNS_TOPIC=com.speculolabs.mory`
   - `APNS_KEY_ID`
   - `APNS_TEAM_ID`
   - `APNS_AUTH_KEY` or `APNS_AUTH_KEY_PATH`
   - `PUSH_DELIVERY_WORKER_ENABLED=true`
   - `PUSH_DELIVERY_INTERVAL=30s`
   - `PUSH_DELIVERY_BATCH_SIZE=32`
   - `PUSH_DELIVERY_MAX_ATTEMPTS=5`
   - `PUSH_DELIVERY_RETRY_BACKOFF=2m`
   - `PUSH_DELIVERY_ALERT_FAILURE_THRESHOLD=3`
- For DeepSeek specifically, use:
  - `AI_PROVIDER=openai_compatible`
  - `AI_MODEL=deepseek-chat`
  - `AI_BASE_URL=https://api.deepseek.com`
  - `JWT_TTL=1h`
5. Deploy with `fly deploy`.
6. Verify `GET /healthz` returns `200 OK`.
7. Verify `GET /metrics` includes request counters, `ai_operation_*` counters, and `push_delivery_*` counters.

Production worker strategy:

- The current delivery worker intentionally runs inside the Go server process. Keep one active server machine for now, or ensure only one machine has `PUSH_DELIVERY_WORKER_ENABLED=true` until delivery locking is added.
- Use `/metrics` for alerting:
  - `push_delivery_consecutive_loop_errors > 0` across multiple scrapes means the loop is unhealthy.
  - `push_delivery_permanent_failed_total` spikes usually mean bad APNs tokens, topic/environment mismatch, or credentials.
  - `push_delivery_retried_total` rising without `push_delivery_sent_total` recovery means APNs/network instability.
  - `ai_operation_errors_total` rising after a deploy means model/provider/schema regression.
- Logs are JSON and include batch delivery summaries plus an explicit `push delivery alert threshold reached` error when one batch crosses `PUSH_DELIVERY_ALERT_FAILURE_THRESHOLD`.

Notes:

- The deployed backend URL is `https://sprout-god7g.fly.dev`.
- Physical devices should point to that Fly URL instead of localhost.
- Push backend changes to `origin/main` after each server update so the deployed service can stay current.
