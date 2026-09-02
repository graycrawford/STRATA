import SwiftUI

/// The small window you see before entering. Mirrors the README of the
/// original: poke the cube to begin, and explore.
struct LaunchView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        @Bindable var appModel = appModel
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("STRATA")
                    .font(.system(size: 56, weight: .thin, design: .default))
                    .tracking(14)
                Text("a musical space by OPTIA")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("Poke the cube to begin, and explore. And listen.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Toggle("Show fingertip markers", isOn: $appModel.showHandMarkers)
                .toggleStyle(.switch)
                .frame(maxWidth: 320)

            switch appModel.immersiveState {
            case .closed:
                Button("Enter") { Task { await enter() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
            case .inTransition:
                ProgressView()
            case .open:
                VStack(spacing: 10) {
                    if !appModel.phaseDescription.isEmpty {
                        Text(appModel.phaseDescription)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Button("Leave") { Task { await leave() } }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        }
        .padding(48)
        .frame(minWidth: 520)
    }

    private func enter() async {
        appModel.immersiveState = .inTransition
        switch await openImmersiveSpace(id: AppModel.immersiveSpaceID) {
        case .opened:
            appModel.immersiveState = .open
        case .userCancelled, .error:
            appModel.immersiveState = .closed
        @unknown default:
            appModel.immersiveState = .closed
        }
    }

    private func leave() async {
        appModel.immersiveState = .inTransition
        await dismissImmersiveSpace()
        appModel.immersiveState = .closed
    }
}
