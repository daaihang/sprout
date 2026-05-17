# 05. Context Auto Collection

## 1. 设计原则

自动上下文采集必须遵循三条原则：

1. **低操作** — 系统自动采集候选并默认勾选，用户可取消或刷新
2. **权限优雅降级** — 用户未授权某项权限时，该上下文跳过，不影响保存
3. **稳定输入快照** — 保存时只写入已采集且被选中的候选，AI 第一次分析使用同一份 artifact 快照
4. **不阻塞保存** — 上下文采集超时（3s）自动放弃，保存不等待晚到结果

## 2. 采集时机

每次 `CaptureComposerView` 打开时，系统并行采集上下文候选：

```
Composer onAppear
  ├── WeatherContextService.capture()          （异步，timeout 3s）
  ├── LocationContextService.capture()         （异步，timeout 3s）
  └── MusicContextService.capture()            （异步，timeout 1s）
  → 生成 ContextCandidate 列表
  → 成功候选默认选中，用户可取消或刷新

保存按钮点击
  ├── 合并用户 Artifact + selected ContextCandidate
  ├── 一次性写入 RecordShell + Artifact
  → 触发异步分析
```

该设计替代早期“保存时静默采集”的方案，原因是后者会让第一次 AI 分析拿不到晚到上下文，或在保存/重跑/删除时留下不一致的派生数据。

## 3. 天气采集

### 3.1 触发条件

- 用户已授权位置权限（Weather 需要坐标）
- WeatherKit 可用

### 3.2 技术实现

```swift
// WeatherContextService.swift
import WeatherKit
import CoreLocation

func captureCurrentWeather() async -> CaptureArtifactDraft? {
    guard let location = await locationManager.currentLocation() else { return nil }

    let weather = try? await WeatherService.shared.weather(for: location)
    guard let current = weather?.currentWeather else { return nil }

    return .weather(
        condition: current.condition.description,
        temperatureCelsius: current.temperature.converted(to: .celsius).value,
        humidity: current.humidity,
        windSpeedKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
        uvIndex: current.uvIndex.value,
        location: location
    )
}
```

### 3.3 权限

- 需要 `NSLocationWhenInUseUsageDescription`
- WeatherKit 需要在 Apple Developer Portal 启用
- Info.plist 添加 WeatherKit capability

### 3.4 费用

WeatherKit 每月免费 500,000 次调用。每次 capture 1 次调用。日均 10 次 capture = 月均 300 次。远低于免费额度。

## 4. 地点采集

### 4.1 触发条件

- 用户已授权位置权限

### 4.2 技术实现

```swift
// LocationContextService.swift
import CoreLocation

func captureCurrentLocation() async -> CaptureArtifactDraft? {
    guard let location = await locationManager.currentLocation() else { return nil }

    let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
    let placemark = placemarks?.first

    return .location(
        title: placemark?.name,
        summary: [
            placemark?.subLocality,
            placemark?.locality,
            placemark?.administrativeArea,
            placemark?.country
        ].compactMap { $0 }.joined(separator: " "),
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude
    )
}
```

### 4.3 精度要求

- 使用 `kCLLocationAccuracyHundredMeters`，不需要高精度
- 如果 5 秒内无法获取位置，放弃

## 5. 音乐采集

### 5.1 触发条件

- 用户已授权 MusicKit
- 当前正在播放音乐

### 5.2 技术实现

```swift
// MusicContextService.swift
import MusicKit

func captureNowPlaying() async -> CaptureArtifactDraft? {
    let status = await MusicAuthorization.request()
    guard status == .authorized else { return nil }

    guard let player = SystemMusicPlayer.shared.queue.currentEntry else { return nil }

    switch player.item {
    case .song(let song):
        return .music(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            durationSeconds: Int(song.duration ?? 0),
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
        )
    default:
        return nil
    }
}
```

### 5.3 权限

- 需要 `NSAppleMusicUsageDescription`
- Info.plist 添加 MusicKit capability

## 6. 权限管理策略

### 6.1 首次请求时机

不在 app 启动时一次性请求所有权限。改为：

| 权限 | 请求时机 |
|------|---------|
| 位置 | 用户打开 Composer 后启用/刷新上下文候选时 |
| MusicKit | 用户打开 Composer 后启用/刷新音乐候选时 |
| 麦克风 | 用户第一次选择录音类型时 |
| 照片 | 用户第一次选择照片类型时 |
| 语音识别 | 用户第一次录音后 |
| 通讯录 | 用户第一次输入 @ 时（P1） |

### 6.2 权限状态持久化

```swift
enum ContextPermissionState: String, Codable {
    case notAsked       // 还没问过
    case granted        // 已授权
    case denied         // 已拒绝
    case restricted     // 系统限制
}
```

存储在 UserDefaults，avoid 重复弹窗。

### 6.3 设置页入口

在 Debug 页（或未来的设置页）提供权限状态查看和跳转到系统设置的入口。v3 已有 `UIApplication.openSettingsURLString` 入口。

## 7. 采集错误处理

| 场景 | 处理 |
|------|------|
| 位置权限被拒 | 跳过地点和天气 Artifact |
| WeatherKit 请求失败 | 跳过天气 Artifact，不阻塞保存 |
| MusicKit 授权但无播放 | 不生成 music Artifact |
| 反向地理编码失败 | 仍保存坐标，title 用坐标代替 |
| 采集超时（3s） | 取消该采集，保存已获取的 Artifact |

错误不阻断保存。权限缺失或候选失败可以在 Composer 中显示启用/刷新状态；产品 UI 不展示底层异常。
