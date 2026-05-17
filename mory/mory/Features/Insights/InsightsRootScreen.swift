import SwiftUI

struct InsightsRootScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    ArcsScreen()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.storylines.title",
                        subtitle: "insights.hub.storylines.subtitle",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }

                NavigationLink {
                    ReflectionsScreen()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.reflections.title",
                        subtitle: "insights.hub.reflections.subtitle",
                        systemImage: "sparkles"
                    )
                }

                NavigationLink {
                    PeopleScreen()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.people.title",
                        subtitle: "insights.hub.people.subtitle",
                        systemImage: "person.2"
                    )
                }
            } footer: {
                Text("insights.hub.footer")
            }
        }
        .navigationTitle("tab.insights")
    }
}
