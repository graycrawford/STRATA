import RealityKit
import SwiftUI

@main
struct STRATAApp: App {
    @State private var appModel = AppModel()

    init() {
        StrataTickSystem.registerSystem()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)

        ImmersiveSpace(id: AppModel.immersiveSpaceID) {
            StrataImmersiveView()
                .environment(appModel)
                .onDisappear {
                    appModel.immersiveState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        .upperLimbVisibility(.visible)
    }
}
