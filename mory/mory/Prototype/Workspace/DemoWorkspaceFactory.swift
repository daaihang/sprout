import Foundation

enum DemoWorkspaceFactory {
    static func makeWorkspaceStore() -> PrototypeWorkspaceStore {
        PrototypeWorkspaceStore.makeDefault()
    }

    static func makeSelectionStore() -> PrototypeSelectionStore {
        PrototypeSelectionStore.makeDefault()
    }
}
