import SwiftUI

struct EntityDestinationView: View {
    let entityID: UUID
    let kind: EntityKind

    var body: some View {
        switch kind {
        case .person:
            PersonDetailView(entityID: entityID)
        case .theme, .place, .decision, .activity, .object:
            EntityDetailView(entityID: entityID)
        }
    }
}
