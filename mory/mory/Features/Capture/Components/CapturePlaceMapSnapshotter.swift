import Foundation
import MapKit
import UIKit

enum CapturePlaceMapSnapshotter {
    @MainActor
    static func snapshotData(
        latitude: Double?,
        longitude: Double?,
        size: CGSize = CGSize(width: 380, height: 264),
        privacyEnabled: Bool = false
    ) async -> Data? {
        guard !privacyEnabled,
              let latitude,
              let longitude,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        options.size = size
        options.pointOfInterestFilter = .includingAll

        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }

                let image = renderPinnedSnapshot(snapshot: snapshot, coordinate: coordinate, size: size)
                continuation.resume(returning: image.jpegData(compressionQuality: 0.78))
            }
        }
    }

    private static func renderPinnedSnapshot(
        snapshot: MKMapSnapshotter.Snapshot,
        coordinate: CLLocationCoordinate2D,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let point = snapshot.point(for: coordinate)
            let pinRect = CGRect(x: point.x - 10, y: point.y - 28, width: 20, height: 28)
            UIColor.systemRed.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: pinRect.midX - 6, y: pinRect.minY, width: 12, height: 12))
            context.cgContext.move(to: CGPoint(x: pinRect.midX, y: pinRect.maxY))
            context.cgContext.addLine(to: CGPoint(x: pinRect.midX - 6, y: pinRect.minY + 9))
            context.cgContext.addLine(to: CGPoint(x: pinRect.midX + 6, y: pinRect.minY + 9))
            context.cgContext.closePath()
            context.cgContext.fillPath()

            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: pinRect.midX - 2.5, y: pinRect.minY + 3.5, width: 5, height: 5))
        }
    }
}
