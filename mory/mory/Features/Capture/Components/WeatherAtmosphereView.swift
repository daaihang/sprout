import SwiftUI

struct WeatherAtmosphereView: View {
    let spec: CaptureWeatherAtmosphereSpec
    let isReduceMotionEnabled: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: paletteColors,
                startPoint: .top,
                endPoint: .bottom
            )

            if spec.motionPattern == .staticPattern || isReduceMotionEnabled {
                WeatherAtmosphereFrame(spec: spec, time: 0)
            } else {
                TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
                    WeatherAtmosphereFrame(
                        spec: spec,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(spec.palette == .storm ? 0.18 : 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var paletteColors: [Color] {
        switch spec.palette {
        case .warmLight:
            return [
                Color(red: 0.56, green: 0.82, blue: 1.0),
                Color(red: 0.9, green: 0.96, blue: 1.0),
                Color(red: 1.0, green: 0.83, blue: 0.42)
            ]
        case .night:
            return [
                Color(red: 0.05, green: 0.08, blue: 0.2),
                Color(red: 0.1, green: 0.14, blue: 0.32),
                Color(red: 0.2, green: 0.19, blue: 0.38)
            ]
        case .softCloud:
            return [
                Color(red: 0.62, green: 0.76, blue: 0.88),
                Color(red: 0.82, green: 0.89, blue: 0.94),
                Color(red: 0.95, green: 0.97, blue: 0.98)
            ]
        case .coolRain:
            return [
                Color(red: 0.24, green: 0.42, blue: 0.58),
                Color(red: 0.17, green: 0.31, blue: 0.46),
                Color(red: 0.1, green: 0.19, blue: 0.31)
            ]
        case .storm:
            return [
                Color(red: 0.07, green: 0.1, blue: 0.18),
                Color(red: 0.12, green: 0.16, blue: 0.3),
                Color(red: 0.2, green: 0.15, blue: 0.34)
            ]
        case .frost:
            return [
                Color(red: 0.72, green: 0.9, blue: 1.0),
                Color(red: 0.91, green: 0.97, blue: 1.0),
                Color(red: 0.99, green: 1.0, blue: 1.0)
            ]
        case .fog:
            return [
                Color(red: 0.7, green: 0.77, blue: 0.82),
                Color(red: 0.84, green: 0.88, blue: 0.9),
                Color(red: 0.94, green: 0.95, blue: 0.94)
            ]
        case .wind:
            return [
                Color(red: 0.58, green: 0.86, blue: 0.92),
                Color(red: 0.78, green: 0.93, blue: 0.94),
                Color(red: 0.96, green: 0.99, blue: 0.97)
            ]
        case .heat:
            return [
                Color(red: 1.0, green: 0.58, blue: 0.36),
                Color(red: 1.0, green: 0.74, blue: 0.45),
                Color(red: 1.0, green: 0.9, blue: 0.58)
            ]
        case .neutral:
            return [
                Color(.secondarySystemBackground),
                Color(.tertiarySystemBackground)
            ]
        }
    }

    private var frameInterval: TimeInterval {
        switch spec.motionPattern {
        case .thunderstorm, .heavyRainFall, .rainFall, .snowDrift:
            return 1.0 / 24.0
        default:
            return 1.0 / 30.0
        }
    }
}

private struct WeatherAtmosphereFrame: View {
    let spec: CaptureWeatherAtmosphereSpec
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            drawBaseTexture(in: &context, size: size)

            switch spec.motionPattern {
            case .staticPattern:
                drawStaticTexture(in: &context, size: size)
            case .sunGlow:
                drawSunGlow(in: &context, size: size)
            case .nightTwinkle:
                drawNightTwinkle(in: &context, size: size)
            case .rainFall:
                drawRain(in: &context, size: size, count: 18, speed: 64, length: 24, opacity: 0.3)
            case .heavyRainFall:
                drawRain(in: &context, size: size, count: 34, speed: 96, length: 34, opacity: 0.42)
                drawWaterGlints(in: &context, size: size)
            case .snowDrift:
                drawSnow(in: &context, size: size)
            case .thunderstorm:
                drawRain(in: &context, size: size, count: 26, speed: 84, length: 32, opacity: 0.4)
                drawStormClouds(in: &context, size: size)
                drawThunderFlash(in: &context, size: size)
            case .fogDrift:
                drawFog(in: &context, size: size)
            case .windFlow:
                drawWind(in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBaseTexture(in context: inout GraphicsContext, size: CGSize) {
        let count = spec.palette == .night ? 10 : 7
        for index in 0..<count {
            let x = deterministic(index, salt: 11) * size.width
            let y = deterministic(index, salt: 29) * size.height
            let radius = (10 + deterministic(index, salt: 47) * 28) * spec.intensity
            let rect = CGRect(x: x - radius / 2, y: y - radius / 2, width: radius, height: radius)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.035 + 0.03 * spec.intensity))
            )
        }
    }

    private func drawStaticTexture(in context: inout GraphicsContext, size: CGSize) {
        switch spec.motionPattern {
        case .rainFall, .heavyRainFall, .thunderstorm:
            drawRain(in: &context, size: size, count: 12, speed: 0, length: 22, opacity: 0.18)
        case .snowDrift:
            drawSnow(in: &context, size: size, frozen: true)
        case .fogDrift:
            drawFog(in: &context, size: size, frozen: true)
        case .windFlow:
            drawWind(in: &context, size: size, frozen: true)
        case .sunGlow:
            drawSunGlow(in: &context, size: size, frozen: true)
        case .nightTwinkle:
            drawNightTwinkle(in: &context, size: size, frozen: true)
        case .staticPattern:
            break
        }
    }

    private func drawSunGlow(in context: inout GraphicsContext, size: CGSize, frozen: Bool = false) {
        let pulse = frozen ? 0.45 : 0.5 + 0.5 * sin(time * 0.7)
        let radius = min(size.width, size.height) * (0.52 + 0.08 * pulse)
        let center = CGPoint(x: size.width * 0.82, y: size.height * 0.12)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius / 2, y: center.y - radius / 2, width: radius, height: radius)),
            with: .color(Color.white.opacity(0.12 + 0.08 * pulse))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius / 4, y: center.y - radius / 4, width: radius / 2, height: radius / 2)),
            with: .color(Color.yellow.opacity(0.12 + 0.08 * spec.intensity))
        )
    }

    private func drawNightTwinkle(in context: inout GraphicsContext, size: CGSize, frozen: Bool = false) {
        for index in 0..<18 {
            let twinkle = frozen ? 0.4 : 0.24 + 0.28 * abs(sin(time * 0.7 + Double(index) * 0.83))
            let starSize = 1.3 + deterministic(index, salt: 5) * 2.5
            let point = CGPoint(
                x: deterministic(index, salt: 13) * size.width,
                y: deterministic(index, salt: 31) * size.height * 0.72
            )
            context.fill(
                Path(ellipseIn: CGRect(x: point.x, y: point.y, width: starSize, height: starSize)),
                with: .color(Color.white.opacity(twinkle))
            )
        }
    }

    private func drawRain(
        in context: inout GraphicsContext,
        size: CGSize,
        count: Int,
        speed: Double,
        length: Double,
        opacity: Double
    ) {
        for index in 0..<count {
            let x = deterministic(index, salt: 19) * (size.width + 44) - 22
            let baseY = deterministic(index, salt: 37) * (size.height + CGFloat(length) + 42)
            let offset = speed == 0 ? 0 : CGFloat((time * speed + Double(index * 9)).truncatingRemainder(dividingBy: Double(size.height + CGFloat(length) + 42)))
            let y = (baseY + offset).truncatingRemainder(dividingBy: size.height + CGFloat(length) + 42) - CGFloat(length)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + CGFloat(length * 0.28), y: y + CGFloat(length)))
            context.stroke(
                path,
                with: .color(Color.white.opacity(opacity * spec.intensity)),
                style: StrokeStyle(lineWidth: length > 30 ? 1.6 : 1.15, lineCap: .round)
            )
        }
    }

    private func drawWaterGlints(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<8 {
            let x = deterministic(index, salt: 7) * size.width
            let y = size.height * (0.74 + deterministic(index, salt: 41) * 0.22)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + 18, y: y + 2))
            context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
        }
    }

    private func drawSnow(in context: inout GraphicsContext, size: CGSize, frozen: Bool = false) {
        for index in 0..<28 {
            let layer = Double(index % 3)
            let drift = frozen ? 0 : sin(time * (0.28 + layer * 0.08) + Double(index)) * (6 + layer * 4)
            let fall = frozen ? 0 : (time * (8 + layer * 5) + Double(index * 13)).truncatingRemainder(dividingBy: Double(size.height + 28))
            let point = CGPoint(
                x: deterministic(index, salt: 3) * size.width + CGFloat(drift),
                y: (deterministic(index, salt: 23) * size.height + CGFloat(fall)).truncatingRemainder(dividingBy: size.height + 20) - 10
            )
            let snowSize = CGFloat(2.0 + layer * 1.4)
            context.fill(
                Path(ellipseIn: CGRect(x: point.x, y: point.y, width: snowSize, height: snowSize)),
                with: .color(Color.white.opacity(0.34 + 0.11 * layer))
            )
        }
    }

    private func drawStormClouds(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<4 {
            let width = size.width * CGFloat(0.42 + deterministic(index, salt: 17) * 0.28)
            let height = size.height * CGFloat(0.2 + deterministic(index, salt: 21) * 0.08)
            let x = size.width * CGFloat(deterministic(index, salt: 25)) - width * 0.22
            let y = size.height * CGFloat(0.02 + deterministic(index, salt: 27) * 0.2)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)),
                with: .color(Color.black.opacity(0.13))
            )
        }
    }

    private func drawThunderFlash(in context: inout GraphicsContext, size: CGSize) {
        let cycle = time.truncatingRemainder(dividingBy: 6.5)
        let pulse = max(0, 1 - abs(cycle - 0.42) / 0.42)
        let flash = pow(pulse, 2.4)
        guard flash > 0.04 else { return }

        var bolt = Path()
        bolt.move(to: CGPoint(x: size.width * 0.68, y: size.height * 0.14))
        bolt.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.48))
        bolt.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.45))
        bolt.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.86))
        context.stroke(
            bolt,
            with: .color(Color.white.opacity(0.18 + 0.3 * flash)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color.white.opacity(0.04 * flash))
        )
    }

    private func drawFog(in context: inout GraphicsContext, size: CGSize, frozen: Bool = false) {
        for index in 0..<6 {
            let width = size.width * CGFloat(0.52 + deterministic(index, salt: 33) * 0.42)
            let xShift = frozen ? 0 : sin(time * (0.18 + Double(index) * 0.015) + Double(index)) * 18
            let x = size.width * CGFloat(deterministic(index, salt: 45)) - width * 0.35 + CGFloat(xShift)
            let y = size.height * CGFloat(0.18 + deterministic(index, salt: 55) * 0.62)
            let rect = CGRect(x: x, y: y, width: width, height: 6 + CGFloat(index % 3) * 2)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 6),
                with: .color(Color.white.opacity(0.16 + 0.035 * Double(index % 3)))
            )
        }
    }

    private func drawWind(in context: inout GraphicsContext, size: CGSize, frozen: Bool = false) {
        for index in 0..<7 {
            let width = size.width * CGFloat(0.36 + deterministic(index, salt: 67) * 0.42)
            let speed = frozen ? 0 : time * (18 + Double(index % 3) * 8)
            let x = CGFloat((speed + Double(index * 31)).truncatingRemainder(dividingBy: Double(size.width + width))) - width
            let y = size.height * CGFloat(0.18 + deterministic(index, salt: 71) * 0.62)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(
                to: CGPoint(x: x + width, y: y + CGFloat(index % 2 == 0 ? 8 : -8)),
                control1: CGPoint(x: x + width * 0.34, y: y - 12),
                control2: CGPoint(x: x + width * 0.64, y: y + 12)
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.16 + 0.05 * spec.intensity)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }

    private func deterministic(_ index: Int, salt: Int) -> CGFloat {
        let value = (index * 1103515245 + salt * 12345 + 67890) & 0x7fffffff
        return CGFloat(value % 10_000) / 10_000
    }
}
