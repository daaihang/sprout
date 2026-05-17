# 04. Auto Context Services

## 1. 服务架构

三个独立服务，统一由 ContextAutoCollector 协调。ContextAutoCollector 由 Composer 在保存前调用，用于生成可选择的上下文候选；它不在保存后追加 artifact。

```
ContextAutoCollector
  ├── WeatherContextService    (WeatherKit + CoreLocation)
  ├── LocationContextService   (CoreLocation + CLGeocoder)
  └── MusicContextService      (MusicKit)
```

每个服务负责：

1. 检查权限
2. 获取数据
3. 转化为 CaptureArtifactDraft
4. 超时/异常返回 nil

调用时机：

```
CaptureComposerView.onAppear / refresh
  → ContextAutoCollector.collectAll(timeout: 3s)
  → ContextCandidate(draft, capturedAt, isSelected, status)
  → 保存时 selected candidates 与用户 artifacts 一次性写入
```

## 2. WeatherContextService

### 2.1 依赖

- WeatherKit framework
- CoreLocation（直接使用 CLLocationManager，不依赖 LocationContextService）
- 需要在 Apple Developer Portal 启用 WeatherKit capability

### 2.2 接口

```swift
final class WeatherContextService {
    private let locationManager = CLLocationManager()

    /// 请求单次位置，超时 3 秒
    func captureCurrentWeather() async -> CaptureArtifactDraft? {
        // 1. 获取当前位置（直接用 CLLocationManager，不依赖 LocationContextService）
        guard let location = await requestLocation(timeout: 3.0) else { return nil }

        // 2. 查询天气
        guard let weather = try? await WeatherService.shared.weather(for: location) else { return nil }
        let current = weather.currentWeather

        // 3. 构建 draft
        return .weather(
            condition: current.condition.description,
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            humidity: current.humidity,
            windSpeedKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
            uvIndex: current.uvIndex.value,
            location: location
        )
    }

    /// 直接请求位置，不依赖 LocationContextService
    private func requestLocation(timeout: TimeInterval) async -> CLLocation? {
        guard locationManager.authorizationStatus == .authorizedWhenInUse
           || locationManager.authorizationStatus == .authorizedAlways
        else { return nil }

        return await withCheckedContinuation { continuation in
            locationManager.requestLocation()
            // 3 秒超时
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                continuation.resume(returning: nil)
            }
        }
    }
}
```

**设计决策**：WeatherContextService 直接使用 CLLocationManager，不依赖 LocationContextService。原因：
1. Weather 只需要坐标，不需要反向地理编码
2. 避免循环依赖风险
3. 超时控制更灵活（weather 3s vs location 5s）

### 2.3 Artifact 映射

```
CaptureArtifactDraft.weather(...) → Artifact {
    kind: .weather
    title: "\(condition) \(temperature)°C"      // "多云 22°C"
    summary: "\(city) · \(condition) · \(temp)°C · 湿度 \(humidity)%"
    textContent: ""
    metadata: { condition, temperatureCelsius, humidity, windSpeedKmh, uvIndex, ... }
}
```

### 2.4 Info.plist 配置

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Mory 需要你的位置来记录天气和地点信息</string>
```

## 3. LocationContextService

### 3.1 依赖

- CoreLocation
- CLGeocoder（反向地理编码）

### 3.2 接口

```swift
final class LocationContextService {
    private let locationManager = CLLocationManager()

    /// 请求单次位置，超时 5 秒
    func requestLocation() async -> CLLocation? {
        guard locationManager.authorizationStatus == .authorizedWhenInUse
           || locationManager.authorizationStatus == .authorizedAlways
        else { return nil }

        return await withCheckedContinuation { continuation in
            // 使用 CLLocationManager.requestLocation() 获取单次位置
            // delegate 回调中 resume continuation
        }
    }

    /// 获取位置 + 反向地理编码
    func captureCurrentLocation() async -> CaptureArtifactDraft? {
        guard let location = await requestLocation() else { return nil }

        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        let pm = placemarks?.first

        return .location(
            title: pm?.name,
            summary: [pm?.subLocality, pm?.locality, pm?.administrativeArea, pm?.country]
                .compactMap { $0 }
                .joined(separator: " "),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
}
```

### 3.3 精度配置

```swift
locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
// 不需要持续定位，只要一次粗略位置
```

## 4. MusicContextService

### 4.1 依赖

- MusicKit framework
- 需要在 Apple Developer Portal 启用 MusicKit capability

### 4.2 接口

```swift
import MusicKit

final class MusicContextService {

    func captureNowPlaying() async -> CaptureArtifactDraft? {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { return nil }

        // SystemMusicPlayer 获取当前播放
        guard let entry = SystemMusicPlayer.shared.queue.currentEntry,
              case .song(let song) = entry.item
        else { return nil }

        return .music(
            trackName: song.title,
            artistName: song.artistName,
            albumName: song.albumTitle ?? "",
            durationSeconds: Int(song.duration ?? 0),
            artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString
        )
    }
}
```

### 4.3 Info.plist 配置

```xml
<key>NSAppleMusicUsageDescription</key>
<string>Mory 可以记录你正在听的音乐</string>
```

## 5. ContextPermissionManager

统一管理权限状态：

```swift
final class ContextPermissionManager: ObservableObject {
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var musicStatus: MusicAuthorization.Status = .notDetermined
    @Published var microphoneStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    /// 按需请求上下文权限（在 Composer 候选采集/刷新时调用）
    func requestContextPermissions() async {
        // 按顺序请求，避免弹窗重叠
        await requestLocationPermission()
        await requestMusicPermission()
    }

    var canCollectWeather: Bool { locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways }
    var canCollectLocation: Bool { canCollectWeather }
    var canCollectMusic: Bool { musicStatus == .authorized }
    var canRecordAudio: Bool { microphoneStatus == .granted }
    var canTranscribe: Bool { speechStatus == .authorized }
}
```

## 6. 测试策略

| 服务 | 模拟器可测 | 真机必测 |
|------|----------|---------|
| WeatherContextService | ❌ 需要真机位置 | ✅ |
| LocationContextService | ⚠️ 可模拟位置 | ✅ |
| MusicContextService | ❌ 需要真机 Apple Music | ✅ |
| PhotoArtifactProcessor | ✅ 可用测试图片 | ✅ |
| AudioTranscriptionService | ❌ 需要真机麦克风 | ✅ |

Debug 页增加上下文采集测试按钮，可以单独测试每个服务的输出。
