import SwiftUI

struct HomeTopTabsBar: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTag: HomeTopDrawerTag
    let isPresented: Bool
    var onSelectTag: () -> Void = {}

    private let horizontalInset: CGFloat = 16
    private let topSpacing: CGFloat = 10
    private let bottomSpacing: CGFloat = 8
    private let tagHeight: CGFloat = 44
    private let tagSpacing: CGFloat = 12
    private let selectedHorizontalPadding: CGFloat = 18
    private let unselectedHorizontalPadding: CGFloat = 16

    static let totalHeight: CGFloat = 62

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: tagSpacing) {
                    ForEach(HomeTopDrawerTag.allCases) { tag in
                        Button {
                            selectedTag = tag
                            onSelectTag()
                        } label: {
                            tagButtonLabel(for: tag)
                        }
                        .buttonStyle(.borderless)
                        .id(tag.id)
                    }
                }
                .padding(.horizontal, horizontalInset)
                .padding(.top, topSpacing)
                .padding(.bottom, bottomSpacing)
            }
            .scrollClipDisabled()
            .onAppear {
                proxy.scrollTo(selectedTag.id, anchor: .center)
            }
            .onChange(of: selectedTag) { _, newTag in
                withTransaction(Transaction(animation: .smooth(duration: 0.24))) {
                    proxy.scrollTo(newTag.id, anchor: .center)
                }
            }
        }
        .frame(height: Self.totalHeight, alignment: .top)
        .opacity(isPresented ? 1 : 0)
        .offset(y: isPresented ? 0 : -12)
        .animation(.smooth(duration: 0.22), value: isPresented)
    }

    @ViewBuilder
    private func tagButtonLabel(for tag: HomeTopDrawerTag) -> some View {
        let isSelected = selectedTag == tag

        Label {
            Text(localization.string(tag.localizationKey, default: tag.defaultTitle))
                .lineLimit(1)
        } icon: {
            Image(systemName: tag.systemImageName)
                .font(.system(size: 15, weight: .semibold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, isSelected ? selectedHorizontalPadding : unselectedHorizontalPadding)
        .frame(height: tagHeight)
        .background(tagButtonBackground(isSelected: isSelected))
        .overlay(tagButtonBorder(isSelected: isSelected))
        .shadow(color: tagButtonShadowColor(isSelected: isSelected), radius: isSelected ? 18 : 10, x: 0, y: 6)
        .scaleEffect(isSelected ? 1.0 : 0.98)
    }

    @ViewBuilder
    private func tagButtonBackground(isSelected: Bool) -> some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(
                    isSelected ? .regular.tint(Color.accentColor) : .regular,
                    in: Capsule()
                )
        } else {
            Capsule()
                .fill(isSelected ? Color.accentColor : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
        }
    }

    @ViewBuilder
    private func tagButtonBorder(isSelected: Bool) -> some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.16),
                    lineWidth: 0.8
                )
        } else {
            Capsule()
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.16) : Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28),
                    lineWidth: 0.6
                )
        }
    }

    private func tagButtonShadowColor(isSelected: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.26 : 0.22)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06)
    }
}
