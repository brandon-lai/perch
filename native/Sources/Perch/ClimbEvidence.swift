import AppKit
import SpriteKit
import PerchCore

@MainActor
extension AppController {
    /// A red panda on a window Perch owns: crawling the face, then gripping a side with its paws on the edge.
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
        guard let top = surfaces.first(where: { $0.windowID == id }) else { throw EvidenceError.fixture("owned top edge unavailable") }
        let day = Rhythm(hour: 15, quietEnabled: false)
        engine = PetEngine(position: Point(top.left + 200, top.y))
        engine.agile = true
        engine.bodyHalfWidth = 16 * rig.pixelScale; engine.muzzleReach = 14 * rig.pixelScale
        engine.perch(on: top, x: top.left + 200)
        guard engine.startScramble(windows: owned) else { throw EvidenceError.fixture("panda could not grip the window") }
        var cases: [String: Bool] = [:]
        for _ in 0..<45 { engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned) }
        render()
        try await waitForRender()
        let wFrame = window.frame
        guard let (panel, view) = overlays.first(where: { $0.0.frame.intersects(wFrame) }) else { throw EvidenceError.noBitmap }
        let scene = view.petScene!
        // Over the top and down the face it comes head first; up it, it climbs; across, it goes side on.
        let facePose = scene.special
        cases["crawlsOnTheWindowFace"] = engine.cling?.side == .front && facePose.map { PixelSprites.climbHead($0) != nil } == true &&
            !scene.sprite.isHidden
        cases["facePoseMatchesHeading"] = engine.cling.map { facePose == PetEngine.pose(for: $0) } ?? false
        cases["crawlPoseIsUpright"] = scene.sprite.zRotation == 0
        // The stride frame comes from how far it has climbed, and the frame is drawn about its torso.
        if let facePose {
            cases["strideFrameFollowsTheClimb"] = scene.strideFrame == engine.strideFrame &&
                scene.displayedFrame.texture === rig.strideFrames(facePose)[engine.strideFrame].texture
        }
        let torso = CGPoint(x: engine.position.x - panel.frame.minX, y: engine.position.y - panel.frame.minY)
        cases["drawnAboutItsTorso"] = scene.sprite.anchorPoint == CGPoint(x: 0.5, y: 0.5) &&
            hypot(scene.sprite.position.x - torso.x, scene.sprite.position.y - torso.y) <= 1 && scene.alphaHit(torso)
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame, to: folder.appendingPathComponent("native-climb-face.png"))

        var reachedSide = false
        for _ in 0..<(30 * 240) where !reachedSide {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned)
            // Climbed back over the top: grab on again so it keeps exploring the window.
            if engine.cling == nil, engine.support?.windowID == id { engine.startScramble(windows: owned) }
            if let grip = engine.cling, grip.side != .front, abs(grip.heading.y) > 0.9 { reachedSide = true }
        }
        guard reachedSide, let grip = engine.cling else { throw EvidenceError.fixture("panda never climbed a side") }
        render()
        try await waitForRender()
        let edge = (grip.side == .left ? wFrame.minX : wFrame.maxX) - panel.frame.minX
        let sprite = scene.sprite.frame, unit = rig.pixelScale, outward: Double = grip.side == .left ? -1 : 1
        let y = engine.position.y - panel.frame.minY
        // Upright and side on: belly to the edge, facing the window, its head the way it's going.
        cases["sideIsUprightAndSideOn"] = scene.sprite.zRotation == 0 &&
            scene.special == (grip.heading.y >= 0 ? .scale : .scaleDown) && (scene.sprite.xScale > 0) == (grip.side == .left)
        cases["sidePawsGripTheWindowEdge"] = abs(sprite.midX - edge) <= 1 &&
            (0..<Int(30 * unit)).contains { scene.alphaHit(CGPoint(x: edge - outward * unit, y: y + Double($0) - 15 * unit)) }
        cases["sideBodyHangsOutsideTheWindow"] = scene.alphaHit(CGPoint(x: edge + outward * 6 * unit, y: y)) &&
            !scene.alphaHit(CGPoint(x: edge - outward * 8 * unit, y: y))
        cases["sideStaysVisible"] = !scene.sprite.isHidden && panel.isVisible
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame, to: folder.appendingPathComponent("native-climb-side.png"))

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
        try writeReport(["cases": cases, "passedChecks": cases.count, "side": grip.side.rawValue,
                         "facePose": facePose?.rawValue ?? "none",
                         "otherAppsWindowsTouched": false], to: folder.appendingPathComponent("climb-evidence.json"))
        print("Climbing verified: \(cases.count) checks on an owned window (side: \(grip.side.rawValue)).")
    }

    /// Our real overlay's SpriteKit texture, cropped to the owned window, with its outline added for reference.
    func captureClimb(scene: PetScene, view: OverlayView, panel: NSPanel, window: NSRect, to url: URL,
                      extras: [SKNode] = [], headroom: Double = 0) throws {
        let rect = window.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY)
        let outline = SKShapeNode(rect: rect); outline.strokeColor = NSColor(hex: "#5F7397"); outline.lineWidth = 2
        outline.zPosition = -10
        var back = rect.insetBy(dx: -120, dy: -40); back.size.height += headroom
        let backdrop = SKShapeNode(rect: back)
        backdrop.fillColor = NSColor(hex: "#9FB0C9"); backdrop.strokeColor = .clear; backdrop.zPosition = -100
        let face = SKShapeNode(rect: rect); face.fillColor = NSColor(hex: "#E9EEF6"); face.strokeColor = .clear; face.zPosition = -50
        for node in [backdrop, face, outline] + extras { scene.addChild(node) }
        defer { for node in [backdrop, face, outline] + extras { node.removeFromParent() } }
        guard let full = view.texture(from: scene)?.cgImage() else { throw EvidenceError.noBitmap }
        let sx = Double(full.width) / Double(scene.size.width), sy = Double(full.height) / Double(scene.size.height)
        var crop = rect.insetBy(dx: -110, dy: -30)
        crop.size.height += headroom
        let pixels = CGRect(x: crop.minX * sx, y: (scene.size.height - crop.maxY) * sy, width: crop.width * sx, height: crop.height * sy)
        guard let image = full.cropping(to: pixels),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: url, options: .atomic)
    }
}
