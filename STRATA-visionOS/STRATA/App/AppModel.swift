import SwiftUI

@MainActor
@Observable
final class AppModel {
    static let immersiveSpaceID = "STRATAImmersiveSpace"

    enum ImmersiveState { case closed, inTransition, open }

    var immersiveState: ImmersiveState = .closed
    var showHandMarkers = true
    var phaseDescription = ""
}
