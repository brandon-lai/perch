import AppKit
import SpriteKit
import PerchCore

@MainActor
extension AppController {
    /// Mischief on two windows Perch owns: wall stop, push request, bite tracking and occlusion, ball, and Accessibility.
    func verifyMischief(folder: URL) async throws {
        guard let screen = NSScreen.screens.first else { throw EvidenceError.noScreen }
        let safe = screen.visibleFrame
        let backView = FixtureView(rig: rig), frontView = FixtureView(rig: rig)
        backView.lines = ["Owned window A"]; frontView.lines = ["Owned window B, in front"]
        let back = ownedWindow(view: backView, size: NSSize(width: 620, height: 260), title: "Perch mischief fixture A")
        back.setFrameOrigin(NSPoint(x: safe.minX + 80, y: safe.minY + 120))
        let front = ownedWindow(view: frontView, size: NSSize(width: 320, height: 330), title: "Perch mischief fixture B")
        front.setFrameOrigin(NSPoint(x: back.frame.maxX - 140, y: back.frame.minY + 60))
        defer { back.close(); front.close(); for (panel, _) in overlays { panel.close() }; overlays = [] }
        try await waitForRender()
        let ids: Set<UInt32> = [UInt32(back.windowNumber), UInt32(front.windowNumber)]
        rebuildOverlays()
        func poll() -> [Surface] {
            tracker.poll(includeOwnIDs: ids)
            return Surfaces.build(windows: tracker.windows.filter { ids.contains($0.id) }, screens: tracker.screens, visible: tracker.visible)
        }
        func owned() -> [DesktopWindow] { tracker.windows.filter { ids.contains($0.id) } }
        var surfaces = poll()
        guard let ledge = surfaces.first(where: { $0.windowID == UInt32(back.windowNumber) }) else {
            throw EvidenceError.fixture("owned top edge unavailable")
        }
        var cases: [String: Bool] = [:]
        let day = Rhythm(hour: 15, quietEnabled: false)
        engine = PetEngine(position: Point(ledge.left + 120, ledge.y))
        engine.perch(on: ledge, x: ledge.left + 120)
        engine.bodyHalfWidth = 16 * rig.pixelScale; engine.muzzleReach = 14 * rig.pixelScale
        engine.mischief = Mischief(push: true)
        engine.startWalking(facing: 1)
        var pushed: UInt32?
        for _ in 0..<(30 * 20) where pushed == nil {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned())
            for case .push(let window, _) in engine.takeEvents() { pushed = window }
        }
        let wallX = front.frame.minX
        cases["stopsWithNoseAtWindowInFront"] = engine.position.x + engine.bodyHalfWidth <= wallX + 0.5
        cases["asksToPushTheWindowInTheWay"] = pushed == UInt32(front.windowNumber)
        render()
        cases["visibleWhilePushing"] = overlays.contains { !$0.1.petScene.sprite.isHidden } && engine.trickPose == .push
        var accessibility: [String: Any] = ["trusted": WindowMover.trusted]
        if WindowMover.trusted, let window = owned().first(where: { $0.id == UInt32(front.windowNumber) }) {
            let before = front.frame.minX
            let started = slide(window, by: 40, within: safe, primaryTop: screen.frame.maxY)
            try await Task.sleep(for: .milliseconds(1200))
            accessibility["slideStarted"] = started; accessibility["movedPoints"] = front.frame.minX - before
        } else {
            accessibility["note"] = "Not granted to this build; the Accessibility slide could not run here."
        }

        // Chew, then check the nibble follows window A and hides behind window B.
        engine.mischief = Mischief(chew: true)
        engine.perch(on: ledge, x: ledge.left + 160)
        guard engine.startChew() else { throw EvidenceError.fixture("could not start chewing") }
        var bite: (UInt32, Double)?
        for _ in 0..<(30 * 4) where bite == nil {
            engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned())
            for case .bite(let window, let edge, let offset) in engine.takeEvents() {
                bite = (window, offset); handle(.bite(window: window, edge: edge, offset: offset))
            }
        }
        guard let bite, bite.0 == UInt32(back.windowNumber) else { throw EvidenceError.fixture("chewing left no bite") }
        render()
        func biteView() -> NSView? { overlays.lazy.flatMap { $0.1.biteViews }.first { !$0.isHidden } }
        func biteScreenX() -> Double? {
            guard let view = biteView(), let window = view.window else { return nil }
            return window.frame.minX + view.frame.midX
        }
        let expected = back.frame.minX + bite.1
        cases["biteDrawnAtTheChewedEdge"] = biteScreenX().map { abs($0 - expected) < 1 } ?? false
        if let view = biteView(), let window = view.window {
            cases["biteHangsFromTheTopEdge"] = abs(window.frame.minY + view.frame.maxY - back.frame.maxY) < 1
        }
        back.setFrameOrigin(NSPoint(x: back.frame.minX + 30, y: back.frame.minY))
        try await Task.sleep(for: .milliseconds(150))
        surfaces = poll(); render()
        cases["biteFollowsItsWindow"] = biteScreenX().map { abs($0 - (expected + 30)) < 1 } ?? false

        // Ball: bring it out and let it settle on real window geometry.
        engine.startPlay()
        for _ in 0..<(30 * 3) { engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned()) }
        render()
        cases["ballDrawnInOverlay"] = engine.ball != nil && overlays.contains { !$0.1.ball.isHidden }
        if let moved = surfaces.first(where: { $0.windowID == UInt32(back.windowNumber) }) {
            engine.perch(on: moved, x: expected + 30 + 3.5 * engine.muzzleReach)
            engine.startWalking(facing: -1); engine.startChew()
        }
        for _ in 0..<30 { engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned()) }
        render()
        try await waitForRender()
        try captureMischief(back: back.frame, front: front.frame, to: folder.appendingPathComponent("native-mischief.png"))

        front.setFrameOrigin(NSPoint(x: expected + 30 - 60, y: front.frame.minY))
        try await Task.sleep(for: .milliseconds(150))
        surfaces = poll(); render()
        cases["biteHidesBehindAWindowInFront"] = biteView() == nil
        back.close()
        try await Task.sleep(for: .milliseconds(300))
        surfaces = poll(); render()
        cases["biteGoesAwayWithItsWindow"] = biteView() == nil

        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("mischief: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        try writeReport(["cases": cases, "passedChecks": cases.count, "accessibility": accessibility,
                         "otherAppsWindowsTouched": false, "windowTitlesRead": false],
                        to: folder.appendingPathComponent("mischief-evidence.json"))
        print("Mischief verified: \(cases.count) owned-window checks. Accessibility trusted: \(WindowMover.trusted).")
    }

    /// Our own drawing state only: owned window outlines, the bite image, the pet and ball textures.
    private func captureMischief(back: NSRect, front: NSRect, to url: URL) throws {
        guard let (panel, view) = overlays.first(where: { $0.0.frame.intersects(back) }) else { throw EvidenceError.noBitmap }
        let scene = view.petScene!
        let crop = back.union(front).insetBy(dx: -24, dy: -24).intersection(panel.frame)
        let image = NSImage(size: crop.size, flipped: false) { _ in
            let context = NSGraphicsContext.current!.cgContext
            context.interpolationQuality = .none
            NSColor(hex: "#9FB0C9").setFill(); NSRect(origin: .zero, size: crop.size).fill()
            for (frame, fill) in [(back, "#E9EEF6"), (front, "#DDE5F1")] {
                let r = frame.offsetBy(dx: -crop.minX, dy: -crop.minY)
                NSColor(hex: fill).setFill(); r.fill()
                NSColor(hex: "#5F7397").setStroke(); NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
                NSColor(hex: "#D2DBE8").setFill(); NSRect(x: r.minX + 1, y: r.maxY - 28, width: r.width - 2, height: 27).fill()
            }
            for mark in view.biteViews where !mark.isHidden {
                let r = mark.frame.offsetBy(dx: panel.frame.minX - crop.minX, dy: panel.frame.minY - crop.minY)
                context.draw(BiteMarkView.images[(mark as? BiteMarkView)?.edge ?? .top]!, in: r)
            }
            if !view.ball.isHidden {
                let r = view.ball.frame.offsetBy(dx: panel.frame.minX - crop.minX, dy: panel.frame.minY - crop.minY)
                context.draw(BallView.images[view.ball.frameIndex % 2], in: r)
            }
            for node in [scene.sprite] where !node.isHidden {
                guard let texture = node.texture?.cgImage() else { continue }
                var r = node.frame.offsetBy(dx: panel.frame.minX - crop.minX, dy: panel.frame.minY - crop.minY)
                context.saveGState()
                if node.xScale < 0 { context.translateBy(x: r.midX * 2, y: 0); context.scaleBy(x: -1, y: 1) }
                r = r.standardized
                context.draw(texture, in: r)
                context.restoreGState()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { throw EvidenceError.noBitmap }
        try png.write(to: url, options: .atomic)
    }
}
