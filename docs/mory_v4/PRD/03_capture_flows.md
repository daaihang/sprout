# 03. Capture Flows

## 1. Capture 统一原则

v4 的 capture 入口是 CaptureComposerView。用户在一次 capture 中可以：

- 写一段文字（必填）
- 附加 0~N 个 Artifact（可选）
- 系统自动附加上下文 Artifact（静默）

保存时，系统同步完成：

1. 写入 RecordShell + 所有 Artifact
2. 自动采集上下文（天气/地点/音乐）并作为额外 Artifact 附加
3. 触发异步 AI 分析流程

## 2. 文字输入流程

```
用户打开 Composer
  → 选择 "文字" 类型
  → 输入文字（rawText）
  → 可选填 mood / inputContext
  → 点击保存
  → RecordShell 写入
  → text Artifact 写入（如果有 title 或 body 区分）
  → 触发异步分析
```

**v3 → v4 变化：无。已完成。**

## 3. 照片输入流程

```
用户打开 Composer
  → 选择 "照片" 类型
  → PhotosPicker 选取一张或多张照片
  → 本地处理（同步，< 3s）：
      a. 读取照片 Data
      b. 生成缩略图（binaryPayload）
      c. Vision 生成图片描述（title + summary）
      d. VisionKit OCR 提取文字（textContent）
      e. 读取 EXIF metadata
  → 用户可编辑/补充描述
  → 点击保存
  → RecordShell 写入
  → photo Artifact 写入（含描述、缩略图、metadata）
  → 触发异步分析（photo.textContent 作为输入）
```

### 3.1 照片 AI 处理细节

| 步骤 | 执行位置 | 框架 | 耗时预估 |
|------|---------|------|---------|
| 图片分类 | 本地 | Vision VNClassifyImageRequest | < 1s |
| 图片描述 | 本地 | Vision VNGenerateAttentionBasedSaliencyImageRequest + 分类组合 | < 2s |
| OCR 文字 | 本地 | VisionKit VNRecognizeTextRequest | < 1s |
| EXIF 读取 | 本地 | CGImageSource | < 0.1s |

**关键决策：** 图片描述在本地用 Vision 框架生成，不发送到服务端。理由：

1. 隐私——照片不离开设备
2. 速度——本地 < 3s vs 服务端 > 5s
3. 成本——不消耗 AI token

生成的文字描述作为 `textContent` 写入 Artifact，后续和 rawText 一起发给服务端做语义分析。

### 3.2 多张照片

用户可一次选取多张照片，每张生成独立的 photo Artifact，共享同一个 RecordShell。

## 4. 录音输入流程

```
用户打开 Composer
  → 选择 "录音" 类型
  → 点击录制按钮 → AVAudioRecorder 开始录音
  → 点击停止 → 录音结束
  → 本地处理（异步，< 10s/分钟）：
      a. iOS Speech 转写（SFSpeechRecognizer）
      b. 转写结果写入 textContent
  → 用户可查看/编辑转写文字
  → 点击保存
  → RecordShell 写入（rawText = 转写文字）
  → audio Artifact 写入（含音频文件、转写文字、时长）
  → 触发异步分析（textContent 参与解析）
  → 异步：服务端润色转写文字（可选，P1）
```

### 4.1 录音转写细节

| 步骤 | 执行位置 | 框架 | 说明 |
|------|---------|------|------|
| 语音转文字 | 本地 | Speech (SFSpeechRecognizer) | 支持中英文自动检测 |
| 文字润色 | 服务端 | AI（与 Analyze 同一模型） | 去口语化、补标点、分段 |
| 语言检测 | 本地 | NLLanguageRecognizer | 自动选择 SFSpeechRecognizer locale |

**关键决策：**

- 转写在本地完成——隐私 + 速度
- 润色是可选的 P1 能力——先让转写可用
- rawText 在保存时自动填充为转写文字——如果用户没有手动输入文字

### 4.2 录音文件存储

录音文件存储在 app sandbox 的 `Documents/Recordings/` 目录，通过 `ArtifactMediaRef.filename` 引用。文件不上传到服务端。

## 5. 链接输入流程

```
用户打开 Composer
  → 选择 "链接" 类型
  → 粘贴 URL
  → 本地处理（异步，< 3s）：
      a. LPMetadataProvider 提取元数据
      b. 获取 title / description / og:image
      c. 下载 og:image 缩略图
  → 用户可补充备注
  → 点击保存
  → RecordShell 写入
  → link Artifact 写入
  → 触发异步分析
```

## 6. 联系人提及流程（P1）

```
用户在 Composer 文字输入区输入 "@"
  → 弹出联系人选择器
  → 数据源：
      a. Mory 内部已有的 Person EntityNode（优先）
      b. iOS Contacts（补充）
  → 用户选择一个人
  → 人名以 inline tag 形式插入文字
  → 保存时写入 RecordShell.entityMentions
  → 解析时 AI 知道这个人的上下文
```

**关键决策：** 联系人提及不是 `ArtifactKind`，它是 `RecordShell` 级别的语义标注，与 v3 ontology 一致。

## 7. 自动上下文附加流程

在每次 capture 保存时，系统静默执行：

```
CaptureComposerView.save() {
  // 1. 用户创建的 Artifact
  let userArtifacts = buildUserArtifacts()

  // 2. 自动上下文
  let weatherArtifact = await WeatherContextService.captureCurrentWeather()
  let locationArtifact = await LocationContextService.captureCurrentLocation()
  let musicArtifact = await MusicContextService.captureNowPlaying()

  // 3. 合并
  let allArtifacts = userArtifacts
    + [weatherArtifact, locationArtifact, musicArtifact].compactMap { $0 }

  // 4. 保存
  let memory = try await repository.createMemory(
    from: MemoryCaptureDraft(
      rawText: rawText,
      mood: mood,
      artifacts: allArtifacts
    )
  )
}
```

详见 [05_context_auto_collection.md](05_context_auto_collection.md)。
