# 02. Capture Pipeline

## 1. v3 Capture 流程

```
用户点击保存
  → CaptureComposerView 构建 MemoryCaptureDraft
  → MoryMemoryRepository.createMemory()
    → MemoryCaptureArtifactBuilder 转化 draft → Artifact
    → 写入 StoreRecord + StoreArtifact
    → 触发 ArchitecturePipelineExecutor.execute()
```

## 2. v4 Capture 流程

```
用户点击保存
  → CaptureComposerView 构建 MemoryCaptureDraft
  → [NEW] ArtifactPreprocessor 处理非文字 Artifact
      ├── PhotoArtifactProcessor  → Vision 描述 + OCR
      ├── AudioTranscriptionService → Speech 转写
      └── LinkMetadataExtractor → URL 元数据
  → [NEW] ContextAutoCollector 并行采集上下文
      ├── WeatherContextService → weather Artifact
      ├── LocationContextService → location Artifact
      └── MusicContextService → music Artifact
  → 合并所有 Artifact
  → MoryMemoryRepository.createMemory()
    → MemoryCaptureArtifactBuilder 转化（扩展后支持 weather/music）
    → 写入 StoreRecord + StoreArtifact
    → 触发 ArchitecturePipelineExecutor.execute()
```

## 3. 统一 Capture 管道

### 3.1 CaptureOrchestrator

新建一个协调器，统一管理 capture 流程：

```swift
// CaptureOrchestrator.swift

@MainActor
final class CaptureOrchestrator {
    private let artifactPreprocessor: ArtifactPreprocessor
    private let contextCollector: ContextAutoCollector
    private let repository: MoryMemoryRepositorying

    func capture(draft: MemoryCaptureDraft) async throws -> MemorySummary {
        // Step 1: 预处理用户 Artifact（本地 AI）
        let processedArtifacts = await artifactPreprocessor.process(draft.artifacts)

        // Step 2: 并行采集上下文（超时 3s）
        let contextArtifacts = await contextCollector.collectAll(timeout: 3.0)

        // Step 3: 合并
        let finalDraft = MemoryCaptureDraft(
            title: draft.title,
            rawText: draft.rawText.isEmpty
                ? processedArtifacts.primaryTextContent ?? ""
                : draft.rawText,
            mood: draft.mood,
            inputContext: draft.inputContext,
            captureSource: draft.captureSource,
            artifacts: processedArtifacts.drafts + contextArtifacts
        )

        // Step 4: 保存 + 触发分析
        return try await repository.createMemory(from: finalDraft)
    }
}
```

### 3.2 ArtifactPreprocessor

```swift
// ArtifactPreprocessor.swift

struct ProcessedArtifacts {
    let drafts: [CaptureArtifactDraft]
    let primaryTextContent: String?   // 第一个有内容的文字
}

final class ArtifactPreprocessor {
    private let photoProcessor: PhotoArtifactProcessor
    private let audioService: AudioTranscriptionService
    private let linkExtractor: LinkMetadataExtractor

    func process(_ drafts: [CaptureArtifactDraft]) async -> ProcessedArtifacts {
        var processed: [CaptureArtifactDraft] = []
        var primaryText: String?

        for draft in drafts {
            switch draft {
            case .photo(_, _, let filename, let imageData, _):
                if let imageData {
                    let result = await photoProcessor.process(imageData: imageData, filename: filename)
                    processed.append(.photo(
                        title: result.title,
                        summary: result.summary,
                        filename: filename,
                        imageData: imageData,
                        thumbnailData: result.thumbnailData
                    ))
                    if primaryText == nil { primaryText = result.summary }
                } else {
                    processed.append(draft)
                }

            case .audio(let title, _, let filename, let audioData, _):
                if let audioData {
                    let transcription = await audioService.transcribe(audioData: audioData)
                    processed.append(.audio(
                        title: title,
                        summary: transcription ?? "",
                        filename: filename,
                        audioData: audioData,
                        transcription: transcription
                    ))
                    if primaryText == nil { primaryText = transcription }
                } else {
                    processed.append(draft)
                }

            case .link(let title, let url, let note):
                let metadata = await linkExtractor.extract(url: url)
                processed.append(.link(
                    title: metadata?.title ?? title,
                    url: url,
                    note: note
                ))

            default:
                processed.append(draft)
            }
        }

        return ProcessedArtifacts(drafts: processed, primaryTextContent: primaryText)
    }
}
```

### 3.3 ContextAutoCollector

```swift
// ContextAutoCollector.swift

final class ContextAutoCollector {
    private let weather: WeatherContextService
    private let location: LocationContextService
    private let music: MusicContextService

    func collectAll(timeout: TimeInterval) async -> [CaptureArtifactDraft] {
        await withTaskGroup(of: CaptureArtifactDraft?.self) { group in
            group.addTask {
                try? await withTimeout(timeout) {
                    await self.weather.captureCurrentWeather()
                }
            }
            group.addTask {
                try? await withTimeout(timeout) {
                    await self.location.captureCurrentLocation()
                }
            }
            group.addTask {
                try? await withTimeout(timeout) {
                    await self.music.captureNowPlaying()
                }
            }

            var results: [CaptureArtifactDraft] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }
}
```

## 4. AnalyzeRequestBuilder 扩展

v3 的 AnalyzeRequestBuilder 组装 API 请求时只用 `rawText` 和部分 artifact 文字。

v4 需要扩展，把所有 artifact 的 textContent/summary 都纳入：

```swift
// AnalyzeRequestBuilder 扩展

func buildArtifactContext(from artifacts: [Artifact]) -> String {
    artifacts.compactMap { artifact in
        let content = artifact.textContent.trimmedOrNil
            ?? artifact.summary.trimmedOrNil
        guard let content else { return nil }
        return "[\(artifact.kind.rawValue)] \(content)"
    }.joined(separator: "\n")
}
```

这段文字拼接到发给 AI 的 prompt 中，让 AI 知道当前记录的完整上下文。

## 5. 管道错误处理

| 阶段 | 失败处理 |
|------|---------|
| PhotoArtifactProcessor | 保存原始图片，textContent 为空 |
| AudioTranscriptionService | 保存原始音频，textContent 为空 |
| LinkMetadataExtractor | 保存原始 URL，title/summary 为空 |
| WeatherContextService | 跳过，不生成 weather Artifact |
| LocationContextService | 跳过，不生成 location Artifact |
| MusicContextService | 跳过，不生成 music Artifact |
| ArchitecturePipelineExecutor | 与 v3 相同：记录错误，可重试 |

任何预处理/采集失败都不阻塞保存。
