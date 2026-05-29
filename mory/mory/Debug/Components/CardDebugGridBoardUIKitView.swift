import SwiftUI
import UIKit

struct CardDebugGridBoardUIKitView: UIViewRepresentable {
    let slots: [CardDebugGridBoardLabSlot]
    let storedItems: [CardDebugGridBoardLabItem]
    let containerWidth: CGFloat
    let boardHeight: CGFloat
    let metrics: MemoryDeskBoardMetrics
    let activeDragItemID: UUID?
    let activeDragTarget: MemoryCardGridPlacement?
    let overlapCount: Int
    var onDragEnded: (CardDebugGridDragPreview) -> Void
    var onDelete: (UUID) -> Void
    var onMoveEarlier: (UUID) -> Void
    var onMoveLater: (UUID) -> Void
    var onSetSize: (UUID, MemoryCardSizeToken) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = CardDebugGridBoardCollectionLayout()
        layout.configure(
            slots: slots,
            boardSize: CGSize(width: containerWidth, height: boardHeight),
            activeDragItemID: activeDragItemID
        )

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.18)
        collectionView.layer.cornerRadius = 14
        collectionView.clipsToBounds = true
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.delaysContentTouches = false
        collectionView.canCancelContentTouches = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.reuseIdentifier)

        let overlayView = CardDebugGridBoardOverlayUIView()
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear
        collectionView.addSubview(overlayView)
        collectionView.sendSubviewToBack(overlayView)
        context.coordinator.overlayView = overlayView

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.28
        longPress.allowableMovement = 16
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        collectionView.addGestureRecognizer(longPress)
        context.coordinator.longPressRecognizer = longPress

        context.coordinator.apply(parent: self, to: collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(parent: self, to: collectionView)
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
        static let reuseIdentifier = "CardDebugGridBoardCell"

        var parent: CardDebugGridBoardUIKitView
        weak var overlayView: CardDebugGridBoardOverlayUIView?
        weak var longPressRecognizer: UILongPressGestureRecognizer?

        private var itemIDs: [UUID] = []
        private var dragContext: CardDebugGridUIKitDragContext?
        private var previewSlots: [CardDebugGridBoardLabSlot]?

        private var currentSlots: [CardDebugGridBoardLabSlot] {
            previewSlots ?? parent.slots
        }

        init(parent: CardDebugGridBoardUIKitView) {
            self.parent = parent
        }

        func apply(
            parent: CardDebugGridBoardUIKitView,
            to collectionView: UICollectionView
        ) {
            guard let layout = collectionView.collectionViewLayout as? CardDebugGridBoardCollectionLayout else {
                return
            }

            let activeSlots = currentSlots
            let activeBoardHeight = boardHeight(for: activeSlots)
            let activeDragItemID = dragContext?.session.itemID ?? parent.activeDragItemID
            let activeDragTarget = dragContext?.lastTargetPlacement ?? parent.activeDragTarget
            let activeDragSize = dragContext?.session.itemSize ?? parent.activeDragItemID.flatMap { id in
                activeSlots.first(where: { $0.item.id == id })?.item.size
            }

            layout.configure(
                slots: activeSlots,
                boardSize: CGSize(width: parent.containerWidth, height: activeBoardHeight),
                activeDragItemID: activeDragItemID
            )

            overlayView?.configure(
                boardHeight: activeBoardHeight,
                metrics: parent.metrics,
                targetPlacement: activeDragTarget,
                targetSize: activeDragSize
            )
            overlayView?.frame = CGRect(
                x: 0,
                y: 0,
                width: parent.containerWidth,
                height: activeBoardHeight
            )

            let nextIDs = activeSlots.map(\.item.id)
            if nextIDs != itemIDs {
                itemIDs = nextIDs
                collectionView.reloadData()
            } else {
                performWithoutAnimation(in: collectionView) {
                    collectionView.collectionViewLayout.invalidateLayout()
                    collectionView.layoutIfNeeded()
                    configureVisibleCells(in: collectionView)
                }
            }

            let maxOffsetY = max(0, activeBoardHeight - collectionView.bounds.height)
            if collectionView.contentOffset.y > maxOffsetY {
                collectionView.contentOffset.y = max(0, maxOffsetY)
            }
        }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            currentSlots.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifier,
                for: indexPath
            )
            configure(cell, at: indexPath)
            return cell
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let collectionView = recognizer.view as? UICollectionView else { return }
            let contentLocation = recognizer.location(in: collectionView)

            switch recognizer.state {
            case .began:
                beginDrag(at: contentLocation, in: collectionView, recognizer: recognizer)

            case .changed:
                guard let context = dragContext else { return }
                updateDrag(
                    for: context.session,
                    at: contentLocation,
                    in: collectionView,
                    forcePreview: false
                )

            case .ended:
                guard let context = dragContext else {
                    cancelDrag(in: collectionView)
                    return
                }
                updateDrag(
                    for: context.session,
                    at: contentLocation,
                    in: collectionView,
                    forcePreview: true
                )
                let preview = context.latestPreview ?? CardDebugGridBoardLabModel.dragPreview(
                    for: context.session,
                    at: contentLocation,
                    boardWidth: parent.containerWidth,
                    metrics: parent.metrics,
                    in: parent.storedItems
                )
                finishDrag(in: collectionView)
                parent.onDragEnded(preview)

            case .cancelled, .failed:
                cancelDrag(in: collectionView)

            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer === (gestureRecognizer.view as? UICollectionView)?.panGestureRecognizer
        }

        private func beginDrag(
            at contentLocation: CGPoint,
            in collectionView: UICollectionView,
            recognizer: UILongPressGestureRecognizer
        ) {
            guard
                let session = CardDebugGridBoardLabModel.beginDrag(at: contentLocation, in: currentSlots),
                let index = currentSlots.firstIndex(where: { $0.item.id == session.itemID }),
                let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)),
                let snapshotView = cell.snapshotView(afterScreenUpdates: false)
            else {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                return
            }

            snapshotView.frame = session.geometry.originalFrame
            snapshotView.layer.shadowColor = UIColor.black.cgColor
            snapshotView.layer.shadowOpacity = 0.16
            snapshotView.layer.shadowRadius = 12
            snapshotView.layer.shadowOffset = CGSize(width: 0, height: 8)
            collectionView.addSubview(snapshotView)
            cell.isHidden = true
            collectionView.isScrollEnabled = false
            dragContext = CardDebugGridUIKitDragContext(
                session: session,
                snapshotView: snapshotView,
                hiddenCell: cell
            )
            updateDrag(
                for: session,
                at: contentLocation,
                in: collectionView,
                forcePreview: true
            )
        }

        private func updateDrag(
            for session: CardDebugGridUIKitDragSession,
            at contentLocation: CGPoint,
            in collectionView: UICollectionView,
            forcePreview: Bool
        ) {
            guard let context = dragContext else { return }
            context.snapshotView.frame = session.geometry.liftedFrame(for: contentLocation)

            let targetPlacement = CardDebugGridBoardLabModel.targetPlacement(
                for: session.geometry.gridAnchorLocation(for: contentLocation),
                itemSize: session.itemSize,
                boardWidth: parent.containerWidth,
                metrics: parent.metrics
            )
            guard forcePreview || targetPlacement != context.lastTargetPlacement else {
                return
            }

            let preview = CardDebugGridBoardLabModel.dragPreview(
                for: session,
                at: contentLocation,
                boardWidth: parent.containerWidth,
                metrics: parent.metrics,
                in: parent.storedItems
            )
            context.lastTargetPlacement = preview.targetPlacement
            context.latestPreview = preview
            previewSlots = CardDebugGridBoardLabModel.slots(
                for: preview.items,
                mode: .storedPlacement,
                containerWidth: parent.containerWidth,
                metrics: parent.metrics
            )
            applyCurrentLayout(to: collectionView)
        }

        private func finishDrag(in collectionView: UICollectionView) {
            dragContext?.snapshotView.removeFromSuperview()
            dragContext?.hiddenCell?.isHidden = false
            dragContext = nil
            previewSlots = nil
            collectionView.isScrollEnabled = true
            applyCurrentLayout(to: collectionView)
        }

        private func cancelDrag(in collectionView: UICollectionView) {
            finishDrag(in: collectionView)
        }

        private func applyCurrentLayout(to collectionView: UICollectionView) {
            guard let layout = collectionView.collectionViewLayout as? CardDebugGridBoardCollectionLayout else {
                return
            }
            let activeSlots = currentSlots
            let activeBoardHeight = boardHeight(for: activeSlots)
            let targetPlacement = dragContext?.lastTargetPlacement ?? parent.activeDragTarget
            let targetSize = dragContext?.session.itemSize ?? parent.activeDragItemID.flatMap { id in
                activeSlots.first(where: { $0.item.id == id })?.item.size
            }
            layout.configure(
                slots: activeSlots,
                boardSize: CGSize(width: parent.containerWidth, height: activeBoardHeight),
                activeDragItemID: dragContext?.session.itemID ?? parent.activeDragItemID
            )
            overlayView?.configure(
                boardHeight: activeBoardHeight,
                metrics: parent.metrics,
                targetPlacement: targetPlacement,
                targetSize: targetSize
            )
            overlayView?.frame = CGRect(
                x: 0,
                y: 0,
                width: parent.containerWidth,
                height: activeBoardHeight
            )
            performWithoutAnimation(in: collectionView) {
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.layoutIfNeeded()
                configureVisibleCells(in: collectionView)
            }
        }

        private func configureVisibleCells(in collectionView: UICollectionView) {
            for cell in collectionView.visibleCells {
                guard let indexPath = collectionView.indexPath(for: cell) else { continue }
                configure(cell, at: indexPath)
            }
        }

        private func configure(
            _ cell: UICollectionViewCell,
            at indexPath: IndexPath
        ) {
            guard currentSlots.indices.contains(indexPath.item) else { return }
            let slot = currentSlots[indexPath.item]
            cell.backgroundColor = .clear
            cell.isHidden = dragContext?.session.itemID == slot.item.id
            cell.contentConfiguration = UIHostingConfiguration {
                CardDebugGridBoardPlaceholderCard(
                    slot: slot,
                    isProblematic: parent.overlapCount > 0,
                    isDragging: parent.activeDragItemID == slot.item.id,
                    isInteractive: true,
                    onDelete: { [weak self] in
                        self?.parent.onDelete(slot.item.id)
                    },
                    onMoveEarlier: { [weak self] in
                        self?.parent.onMoveEarlier(slot.item.id)
                    },
                    onMoveLater: { [weak self] in
                        self?.parent.onMoveLater(slot.item.id)
                    },
                    onSetSize: { [weak self] size in
                        self?.parent.onSetSize(slot.item.id, size)
                    }
                )
            }
            .margins(.all, 0)
        }

        private func boardHeight(for slots: [CardDebugGridBoardLabSlot]) -> CGFloat {
            let maxY = slots.map(\.frame.maxY).max() ?? parent.metrics.verticalPadding + parent.metrics.rowHeight
            return max(parent.boardHeight, maxY + parent.metrics.verticalPadding)
        }

        private func performWithoutAnimation(
            in collectionView: UICollectionView,
            _ updates: () -> Void
        ) {
            UIView.performWithoutAnimation {
                let animationsEnabled = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(false)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                updates()
                CATransaction.commit()
                UIView.setAnimationsEnabled(animationsEnabled)
                collectionView.layoutIfNeeded()
            }
        }
    }
}

private final class CardDebugGridUIKitDragContext {
    let session: CardDebugGridUIKitDragSession
    let snapshotView: UIView
    weak var hiddenCell: UICollectionViewCell?
    var lastTargetPlacement: MemoryCardGridPlacement?
    var latestPreview: CardDebugGridDragPreview?

    init(
        session: CardDebugGridUIKitDragSession,
        snapshotView: UIView,
        hiddenCell: UICollectionViewCell
    ) {
        self.session = session
        self.snapshotView = snapshotView
        self.hiddenCell = hiddenCell
    }
}

final class CardDebugGridBoardOverlayUIView: UIView {
    private var boardHeight: CGFloat = 0
    private var metrics = MemoryDeskBoardMetrics.default
    private var targetPlacement: MemoryCardGridPlacement?
    private var targetSize: MemoryCardSizeToken?

    func configure(
        boardHeight: CGFloat,
        metrics: MemoryDeskBoardMetrics,
        targetPlacement: MemoryCardGridPlacement?,
        targetSize: MemoryCardSizeToken?
    ) {
        self.boardHeight = boardHeight
        self.metrics = metrics
        self.targetPlacement = targetPlacement
        self.targetSize = targetSize
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let cellWidth = metrics.cellWidth(for: bounds.width)
        let rowStep = metrics.rowHeight + metrics.rowSpacing
        let rowCount = max(1, Int(ceil((boardHeight - metrics.verticalPadding * 2) / rowStep)))

        context.setLineWidth(0.7)
        UIColor.secondaryLabel.withAlphaComponent(0.18).setStroke()
        UIColor.systemBackground.withAlphaComponent(0.22).setFill()

        for row in 0..<rowCount {
            for column in 0..<MemoryCardRecipeLayoutPolicy.columnCount {
                let frame = CGRect(
                    x: metrics.horizontalPadding + CGFloat(column) * (cellWidth + metrics.columnSpacing),
                    y: metrics.verticalPadding + CGFloat(row) * rowStep,
                    width: cellWidth,
                    height: metrics.rowHeight
                )
                let path = UIBezierPath(roundedRect: frame, cornerRadius: 6)
                path.fill()
                path.stroke()
            }
        }

        guard
            let targetPlacement,
            let targetSize
        else {
            return
        }

        let targetFrame = frame(
            for: targetPlacement,
            size: targetSize,
            cellWidth: cellWidth
        )
        UIColor.tintColor.withAlphaComponent(0.16).setFill()
        UIColor.tintColor.withAlphaComponent(0.72).setStroke()
        let path = UIBezierPath(roundedRect: targetFrame, cornerRadius: 10)
        path.fill()
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [6, 4])
        path.lineWidth = 2
        path.stroke()
        context.restoreGState()
    }

    private func frame(
        for placement: MemoryCardGridPlacement,
        size: MemoryCardSizeToken,
        cellWidth: CGFloat
    ) -> CGRect {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        return CGRect(
            x: metrics.horizontalPadding + CGFloat(placement.column) * (cellWidth + metrics.columnSpacing),
            y: metrics.verticalPadding + CGFloat(placement.row) * (metrics.rowHeight + metrics.rowSpacing),
            width: CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing,
            height: CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing
        )
    }
}
