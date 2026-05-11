# Sprout

Sprout is a SwiftUI-first journaling app built around a containerized home-card system. Records are persisted with SwiftData, rendered into adaptive cards on the home screen, and arranged by a custom sticker-style grid layout.

## Current Architecture

- `sprout/sprout/Models`
  SwiftData models such as `Record`, `MediaCard`, `Activity`, and related entities.
- `sprout/sprout/Cards`
  One SwiftUI file per card type. Cards adapt to the container size they receive instead of relying on legacy fixed-size variants.
- `sprout/sprout/Services`
  Mapping, parsing, and external-data integration such as music and weather.
- `sprout/sprout/Views`
  App screens and editing flows including `DailyView`, `AddCardSheet`, and `RecordDetailView`.

## Home Layout

- Home layout is container-first.
- `ContainerSpan` is the placement unit for the grid.
- `StickerGridLayout` arranges containers responsively.
- `CardContainerView` owns container-level visual placement behavior.
- Cards are self-adaptive internally and do not encode `4x1` / `4x2` / `4x4` semantics.

## Card Actions

- Cards use the system native long-press `contextMenu`.
- Menu actions include card size options and delete.
- Supported container sizes per card type are defined in `sprout/sprout/Cards/GridConfig.swift` under `cardSizeLimits`.
- The home grid uses a stable occupancy-based placement algorithm so resizing a card mainly affects the cards after it instead of reshuffling the whole page.

## Record Storage

`Record` currently stores:

- Base content: `body`, `createdAt`, `updatedAt`, `tags`
- Home layout: `cardType`, `cardWidthColumns`, `cardUnits`, `dashboardCardSpanOverridesData`, `dashboardOrder`
- Emotion: `mood`, `intensity`
- Weather snapshot: `weather`, `temperature`, `feelsLike`, `humidity`, `weatherHigh`, `weatherLow`, `location`, `latitude`, `longitude`, `weatherObservedAt`, `weatherSource`
- Media / map / music related relationships and fields

Home layout sizing now works in two layers:

- `cardWidthColumns` and `cardUnits` are legacy/default fallback values on the `Record`.
- `dashboardCardSpanOverridesData` stores per-container size overrides keyed by dashboard card suffix such as `photo`, `text`, or `weather`.
- This prevents multiple dashboard containers from the same `Record` from resizing together.

## Weather Strategy

Weather is treated as a recorded snapshot, not a mutable live value.

- When creating a weather card, Sprout should request current location and fetch WeatherKit data.
- The fetched result is persisted into the `Record` as the weather at record time.
- Home cards and detail pages primarily display the recorded snapshot.
- For same-day records with coordinates, the weather card may fetch live weather for that location and show it only as supplemental text such as `现在 26° 晴`.
- Live weather must not overwrite the stored snapshot.
- Reverse geocoding failure must not block weather snapshot creation. If placemark lookup fails, the app falls back to formatted coordinates.
- On the simulator, SwiftData CloudKit sync is disabled to avoid `CKAccountStatusNoAccount` startup failures when no iCloud account is signed in.

## Build

Preferred verification command:

```sh
xcodebuild -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(error:|warning:|BUILD)" | tail -50
```

For fuller output:

```sh
xcodebuild -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -100
```

## Backend Deployment

The backend lives in `server/` and can be deployed to Fly.io.

- Repo-level Fly config: [fly.toml](/Users/z14/Documents/sprout/fly.toml)
- Container build: [server/Dockerfile](/Users/z14/Documents/sprout/server/Dockerfile)
- Deployment notes: [server/DEPLOY_FLY.md](/Users/z14/Documents/sprout/server/DEPLOY_FLY.md)
- Fly working directory: repo root (`/Users/z14/Documents/sprout`)

Default deployment mode is conservative:

- `AI_MODE=mock`
- `AI_PROVIDER=mock`
- `DEV_AUTH_ENABLED=false`
- SQLite persisted on a Fly volume at `/data/sprout.db`
- Physical iPhones/iPads should use `https://sprout-god7g.fly.dev`

Fly Managed Postgres is not used here. If the Fly dashboard only shows database options, create a regular Fly Volume with `fly volumes create` instead of selecting Managed Postgres.

To switch to live AI, set Fly secrets/envs for `AI_MODE=live`, choose `AI_PROVIDER=anthropic` or `openai_compatible`, then provide `AI_MODEL` and `AI_API_KEY`. For OpenAI-compatible vendors, also set `AI_BASE_URL` when the endpoint differs from OpenAI's default.

Backend changes should be committed and pushed to `origin/main` after each update so the Fly deployment stays in sync.

## Known Follow-ups

- Clean remaining warnings in weather, map, layout actor-isolation, and mapper files.
- Add migration handling if SwiftData schema changes need explicit rollout support.
- Consider extracting weather snapshot types into a dedicated model or value object if the feature expands further.
