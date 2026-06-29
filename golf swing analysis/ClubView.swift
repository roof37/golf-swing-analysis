//
//  ClubView.swift
//  golf swing analysis
//
//  A 3D clubhead at impact, built with SceneKit. The head's orientation shows
//  face angle (yaw), dynamic loft (pitch), and lie angle (roll); a separate
//  ground arrow shows the club path and angle of attack. Drag to orbit.
//

import SwiftUI
import SceneKit

struct ClubView: UIViewRepresentable {
    var swing: SwingModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = buildScene(context: context)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        apply(context: context)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        apply(context: context)
    }

    // MARK: Live orientation

    private func apply(context: Context) {
        let d = Float.pi / 180
        // Head: loft tilts the face back (pitch), face angle yaws, lie rolls.
        context.coordinator.clubNode?.eulerAngles = SCNVector3(
            -Float(swing.dynamicLoft) * d,
            Float(swing.faceAngle) * d,
            Float(swing.lieAngle) * d
        )
        // Path arrow: club path yaws, angle of attack pitches it up/down.
        context.coordinator.pathNode?.eulerAngles = SCNVector3(
            Float(swing.angleOfAttack) * d,
            Float(swing.clubPath) * d,
            0
        )
    }

    // MARK: Scene construction

    private func buildScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        // Camera.
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 40
        camera.position = SCNVector3(0.0, 0.28, 0.85)
        camera.eulerAngles = SCNVector3(-0.32, 0, 0)
        root.addChildNode(camera)

        // Lighting.
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 900
        key.position = SCNVector3(0.6, 1.0, 0.8)
        root.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        root.addChildNode(ambient)

        // Ground reference plane.
        let plane = SCNPlane(width: 0.9, height: 0.9)
        plane.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.15)
        plane.firstMaterial?.isDoubleSided = true
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        planeNode.position = SCNVector3(0, -0.03, 0)
        root.addChildNode(planeNode)

        // Target line (static, down the middle).
        let target = SCNBox(width: 0.004, height: 0.001, length: 0.7, chamferRadius: 0)
        target.firstMaterial?.diffuse.contents = UIColor.secondaryLabel
        let targetNode = SCNNode(geometry: target)
        targetNode.position = SCNVector3(0, -0.028, 0.15)
        root.addChildNode(targetNode)

        // Club + path arrow.
        let club = buildClub()
        context.coordinator.clubNode = club
        root.addChildNode(club)

        let path = buildPathArrow()
        context.coordinator.pathNode = path
        root.addChildNode(path)

        return scene
    }

    private func buildClub() -> SCNNode {
        let container = SCNNode()

        // Head body.
        let head = SCNBox(width: 0.10, height: 0.05, length: 0.022, chamferRadius: 0.006)
        head.firstMaterial?.diffuse.contents = UIColor.darkGray
        head.firstMaterial?.metalness.contents = 0.8
        head.firstMaterial?.roughness.contents = 0.35
        container.addChildNode(SCNNode(geometry: head))

        // Face plate (the +Z side — where the ball is struck).
        let face = SCNBox(width: 0.092, height: 0.042, length: 0.003, chamferRadius: 0.001)
        face.firstMaterial?.diffuse.contents = UIColor.lightGray
        let faceNode = SCNNode(geometry: face)
        faceNode.position = SCNVector3(0, 0, 0.012)
        container.addChildNode(faceNode)

        // Grooves.
        for i in 0..<4 {
            let groove = SCNBox(width: 0.082, height: 0.0015, length: 0.001, chamferRadius: 0)
            groove.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.6)
            let g = SCNNode(geometry: groove)
            g.position = SCNVector3(0, Float(i) * 0.009 - 0.014, 0.0135)
            container.addChildNode(g)
        }

        // Sweet spot.
        let dot = SCNSphere(radius: 0.005)
        dot.firstMaterial?.diffuse.contents = UIColor.systemOrange
        let dotNode = SCNNode(geometry: dot)
        dotNode.position = SCNVector3(0, 0, 0.015)
        container.addChildNode(dotNode)

        // Shaft.
        let shaft = SCNCylinder(radius: 0.005, height: 0.5)
        shaft.firstMaterial?.diffuse.contents = UIColor.black
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(-0.045, 0.24, -0.005)
        shaftNode.eulerAngles = SCNVector3(0, 0, 0.2)
        container.addChildNode(shaftNode)

        return container
    }

    private func buildPathArrow() -> SCNNode {
        let container = SCNNode()
        container.position = SCNVector3(0, -0.026, 0)

        // Shaft of the arrow, pointing +Z.
        let body = SCNBox(width: 0.006, height: 0.002, length: 0.4, chamferRadius: 0)
        body.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0, 0.2)
        container.addChildNode(bodyNode)

        // Arrowhead (cone points +Y by default; rotate to face +Z).
        let head = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.05)
        head.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let headNode = SCNNode(geometry: head)
        headNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        headNode.position = SCNVector3(0, 0, 0.42)
        container.addChildNode(headNode)

        return container
    }

    final class Coordinator {
        var clubNode: SCNNode?
        var pathNode: SCNNode?
    }
}
