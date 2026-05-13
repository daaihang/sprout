import SwiftUI

struct ContentView: View {
    @State private var workspaceStore = DemoWorkspaceFactory.makeWorkspaceStore()
    @State private var selectionStore = DemoWorkspaceFactory.makeSelectionStore()

    var body: some View {
        PrototypeRootView()
            .environment(workspaceStore)
            .environment(selectionStore)
            .task {
                if selectionStore.activeBoardID == nil {
                    selectionStore.activeBoardID = workspaceStore.boards.first?.id
                }
            }
            .onChange(of: workspaceStore.snapshot(), initial: false) { _, snapshot in
                try? PrototypeLocalPersistence.save(snapshot)
            }
    }
}

#Preview {
    ContentView()
}
