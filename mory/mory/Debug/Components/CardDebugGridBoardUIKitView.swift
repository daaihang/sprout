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
    var onPreviewChanged: (CardDebugGridDragPreview) -> Void
    var onDragEnded: (CardDebugGridDragPreview) -> Void
    var onDragCancelled: () -> Void
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
        private var activeSession: CardDebugGridUIKitDragSession?
        private var activePreview: CardDebugGridDragPreview?

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

            layout.configure(
                slots: parent.slots,
                boardSize: CGSize(width: parent.containerWidth, height: parent.boardHeight),
                activeDragItemID: parent.activeDragItemID
            )

            overlayView?.configure(
                boardHeight: parent.boardHeight,
                metrics: parent.metrics,
                targetPlacement: parent.activeDragTarget,
                targetSize: parent.activeDragItemID.flatMap { id in
                    parent.slots.first(where: { $0.item.id == id })?.item.size
                }
            )
            overlayView?.frame = CGRect(
                x: 0,
                y: 0,
                width: parent.containerWidth,
                height: parent.boardHeight
            )

            let nextIDs = parent.slots.map(\.item.id)
            if nextIDs != itemIDs {
                itemIDs = nextIDs
                collectionView.reloadData()
            } else {
                collectionView.collectionViewLayout.invalidateLayout()
                configureVisibleCells(in: collectionView)
            }

            let maxOffsetY = max(0, parent.boardHeight - collectionView.bounds.height)
            if collectionView.contentOffset.y > maxOffsetY {
                collectionView.contentOffset.y = max(0, maxOffsetY)
            }
        }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            parent.slots.count
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

        func collectionView(
            _ collectionView: UICollectionView,
            canMoveItemAt indexPath: IndexPath
        ) -> Bool {
            parent.slots.indices.contains(indexPath.item)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            moveItemAt sourceIndexPath: IndexPath,
            to destinationIndexPath: IndexPath
        ) {
            // The debug board persists grid placement, not collection index movement.
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let collectionView = recognizer.view as? UICollectionView else { return }
            let visibleLocation = recognizer.location(in: collectionView)
            let contentLocation = CGPoint(
                x: visibleLocation.x + collectionView.contentOffset.x,
                y: visibleLocation.y + collectionView.contentOffset.y
            )

            switch recognizer.state {
            case .began:
                guard let session = CardDebugGridBoardLabModel.beginDrag(at: contentLocation, in: parent.slots) else {
                    recognizer.isEnabled = false
                    recognizer.isEnabled = true
                    return
                }
                activeSession = session
                collectionView.isScrollEnabled = false
                if let index = parent.slots.firstIndex(where: { $0.item.id == session.itemID }) {
                    _ = collectionView.indexPathForItem(at: visibleLocation)
                    collectionView.beginInteractiveMovementForItem(at: IndexPath(item: index, section: 0))
                }
                updatePreview(for: session, at: contentLocation, in: collectionView)

            case .changed:
                guard let session = activeSession else { return }
                collectionView.updateInteractiveMovementTargetPosition(visibleLocation)
                updatePreview(for: session, at: contentLocation, in: collectionView)

            case .ended:
                guard let session = activeSession else {
                    cancelDrag(in: collectionView)
                    return
                }
                collectionView.updateInteractiveMovementTargetPosition(visibleLocation)
                let preview = CardDebugGridBoardLabModel.dragPreview(
                    for: session,
                    at: contentLocation,
                    boardWidth: parent.containerWidth,
                    metrics: parent.metrics,
                    in: parent.storedItems
                )
                collectionView.endInteractiveMovement()
                finishDrag(in: collectionView)
                parent.onDragEnded(preview)

            case .cancelled, .failed:
                collectionView.cancelInteractiveMovement()
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

        private func updatePreview(
            for session: CardDebugGridUIKitDragSession,
            at contentLocation: CGPoint,
            in collectionView: UICollectionView
        ) {
            let preview = CardDebugGridBoardLabModel.dragPreview(
                for: session,
                at: contentLocation,
                boardWidth: parent.containerWidth,
                metrics: parent.metrics,
                in: parent.storedItems
            )
            activePreview = preview
            parent.onPreviewChanged(preview)
            configureVisibleCells(in: collectionView)
        }

        private func finishDrag(in collectionView: UICollectionView) {
            activeSession = nil
            activePreview = nil
            collectionView.isScrollEnabled = true
        }

        private func cancelDrag(in collectionView: UICollectionView) {
            finishDrag(in: collectionView)
            parent.onDragCancelled()
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
            guard parent.slots.indices.contains(indexPath.item) else { return }
            let slot = parent.slots[indexPath.item]
            cell.backgroundColor = .clear
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
