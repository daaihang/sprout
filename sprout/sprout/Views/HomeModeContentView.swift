import SwiftUI
import UIKit

struct HomeModeContentView: View {
    @Environment(AppLocalization.self) private var localization
    @Binding var selectedTag: HomeTopDrawerTag
    @Binding var selectedDate: Date
    let cardsTopInset: CGFloat
    var onPrimaryContentInteraction: () -> Void = {}

    var body: some View {
        Group {
            switch selectedTag {
            case .cards:
                HomeCardsPagerView(selectedDate: $selectedDate, topContentInset: cardsTopInset)
            case .rawRecords:
                RecordTimelineView(selectedDate: selectedDate)
            case .arcs:
                ArcsHomeView(selectedDate: selectedDate)
            case .people:
                PeopleHomeView()
            case .decisions:
                placeholderView(for: .decisions)
            case .map:
                placeholderView(for: .map)
            case .photos:
                placeholderView(for: .photos)
            }
        }
        .background(Color.clear)
        .overlay {
            ClearAncestorBackgroundView(clearDescendantScrollViews: true)
                .allowsHitTesting(false)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    onPrimaryContentInteraction()
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onPrimaryContentInteraction()
                }
        )
    }

    private func localizedTitle(for tag: HomeTopDrawerTag) -> String {
        localization.string(tag.localizationKey, default: tag.defaultTitle)
    }

    @ViewBuilder
    private func placeholderView(for tag: HomeTopDrawerTag) -> some View {
        HomeSectionPlaceholderView(
            systemImage: tag.systemImageName,
            title: localizedTitle(for: tag),
            subtitle: placeholderSubtitle(for: tag)
        )
    }

    private func placeholderSubtitle(for tag: HomeTopDrawerTag) -> String {
        switch tag {
        case .arcs:
            return localization.string(
                "content.home.placeholder.arcs",
                default: "阶段页已接入，会展示当前阶段、阶段反思与近期阶段列表。"
            )
        case .decisions:
            return localization.string(
                "content.home.placeholder.decisions",
                default: "决策主页还未接入，先保留这个入口。"
            )
        case .map:
            return localization.string(
                "content.home.placeholder.map",
                default: "地图主页还未接入，先保留这个入口。"
            )
        case .photos:
            return localization.string(
                "content.home.placeholder.photos",
                default: "图片墙主页还未接入，先保留这个入口。"
            )
        case .cards, .rawRecords, .people:
            return ""
        }
    }
}

private struct HomeCardsPagerView: View {
    @Binding var selectedDate: Date
    let topContentInset: CGFloat

    var body: some View {
        HomeCardsSwiftUIPager(selectedDate: $selectedDate, topContentInset: topContentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

private struct HomeCardsPageView: View {
    let date: Date
    let topContentInset: CGFloat

    var body: some View {
        DailyView(date: date, topContentInset: topContentInset)
            .id(date)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
    }
}

private struct NativeDayPagingView: UIViewControllerRepresentable {
    @Binding var selectedDate: Date
    let topContentInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, topContentInset: topContentInset)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        configureTransparentBackgrounds(for: controller)

        let initialDate = context.coordinator.clamped(date: selectedDate)
        let initialController = context.coordinator.controller(for: initialDate)
        context.coordinator.currentDate = initialDate
        controller.setViewControllers([initialController], direction: .forward, animated: false)
        context.coordinator.pruneCache(around: initialDate)
        configureTransparentBackgrounds(for: controller)

        return controller
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        context.coordinator.topContentInset = topContentInset
        context.coordinator.refreshCachedControllers()
        context.coordinator.refreshVisibleControllers(in: uiViewController)
        let targetDate = context.coordinator.clamped(date: selectedDate)
        guard !context.coordinator.calendar.isDate(targetDate, inSameDayAs: context.coordinator.currentDate) else {
            configureTransparentBackgrounds(for: uiViewController)
            return
        }

        let direction: UIPageViewController.NavigationDirection =
            targetDate > context.coordinator.currentDate ? .forward : .reverse
        let targetController = context.coordinator.controller(for: targetDate)

        context.coordinator.currentDate = targetDate
        uiViewController.setViewControllers([targetController], direction: direction, animated: false)
        context.coordinator.pruneCache(around: targetDate)
        configureTransparentBackgrounds(for: uiViewController)
    }

    private func configureTransparentBackgrounds(for controller: UIPageViewController) {
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        for subview in controller.view.subviews {
            subview.backgroundColor = .clear
            subview.isOpaque = false

            if let scrollView = subview as? UIScrollView {
                scrollView.backgroundColor = .clear
                scrollView.isOpaque = false
            }
        }

        controller.viewControllers?.forEach { hosted in
            hosted.view.backgroundColor = .clear
            hosted.view.isOpaque = false
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let calendar = Calendar.current
        private let anchorDate: Date
        private let selectedDate: Binding<Date>
        private var cachedControllers: [Date: DayPageHostingController] = [:]
        var topContentInset: CGFloat

        var currentDate: Date

        init(selectedDate: Binding<Date>, topContentInset: CGFloat) {
            self.selectedDate = selectedDate
            self.topContentInset = topContentInset
            let today = calendar.startOfDay(for: Date())
            self.anchorDate = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) ?? today
            let normalized = calendar.startOfDay(for: selectedDate.wrappedValue)
            let clamped = max(normalized, anchorDate)
            self.currentDate = clamped
        }

        func clamped(date: Date) -> Date {
            let normalized = calendar.startOfDay(for: date)
            return max(normalized, anchorDate)
        }

        func controller(for date: Date) -> DayPageHostingController {
            let normalizedDate = clamped(date: date)
            if let cached = cachedControllers[normalizedDate] {
                cached.rootView = HomeCardsPageView(date: normalizedDate, topContentInset: topContentInset)
                return cached
            }

            let controller = DayPageHostingController(date: normalizedDate, topContentInset: topContentInset)
            controller.view.backgroundColor = .clear
            cachedControllers[normalizedDate] = controller
            return controller
        }

        func refreshCachedControllers() {
            for (date, controller) in cachedControllers {
                controller.rootView = HomeCardsPageView(date: date, topContentInset: topContentInset)
            }
        }

        func refreshVisibleControllers(in pageViewController: UIPageViewController) {
            pageViewController.viewControllers?.forEach { hosted in
                guard let controller = hosted as? DayPageHostingController else { return }
                controller.rootView = HomeCardsPageView(
                    date: controller.representedDate,
                    topContentInset: topContentInset
                )
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let controller = viewController as? DayPageHostingController,
                  let previousDate = calendar.date(byAdding: .day, value: -1, to: controller.representedDate),
                  previousDate >= anchorDate
            else {
                return nil
            }

            return self.controller(for: previousDate)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let controller = viewController as? DayPageHostingController,
                  let nextDate = calendar.date(byAdding: .day, value: 1, to: controller.representedDate)
            else {
                return nil
            }

            return self.controller(for: nextDate)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let visibleController = pageViewController.viewControllers?.first as? DayPageHostingController
            else {
                return
            }

            let visibleDate = visibleController.representedDate
            guard !calendar.isDate(visibleDate, inSameDayAs: currentDate) else { return }

            currentDate = visibleDate
            pruneCache(around: visibleDate)
            HapticFeedback.selection()
            selectedDate.wrappedValue = visibleDate
        }

        func pruneCache(around centerDate: Date) {
            let keepDates = Set(
                (-1...1).compactMap { offset in
                    calendar.date(byAdding: .day, value: offset, to: centerDate).map(clamped(date:))
                }
            )
            cachedControllers = cachedControllers.filter { keepDates.contains($0.key) }
        }
    }
}

private final class DayPageHostingController: UIHostingController<HomeCardsPageView> {
    let representedDate: Date

    init(date: Date, topContentInset: CGFloat) {
        self.representedDate = Calendar.current.startOfDay(for: date)
        super.init(rootView: HomeCardsPageView(date: self.representedDate, topContentInset: topContentInset))
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }
}

struct ClearAncestorBackgroundView: UIViewRepresentable {
    var clearDescendantScrollViews: Bool = false

    final class Coordinator {
        weak var lastSuperview: UIView?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.backgroundColor = .clear
        uiView.isOpaque = false

        let superviewChanged = context.coordinator.lastSuperview !== uiView.superview
        guard superviewChanged else { return }

        context.coordinator.lastSuperview = uiView.superview

        var currentSuperview = uiView.superview
        var steps = 0
        while let view = currentSuperview, steps < 16 {
            clearBackground(for: view)
            if clearDescendantScrollViews {
                clearImmediateScrollContainers(under: view)
            }
            currentSuperview = view.superview
            steps += 1
        }
    }

    private func clearBackground(for view: UIView) {
        guard !(view is UIVisualEffectView) else { return }
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    private func clearImmediateScrollContainers(under root: UIView) {
        for subview in root.subviews {
            clearBackground(for: subview)
            if let scrollView = subview as? UIScrollView {
                clearBackground(for: scrollView)
            }
            if let tableView = subview as? UITableView {
                clearBackground(for: tableView)
            }
            if let collectionView = subview as? UICollectionView {
                clearBackground(for: collectionView)
            }
        }
    }
}

struct HomeSectionPlaceholderView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    )

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 96)
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
