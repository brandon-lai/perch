import AppKit
import SpriteKit
import PerchCore

@MainActor
extension AppController {
    /// A red panda playing with a synthetic pointer above a window Perch owns. The real pointer is never moved
    /// or read here: every position below is made up for the check.
    func verifyCursorPlay(folder: URL) async throws {
        guard let screen = NSScreen.screens.first else { throw EvidenceError.noScreen }
        let safe = screen.visibleFrame
        let panda = PetPack.redPanda()
        rig = PetRig(pack: panda)
        let canvas = FixtureView(rig: rig)
        canvas.lines = ["Owned window for cursor play"]
        let window = ownedWindow(view: canvas, size: NSSize(width: 560, height: 360), title: "Perch cursor fixture")
        window.setFrameOrigin(NSPoint(x: safe.minX + 160, y: safe.minY + 100))
        defer { window.close(); for (panel, _) in overlays { panel.close() }; overlays = [] }
        try await waitForRender()
        let id = UInt32(window.windowNumber)
        rebuildOverlays()
        for (_, view) in overlays { view.petScene.rig = rig }
        window.orderFrontRegardless()
        tracker.poll(includeOwnIDs: [id])
        let owned = tracker.windows.filter { $0.id == id }
        let surfaces = Surfaces.build(windows: owned, screens: tracker.screens, visible: tracker.visible)
        guard let top = surfaces.first(where: { $0.windowID == id }) else { throw EvidenceError.fixture("owned top edge unavailable") }
        let scale = rig.pixelScale, day = Rhythm(hour: 15, quietEnabled: false)
        func fresh(at x: Double) {
            engine = PetEngine(position: Point(x, top.y))
            engine.agile = true; engine.mischief = Mischief(cursor: true); engine.bambooPointer = true
            engine.bodyHalfWidth = 16 * scale; engine.muzzleReach = 14 * scale
            engine.perch(on: top, x: x)
        }
        // Like the app, the panda goes for the bottom end of the bamboo on the pointer.
        func step(_ pointer: Point?, rhythm: Rhythm = day, windows: [DesktopWindow]? = nil) {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: rhythm, windows: windows ?? owned,
                        cursor: pointer.map { Bamboo.end(tip: $0, remaining: engine.bamboo, scale: scale) })
        }
        let wFrame = window.frame
        var cases: [String: Bool] = [:]

        // Stalk, swipe and grab a pointer lingering above the window's top edge.
        fresh(at: top.left + 150)
        var pointer = Point(top.left + 330, top.y + 40 * scale)
        var stalked = false, swiped = false
        for _ in 0..<(30 * 40) where !engine.holdingCursor {
            step(pointer, windows: [])
            stalked = stalked || engine.running
            swiped = swiped || engine.trickPose == .grab
        }
        cases["stalksThePointer"] = stalked
        cases["rearsUpToSwipeAtIt"] = swiped
        cases["grabsIt"] = engine.holdingCursor
        for _ in 0..<60 { step(pointer, windows: []) }
        render(mouseOverride: NSPoint(x: pointer.x, y: pointer.y))
        try await waitForRender()
        guard let (panel, view) = overlays.first(where: { $0.0.frame.contains(NSPoint(x: pointer.x, y: pointer.y)) }) else {
            throw EvidenceError.noBitmap
        }
        let scene = view.petScene!
        let local = CGPoint(x: pointer.x - panel.frame.minX, y: pointer.y - panel.frame.minY)
        let end = Bamboo.end(tip: pointer, remaining: engine.bamboo, scale: scale)
        let localEnd = CGPoint(x: end.x - panel.frame.minX, y: end.y - panel.frame.minY)
        // The sprite's anchor is its paw line; its teeth are `reach` above that, along the swung axis.
        let reach = (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) * scale
        let angle = Double(scene.sprite.zRotation)
        let teeth = CGPoint(x: scene.sprite.position.x - reach * sin(angle), y: scene.sprite.position.y + reach * cos(angle))
        cases["hangsByItsTeethOnTheBambooEnd"] = scene.special == .hang && hypot(teeth.x - localEnd.x, teeth.y - localEnd.y) <= 1.5
        let stalk = view.bamboo
        cases["bambooSitsOnThePointerTip"] = !stalk.isHidden && abs(stalk.frame.minX + Bamboo.centerX * scale - local.x) <= 1 &&
            abs(stalk.frame.maxY - 1.5 * scale - local.y) <= 1 && stalk.hitTest(NSPoint(x: stalk.frame.midX, y: stalk.frame.midY)) == nil
        cases["pointerIsOverThePet"] = scene.alphaHit(localEnd)
        cases["clicksPassThroughWhileItHangs"] = panel.ignoresMouseEvents
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame,
                         to: folder.appendingPathComponent("native-cursor-hang.png"),
                         extras: stalkNodes(stalk, panel: panel) + [arrow(at: local)], headroom: 70 * scale)

        // It eats the stalk from the bottom up while it hangs on.
        let before = stalk.length
        for _ in 0..<60 { step(pointer, windows: []) }
        render(mouseOverride: NSPoint(x: pointer.x, y: pointer.y))
        cases["eatsTheBambooFromTheBottomUp"] = engine.holdingCursor && stalk.length < before &&
            abs(engine.position.y - Bamboo.end(tip: pointer, remaining: engine.bamboo, scale: scale).y) < 0.01

        // Ride along a brisk move, swinging out behind it.
        for _ in 0..<10 { pointer.x += 24; pointer.y += 3; step(pointer, windows: []) }
        render(mouseOverride: NSPoint(x: pointer.x, y: pointer.y))
        try await waitForRender()
        cases["ridesAlongStuckToThePointer"] = engine.holdingCursor &&
            engine.position == Bamboo.end(tip: pointer, remaining: engine.bamboo, scale: scale)
        cases["swingsBehindAMovingPointer"] = engine.hangSwing < -0.05 && abs(Double(scene.sprite.zRotation) - engine.hangSwing) < 0.001
        let rideLocal = CGPoint(x: pointer.x - panel.frame.minX, y: pointer.y - panel.frame.minY)
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame,
                         to: folder.appendingPathComponent("native-cursor-ride.png"),
                         extras: stalkNodes(stalk, panel: panel) + [arrow(at: rideLocal)], headroom: 70 * scale)

        // A quick shake drops it.
        for i in 0..<15 where engine.holdingCursor { pointer.x += i % 2 == 0 ? 60 : -60; step(pointer, windows: []) }
        cases["aShakeDropsIt"] = !engine.holdingCursor && engine.state == .fall

        // Sticky paws: falling right past the window's side, it grabs the edge (never its face).
        var caught = false, onFace = false
        for _ in 0..<8 where !caught {
            engine.hold(at: Point(wFrame.minX - engine.bodyHalfWidth * 0.4, wFrame.minY + 260)); engine.release()
            for _ in 0..<60 where !caught {
                step(nil); caught = engine.cling?.window == id
                if let grip = engine.cling, grip.side == .left, abs(engine.position.x - wFrame.minX) > 0.5 { onFace = true }
            }
        }
        cases["catchesTheWindowSideWhileFalling"] = caught && engine.cling?.side == .left && !onFace

        // Asleep up high, it drapes over the edge with its belly on it.
        fresh(at: top.left + 220)
        let night = Rhythm(hour: 23, quietStart: 22, quietEnd: 7)
        step(nil, rhythm: night)
        render()
        try await waitForRender()
        let drapeBottom = top.y - Double(PixelSprites.side - 1 - PixelSprites.drapeLedgeRow) * scale - panel.frame.minY
        cases["drapesOverTheEdgeToSleep"] = engine.trickPose == .drape && scene.special == .drape &&
            abs(Double(scene.sprite.frame.minY) - drapeBottom) <= 1 && !scene.sprite.isHidden
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame, to: folder.appendingPathComponent("native-drape.png"),
                         headroom: 12 * scale)

        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("cursor: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        try writeReport(["cases": cases, "passedChecks": cases.count, "pointer": "synthetic",
                         "realPointerMoved": false, "otherAppsWindowsTouched": false],
                        to: folder.appendingPathComponent("cursor-evidence.json"))
        print("Cursor play verified: \(cases.count) checks with a synthetic pointer and its bamboo over an owned window.")
    }

    /// The real BambooView's image at its real frame, added to the scene capture (the view itself is AppKit).
    private func stalkNodes(_ stalk: BambooView, panel: NSPanel) -> [SKNode] {
        guard !stalk.isHidden else { return [] }
        let node = SKSpriteNode(texture: SKTexture(cgImage: BambooView.images[stalk.length]))
        node.texture?.filteringMode = .nearest
        node.size = stalk.frame.size; node.anchorPoint = .zero; node.position = stalk.frame.origin; node.zPosition = 50
        return [node]
    }

    /// A stand-in arrow pointer for the evidence image; the real pointer is never drawn into overlays.
    private func arrow(at tip: CGPoint) -> SKShapeNode {
        let outline: [(Double, Double)] = [(0, 0), (0, -17), (4, -13), (7, -20), (10, -19), (7, -12), (12, -12)]
        let path = CGMutablePath()
        path.addLines(between: outline.map { CGPoint(x: tip.x + $0.0, y: tip.y + $0.1) }); path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = .black; node.strokeColor = .white; node.lineWidth = 1.5; node.zPosition = 100
        return node
    }
}
