import SwiftUI

struct NotebookCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let item: CaptureCardItem
    let accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            paperBackground

            marginLine
                .padding(.leading, 28)

            contentArea
                .padding(EdgeInsets(top: 14, leading: 36, bottom: 14, trailing: 14))
        }
        .frame(width: 180, height: 200)
        .clipShape(notebookShape)
        .overlay {
            notebookShape
                .strokeBorder(Color.brown.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private var paperBackground: some View {
        ZStack {
            Color(red: 0.98, green: 0.96, blue: 0.90)

            Canvas { context, size in
                let lineSpacing: CGFloat = 22
                var y = lineSpacing + 8
                while y < size.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(.blue.opacity(0.12)), lineWidth: 0.5)
                    y += lineSpacing
                }
            }
        }
    }

    private var marginLine: some View {
        Rectangle()
            .fill(Color.red.opacity(0.2))
            .frame(width: 0.5)
    }

    @ViewBuilder
    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = common.title?.trimmedOrNil {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .lineLimit(2)
                    .foregroundStyle(Color(white: 0.15))
            }

            adaptiveContent

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var adaptiveContent: some View {
        switch item.payload {
        case let .todo(payload):
            todoContent(payload)
        case let .link(payload):
            linkContent(payload)
        case let .prompt(payload):
            promptContent(payload)
        default:
            genericContent
        }
    }

    @ViewBuilder
    private func todoContent(_ payload: CaptureTodoCardPayload) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: common.isSelected ? "checkmark.square" : "square")
                .font(.system(size: 11))
                .foregroundStyle(accent.opacity(0.7))
                .padding(.top, 2)

            Text(common.detail)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(Color(white: 0.3))
                .lineLimit(5)
                .strikethrough(common.isSelected, color: Color(white: 0.3).opacity(0.5))
        }
    }

    @ViewBuilder
    private func linkContent(_ payload: CaptureLinkCardPayload) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 9))
                    .foregroundStyle(accent.opacity(0.6))
                Text(common.detail)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.blue.opacity(0.6))
                    .lineLimit(2)
                    .underline()
            }

            if let metadata = common.metadata?.trimmedOrNil {
                Text(metadata)
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(Color(white: 0.4))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func promptContent(_ payload: CapturePromptCardPayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.prompt)
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(Color(white: 0.25))
                .lineLimit(3)
                .italic()

            if let answer = payload.answer?.trimmedOrNil {
                Text(answer)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(Color(white: 0.35))
                    .lineLimit(4)
            }
        }
    }

    private var genericContent: some View {
        Text(common.detail)
            .font(.system(size: 11, design: .serif))
            .foregroundStyle(Color(white: 0.3))
            .lineLimit(6)
    }

    private var notebookShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }
}
