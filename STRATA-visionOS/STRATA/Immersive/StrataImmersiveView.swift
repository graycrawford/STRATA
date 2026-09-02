import RealityKit
import SwiftUI

/// The full-immersion space. Builds the world once and hands it to the
/// per-frame system via `StrataWorld.shared`.
struct StrataImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var world: StrataWorld?

    var body: some View {
        RealityView { content in
            let world = StrataWorld(appModel: appModel)
            world.attach(to: &content)
            StrataWorld.shared = world
            self.world = world
            await world.start()
        }
        .onDisappear {
            world?.shutdown()
            world = nil
        }
    }
}
