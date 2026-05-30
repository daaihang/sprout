import UIKit

final class CardDebugGridBoardCollectionLayout: UICollectionViewLayout {
    private var slots: [CardDebugGridBoardLabSlot] = []
    private var boardSize: CGSize = .zero
    private var activeDragItemID: UUID?
    private var attributesByIndexPath: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var allAttributes: [UICollectionViewLayoutAttributes] = []

    func configure(
        slots: [CardDebugGridBoardLabSlot],
        boardSize: CGSize,
        activeDragItemID: UUID?
    ) {
        self.slots = slots
        self.boardSize = boardSize
        self.activeDragItemID = activeDragItemID
        invalidateLayout()
    }

    override var collectionViewContentSize: CGSize {
        boardSize
    }

    override func prepare() {
        super.prepare()

        attributesByIndexPath = [:]
        allAttributes = slots.enumerated().map { index, slot in
            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = slot.renderFrame
            attributes.zIndex = slot.item.id == activeDragItemID ? 10_000 : Int(slot.layout.zIndex)
            attributesByIndexPath[indexPath] = attributes
            return attributes
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        allAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        attributesByIndexPath[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != collectionView?.bounds.size
    }
}
