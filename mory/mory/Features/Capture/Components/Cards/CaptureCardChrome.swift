import SwiftUI

struct CaptureCardChrome<Content: View, Footer: View, TrailingControl: View, ContainerStroke: View>: View {
    let item: CaptureCardItem
    let containerBackground: AnyShapeStyle
    let containerStroke: ContainerStroke
    let footer: Footer
    let trailingControl: TrailingControl
    let showsLayoutGuides: Bool
    let fieldAuditText: String?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(containerBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .redacted(reason: item.state == .loading ? .placeholder : [])
                .overlay(alignment: .bottomLeading) { footer }
                .overlay {
                    if showsLayoutGuides {
                        layoutGuides
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let fieldAuditText {
                        Text(fieldAuditText)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(5)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(containerStroke)

            trailingControl
                .padding(9)
        }
    }

    private var layoutGuides: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.yellow.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .allowsHitTesting(false)
    }
}
