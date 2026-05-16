# 02. Artifact Input Matrix

## 1. Artifact 类型全量分层

### 1.1 v4 正式支持（P0）

| ArtifactKind | 用户触发 | 自动采集 | AI 处理 | iOS 原生框架 | v3 现状 |
|-------------|---------|---------|--------|------------|--------|
| `text` | 手动输入 | — | 润色/摘要/实体提取 | — | ✅ 已完成 |
| `photo` | PhotosPicker | — | Vision 描述 → 文字 → 解析 | Vision / VisionKit | ⚠️ 可选取但无 AI |
| `audio` | AVAudioRecorder | — | Speech 转写 → 润色 → 解析 | Speech / AVFoundation | ⚠️ 可录制但无转写 |
| `weather` | — | ✅ 自动 | — | WeatherKit | ❌ 未实现 |
| `location` | 手动/自动 | ✅ 自动 | 反向地理编码语义化 | CoreLocation / MapKit | ❌ 未实现 |
| `music` | — | ✅ 自动 | — | MusicKit | ❌ 未实现 |

### 1.2 v4 计划支持（P1）

| ArtifactKind | 用户触发 | AI 处理 | iOS 原生框架 |
|-------------|---------|--------|------------|
| `link` | 粘贴 URL | 元数据提取（title/description/og:image） | LinkPresentation |
| `personMention`* | 手动 @ | 匹配 Contacts + Mory EntityNode | Contacts |

*注：`personMention` 不是 `ArtifactKind`，它是 `RecordShell.entityMentions` 字段，v3 ontology 已有此边界。

### 1.3 未来版本（v5+）

| ArtifactKind | 优先级 | 说明 |
|-------------|-------|------|
| `ticket` | P2 | 机票/演唱会门票结构化识别（Vision OCR） |
| `health` | P2 | HealthKit 只读数据作为 Reflection 背景上下文 |
| `book` / `media` | P2 | 书影音记录，需要元数据源 |
| `countdown` | P2 | 限定为关联已有记忆/人物的计数，不做通用倒计时 |
| `scent` | P3 | 气味便签，纯标签无 AI |

## 2. 每种 Artifact 的数据结构

### 2.1 photo Artifact

```
Artifact {
  kind: .photo
  title: "AI 生成的图片标题"          // Vision 生成
  summary: "AI 生成的图片描述"         // Vision 生成
  textContent: "图片中的文字（OCR）"    // VisionKit OCR
  mediaRef: ArtifactMediaRef {
    filename: "IMG_2024.heic"
    mimeType: "image/heic"
    byteCount: 2_400_000
    localIdentifier: "PHAsset.localIdentifier"
  }
  binaryPayload: Data (缩略图)
  metadata: [
    "width": "4032",
    "height": "3024",
    "captureDate": "2026-05-16T10:30:00Z"
  ]
}
```

### 2.2 audio Artifact

```
Artifact {
  kind: .audio
  title: "录音 2026-05-16 10:30"       // 自动生成
  summary: "AI 润色后的语音摘要"         // 服务端生成
  textContent: "iOS Speech 转写的原始文字" // 本地 Speech
  mediaRef: ArtifactMediaRef {
    filename: "recording_1715843400.m4a"
    mimeType: "audio/m4a"
    byteCount: 450_000
  }
  metadata: [
    "durationSeconds": "45",
    "sampleRate": "44100",
    "locale": "zh-Hans"
  ]
}
```

### 2.3 weather Artifact

```
Artifact {
  kind: .weather
  title: "多云 22°C"
  summary: "上海 · 多云 · 22°C · 湿度 65%"
  textContent: ""
  metadata: [
    "condition": "cloudy",
    "temperatureCelsius": "22",
    "humidity": "0.65",
    "windSpeedKmh": "12",
    "uvIndex": "3",
    "location": "Shanghai, China"
  ]
}
```

### 2.4 location Artifact

```
Artifact {
  kind: .location
  title: "星巴克 · 南京西路"
  summary: "上海市静安区南京西路 1038 号"
  textContent: ""
  metadata: [
    "latitude": "31.2304",
    "longitude": "121.4737",
    "altitude": "4.0",
    "horizontalAccuracy": "5.0",
    "placemark": "星巴克 南京西路店",
    "locality": "上海市",
    "subLocality": "静安区",
    "country": "中国"
  ]
}
```

### 2.5 music Artifact

```
Artifact {
  kind: .music
  title: "Bohemian Rhapsody"
  summary: "Queen · A Night at the Opera · 1975"
  textContent: ""
  metadata: [
    "trackName": "Bohemian Rhapsody",
    "artistName": "Queen",
    "albumName": "A Night at the Opera",
    "durationSeconds": "354",
    "appleMusicID": "1440806041",
    "artworkURL": "https://..."
  ]
  binaryPayload: Data (专辑封面缩略图)
}
```

### 2.6 link Artifact

```
Artifact {
  kind: .link
  title: "Extracted page title"
  summary: "OG description or first paragraph"
  textContent: "用户备注"
  metadata: [
    "url": "https://example.com/article",
    "ogImage": "https://example.com/og.jpg",
    "siteName": "Example Blog",
    "publishDate": "2026-05-10"
  ]
  binaryPayload: Data (og:image 缩略图)
}
```

## 3. Artifact 与 AI 解析的关系

每种 Artifact 最终都要**生成可供 AI 解析的文本**。AI 分析的输入始终是：

```
RecordShell.rawText
  + Artifact[0].textContent (或 AI 生成的描述)
  + Artifact[1].textContent
  + ...
  + 自动上下文摘要（天气 + 地点 + 音乐）
```

这意味着：

- `text` → 直接参与解析
- `photo` → Vision 生成描述 → 作为 textContent 参与解析
- `audio` → Speech 转写 → 作为 textContent 参与解析
- `weather` → summary 字段（"多云 22°C 上海"）参与解析
- `location` → summary 字段（"星巴克 南京西路"）参与解析
- `music` → summary 字段（"Queen - Bohemian Rhapsody"）参与解析
- `link` → title + summary 参与解析

AI 不需要看到二进制数据。它只消费文本。
