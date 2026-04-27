import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        PlannerShellView()
    }
}

#Preview {
    ContentView()
        .modelContainer(AppConfiguration.makeModelContainer())
}
