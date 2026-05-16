# 01. Artifact Kind Expansion

## 1. 现状

v3 已定义 `ArtifactKind` 枚举：

```swift
enum ArtifactKind: String, Codable, CaseIterable {
    case text, photo, audio, music, link, location, weather, todo, document
}
```

v3 的 `CaptureArtifactDraft` 支持：

```swift
enum CaptureArtifactDraft {
    case text(title: String?, body: String)
    case photo(title: String?, summary: String, filename: String, imageData: Data?, thumbnailData: Data?)
    case audio(title: String?, summary: String, filename: String, audioData: Data?)
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?)
    case link(title: String?, url: String, note: String?)
    case todo(title: String, note: String?)
}
```

**问题：** `weather` 和 `music` 没有对应的 `CaptureArtifactDraft` case。

## 2. v4 扩展

### 2.1 新增 CaptureArtifactDraft case

```swift
enum CaptureArtifactDraft {
    // v3 已有
    case text(title: String?, body: String)
    case photo(title: String?, summary: String, filename: String, imageData: Data?, thumbnailData: Data?)
    case audio(title: String?, summary: String, filename: String, audioData: Data?, transcription: String?)
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?)
    case link(title: String?, url: String, note: String?)
    case todo(title: String, note: String?)

    // v4 新增
    case weather(
        condition: String,
        temperatureCelsius: Double,
        humidity: Double,
        windSpeedKmh: Double,
        uvIndex: Int,
        location: CLLocation?
    )
    case music(
        trackName: String,
        artistName: String,
        albumName: String,
        durationSeconds: Int,
        artworkURL: String?
    )
}
```

### 2.2 audio case 变更

v3 的 `audio` case 没有 `transcription` 字段。v4 增加：

```swift
// v3
case audio(title: String?, summary: String, filename: String, audioData: Data?)

// v4
case audio(title: String?, summary: String, filename: String, audioData: Data?, transcription: String?)
```

`transcription` 是 iOS Speech 转写的结果文字，保存后写入 `Artifact.textContent`。

### 2.3 photo case 改造

v3 的 photo 只存储原始数据。v4 增加 AI 生成的字段：

```swift
// v4 photo case 改为通过 PhotoArtifactProcessor 处理后再传入
// processor 输出：
struct ProcessedPhotoArtifact {
    let title: String           // Vision 生成
    let summary: String         // Vision 生成
    let ocrText: String         // VisionKit OCR
    let thumbnailData: Data     // 缩略图
    let metadata: [String: String]  // EXIF
    let originalFilename: String
    let imageData: Data?
}
```

## 3. ArtifactKind 不变

不新增 `ArtifactKind` case。v3 定义的 9 种已覆盖 v4 所有需求。

- `personMention` 不是 ArtifactKind，是 RecordShell.entityMentions
- `ticket` 是 v5 范围
- `health` 是 v5 范围

## 4. Artifact 存储变化

### 4.1 Store 层

`StoreArtifact`（CoreData entity）不需要改 schema。现有字段覆盖：

| CaptureArtifactDraft 新 case | StoreArtifact 字段映射 |
|------------------------------|----------------------|
| `.weather(...)` | kind="weather", title, summary, metadata (JSON) |
| `.music(...)` | kind="music", title, summary, metadata (JSON), binaryPayload (封面) |
| `.audio(..., transcription)` | textContent = transcription |

### 4.2 MoryDomainMappers 变化

`MemoryCaptureArtifactBuilder` 需要新增 weather 和 music 的 draft → Artifact 映射。

## 5. 迁移风险

无。纯增量。不改现有字段，不改 Store schema。
