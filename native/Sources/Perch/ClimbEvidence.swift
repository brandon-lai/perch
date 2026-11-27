import AppKit
import SpriteKit
import PerchCore

@MainActor
extension AppController {
    /// A red panda on a window Perch owns, only ever on its edges: backing down its side, side on, then round
    /// the corner to hang from its bottom edge and along it hand over hand.
    func verifyClimb(folder: URL) async throws {
        guard let screen = NSScreen.screens.first else { throw EvidenceError.noScreen }
        let safe = screen.visibleFrame
        let panda = PetPack.redPanda()
        rig = PetRig(pack: panda)
        let canvas = FixtureView(rig: rig)
        canvas.lines = ["Owned window for climbing"]
        let window = ownedWindow(view: canvas, size: NSSize(width: 560, height: 420), title: "Perch climbing fixture")
        window.setFrameOrigin(NSPoint(x: safe.minX + 160, y: safe.minY + 120))
        defer { window.close(); for (panel, _) in overlays { panel.close() }; overlays = [] }
        try await waitForRender()
        let id = UInt32(window.windowNumber)
        rebuildOverlays()
        for (_, view) in overlays { view.petScene.rig = rig }
        func poll() -> ([Surface], [DesktopWindow]) {
            window.orderFrontRegardless()
            tracker.poll(includeOwnIDs: [id])
            let owned = tracker.windows.filter { $0.id == id }
            return (Surfaces.build(windows: owned, screens: tracker.screens, visible: tracker.visible), owned)
        }
        var (surfaces, owned) = poll()
        guard let top = surfaces.first(where: { $0.windowID == id }), let w = owned.first else {
            throw EvidenceError.fixture("owned top edge unavailable")
        }
        let day = Rhythm(hour: 15, quietEnabled: false), unit = rig.pixelScale
        engine = PetEngine(position: Point(top.right - 6, top.y))
        engine.agile = true
        engine.bodyHalfWidth = 16 * unit; engine.muzzleReach = 14 * unit
        engine.hangDepth = Double(PixelSprites.side - PixelSprites.climbLedgeRow - 1) * unit
        engine.perch(on: top, x: top.right - 6)
        guard engine.startEdgeDescent(from: w, toward: 1, surfaces: surfaces, windows: owned) else {
            throw EvidenceError.fixture("panda could not start down the window's side")
        }
        var cases: [String: Bool] = [:], offTheEdges = false
        func step() {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned)
            guard let grip = engine.cling, !engine.turning else { return }
            // Never on the window's face: on a side its paws are on the edge; underneath, it hangs below it.
            switch grip.side {
            case .left: if abs(engine.position.x - w.bounds.minX) > 0.5 { offTheEdges = true }
            case .right: if abs(engine.position.x - w.bounds.maxX) > 0.5 { offTheEdges = true }
            case .under: if engine.position.y > w.bounds.minY - engine.bodyHalfWidth { offTheEdges = true }
            case .top: offTheEdges = true
            }
        }
        for _ in 0..<45 { step() }
        render()
        try await waitForRender()
        let wFrame = window.frame
        guard let (panel, view) = overlays.first(where: { $0.0.frame.intersects(wFrame) }), let grip = engine.cling else {
            throw EvidenceError.noBitmap
        }
        let scene = view.petScene!
        // Backing down the right side, side on: upright, facing the window, paws on the edge, body outside it.
        let edge = wFrame.maxX - panel.frame.minX, y = engine.position.y - panel.frame.minY
        cases["backsDownTheSideSideOn"] = grip.side == .right && scene.special == .scaleDown && scene.sprite.zRotation == 0 &&
            scene.sprite.xScale < 0 && engine.trickPose == .scaleDown
        cases["sidePawsGripTheWindowEdge"] = abs(scene.sprite.frame.midX - edge) <= 1 &&
            (0..<Int(30 * unit)).contains { scene.alphaHit(CGPoint(x: edge - unit, y: y + Double($0) - 15 * unit)) }
        cases["sideBodyHangsOutsideTheWindow"] = scene.alphaHit(CGPoint(x: edge + 6 * unit, y: y)) &&
            !scene.alphaHit(CGPoint(x: edge - 8 * unit, y: y))
        cases["strideFrameFollowsTheClimb"] = scene.strideFrame == engine.strideFrame &&
            scene.displayedFrame.texture === rig.strideFrames(.scaleDown)[engine.strideFrame].texture
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame, to: folder.appendingPathComponent("native-climb-side.png"))

        // Too high above the floor to step off: round the corner to hang under the window, then along it.
        var under = false, moving = 0
        for _ in 0..<(30 * 40) where moving < 20 {
            step()
            if engine.cling?.side == .under, !engine.turning { under = true; moving = engine.climbHolding ? moving : moving + 1 }
        }
        guard under else { throw EvidenceError.fixture("panda never hung under the window") }
        render()
        try await waitForRender()
        let bottom = wFrame.minY - panel.frame.minY, x = engine.position.x - panel.frame.minX
        cases["hangsUnderTheBottomEdgeSideOn"] = engine.cling?.side == .under && scene.special == .shimmy &&
            scene.sprite.zRotation == 0 && !scene.sprite.isHidden
        cases["forepawsGripTheBottomEdge"] = (-8...8).contains { scene.alphaHit(CGPoint(x: x + Double($0) * unit, y: bottom - unit)) } &&
            !(-8...8).contains { scene.alphaHit(CGPoint(x: x + Double($0) * unit, y: bottom + 3 * unit)) }
        cases["neverClimbsTheWindowFace"] = !offTheEdges
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame, to: folder.appendingPathComponent("native-climb-under.png"),
                         footroom: 40 * unit)

        // Carried along when its window moves slowly.
        let before = engine.position
        window.setFrameOrigin(NSPoint(x: window.frame.minX + 6, y: window.frame.minY))
        try await Task.sleep(for: .milliseconds(120))
        (surfaces, owned) = poll()
        engine.tick(dt: 0.001, surfaces: surfaces, screens: tracker.screens, rhythm: day, surfaceDT: 0.12, windows: owned)
        cases["ridesItsWindow"] = engine.cling != nil && abs(engine.position.x - before.x - 6) < 1

        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("climb: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        try writeReport(["cases": cases, "passedChecks": cases.count, "otherAppsWindowsTouched": false],
                        to: folder.appendingPathComponent("climb-evidence.json"))
        print("Climbing verified: \(cases.count) checks on an owned window, only ever on its edges.")
    }

    /// Our real overlay's SpriteKit texture, cropped to the owned window, with its outline added for reference.
    func captureClimb(scene: PetScene, view: OverlayView, panel: NSPanel, window: NSRect, to url: URL,
                      extras: [SKNode] = [], headroom: Double = 0, footroom: Double = 0) throws {
        let rect = window.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY)
        let outline = SKShapeNode(rect: rect); outline.strokeColor = NSColor(hex: "#5F7397"); outline.lineWidth = 2
        outline.zPosition = -10
        var back = rect.insetBy(dx: -120, dy: -40); back.size.height += headroom + footroom; back.origin.y -= footroom
        let backdrop = SKShapeNode(rect: back)
        backdrop.fillColor = NSColor(hex: "#9FB0C9"); backdrop.strokeColor = .clear; backdrop.zPosition = -100
        let face = SKShapeNode(rect: rect); face.fillColor = NSColor(hex: "#E9EEF6"); face.strokeColor = .clear; face.zPosition = -50
        for node in [backdrop, face, outline] + extras { scene.addChild(node) }
        defer { for node in [backdrop, face, outline] + extras { node.removeFromParent() } }
        guard let full = view.texture(from: scene)?.cgImage() else { throw EvidenceError.noBitmap }
        let sx = Double(full.width) / Double(scene.size.width), sy = Double(full.height) / Double(scene.size.height)
        var crop = rect.insetBy(dx: -110, dy: -30)
        crop.size.height += headroom + footroom; crop.origin.y -= footroom
        let pixels = CGRect(x: crop.minX * sx, y: (scene.size.height - crop.maxY) * sy, width: crop.width * sx, height: crop.height * sy)
        guard let image = full.cropping(to: pixels),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: url, options: .atomic)
    }
}
