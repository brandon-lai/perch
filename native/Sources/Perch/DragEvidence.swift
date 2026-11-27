import AppKit
import SpriteKit
import PerchCore

@MainActor
extension AppController {
    /// Picking up and carrying the red panda (awake and asleep), petting and waking it, and moving its tree, all
    /// through AppKit's own mouse-event dispatch to the overlay panel, which isn't key and belongs to an app that's
    /// never active. The events are made up and handed straight to Perch's own panel: the real pointer is never
    /// moved, and no other app sees them.
    func verifyDrag(folder: URL) async throws {
        guard let screen = NSScreen.screens.first else { throw EvidenceError.noScreen }
        let safe = screen.visibleFrame
        preferences = Preferences()
        rig = PetRig(pack: .redPanda())
        let canvas = FixtureView(rig: rig)
        canvas.lines = ["Owned window for picking up the panda"]
        let window = ownedWindow(view: canvas, size: NSSize(width: 560, height: 300), title: "Perch drag fixture")
        window.setFrameOrigin(NSPoint(x: safe.minX + 220, y: safe.minY + 170))
        defer { timer?.invalidate(); timer = nil; window.close(); for (panel, _) in overlays { panel.close() }; overlays = [] }
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
        engine = PetEngine(position: Point(top.left + 160, top.y))
        engine.agile = true; engine.bodyHalfWidth = 16 * scale; engine.muzzleReach = 14 * scale
        engine.hangDepth = Double(PixelSprites.side - PixelSprites.climbLedgeRow - 1) * scale
        engine.perch(on: top, x: top.left + 160)
        func step(_ ticks: Int = 1) {
            for _ in 0..<ticks {
                engine.tick(dt: 1.0 / 30, surfaces: surfaces, screens: tracker.screens, rhythm: day, windows: owned)
            }
            render()
        }
        step()
        guard let (panel, view) = overlays.first(where: { $0.0.frame.contains(NSPoint(x: engine.position.x, y: engine.position.y)) })
        else { throw EvidenceError.fixture("no overlay under the panda") }
        let scene = view.petScene!
        /// A pixel of the panda that takes clicks, on screen: the one nearest the middle of its sprite.
        func onThePanda() -> NSPoint? {
            let frame = scene.sprite.frame
            var best: (CGPoint, Double)?
            for y in stride(from: frame.minY + 0.5, to: frame.maxY, by: 1.5) {
                for x in stride(from: frame.minX + 0.5, to: frame.maxX, by: 1.5) where scene.alphaHit(CGPoint(x: x, y: y)) {
                    let d = Double(hypot(x - frame.midX, y - frame.midY))
                    if best.map({ d < $0.1 }) ?? true { best = (CGPoint(x: x, y: y), d) }
                }
            }
            return best.map { NSPoint(x: $0.0.x + panel.frame.minX, y: $0.0.y + panel.frame.minY) }
        }
        var time = ProcessInfo.processInfo.systemUptime
        func send(_ type: NSEvent.EventType, _ point: NSPoint, clicks: Int = 1, to target: NSPanel? = nil) {
            let target = target ?? panel
            time += 0.05
            guard let event = NSEvent.mouseEvent(with: type, location: target.convertPoint(fromScreen: point), modifierFlags: [],
                                                 timestamp: time, windowNumber: target.windowNumber, context: nil, eventNumber: 0,
                                                 clickCount: clicks, pressure: type == .leftMouseUp ? 0 : 1) else { return }
            target.sendEvent(event)
            // A press starts the app's own timer; this fixture drives the engine itself.
            timer?.invalidate(); timer = nil
        }
        var cases: [String: Bool] = [:]
        /// Every press below is a first press: the panel isn't key, as when you reach for the panda while working.
        func unkey(_ target: NSPanel) { if target.isKeyWindow { target.orderOut(nil); target.orderFrontRegardless() } }

        // Awake: the very first press picks it up, though Perch's panel isn't key and Perch is never active.
        unkey(panel)
        guard let grip = onThePanda() else { throw EvidenceError.fixture("no opaque panda pixel") }
        let start = engine.position
        cases["thePanelIsNotKeyBeforehand"] = !panel.isKeyWindow
        send(.leftMouseDown, grip)
        cases["theFirstPressPicksItUp"] = dragOriginal != nil && engine.state == .held
        let carried = NSPoint(x: grip.x + 140, y: grip.y + 60)
        send(.leftMouseDragged, NSPoint(x: grip.x + 70, y: grip.y + 30)); send(.leftMouseDragged, carried)
        cases["draggingCarriesItWithThePointer"] = abs(engine.position.x - start.x - 140) < 1 && abs(engine.position.y - start.y - 60) < 1
        send(.leftMouseUp, carried)
        step(60)
        cases["lettingGoDropsItOntoTheWindowBelow"] = dragOriginal == nil && engine.support?.windowID == id &&
            abs(engine.position.x - start.x - 140) < 2

        // Asleep: carried limp, still dozing with its z's, and set down gently it naps on where it's put.
        engine.takeNap()
        for _ in 0..<(30 * 8) where engine.state != .sleep { step() }
        let napper = engine.position
        guard engine.state == .sleep, let sleeper = onThePanda() else { throw EvidenceError.fixture("the panda didn't settle for a nap") }
        unkey(panel)
        send(.leftMouseDown, sleeper)
        let place = NSPoint(x: sleeper.x - 130, y: sleeper.y + 24)
        send(.leftMouseDragged, NSPoint(x: sleeper.x - 60, y: sleeper.y + 12)); send(.leftMouseDragged, place)
        step()
        cases["pickedUpAsleepItDozesOnInYourHand"] = engine.state == .held && engine.trickPose == .dozing &&
            scene.special == .dozing && scene.bubbleKind == .zs && !scene.bubble.isHidden
        try captureClimb(scene: scene, view: view, panel: panel, window: window.frame,
                         to: folder.appendingPathComponent("native-carried-asleep.png"), headroom: 90 * scale)
        send(.leftMouseUp, place)
        step(45)
        cases["setDownGentlyItNapsOnWhereItsPut"] = engine.state == .sleep && engine.napping &&
            engine.support?.windowID == id && engine.trickPose == .drape && abs(engine.position.x - (napper.x - 130)) < 2

        // Asleep, a click pets it and it snuggles in; a double-click wakes it.
        guard let pat = onThePanda() else { throw EvidenceError.fixture("no opaque pixel on the sleeping panda") }
        unkey(panel)
        send(.leftMouseDown, pat); send(.leftMouseUp, pat)
        step()
        cases["aClickPetsItAndItSnugglesIn"] = engine.state == .sleep && engine.trickPose == .drapeSnuggle
        unkey(panel)
        send(.leftMouseDown, pat, clicks: 2); send(.leftMouseUp, pat, clicks: 2)
        step()
        cases["aDoubleClickWakesIt"] = engine.state != .sleep && engine.action == .stretch

        // Its tree: the first press on the trunk drags it along too.
        guard let (index, tree) = treeLocation else { throw EvidenceError.fixture("no visible display for the tree") }
        let treePanel = overlays[index].0
        unkey(treePanel)
        let trunk = NSPoint(x: tree.trunkX, y: tree.origin.y + 12 * scale)
        send(.leftMouseDown, trunk, to: treePanel)
        send(.leftMouseDragged, NSPoint(x: trunk.x + 75, y: trunk.y), to: treePanel)
        send(.leftMouseDragged, NSPoint(x: trunk.x + 150, y: trunk.y), to: treePanel)
        send(.leftMouseUp, NSPoint(x: trunk.x + 150, y: trunk.y), to: treePanel)
        cases["theFirstPressOnTheTreeDragsIt"] = (treeLocation?.tree.trunkX).map { abs($0 - tree.trunkX - 150) < 1 } ?? false

        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("drag: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        try writeReport(["cases": cases, "passedChecks": cases.count, "events": "synthetic, sent to Perch's own panel",
                         "realPointerMoved": false, "otherAppsWindowsTouched": false],
                        to: folder.appendingPathComponent("drag-evidence.json"))
        print("Dragging verified: \(cases.count) checks through AppKit's mouse-event dispatch to a panel that isn't key.")
    }
}
