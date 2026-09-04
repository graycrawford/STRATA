# STRATA for Apple Vision Pro

A native visionOS recreation of STRATA (Unity 2017 + Leap Motion + SteamVR),
built on SwiftUI, RealityKit, ARKit hand tracking and AVAudioEngine.

Poke the cube to begin, and explore. And listen.

## Building

Requirements: Xcode 16 or newer, visionOS 2.0 SDK, a Vision Pro for hand
tracking (the simulator runs the app but has no hands).

1. Import the stems. They are not committed to git (≈175 MB of AIFF); this
   converts the ones the piece uses to Apple Lossless into the app bundle:

       cd STRATA-visionOS
       ./Scripts/import-audio.sh

2. Open `STRATA.xcodeproj`, pick your team under Signing, run on device.

If Xcode ever refuses the project file, `project.yml` regenerates an
equivalent one with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
`xcodegen generate`.

## What is where

```
STRATA/
  App/         SwiftUI shell: launch window, app model, ImmersiveSpace
  Immersive/   StrataWorld — owns tracking, audio, scenes, timeline; ticked per frame
  Tracking/    ARKit HandTrackingProvider + WorldTrackingProvider → collision spheres, head pose
  Cloth/       Position-based cloth sim (pure Swift) + LowLevelMesh renderer
  Audio/       AVAudioEngine bus graph mirroring Unity's Mixer1, and the tanh mappings
  Scene/       Layout constants, materials, instruments, tine field, intro/strata scenes
  Resources/   Audio (plink samples committed; stems imported by the script)
```

## How the original maps onto this

| Unity (2017)                                   | Here                                                     |
| ---------------------------------------------- | -------------------------------------------------------- |
| Leap Motion hands, `hand sphere` colliders     | ARKit `HandTrackingProvider`, 21 spheres per hand (`TrackingSession`) |
| `Cloth` component, tethers, no gravity         | `ClothSimulation`: Verlet + distance/bend constraints + rest-spring |
| `SkinnedMeshRenderer.bounds.extents`           | `ClothMetrics.normalExtent` (bounding-box half extent along the sheet normal) |
| `StrataDisplacement*` / `ClothDisplacementSurfacing` | `ClothInstrument` → `AudioMapping.volumeDecibels` (`80·(tanh(15x)−1)`) |
| `ClothDisplacementLowpass`, `StrataDisplacementLowpass` | `AudioMapping.lowpassHertz` on the master / strata lowpass EQ |
| `WallDisplacementReverb`                       | `AudioMapping.reverbWet` on the master reverb            |
| `HeadVelocitySurfacing`                        | Device-anchor speed → Background+Head bus gain          |
| `AudioSource.pitch` 0.5 / 0.6 / 0.8            | `AVAudioUnitVarispeed.rate` per stem                     |
| `Mixer1` buses, Cloth sends → echo return      | `StemEngine`: mixer nodes, `AVAudioUnitDelay` send/return |
| `PlayTine` capsules with `plink echo` samples  | `TineField`: RealityKit spatial audio at each tine       |
| `PlayHandSound2` (HandCube enters "Cloth")     | `HandStemTrigger`: left hand = terroir part a, right = part b |
| `SwitchScene1` (poke the cube)                 | `IntroScene.pokeTriggered` → `StrataWorld.enterStrata`   |
| `ResetTimer` 235 s, `GlobalShrink` 169–233 s   | `StrataLayout` timeline; `contentRoot` scale             |
| `Haptic1` (SteamVR controller haptics)         | Dropped — no hand haptics on Vision Pro; tines glow on contact |

The scene positions were re-laid-out for a seated/standing viewer facing
forward (the Unity scene had the stack off to the left). All positions and
sizes are constants in `Scene/StrataLayout.swift`; cloth feel per sheet is in
`Cloth/ClothParameters.swift`.

## Where to go next

- **Metal compute cloth.** The sim is plain Swift on the main thread. It is
  written over flat arrays so it can move to a compute kernel that writes the
  `LowLevelMesh` vertex buffer directly.
- **Per-region sound.** `ClothMetrics` already exposes the agitation centroid
  and per-particle displacement; place PHASE / RealityKit spatial sources at
  the centroid so a sheet sounds from where it is being touched.
- **PHASE** for the stems if head-tracked spatialisation of the long layers is
  wanted (they are currently non-spatial, as in the original).
- Tune `ClothParameters` presets and `StrataLayout` on device — the numbers
  are transcriptions of the Unity values, not yet felt through the headset.
