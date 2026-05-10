import SwiftUI

// MARK: - Bottom Capsule Bar

struct BottomCapsuleBar: View {
    @Binding var isOpen: Bool
    var onCameraTapped: () -> Void = {}
    var onAddTapped: () -> Void = {}
    var onSend: (String) -> Void = { _ in }

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @Namespace private var morphSpace

    private let sideSize: CGFloat = 52
    private let pillH: CGFloat = 52
    private let hPad: CGFloat = 20
    private let cardRadius: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed backdrop when open
            if isOpen {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                if #available(iOS 26.0, *) {
                    ios26Bar
                } else {
                    fallbackBar
                }
            }
            .padding(.bottom, 20)
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: isOpen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: iOS 26 — liquid glass with GlassEffectContainer morph

    @available(iOS 26.0, *)
    private var ios26Bar: some View {
        GlassEffectContainer {
            if isOpen {
                cardBody
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                    .matchedGeometryEffect(id: "bar", in: morphSpace)
                    .padding(.horizontal, hPad)
                    .onAppear { inputFocused = true }
            } else {
                HStack(spacing: 10) {
                    Button { onCameraTapped() } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: sideSize, height: sideSize)
                    }
                    .glassEffect(.regular, in: Circle())

                    Button { open() } label: {
                        Text("记录一下…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: pillH)
                    }
                    .glassEffect(.regular, in: Capsule())
                    .matchedGeometryEffect(id: "bar", in: morphSpace)

                    Button { onAddTapped() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: sideSize, height: sideSize)
                    }
                    .glassEffect(.regular, in: Circle())
                }
                .padding(.horizontal, hPad)
            }
        }
    }

    // MARK: Fallback — ultraThinMaterial (iOS 18)

    private var fallbackBar: some View {
        Group {
            if isOpen {
                cardBody
                    .background(.ultraThinMaterial,
                                 in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
                    .padding(.horizontal, hPad)
                    .onAppear { inputFocused = true }
                    .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
            } else {
                HStack(spacing: 10) {
                    fallbackCircleBtn(icon: "camera.fill") { onCameraTapped() }

                    Button { open() } label: {
                        Text("记录一下…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: pillH)
                    }
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 12)
                    .transition(.scale(scale: 0.95, anchor: .bottom).combined(with: .opacity))

                    fallbackCircleBtn(icon: "plus") { onAddTapped() }
                }
                .padding(.horizontal, hPad)
            }
        }
    }

    @ViewBuilder
    private func fallbackCircleBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: sideSize, height: sideSize)
        }
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 12)
    }

    // MARK: Card body (shared between iOS 26 + fallback)

    private var cardBody: some View {
        VStack(spacing: 0) {
            // Top row: close
            HStack {
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(0.12), in: Circle())
                }
                Spacer()
            }
            .padding(.bottom, 10)

            // Text input
            TextField("今天想记录什么？", text: $inputText, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(3...8)
                .focused($inputFocused)

            Divider()
                .padding(.vertical, 12)

            // Toolbar row
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        toolbarBtn("mic")
                        toolbarBtn("photo")
                        toolbarBtn("camera")
                        toolbarBtn("location")
                        toolbarBtn("music.note")
                        toolbarBtn("link")
                    }
                }

                Spacer(minLength: 8)

                let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                Button {
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    close()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            trimmed.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                           : AnyShapeStyle(Color.accentColor),
                            in: Circle()
                        )
                }
                .disabled(trimmed.isEmpty)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func toolbarBtn(_ icon: String) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
        }
    }

    private func open() {
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { isOpen = true }
    }

    private func close() {
        inputFocused = false
        inputText = ""
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) { isOpen = false }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.78, green: 0.91, blue: 0.97), location: 0),
                .init(color: Color(red: 0.92, green: 0.96, blue: 0.92), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        BottomCapsuleBar(isOpen: .constant(false))
    }
}
