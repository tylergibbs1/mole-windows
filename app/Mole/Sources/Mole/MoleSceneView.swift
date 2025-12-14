import QuartzCore
import SceneKit
import SwiftUI
import GameplayKit

// A native 3D SceneKit View
struct MoleSceneView: NSViewRepresentable {
    @Binding var state: AppState
    @Binding var rotationVelocity: CGSize // Interaction Input

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()

        // Scene Setup
        let scene = SCNScene()
        scnView.scene = scene
        scnView.backgroundColor = NSColor.clear
        scnView.delegate = context.coordinator // Delegate for Game Loop
        scnView.isPlaying = true // Critical: Ensure the loop runs!

        // 1. The Planet (Sphere)
        let sphereGeo = SCNSphere(radius: 1.4)
        sphereGeo.segmentCount = 128

        let sphereNode = SCNNode(geometry: sphereGeo)
        sphereNode.name = "molePlanet"

        // Mars Material (Red/Dusty)
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased

        // Generate Noise Texture
        let noiseSource = GKPerlinNoiseSource(frequency: 1.0, octaveCount: 3, persistence: 0.4, lacunarity: 2.0, seed: Int32.random(in: 0...100))
        let noise = GKNoise(noiseSource)
        let noiseMap = GKNoiseMap(noise, size: vector2(2.0, 1.0), origin: vector2(0.0, 0.0), sampleCount: vector2(512, 256), seamless: true)
        let texture = SKTexture(noiseMap: noiseMap)

        // Use Noise for Diffuse (Color) - Mapping noise to Orange/Red Gradient
        // Ideally we map values to colors, but SCNMaterial takes the texture as is (Black/White).
        // To get Red Mars, we can tint it or use it as a mask.
        // Simple trick: Set base color to Red, use noise for Roughness/Detail.

        material.diffuse.contents = NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.1, alpha: 1.0)

        // Use noise for surface variation
        material.roughness.contents = texture

        // Also use noise for Normal Map (Bumpiness) -> This gives the real terrain look
        material.normal.contents = texture
        material.normal.intensity = 0.5 // Subtler bumps, no black stripes

        sphereNode.geometry?.materials = [material]
        scene.rootNode.addChildNode(sphereNode)

        // 2. Lighting
        // A. Omni (Sun)
        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light?.type = .omni
        sunLight.light?.color = NSColor(calibratedWhite: 1.0, alpha: 1.0)
        sunLight.light?.intensity = 1500
        sunLight.position = SCNVector3(x: 5, y: 5, z: 10)
        scene.rootNode.addChildNode(sunLight)

        // B. Rim Light (Mars Atmosphere)
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .spot
        rimLight.light?.color = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)
        rimLight.light?.intensity = 2500
        rimLight.position = SCNVector3(x: -5, y: 2, z: -5)
        rimLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(rimLight)

        // C. Ambient
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.05, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4)
        scene.rootNode.addChildNode(cameraNode)

        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false

        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        // Just update velocity binding for the coordinator to use
        context.coordinator.parent = self
    }

    // Coordinator to handle Frame-by-Frame updates
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: MoleSceneView

        init(_ parent: MoleSceneView) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let planet = renderer.scene?.rootNode.childNode(withName: "molePlanet", recursively: false) else { return }

            // Auto Rotation Speed
            // Back to visible speed
            let baseRotation = 0.01

            // Drag Influence
            let dragInfluence = Double(parent.rotationVelocity.width) * 0.0005

            // Vertical Tilt (X-Axis) + Slow Restore to 0
            let tiltInfluence = Double(parent.rotationVelocity.height) * 0.0005

            // Apply Rotation
            planet.eulerAngles.y += CGFloat(baseRotation + dragInfluence)
            planet.eulerAngles.x += CGFloat(tiltInfluence)
        }
    }
}
