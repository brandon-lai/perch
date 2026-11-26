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
        let panda = PetPack(name: "Maple", species: .redPanda, coat: "#C2532B", earColor: "#3B2522", markingColor: "#F4EEE4",
                            marking: .none, ears: .pointed)
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
            engine.agile = true; engine.mischief = Mischief(cursor: true)
            engine.bodyHalfWidth = 16 * scale; engine.muzzleReach = 14 * scale
            engine.perch(on: top, x: x)
        }
        func step(_ pointer: Point?, rhythm: Rhythm = day, windows: [DesktopWindow]? = nil) {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: rhythm,
                        windows: windows ?? owned, cursor: pointer)
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
        // The sprite's anchor is its paw line; its teeth are `reach` above that, along the swung axis.
        let reach = (Double(PixelSprites.side - PixelSprites.hangGripRow) - 0.5) * scale
        let angle = Double(scene.sprite.zRotation)
        let teeth = CGPoint(x: scene.sprite.position.x - reach * sin(angle), y: scene.sprite.position.y + reach * cos(angle))
        cases["hangsByItsTeethOnTheTip"] = scene.special == .hang && hypot(teeth.x - local.x, teeth.y - local.y) <= 1.5
        cases["pointerIsOverThePet"] = scene.alphaHit(local)
        cases["clicksPassThroughWhileItHangs"] = panel.ignoresMouseEvents
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame,
                         to: folder.appendingPathComponent("native-cursor-hang.png"), extras: [arrow(at: local)], headroom: 70 * scale)

        // Ride along a brisk move, swinging out behind it.
        for _ in 0..<10 { pointer.x += 24; pointer.y += 3; step(pointer, windows: []) }
        render(mouseOverride: NSPoint(x: pointer.x, y: pointer.y))
        try await waitForRender()
        cases["ridesAlongStuckToThePointer"] = engine.holdingCursor && engine.position == pointer
        cases["swingsBehindAMovingPointer"] = engine.hangSwing < -0.05 && abs(Double(scene.sprite.zRotation) - engine.hangSwing) < 0.001
        let rideLocal = CGPoint(x: pointer.x - panel.frame.minX, y: pointer.y - panel.frame.minY)
        try captureClimb(scene: scene, view: view, panel: panel, window: wFrame,
                         to: folder.appendingPathComponent("native-cursor-ride.png"), extras: [arrow(at: rideLocal)], headroom: 70 * scale)

        // A quick shake drops it.
        for i in 0..<15 where engine.holdingCursor { pointer.x += i % 2 == 0 ? 60 : -60; step(pointer, windows: []) }
        cases["aShakeDropsIt"] = !engine.holdingCursor && engine.state == .fall

        // Sticky paws: falling past the window's face, it catches hold.
        var caught = false
        for _ in 0..<8 where !caught {
            engine.hold(at: Point(wFrame.midX, wFrame.minY + 260)); engine.release()
            for _ in 0..<60 where !caught { step(nil); caught = engine.cling?.window == id }
        }
        cases["catchesTheWindowFaceWhileFalling"] = caught

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
        print("Cursor play verified: \(cases.count) checks with a synthetic pointer over an owned window.")
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
