# 05. Core ML And Core Spotlight

## 1. Goal

Use native Apple intelligence surfaces where they fit Mory's local storage, privacy, and system-integration design.

Core ML and local rules should provide cheap, private, repeated hints. Core Spotlight should provide system-native semantic retrieval. Cloud AI remains the primary deep-intelligence path for transcript refinement, question candidates, chapter naming, reflection, and future multimodal photo understanding.

## 2. Core ML Role

Core ML should not replace the cloud deep-intelligence pipeline in V6. It should provide lightweight local signals and future opt-in local-first modes.

Candidate local outputs:

- Salience hint.
- Memory type hint.
- Question eligibility.
- Sensitive topic hint.
- Revisit score.
- Board card size suggestion.
- Search ranking boost.
- Duplicate/alias similarity.

## 3. Local Rules Before Models

Start with deterministic local rules:

- Mention count.
- Last mentioned date.
- Frequency windows.
- Repeated location/music.
- Recent high-density periods.
- Open decision markers.
- User dismiss/reduce history.

Then swap or augment with Core ML where useful.

## 4. Core ML Data Boundary

Local ML input should use:

- Normalized text snippets.
- Derived labels.
- Dates.
- Artifact kinds.
- Entity counts.
- Local metadata.

Avoid:

- Sending local ML data to server.
- Training on user data without explicit future consent.
- Blocking capture on model inference.

## 5. Core Spotlight Indexing

Add `SpotlightIndexService`.

Indexable items:

- Memory.
- Person/entity profile.
- Place.
- Theme.
- Decision.
- Temporal arc/chapter.
- Reflection.

Suggested memory attributes:

```swift
attributes.title = memory.title
attributes.contentDescription = memory.summaryText
attributes.textContent = canonicalMemoryText
attributes.keywords = retrievalTerms + entityNames + artifactKinds
attributes.contentCreationDate = memory.record.createdAt
attributes.metadataModificationDate = memory.record.updatedAt
attributes.userCreated = true
attributes.userOwned = true
attributes.rankingHint = salienceScore
```

For voice:

```swift
attributes.transcribedTextContent = transcript
```

For location:

```swift
attributes.namedLocation = placeName
attributes.latitude = latitude
attributes.longitude = longitude
```

## 6. Search Query Flow

```text
SearchScreen query
  -> SpotlightSearchService if available
  -> Map item IDs to local domain objects
  -> Merge with MemorySearchService fallback
  -> Render grouped results
```

## 7. Index Update Triggers

- Memory created.
- Memory edited.
- Memory deleted.
- Analysis completed.
- Entity profile answered.
- Reflection saved/dismissed.
- Arc/chapter accepted.

## 8. Fallback Strategy

If Core Spotlight is unavailable or errors:

- Continue using `MemorySearchService`.
- Show no error unless search entirely fails.
- Keep exact search reliable.

## 9. Engagement Feedback

Where OS supports it:

- Report selected result.
- Report focused result.
- Use visible result list.

This can improve ranking without server storage.

## 10. Tests

Required:

- Index item builder tests.
- Delete removes item from index.
- Search result ID mapping tests.
- Fallback tests.
- Search UI remains usable with empty Spotlight results.
